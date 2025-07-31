use starknet::ContractAddress;
use crate::structs::PaymentRecord;

#[starknet::interface]
pub trait IAccount<T> {
    fn approve_token(ref self: T, symbol: felt252, token_address: ContractAddress);
    fn deposit_fiat(ref self: T, currency: felt252, amount: u128);
    fn withdraw_fiat(ref self: T, currency: felt252, amount: u128, recipient: ContractAddress);
    fn make_payment(
        ref self: T,
        recipient: ContractAddress,
        currency: felt252,
        amount: u128,
        use_liquidity_bridge: bool,
    ) -> bool;
    fn set_default_fiat_currency(ref self: T, currency: felt252);
    fn get_default_fiat_currency(self: @T) -> felt252;
    fn get_fiat_balance(self: @T, currency: felt252) -> u128;
    fn get_token_balance(self: @T, token_symbol: felt252) -> u256;
    fn get_liquidity_bridge(self: @T) -> ContractAddress;
    fn get_payment_history(self: @T, payment_id: u128) -> PaymentRecord;
    fn get_next_payment_id(self: @T) -> u128;
    fn get_token_address(self: @T, symbol: felt252) -> ContractAddress;
}
