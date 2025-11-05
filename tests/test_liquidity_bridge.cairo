use crate::setup::deploy_account;
use core::num::traits::Pow;
use isyncpayment::events::liquidityBridgeEvents::{UserRegistered};
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
    let (ETH_token_address, ETH_token) = deploy_erc20("etherium", "ETH");
    let (STRK_token_address, STRK_token) = deploy_erc20("starknet", "STRK");

    let (bridge_address, bridge) = deploy_bridge(ETH_token_address, STRK_token_address);

    start_cheat_caller_address(ETH_token_address, owner());
    ETH_token.mint(owner(), 500 * 10_u256.pow(18));
    ETH_token.mint(random_user(), 500 * 10_u256.pow(18));
    ETH_token.mint(bridge_address, 500 * 10_u256.pow(18));
    ETH_token.approve(bridge_address, 400 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token_address);

    start_cheat_caller_address(ETH_token_address, random_user());
    ETH_token.approve(bridge_address, 400 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token_address);

    start_cheat_caller_address(STRK_token_address, owner());
    STRK_token.mint(owner(), 500 * 10_u256.pow(18));
    STRK_token.mint(random_user(), 500 * 10_u256.pow(18));
    STRK_token.mint(bridge_address, 500 * 10_u256.pow(18));
    STRK_token.approve(bridge_address, 400 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token_address);

    start_cheat_caller_address(STRK_token_address, random_user());
    STRK_token.approve(bridge_address, 400 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token_address);

    // First, authorize the owner as an operator
    start_cheat_caller_address(bridge_address, owner());
    bridge.set_operator(owner(), true);
    stop_cheat_caller_address(bridge_address);
    
    // Now perform operations as the operator
    start_cheat_caller_address(bridge_address, owner());
    bridge.add_token_liquidity('ETH/USD', 400 * 10_u256.pow(18));
    bridge.add_token_liquidity('STRK/USD', 400 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);
    
    // Register the owner as a user for testing
    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(owner(), 'owner-123');
    stop_cheat_caller_address(bridge_address);

    (bridge_address, bridge, ETH_token, STRK_token)
}

#[test]
fn debug_token_mapping() {
    // Deploy tokens first
    let (eth_token_address, _) = deploy_erc20("ethereum", "ETH");
    let (strk_token_address, _) = deploy_erc20("starknet", "STRK");

    // Deploy bridge with the deployed token addresses
    let (_, bridge) = deploy_bridge(eth_token_address, strk_token_address);

    // Check what token address the bridge has for 'ETH/USD'
    let bridge_eth_address = bridge.get_supported_tokens_by_symbol('ETH/USD');

    // The bridge should return the deployed token address
    assert(bridge_eth_address == eth_token_address, 'Token address mismatch!');

    // Also verify STRK token mapping
    let bridge_strk_address = bridge.get_supported_tokens_by_symbol('STRK/USD');
    assert(bridge_strk_address == strk_token_address, 'STRK token address mismatch!');
}

#[test]
fn test_set_fee() {
    let (bridge_address, bridge, _, _) = setup();
    start_cheat_caller_address(bridge_address, owner());
    bridge.set_fee_bps(200); // 2% fee
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_fee_unauthorized() {
    let (bridge_address, bridge, _, _) = setup();

    start_cheat_caller_address(bridge_address, random_user());
    bridge.set_fee_bps(200);
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
fn test_swap_fiat_to_token() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let user = random_user();

    // Register user and add initial token liquidity
    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user123');
    stop_cheat_caller_address(bridge_address);
    let contract_balance = ETH_token.balance_of(bridge_address);
    println!("Contract ETH balance: {}", contract_balance);

    // Perform the swap
    start_cheat_caller_address(bridge_address, user);
    let success = bridge.swap_fiat_to_token(user, '543tw4g45', 'USD', 'ETH/USD', 10_u256.pow(18), 10_u256.pow(17), 30);
    stop_cheat_caller_address(bridge_address);

    // Verify the swap was successful
    assert(success, 'Swap should succeed');
    let user_balance = ETH_token.balance_of(user);
    assert(user_balance > 0, 'User should receive tokens');
}

#[test]
fn test_swap_ETH_to_fiat() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let user = random_user();
    let token_symbol = 'ETH/USD';
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
    let _success = bridge.swap_token_to_fiat(user, '543tw4g45', fiat_symbol, token_symbol, token_amount);
    stop_cheat_caller_address(bridge_address);
    assert(_success, 'Swap should have succeeded');

    let final_contract_balance = ETH_token.balance_of(bridge_address);

    let fee_bps = bridge.get_fee_bps();
    let fee = (token_amount * fee_bps.into()) / 10000_u256;
    let tokens_received = token_amount - fee;

    assert_eq!(
        final_contract_balance,
        initial_contract_balance + tokens_received, // Should INCREASE by tokens received
        "Invalid contract balance",
    );
}

