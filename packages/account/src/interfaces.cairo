use starknet::ClassHash;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAccount<T> {
    // Token management
    fn set_token_address(ref self: T, symbol: felt252, token_address: ContractAddress);
    fn get_token_address(self: @T, symbol: felt252) -> ContractAddress;

    // Bridge interaction
    fn set_bridge(ref self: T, bridge: ContractAddress);
    fn get_bridge(self: @T) -> ContractAddress;

    // Staking interaction
    fn set_staking_contract(ref self: T, staking: ContractAddress);
    fn get_staking_contract(self: @T) -> ContractAddress;
}

#[starknet::interface]
pub trait IAccountFactory<T> {
    // Factory management
    fn create_account(ref self: T, public_key: felt252, user_unique_id: felt252);
    fn get_account(self: @T, user_unique_id: felt252) -> ContractAddress;
    fn set_account_class_hash(ref self: T, class_hash: ClassHash);
    fn set_liquidity_bridge(ref self: T, bridge: ContractAddress);
    fn set_default_fiat_currency(ref self: T, currency: felt252);
    fn add_default_token(ref self: T, symbol: felt252, token_address: ContractAddress);
}