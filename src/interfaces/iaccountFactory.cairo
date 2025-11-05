use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

#[starknet::interface]
pub trait IAccountFactory<T> {
    fn create_account(ref self: T, public_key: felt252, user_unique_id: felt252);
    fn get_account(self: @T, user: felt252) -> ContractAddress;
    fn set_liquidity_bridge(ref self: T, new_bridge: ContractAddress);
    fn set_account_class_hash(ref self: T, new_account_class_hash: ClassHash);
    fn get_account_class_hash(self: @T) -> ClassHash;
    fn get_liquidity_bridge(self: @T) -> ContractAddress;
    fn swap_fiat_to_token(
        ref self: T,
        user_unique_id: felt252,
        _swap_order_id: felt252,
        _fiat_symbol: felt252,
        _token_symbol: felt252,
        _fiat_amount: u256,
        _token_amount: u256,
        _fee: u128,
    ) -> bool;
    fn swap_token_to_fiat(
        ref self: T,
        user_unique_id: felt252,
        _swap_order_id: felt252,
        _fiat_symbol: felt252,
        _token_symbol: felt252,
        _token_amount: u256,
    ) -> bool;
}

