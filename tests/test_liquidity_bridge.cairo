use core::num::traits::Pow;
use isyncpayment::events::liquidityBridgeEvents::{FiatLiquidityAdded, UserRegistered};
use isyncpayment::interfaces::ierc20::{SyncTokenDispatcher, SyncTokenDispatcherTrait};
use isyncpayment::interfaces::iliquidityBridge::{
    ILiquidityBridgeDispatcher, ILiquidityBridgeDispatcherTrait,
};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::setup::{deploy_bridge, deploy_erc20, owner, random_user, random_user2, zero_address};


fn setup() -> (
    ContractAddress, ILiquidityBridgeDispatcher, SyncTokenDispatcher, SyncTokenDispatcher,
) {
    let (bridge_address, bridge) = deploy_bridge();

    let (ETH_token_address, ETH_token) = deploy_erc20("etherium", "ETH");

    start_cheat_caller_address(ETH_token_address, owner());
    ETH_token.mint(owner(), 500 * 10_u256.pow(18)); // Mint tokens to owner
    ETH_token.approve(bridge_address, 100 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token_address);

    let (STRK_token_address, STRK_token) = deploy_erc20("starknet", "STRK");

    start_cheat_caller_address(STRK_token_address, owner());
    STRK_token.mint(owner(), 500 * 10_u256.pow(18)); // Mint tokens to owner
    STRK_token.approve(bridge_address, 100 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token_address);

    start_cheat_caller_address(bridge_address, owner());
    bridge.add_fiat_liquidity('USD'.into(), 1_000_000 * 10_u256.pow(18));

    bridge.add_supported_token('ETH'.into(), ETH_token_address);
    bridge.add_supported_token('STRK'.into(), STRK_token_address);

    bridge.add_token_liquidity('ETH'.into(), 100 * 10_u256.pow(18));
    bridge.add_token_liquidity('STRK'.into(), 100 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);

    (bridge_address, bridge, ETH_token, STRK_token)
}

// #[test]
// fn test_constructor() {
//     let (_, bridge, _, _) = setup();

//     // Test initial state - these would need getter functions in the interface
//     assert(bridge.get_token_balance('ETH') == 0, 'Initial ETH balance should be 0');
//     assert(
//         bridge.get_fiat_balance('USD', 'ETH') == 1000000 * 10_u256.pow(18), 'Ini fiat balance
//         should be 0',
//     );
// }

#[test]
fn test_set_fee() {
    let (bridge_address, bridge, _, _) = setup();
    start_cheat_caller_address(bridge_address, owner());
    bridge.set_fee(200); // 2% fee
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_fee_unauthorized() {
    let (bridge_address, bridge, _, _) = setup();

    start_cheat_caller_address(bridge_address, random_user());
    bridge.set_fee(200);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_register_user_success() {
    let (bridge_address, bridge, _, _) = setup();
    let fiat_account_id = 'user1fiataccount';
    let user1 = random_user();

    let mut _spy = spy_events();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user1, fiat_account_id);
    stop_cheat_caller_address(bridge_address);

    // Verify user is registered
    assert(bridge.is_user_registered(user1), 'User should be registered');
    assert(bridge.get_fiat_account_id(user1) == fiat_account_id, 'Fiat account ID should match');
    // Verify event emission
// _spy.assert_emitted(@array![(bridge_address, UserRegistered { user: user1, fiat_account_id
// })]);
}

#[test]
#[should_panic(expected: ('Fiat account ID is required',))]
fn test_register_user_invalid_fiat_id() {
    let (bridge_address, bridge, _, _) = setup();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(random_user(), 0);
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('Invalid token address',))]
fn test_register_user_invalid_address() {
    let (bridge_address, bridge, _, _) = setup();
    let zero_address = zero_address();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(zero_address, 'valid_fiat_id');
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_add_fiat_liquidity_success() {
    let (bridge_address, bridge, _, _) = setup();
    let fiat_symbol = 'USD';
    let fiat_amount = 10000_u256;

    let mut _spy = spy_events();

    start_cheat_caller_address(bridge_address, owner());
    bridge.add_fiat_liquidity(fiat_symbol, fiat_amount);
    stop_cheat_caller_address(bridge_address);
    // // Verify fiat balance
// assert(
//     bridge.get_fiat_balance(fiat_symbol, 'ETH') == fiat_amount,
//     'Fiat balance should match',
// );

    // Verify event emission
// spy
//     .assert_emitted(
//         @array![
//             (
//                 bridge_address,
//                 FiatLiquidityAdded { provider: owner(), fiat_symbol, amount: fiat_amount },
//             ),
//         ],
//     );
}

#[test]
#[should_panic(expected: ('fiat_currency is required',))]
fn test_add_fiat_liquidity_invalid_symbol() {
    let (bridge_address, bridge, _, _) = setup();

    start_cheat_caller_address(bridge_address, owner());
    bridge.add_fiat_liquidity(0, 1000_u256);
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('Amount cannot be zero',))]
fn test_add_fiat_liquidity_zero_amount() {
    let (bridge_address, bridge, _, _) = setup();

    start_cheat_caller_address(bridge_address, owner());
    bridge.add_fiat_liquidity('USD', 0);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_swap_fiat_to_token() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user123');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    bridge.swap_fiat_to_token(user, 'USD', 'ETH', 2000 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);
    let user_balance = ETH_token.balance_of(user);
    assert_eq!(user_balance, 666666666666666666, "Invalid user balance");
}

