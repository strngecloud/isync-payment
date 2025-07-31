use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

#[starknet::interface]
pub trait IAccountFactory<T> {
    fn create_account(ref self: T, public_key: felt252, user_unique_id: felt252);
    fn get_account(self: @T, user: felt252) -> ContractAddress;
    fn set_liquidity_bridge(ref self: T, new_bridge: ContractAddress);
    fn set_account_class_hash(ref self: T, new_account_class_hash: ClassHash);
    fn get_liquidity_bridge(self: @T) -> ContractAddress;
}

