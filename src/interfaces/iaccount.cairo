use starknet::ContractAddress;

#[starknet::interface]
pub trait IAccount<T> {
    fn set_liquidity_bridge(ref self: T, bridge: ContractAddress);
    fn set_staking_contract(ref self: T, staking: ContractAddress);
    fn set_token_address(ref self: T, symbol: felt252, token_address: ContractAddress);
    fn get_liquidity_bridge(self: @T) -> ContractAddress;
    fn get_token_address(self: @T, symbol: felt252) -> ContractAddress;
    fn swap_fiat_to_token(
        ref self: T,
        swap_order_id: felt252,
        fiat_symbol: felt252,
        token_symbol: felt252,
        fiat_amount: u256,
        token_amount: u256,
        fee: u128,
    ) -> bool;

    fn swap_token_to_fiat(
        ref self: T,
        swap_order_id: felt252,
        fiat_symbol: felt252,
        token_symbol: felt252,
        token_amount: u256,
    ) -> bool;
    // New staking functions
    fn stake_tokens(ref self: T, token_symbol: felt252, amount: u256, lock_duration: u64) -> bool;

    fn unstake_tokens(ref self: T, token_symbol: felt252, stake_id: u64) -> bool;

    fn claim_staking_rewards(ref self: T, token_symbol: felt252, stake_id: u64) -> bool;

    // fn get_my_stakes(self: @T, token_symbol: felt252) -> Array<StakePosition>;
    fn get_my_stakes(self: @T, token_symbol: felt252) -> Array<u64>;

    fn get_my_total_staked(self: @T, token_symbol: felt252) -> u256;
    fn emergency_unstake_tokens(ref self: T, token_symbol: felt252, stake_id: u64) -> bool;
    fn configure_auto_stake(
        ref self: T, token_symbol: felt252, enabled: bool, duration: u64, threshold: u256,
    );
    fn get_auto_stake_config(self: @T, token_symbol: felt252) -> (bool, u64, u256);
    fn get_stake_rewards(self: @T, token_symbol: felt252, stake_id: u64) -> u256;
}
