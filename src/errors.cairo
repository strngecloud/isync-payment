//
// Custom Errors
//
pub mod AccountErrors {
    pub const CANNOT_BE_ADDR_ZERO: felt252 = 'Address cannot be zero';
    pub const AMOUNT_CANNOT_BE_ZERO: felt252 = 'Amount cannot be zero';
    pub const CURRENCY_IS_REQUIRED: felt252 = 'Currency is required';
    pub const CANNOT_BE_ZERO: felt252 = 'Cannot be zero';
}

pub mod LiquidityBridgeErrors {
    pub const INVALID_TOKEN_ADDRESS: felt252 = 'Invalid token address';
    pub const NOT_REGISTERED: felt252 = 'Token not registered';
    pub const TOKEN_ALREADY_SUPPORTED: felt252 = 'Token already supported';
    pub const INVALID_EXCHANGE_RATE: felt252 = 'Invalid exchange rate/not set';
    pub const INVALID_FIAT_SYMBOL: felt252 = 'fiat_currency is required';
    pub const INVALID_TOKEN_SYMBOL: felt252 = 'token_symbol is required';
    pub const INVALID_AMOUNT: felt252 = 'Amount cannot be zero';
    pub const INVALID_FEE: felt252 = 'Fee cannot be zero';
    pub const INVALID_FEE_BASIS_POINTS: felt252 = 'Fee basis points cannot be zero';
    pub const INVALID_FIAT_ID: felt252 = 'Fiat account ID is required';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const FEE_TOO_HIGH: felt252 = 'fee too high';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const USER_NOT_REGISTERED: felt252 = 'User not registered';
    pub const INSUFFICIENT_FIAT_LIQUIDITY: felt252 = 'Insufficient fiat liquidity';
    pub const INSUFFICIENT_TOKEN_LIQUIDITY: felt252 = 'Insufficient token liquidity';
    pub const CANNOT_BE_ZERO: felt252 = 'Cannot be zero';
    pub const INVALID_SUPPORTED_TOKEN_ADDRESS: felt252 = 'Invalid supported token address';
}
