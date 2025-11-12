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
    pub const INVALID_SUPPORTED_TOKEN: felt252 = 'Invalid supported token address';
    pub const SLIPPAGE_EXCEEDED: felt252 = 'Slippage tolerance exceeded';
    pub const RATE_LIMIT_EXCEEDED: felt252 = 'Rate limit exceeded';
    pub const UNAUTHORIZED_OPERATOR: felt252 = 'Not authorized operator';
    pub const EMERGENCY_MODE_ACTIVE: felt252 = 'Emergency mode active';
    pub const TOKEN_NOT_ACTIVE: felt252 = 'Token not active';
    pub const INSUFFICIENT_LOCKED_FUNDS: felt252 = 'Insufficient locked funds';
}

pub mod StakingErrors {
    pub const POOL_ALREADY_EXISTS: felt252 = 'Pool already exists';
    pub const POOL_DOES_NOT_EXIST: felt252 = 'Pool does not exist';
    pub const POOL_NOT_ACTIVE: felt252 = 'Pool is not active';
    pub const INVALID_AMOUNT: felt252 = 'Invalid staking amount';
    pub const AMOUNT_TOO_LOW: felt252 = 'Amount below minimum';
    pub const AMOUNT_TOO_HIGH: felt252 = 'Amount exceeds maximum';
    pub const INVALID_DURATION: felt252 = 'Invalid lock duration';
    pub const STAKE_NOT_FOUND: felt252 = 'Stake does not exist';
    pub const STAKE_LOCKED: felt252 = 'Stake still locked';
    pub const STAKE_NOT_ACTIVE: felt252 = 'Stake is not active';
    pub const NO_REWARDS: felt252 = 'No rewards to claim';
    pub const REWARDS_NOT_CLAIMABLE: felt252 = 'Rewards not yet claimable';
    pub const CONTRACT_PAUSED: felt252 = 'Contract is paused';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const EMERGENCY_MODE_ACTIVE: felt252 = 'Emergency mode active';
    pub const TOKEN_NOT_ACTIVE: felt252 = 'Token not active';
    pub const INSUFFICIENT_LOCKED_FUNDS: felt252 = 'Insufficient locked funds';
    pub const INVALID_APY: felt252 = 'Invalid APY value';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const INSUFFICIENT_REWARDS: felt252 = 'Insufficient reward balance';
}