#[test]
fn test_swap_STRK_to_fiat() {
    let (bridge_address, bridge, _, STRK_token) = setup();
    let user = random_user();
    let token_symbol = 'STRK/USD';
    let fiat_symbol = 'USD';
    let token_amount = 10_u256.pow(18);

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user123');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(STRK_token.contract_address, owner());
    STRK_token.mint(user, 500 * 10_u256.pow(18)); // Mint tokens to user
    stop_cheat_caller_address(STRK_token.contract_address);

    // Give user tokens and approve from user's address
    start_cheat_caller_address(STRK_token.contract_address, user);
    STRK_token.approve(bridge_address, token_amount);
    stop_cheat_caller_address(STRK_token.contract_address);

    let initial_contract_balance = STRK_token.balance_of(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    let _success = bridge.swap_token_to_fiat(user, '543tw4g45', fiat_symbol, token_symbol, token_amount);
    stop_cheat_caller_address(bridge_address);
    assert(_success, 'Swap should have succeeded');

    let final_contract_balance = STRK_token.balance_of(bridge_address);

    let fee_bps = bridge.get_fee_bps();
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
    bridge.swap_fiat_to_token(user, '543tw4g45', 'USD', 'ETH/USD', 2_000_000 * 10_u256.pow(18), 2_000_000 * 10_u256.pow(17), 30);
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('User not registered',))]
fn test_swap_fiat_to_token_unregistered_user() {
    let (bridge_address, bridge, _, _) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.swap_fiat_to_token(user, '543tw4g45', 'USD', 'ETH/USD', 10_u256.pow(18), 10_u256.pow(17), 30);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_lock_user_funds_success() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let token_symbol = 'ETH/USD';
    let lock_amount = 10_u256.pow(18); // 1 ETH
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

    let before_user_balance = ETH_token.balance_of(user);
    let before_contract_balance = ETH_token.balance_of(bridge_address);
    println!("user balance before lock {:?}", before_user_balance);
    println!("bridge balance before lock {:?}", before_contract_balance);

    start_cheat_caller_address(bridge_address, user);
    bridge.lock_user_funds(user, token_symbol, lock_amount);
    stop_cheat_caller_address(bridge_address);

    // Verify user's balance decreased
    let final_balance = ETH_token.balance_of(user);
    println!("final_balance after lock {:?}", final_balance);
    assert(final_balance == before_user_balance - lock_amount, 'Balance should decrease');

    // Verify contract received the tokens
    println!("bridge balance after lock {:?}", ETH_token.balance_of(bridge_address));
    assert(
        ETH_token.balance_of(bridge_address) == before_contract_balance + lock_amount,
        'Contract should receive tokens',
    );
}

#[test]
fn test_confirm_withdrawal_success() {
    let (bridge_address, bridge, ETH_token, _) = setup();
    let token_symbol = 'ETH/USD';
    let lock_amount = 10_u256.pow(18); // 1 ETH
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

    // Authorize the owner as an operator and confirm withdrawal
    start_cheat_caller_address(bridge_address, owner());
    bridge.set_operator(owner(), true);
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
    bridge.set_fee_bps(invalid_fee_bps);
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

    // I have already minted and approved for user1 in setup
    start_cheat_caller_address(ETH_token.contract_address, owner());
    ETH_token.mint(user2, 500 * 10_u256.pow(18));
    stop_cheat_caller_address(ETH_token.contract_address);

    start_cheat_caller_address(STRK_token.contract_address, owner());
    STRK_token.mint(user2, 500 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token.contract_address);

    // User2 adds STRK liquidity
    start_cheat_caller_address(STRK_token.contract_address, user2);
    STRK_token.approve(bridge_address, 400 * 10_u256.pow(18));
    stop_cheat_caller_address(STRK_token.contract_address);

    let expected_eth = 500 * 10_u256.pow(18);
    let eth_balance = ETH_token.balance_of(bridge_address);

    assert!(eth_balance == expected_eth, "ETH balance expected {expected_eth}, got {eth_balance}");

    let expected_strk = 500 * 10_u256.pow(18);
    let strk_balance = STRK_token.balance_of(bridge_address);

    assert!(
        strk_balance == expected_strk, "STRK balance expected {expected_strk}, got {strk_balance}",
    );

    // Test successful swaps
    start_cheat_caller_address(bridge_address, user1);
    let success1 = bridge.swap_fiat_to_token(user1, '546435453', 'USD', 'ETH/USD', 3000_u256, 300_u256, 30);
    let success2 = bridge.swap_fiat_to_token(user2, 'fage654egw','USD', 'STRK/USD', 100_u256, 10_u256, 30);
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

    // Try to swap more than available - should panic
    start_cheat_caller_address(bridge_address, owner());
    let success = bridge.swap_fiat_to_token(user1, '546435453', 'USD', 'ETH/USD', 10000_u256, 1000_u256, 30);
    stop_cheat_caller_address(bridge_address);

    // Should fail due to insufficient token liquidity
    assert(!success, 'insufficient liquidity');
}

#[test]
fn test_get_token_balance() {
    let (account_address, _, _) = deploy_account();
    let (token_address, token_dispatcher) = deploy_erc20("SyncToken", "SYNC");
    let (_, bridge, _, _) = setup();
    let symbol = 'SYNC';

    start_cheat_caller_address(token_address, owner());
    let mint_amount = 1000.into();
    token_dispatcher.mint(account_address, mint_amount);
    let balance = bridge.get_token_balance(symbol);
    assert!(balance == mint_amount, "Expected token balance to match minted amount");

    stop_cheat_caller_address(token_address);
}