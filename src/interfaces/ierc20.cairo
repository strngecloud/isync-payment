use starknet::ContractAddress;
// Dispatcher implementation
#[starknet::interface]
pub trait SyncToken<T> {
    fn get_name(self: @T) -> felt252;
    fn get_symbol(self: @T) -> felt252;
    fn get_decimals(self: @T) -> u8;
    fn total_supply(self: @T) -> u256;
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(self: @T, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        self: @T, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(self: @T, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(
        self: @T, spender: ContractAddress, added_value: u256,
    ) -> bool;
    fn decrease_allowance(
        self: @T, spender: ContractAddress, subtracted_value: u256,
    ) -> bool;
    fn mint(self: @T, recipient: ContractAddress, amount: u256);
    fn burn(self: @T, value: u256);
}