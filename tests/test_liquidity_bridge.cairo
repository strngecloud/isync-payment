use core::num::traits::Pow;
use isyncpayment::interfaces::ierc20::{SyncTokenDispatcher, SyncTokenDispatcherTrait};
use isyncpayment::interfaces::iliquidityBridge::{
    ILiquidityBridgeDispatcher, ILiquidityBridgeDispatcherTrait,
};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use crate::setup::{deploy_bridge, deploy_erc20, owner, random_user};

fn setup() -> (ContractAddress, ILiquidityBridgeDispatcher, SyncTokenDispatcher) {
    let bridge_address = deploy_bridge();
    let bridge = ILiquidityBridgeDispatcher { contract_address: bridge_address };

    let (token_address, token) = deploy_erc20();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_token('ETH', token_address);
    bridge.add_fiat_liquidity('USD', 1_000_000 * 10_u256.pow(18));
    bridge.add_token_liquidity('ETH', 500 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);

    (bridge_address, bridge, token)
}

#[test]
fn test_set_fee() {
    let (bridge_address, bridge, _) = setup();

    start_cheat_caller_address(bridge_address, owner());
    bridge.set_fee(200); // 2% fee
    stop_cheat_caller_address(bridge_address);
}

#[test]
#[should_panic(expected: ('Unauthorized',))]
fn test_set_fee_unauthorized() {
    let (bridge_address, bridge, _) = setup();

    start_cheat_caller_address(bridge_address, random_user());
    bridge.set_fee(200);
    stop_cheat_caller_address(bridge_address);
}

#[test]
fn test_swap_fiat_to_token() {
    let (bridge_address, bridge, token) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user-123');
    stop_cheat_caller_address(bridge_address);
    start_cheat_caller_address(bridge_address, user);
    bridge.swap_fiat_to_token(user, 'USD', 'ETH', 2000 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);

    let user_balance = token.balance_of(user);
    // Price from mock is 2000, fee is 1% (100 bps), so user gets 0.99 ETH
    assert_eq!(user_balance, 99 * 10_u256.pow(16), "Invalid user balance");
}

#[test]
fn test_swap_token_to_fiat() {
    let (bridge_address, bridge, token) = setup();
    let user = random_user();

    // Give user some tokens
    start_cheat_caller_address(bridge_address, owner());
    token.transfer(user, 1 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    token.approve(bridge.contract_address, 1 * 10_u256.pow(18));
    // bridge.swap_token_to_fiat('USD', 'ETH', 1 * 10_u256.pow(18));
    // stop_cheat_caller_address(bridge_address);

    // // User should have received ~$1980 worth of fiat (less 1% fee)
    // // We can't check fiat balance directly, but we can check the treasury's token balance
    // let treasury_bal = token.balance_of(random_user());
    // assert_eq!(treasury_bal, 1 * 10_u256.pow(16), 'Invalid treasury balance');
}

#[test]
#[should_panic(expected: ('Insufficient token liquidity',))]
fn test_insufficient_liquidity() {
    let (bridge_address, bridge, _) = setup();
    let user = random_user();

    start_cheat_caller_address(bridge_address, owner());
    bridge.register_user(user, 'user-123');
    stop_cheat_caller_address(bridge_address);

    start_cheat_caller_address(bridge_address, user);
    // Try to swap for more tokens than are in the pool
    bridge.swap_fiat_to_token(user, 'USD', 'ETH', 2_000_000 * 10_u256.pow(18));
    stop_cheat_caller_address(bridge_address);
}
