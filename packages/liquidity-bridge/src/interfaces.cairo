use starknet::ContractAddress;
use pragma_lib::types::DataType;

#[starknet::interface]
pub trait ILiquidityBridge<T> {
    // Token management
    fn add_token(
        ref self: T,
        token: ContractAddress,
        symbol: felt252,
        feed_id: felt252,
        decimals: u8,
        min_amount: u256,
        max_amount: u256,
        is_active: bool,
    );
    
    fn remove_token(ref self: T, token: ContractAddress);
    fn pause_token(ref self: T, token: ContractAddress);
    fn unpause_token(ref self: T, token: ContractAddress);
    fn set_operator(ref self: T, operator: ContractAddress, is_authorized: bool);
    fn register_user(ref self: T, user: ContractAddress, fiat_account_id: felt252);
    fn is_user_registered(self: @T, user: ContractAddress) -> bool;
    fn get_fiat_account_id(self: @T, user: ContractAddress) -> felt252;
    
    // Swap functions
    fn swap(
        ref self: T,
        from_token: ContractAddress,
        to_token: ContractAddress,
        from_amount: u256,
        min_to_amount: u256,
        deadline: u64,
    ) -> u64;
    
    fn cancel_swap(ref self: T, swap_id: u64);
    fn execute_swap(ref self: T, swap_id: u64);

    // Fiat-specific flows
    fn swap_fiat_to_token(
        ref self: T,
        user: ContractAddress,
        swap_order_id: felt252,
        fiat_symbol: felt252,
        token_symbol: felt252,
        fiat_amount: u256,
        token_amount: u256,
        fee: u128,
    ) -> bool;

    fn swap_token_to_fiat(
        ref self: T,
        user: ContractAddress,
        swap_order_id: felt252,
        fiat_symbol: felt252,
        token_symbol: felt252,
        token_amount: u256,
        min_fiat_amount: u256,
    ) -> bool;

    // Withdrawal / escrow flows
    fn lock_user_funds(ref self: T, user: ContractAddress, token_symbol: felt252, amount: u256);
    fn confirm_withdrawal(ref self: T, user: ContractAddress, token_symbol: felt252, amount: u256, fiat_reference: felt252);
    fn get_locked_funds(self: @T, user: ContractAddress, token_symbol: felt252) -> u256;
    
    // Liquidity management
    fn add_liquidity(
        ref self: T,
        token: ContractAddress,
        amount: u256,
        min_liquidity: u256,
    ) -> u256;
    
    fn remove_liquidity(
        ref self: T,
        token: ContractAddress,
        liquidity: u256,
        min_amount: u256,
    ) -> u256;
    
    // Fee management
    fn set_fee_receiver(ref self: T, receiver: ContractAddress);
    fn set_swap_fee(ref self: T, fee_rate: u256);
    fn withdraw_fees(ref self: T, token: ContractAddress, amount: u256);
    
    // Emergency functions
    fn enable_emergency_mode(ref self: T, enable: bool);
    fn emergency_withdraw(
        ref self: T,
        token: ContractAddress,
        to: ContractAddress,
        amount: u256,
    );
    
    // View functions
    fn get_swap(self: @T, swap_id: u64) -> SwapInfo;
    fn get_token_info(self: @T, token: ContractAddress) -> TokenInfo;
    fn get_pool_info(self: @T, token: ContractAddress) -> PoolInfo;
    fn calculate_swap_amount(
        self: @T,
        from_token: ContractAddress,
        to_token: ContractAddress,
        from_amount: u256,
    ) -> u256;

    // Additional helpers & views
    fn add_token_liquidity(ref self: T, token: ContractAddress, amount: u256);
    fn get_token_balance(self: @T, token: ContractAddress) -> u256;
    fn get_asset_price_median(self: @T, asset: DataType) -> (u128, u32);
    fn get_token_amount_in_usd(self: @T, token: ContractAddress, token_amount: u256) -> u256;

    // Emergency / admin utilities
    fn emergency_unlock_locked_funds(ref self: T, user: ContractAddress, token_symbol: felt252, amount: u256);

    // Fee & oracle config
    fn set_fee_bps(ref self: T, fee_bps: u16);
    fn get_fee_bps(self: @T) -> u16;
    fn update_pragma_oracle_address(ref self: T, new_address: ContractAddress);

    fn set_slippage_tolerance(ref self: T, bps: u16) ;
}

// Data structures
#[derive(Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub symbol: felt252,
    pub decimals: u8,
    pub min_amount: u256,
    pub max_amount: u256,
    pub is_active: bool,
    pub total_liquidity: u256,
    // metadata
    pub feed_id: felt252,
    pub added_at: u64,
    pub last_updated: u64,
}

#[derive(Drop, Serde)]
pub struct PoolInfo {
    pub token: ContractAddress,
    pub total_liquidity: u256,
    pub total_supply: u256,
    pub reserve0: u256,
    pub reserve1: u256,
    pub last_update_time: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SwapInfo {
    pub id: u64,
    pub user: ContractAddress,
    pub from_token: ContractAddress,
    pub to_token: ContractAddress,
    pub from_amount: u256,
    pub to_amount: u256,
    pub fee_amount: u256,
    pub status: SwapStatus,
    pub created_at: u64,
    pub completed_at: u64,
    pub nonce: u64,
    pub deadline: u64,
}

#[derive(Drop, Serde, PartialEq, starknet::Store)]
pub enum SwapStatus {
    #[default]
    Pending,
    Completed,
    Cancelled,
    Expired,
}

// Role definitions
pub const DEFAULT_ADMIN_ROLE: felt252 = 0;
pub const OPERATOR_ROLE: felt252 = selector!("OPERATOR_ROLE");
pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
pub const FEE_MANAGER_ROLE: felt252 = selector!("FEE_MANAGER_ROLE");
pub const EMERGENCY_ROLE: felt252 = selector!("EMERGENCY_ROLE");

// Constants
pub const MAX_FEE_RATE: u256 = 10000; // 100%
pub const FEE_DECIMALS: u8 = 4; // 4 decimal places for fee calculation
pub const MAX_SWAP_DEADLINE: u64 = 604800; // 1 week in seconds