#[test]
fn test_swap_token_to_fiat() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let user = random_user();
    let token_symbol = 'ETH';
    let fiat_symbol = 'USD';
    let token_amount = 10_u256.pow(18);

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user123');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(ETH_token.contract_address, owner());
    ETH_token.mint(user, 500 * 10_u256.pow(18)); // Mint tokens to user
    stop_cheat_caller_address(ETH_token.contract_address);

    // Give user tokens and approve from user's address
    start_cheat_caller_address(ETH_token.contract_address, user);
    ETH_token.approve(bridge_address, token_amount);
    stop_cheat_caller_address(ETH_token.contract_address);

    let initial_contract_balance = ETH_token.balance_of(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    let _success = bridge.swap_token_to_fiat(fiat_symbol, token_symbol, token_amount);
    stop_cheat_caller_address(bridge_address);
    assert(_success, 'Swap should have succeeded');

    let final_contract_balance = ETH_token.balance_of(bridge_address);

    let fee_bps = bridge.fee_bps();
    let fee = (token_amount * fee_bps.into()) / 10000_u256;
    let tokens_received = token_amount - fee;

    assert_eq!(
        final_contract_balance,
        initial_contract_balance + tokens_received, // Should INCREASE by tokens received
        "Invalid contract balance",
    );
}

#[test]
#[should_panic(expected: ('Insufficient token liquidity',))]
fn test_insufficient_liquidity() {
    let (bridge_address, bridge, _, _) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user-123');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    // Try to swap for more tokens than are in the pool
    bridge.swap_fiat_to_token(user, 'USD', 'ETH', 2_000_000 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);
}


#[test]
fn test_process_fiat_deposit_success() {
    let (bridge_address, bridge, _, _) = setup();
    let fiat_account_id = 'user1_fiat_account';
    let fiat_symbol = 'USD';
    let amount = 5000_u256;
    let transaction_id = 'tx_12345';
    let user = random_user();

    // First register the user
    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, fiat_account_id);
    stop_cheat_caller_address(bridge_address);
    // // let mut spy = spy_events();

    start_cheat_caller_address(bridge_address, owner());
    bridge.process_fiat_deposit(user, fiat_symbol, amount, transaction_id);
    stop_cheat_caller_address(bridge_address);
    // Verify event emission
// spy.assert_emitted(@array![
//     (liquidity_bridge.contract_address, FiatDeposit {
//         user: user1,
//         fiat_account_id,
//         fiat_symbol,
//         amount,
//         transaction_id
//     })
// ]);
}

#[test]
#[should_panic(expected: ('User not registered',))]
fn test_swap_fiat_to_token_unregistered_user() {
    let (bridge_address, bridge, _, _) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.swap_fiat_to_token(user, 'USD', 'ETH', 1000_u256);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_lock_user_funds_success() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let token_symbol = 'ETH';
    let lock_amount = 1 * 10_u256.pow(18); // 1 ETH
    let user = random_user();

    start_cheat_caller_address(ETH_token.contract_address, owner());
    ETH_token.mint(user, lock_amount);
    stop_cheat_caller_address(ETH_token.contract_address);

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user123');
    stop_cheat_caller_address(bridge_address);

    // Approve token transfer
    start_cheat_caller_address(ETH_token.contract_address, user);
    ETH_token.approve(bridge_address, lock_amount);
    stop_cheat_caller_address(ETH_token.contract_address);

    start_cheat_caller_address(bridge_address, user);
    bridge.lock_user_funds(user, token_symbol, lock_amount);
    stop_cheat_caller_address(bridge_address);

    // Verify user's balance decreased
    let final_balance = ETH_token.balance_of(user);
    assert(final_balance == 0, 'Balance should decrease');

    // Verify contract received the tokens
    let contract_balance = ETH_token.balance_of(bridge_address);
    assert(contract_balance >= lock_amount, 'Contract should receive tokens');
}

#[test]
fn test_confirm_withdrawal_success() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let token_symbol = 'ETH';
    let lock_amount = 1_u256 * 1000000000000000000_u256; // 1 ETH
    let fiat_reference = 'fiat_tx_123';
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user1fiataccount');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(ETH_token.contract_address, owner());
    ETH_token.mint(user, lock_amount);
    stop_cheat_caller_address(ETH_token.contract_address);

    // First lock some funds
    start_cheat_caller_address(ETH_token.contract_address, user);
    ETH_token.approve(bridge_address, lock_amount);
    stop_cheat_caller_address(ETH_token.contract_address);

    start_cheat_caller_address(bridge_address, user);
    bridge.lock_user_funds(user, token_symbol, lock_amount);
    stop_cheat_caller_address(bridge_address);

    // let mut spy = spy_events();

    // Confirm withdrawal
    start_cheat_caller_address(bridge_address, owner());
    bridge.confirm_withdrawal(user, token_symbol, lock_amount, fiat_reference);
    stop_cheat_caller_address(bridge_address);
    // // Verify event emission
