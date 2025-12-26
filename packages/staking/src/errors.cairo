//! Error definitions for the staking package

pub mod staking_errors {
    pub const POOL_ALREADY_EXISTS: felt252 = 'Pool already exists';
    pub const POOL_DOES_NOT_EXIST: felt252 = 'Pool does not exist';
    pub const POOL_NOT_ACTIVE: felt252 = 'Pool is not active';
    pub const INVALID_AMOUNT: felt252 = 'Invalid staking amount';
    pub const AMOUNT_TOO_LOW: felt252 = 'Amount below minimum';
    pub const AMOUNT_TOO_HIGH: felt252 = 'Amount exceeds maximum';
    pub const INVALID_DURATION: felt252 = 'Invalid lock duration';
    pub const DURATION_TOO_SHORT: felt252 = 'Duration too short';
    pub const DURATION_TOO_LONG: felt252 = 'Duration too long';
    pub const STAKE_NOT_FOUND: felt252 = 'Stake not found';
    pub const STAKE_NOT_ACTIVE: felt252 = 'Stake is not active';
    pub const STAKE_NOT_UNLOCKED: felt252 = 'Stake not found';
    pub const STAKE_LOCKED: felt252 = 'Stake is still locked';
    pub const NO_REWARDS: felt252 = 'No rewards to claim';
    pub const INVALID_APY: felt252 = 'Invalid APY value';
    pub const INSUFFICIENT_LIQUIDITY: felt252 = 'Insufficient liquidity in pool';
    pub const INSUFFICIENT_REWARDS: felt252 = 'Insufficient rewards available';
    pub const REWARD_RATE_TOO_HIGH: felt252 = 'Reward rate too high';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    pub const REWARD_ALREADY_CLAIMED: felt252 = 'Reward already claimed';
    pub const EMERGENCY_WITHDRAWAL_ACTIVE: felt252 = 'Emergency withdrawal active';
    pub const EMERGENCY_WITHDRAWAL_NOT_ACTIVE: felt252 = 'Emergency withdrawal not active';
    pub const EMERGENCY_WITHDRAWAL_ALREADY_INITIATED: felt252 = 'Emergency withdrawal started';
    pub const EMERGENCY_WITHDRAWAL_NOT_INITIATED: felt252 = 'Withdrawal not initiated';
    pub const EMERGENCY_WITHDRAWAL_DELAY_NOT_PASSED: felt252 = 'Withdrawal delay not passed';
    pub const EMERGENCY_WITHDRAWAL_GRACE_PERIOD_PASSED: felt252 = 'Grace period expired';
}
