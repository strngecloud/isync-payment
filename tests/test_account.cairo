use crate::setup::owner;
use crate::setup::zero_address;
use crate::setup::random_user;
use crate::setup::deploy_erc20;
use crate::setup::deploy_account;
use isyncpayment::account::account::Account;
use isyncpayment::events::accountEvents::AccountFiatDeposit;
use isyncpayment::interfaces::iaccount::IAccountDispatcherTrait;
use isyncpayment::interfaces::ierc20::SyncTokenDispatcherTrait;
use snforge_std::{EventSpyAssertionsTrait, EventSpyTrait,
    spy_events, start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;


#[test]
fn test_constructor() {
    let (account_address, account, _) = deploy_account();

    // Test that constructor initializes properly
    assert!(account_address != 0.try_into().unwrap(), "Account should be deployed");

    // Test initial values
    assert_eq!(account.get_default_fiat_currency(), 0, "Default currency should be 0");
    assert_eq!(account.get_liquidity_bridge(), 0.try_into().unwrap(), "Bridge should be zero");
}

#[test]
fn test_fiat_deposit() {
    let (account_address, account, _) = deploy_account();
    let mut spy = spy_events();

    start_cheat_caller_address(account_address, account_address);

    let currency = 'USD';
    let amount = 1000_u128;

    // Test deposit
    account.deposit_fiat(currency, amount);

    // Verify balance
    assert_eq!(account.get_fiat_balance(currency), amount, "Balance should match deposit");

    // Verify event
    spy
        .assert_emitted(
            @array![
                (
                    account_address,
                    Account::Event::AccountFiatDeposit(
                        AccountFiatDeposit { user: account_address, currency, amount },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(account_address);
}

#[test]
fn test_multiple_fiat_deposits() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);

    let currency = 'USD';
    let amount1 = 500_u128;
    let amount2 = 300_u128;

    account.deposit_fiat(currency, amount1);
    account.deposit_fiat(currency, amount2);

    assert_eq!(
        account.get_fiat_balance(currency), amount1 + amount2, "Balance should
    accumulate",
    );

    stop_cheat_caller_address(account_address);
}

#[test]
#[should_panic(expected: 'Amount cannot be zero')]
fn test_deposit_zero_amount_should_fail() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);
    account.deposit_fiat('USD', 0);
    stop_cheat_caller_address(account_address);
}

#[test]
#[should_panic(expected: 'Currency is required')]
fn test_deposit_zero_currency_should_fail() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);
    account.deposit_fiat(0, 1000);
    stop_cheat_caller_address(account_address);
}

#[test]
fn test_fiat_withdrawal() {
    let (account_address, account, _) = deploy_account();
    let mut spy = spy_events();

    start_cheat_caller_address(account_address, account_address);

    let currency = 'USD';
    let deposit_amount = 1000_u128;
    let withdraw_amount = 300_u128;

    // First deposit
    account.deposit_fiat(currency, deposit_amount);

    // Then withdraw
    account.withdraw_fiat(currency, withdraw_amount, random_user());

    // Verify balance
    let expected_balance = deposit_amount - withdraw_amount;
    assert_eq!(
        account.get_fiat_balance(currency), expected_balance, "Balance should be
    reduced",
    );

    // Verify event (check the last event which should be withdrawal)
    let events = spy.get_events();
    let _last_event = events.events.at(events.events.len() - 1);

    println!("last event is {:?}", _last_event);
    let (_, event) = _last_event;
    // The amount should be at index 2 in the event data
    // Convert the numeric literal to felt252 using the 'into_felt252' function
    let expected_amount = 700_u128;
    assert_eq!(event.data[2], @expected_amount.into(), "Withdrawal amount should match");

    stop_cheat_caller_address(account_address);
}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_withdraw_insufficient_balance_should_fail() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);

    account.deposit_fiat('USD', 100);
    account.withdraw_fiat('USD', 200, random_user()); // Should panic

    stop_cheat_caller_address(account_address);
}