// spy
//     .assert_emitted(
//         @array![
//             (
//                 liquidity_bridge.contract_address,
//                 WithdrawalCompleted {
//                     user: user1, token_symbol, amount: lock_amount, fiat_reference,
//                 },
//             ),
//         ],
//     );
}

#[test]
#[should_panic(expected: ('fee too high',))]
fn test_set_fee_too_high() {
    let (bridge_address, bridge, _, _) = setup();
    let invalid_fee_bps = 1001_u16; // > 10%

    start_cheat_caller_address(bridge_address, owner());
    bridge.set_fee(invalid_fee_bps);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_remove_fiat_liquidity_success() {
    let (bridge_address, bridge, _, _) = setup();
    let fiat_symbol = 'USD';
    let remove_amount = 5000_u256;
    let initial_amount = 1_000_000 * 10_u256.pow(18); // same as setup

    // let mut spy = spy_events();

    // Remove fiat liquidity
    start_cheat_caller_address(bridge_address, owner());
    bridge.remove_fiat_liquidity(fiat_symbol, remove_amount);
    stop_cheat_caller_address(bridge_address);

    // Verify remaining balance
    let remaining_balance = bridge.get_fiat_balance(fiat_symbol);
    assert(remaining_balance == initial_amount - remove_amount, 'Remaining balance should match');
    // // Verify event emission
// spy
//     .assert_emitted(
//         @array![
//             (
//                 bridge_address,
//                 FiatLiquidityRemoved { provider: owner(), fiat_symbol, amount: remove_amount
//                 },
//             ),
//         ],
//     );
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_remove_fiat_liquidity_unauthorized() {
    let (bridge_address, bridge, _, _) = setup();
    let user1 = random_user();

    start_cheat_caller_address(bridge_address, user1);
    bridge.remove_fiat_liquidity('USD', 1000_u256);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_multiple_users_and_transactions() {
    let (bridge_address, bridge, ETH_token, STRK_token) = setup();
    let user1 = random_user();
    let user2 = random_user2();

    // Register both users
    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user1, 'user1_fiat');
    bridge.register_user(user2, 'user2_fiat');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(ETH_token.contract_address, owner());
    ETH_token.mint(user1, 10 * 10_u256.pow(18));
    ETH_token.mint(user2, 10 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token.contract_address);

    start_cheat_caller_address(STRK_token.contract_address, owner());
    STRK_token.mint(user1, 10 * 10_u256.pow(18));
    STRK_token.mint(user2, 10 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token.contract_address);

    // User1 adds ETH liquidity
    start_cheat_caller_address(ETH_token.contract_address, user1);
    ETH_token.approve(bridge_address, 10 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token.contract_address);

    // User2 adds STRK liquidity
    start_cheat_caller_address(STRK_token.contract_address, user2);
    STRK_token.approve(bridge_address, 10 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token.contract_address);

    let expected_eth = 100 * 10_u256.pow(18);
    let eth_balance = bridge.get_token_balance('ETH');

    assert!(eth_balance == expected_eth, "ETH balance expected {expected_eth}, got {eth_balance}");

    let expected_strk = 100 * 10_u256.pow(18);
    let strk_balance = bridge.get_token_balance('STRK');

    assert!(
        strk_balance == expected_strk, "STRK balance expected {expected_strk}, got {strk_balance}",
    );

    let expected_usd = 1_000_000 * 10_u256.pow(18);
    let usd_balance = bridge.get_fiat_balance('USD');

    assert!(usd_balance == expected_usd, "USD balance expected {expected_usd}, got {usd_balance}");

    // Test successful swaps
    start_cheat_caller_address(bridge_address, user1);
    let success1 = bridge.swap_fiat_to_token(user1, 'USD', 'ETH', 3000_u256);
    let success2 = bridge.swap_fiat_to_token(user2, 'USD', 'STRK', 100_u256);
    stop_cheat_caller_address(bridge_address);

    assert(success1, 'First swap should succeed');
    assert(success2, 'Second swap should succeed');
}

#[test]
#[should_panic(expected: ('insufficient liquidity',))]
fn test_insufficient_liquidity_scenarios() {
    let (bridge_address, bridge, _, _) = setup();
    let user1 = random_user();

    // Register user
    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user1, 'user1_fiat');
    stop_cheat_caller_address(bridge_address);

    // Add minimal liquidity
    start_cheat_caller_address(bridge_address, user1);
    bridge.add_fiat_liquidity('USD', 100_u256); // Very low fiat
    stop_cheat_caller_address(bridge_address);

    // Try to swap more than available - should panic
    start_cheat_caller_address(bridge_address, owner());
    let success = bridge.swap_fiat_to_token(user1, 'USD', 'ETH', 10000_u256);
    stop_cheat_caller_address(bridge_address);

    // Should fail due to insufficient token liquidity
    assert(!success, 'insufficient liquidity');
}
