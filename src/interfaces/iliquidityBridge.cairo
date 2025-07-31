    use starknet::ContractAddress;

#[starknet::interface]
pub trait ILiquidityBridge<T> {
    fn register_user(ref self: T, user: ContractAddress, fiat_account_id: felt252);
    fn add_fiat_liquidity(ref self: T, _fiat_symbol: felt252, _fiat_amount: u256);
    fn add_token_liquidity(ref self: T, _token_symbol: felt252, _token_amount: u256);
    fn process_fiat_deposit(
        ref self: T,
        _user: ContractAddress,
        _fiat_symbol: felt252,
        _amount: u256,
        _transaction_id: felt252,
    );
    fn add_supported_token(ref self: T, _symbol: felt252, _token_address: ContractAddress);
    fn update_exchange_rate(
        ref self: T, _fiat_symbol: felt252, _token_symbol: felt252, _new_rate: u256,
    );
    fn is_user_registered(self: @T, _user: ContractAddress) -> bool;
    fn lock_user_funds(ref self: T, _user: ContractAddress, _token_symbol: felt252, _amount: u256);
    fn confirm_withdrawal(
        ref self: T,
        _user: ContractAddress,
        _token_symbol: felt252,
        _amount: u256,
        _fiat_reference: felt252,
    );
    fn remove_fiat_liquidity(ref self: T, _fiat_symbol: felt252, _fiat_amount: u256);
    fn swap_fiat_to_token(
        ref self: T,
        _user: ContractAddress,
        _fiat_symbol: felt252,
        _token_symbol: felt252,
        _fiat_amount: u256,
    ) -> bool;
    fn swap_token_to_fiat(
        ref self: T, _fiat_symbol: felt252, _token_symbol: felt252, _token_amount: u256,
    ) -> bool;
    fn set_fee(ref self: T, _new_fee_bps: u16);
    fn get_fiat_account_id(self: @T, _user: ContractAddress) -> felt252;
    fn get_exchange_rate(self: @T, _fiat_symbol: felt252, _token_symbol: felt252) -> u256;
    fn get_token_balance(self: @T, _token_symbol: felt252) -> u256;
    fn get_fiat_balance(self: @T, _fiat_symbol: felt252, _token_symbol: felt252) -> u256;
}