#[test]
fn test_approve_token() {
    let (account_address, account, _) = deploy_account();
    let (token_address, _) = deploy_erc20();

    let mut _spy = spy_events();

    start_cheat_caller_address(account_address, account_address);

    let symbol = 'SYNC';
    account.approve_token(symbol, token_address);

    // Verify token address is stored
    assert_eq!(
        account.get_token_address(symbol), token_address, "Token address should be
    stored",
    );

    // // Verify event
    // spy.assert_emitted(@array![
    //     (account_address, Account::TokenApproved {
    //         user: account_address,
    //         symbol,
    //         token_address,
    //     })
    // ]);

    stop_cheat_caller_address(account_address);
}

#[test]
#[should_panic(expected: 'Address cannot be zero')]
fn test_approve_zero_token_address_should_fail() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);
    account.approve_token('SYNC', zero_address());
    stop_cheat_caller_address(account_address);
}

#[test]
fn test_direct_payment() {
    let (account_address, account, _) = deploy_account();
    let recipient = random_user();
    let mut _spy = spy_events();

    start_cheat_caller_address(account_address, account_address);
    start_cheat_block_timestamp(account_address, 1000);

    let currency = 'USD';
    let deposit_amount = 1000_u128;
    let payment_amount = 300_u128;

    // Deposit first
    account.deposit_fiat(currency, deposit_amount);

    // Make payment
    let success = account.make_payment(recipient, currency, payment_amount, false);

    assert!(success, "Payment should succeed");

    // Check sender balance
    let expected_sender_balance = deposit_amount - payment_amount;
    assert_eq!(
        account.get_fiat_balance(currency),
        expected_sender_balance,
        "Sender balance
    should decrease",
    );

    // Check payment history
    let payment_id = 1_u128;
    let payment_record = account.get_payment_history(payment_id);
    assert_eq!(payment_record.from, account_address, "Payment from should match");
    assert_eq!(payment_record.to, recipient, "Payment to should match");
    assert_eq!(payment_record.amount, payment_amount, "Payment amount should match");
    assert_eq!(payment_record.currency, currency, "Payment currency should match");
    assert!(!payment_record.used_bridge, "Should not have used bridge");

    stop_cheat_block_timestamp(account_address);
    stop_cheat_caller_address(account_address);
}

#[test]
fn test_payment_insufficient_balance_without_bridge() {
    let (account_address, account, _) = deploy_account();
    let recipient = random_user();

    start_cheat_caller_address(account_address, account_address);

    let currency = 'USD';
    let deposit_amount = 100_u128;
    let payment_amount = 200_u128;

    account.deposit_fiat(currency, deposit_amount);

    let success = account.make_payment(recipient, currency, payment_amount, false);

    assert!(!success, "Payment should fail");
    assert_eq!(
        account.get_fiat_balance(currency), deposit_amount, "Balance should remain
    unchanged",
    );

    stop_cheat_caller_address(account_address);
}

#[test]
fn test_default_fiat_currency() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);

    let currency = 'USD';
    account.set_default_fiat_currency(currency);

    assert_eq!(account.get_default_fiat_currency(), currency, "Default currency should be set");

    stop_cheat_caller_address(account_address);
}

#[test]
fn test_get_token_balance() {
    let (account_address, account, _) = deploy_account();
    let (token_address, token_dispatcher) = deploy_erc20();

    start_cheat_caller_address(account_address, account_address);

    // First, approve the token with a symbol
    let symbol = 'SYNC';
    account.approve_token(symbol, token_address);

    stop_cheat_caller_address(account_address);

    start_cheat_caller_address(token_address, owner());

    // Mint some tokens to the account
    let mint_amount = 1000.into();
    token_dispatcher.mint(account_address, mint_amount);
    // Now check the balance using the same symbol used in approve_token
    let balance = account.get_token_balance(symbol);
    assert!(balance == mint_amount, "Expected token balance to match minted amount");

    stop_cheat_caller_address(token_address);
}

#[test]
#[should_panic(expected: 'Address cannot be zero')]
fn test_get_token_balance_unregistered_token_should_fail() {
    let (account_address, account, _) = deploy_account();

    start_cheat_caller_address(account_address, account_address);
    account.get_token_balance('NONEXISTENT');
    stop_cheat_caller_address(account_address);
}
