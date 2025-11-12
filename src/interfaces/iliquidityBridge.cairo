use pragma_lib::abi::DataType;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ILiquidityBridge<T> {
    fn register_user(ref self: T, user: ContractAddress, fiat_account_id: felt252);
    fn is_user_registered(self: @T, _user: ContractAddress) -> bool;
    fn add_token_liquidity(ref self: T, _token_symbol: felt252, _token_amount: u256);
    fn add_supported_token(
        ref self: T, _symbol: felt252, _token_address: ContractAddress, _feed_id: felt252,
    );

    fn lock_user_funds(ref self: T, _user: ContractAddress, _token_symbol: felt252, _amount: u256);
    fn confirm_withdrawal(
        ref self: T,
        _user: ContractAddress,
        _token_symbol: felt252,
        _amount: u256,
        _fiat_reference: felt252,
    );
    fn swap_fiat_to_token(
        ref self: T,
        _user: ContractAddress,
        _swap_order_id: felt252,
        _fiat_symbol: felt252,
        _token_symbol: felt252,
        _fiat_amount: u256,
        _token_amount: u256,
        _fee: u128,
    ) -> bool;
    fn swap_token_to_fiat(
        ref self: T,
        _user: ContractAddress,
        _swap_order_id: felt252,
        _fiat_symbol: felt252,
        _token_symbol: felt252,
        _token_amount: u256,
    ) -> bool;
    fn set_fee_bps(ref self: T, fee_bps: u16);
    fn set_operator(ref self: T, operator: ContractAddress, is_authorized: bool);

    fn get_fiat_account_id(self: @T, _user: ContractAddress) -> felt252;
    fn get_token_balance(self: @T, _token_symbol: felt252) -> u256;
    fn get_asset_price_median(self: @T, asset: DataType) -> (u128, u32);
    fn check_price_threshold(
        self: @T, token: ContractAddress, expected_min_price: u256, expected_max_price: u256,
    ) -> bool;
    fn get_token_amount_in_usd(self: @T, token: ContractAddress, token_amount: u256) -> u256;
    fn get_fee_bps(self: @T) -> u16;
    fn get_supported_tokens_by_symbol(self: @T, _symbol: felt252) -> ContractAddress;
    fn get_token_info(self: @T, token_address: ContractAddress) -> TokenInfo;
    fn get_all_supported_tokens(self: @T) -> Array<ContractAddress>;
    fn get_all_token_pools(self: @T) -> Array<felt252>;
    fn get_locked_funds(self: @T, user: ContractAddress, token_symbol: felt252) -> u256;
    fn update_token_status(ref self: T, symbol: felt252, is_active: bool);
    fn update_pragma_oracle_address(ref self: T, new_address: ContractAddress);
    fn remove_supported_token(ref self: T, symbol: felt252);
}

#[derive(Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub symbol: felt252,
    pub address: ContractAddress,
    pub feed_id: felt252, // Pragma oracle feed ID
    pub decimals: u8,
    pub is_active: bool,
    pub added_at: u64,
    pub last_updated: u64,
}