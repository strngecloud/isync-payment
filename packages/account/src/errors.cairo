//! Error definitions for the account package

pub mod AccountErrors {
    pub const ACCOUNT_ALREADY_EXIST: felt252 = 'Account already exists';
    pub const PUBLIC_KEY_CANNOT_BE_ZERO: felt252 = 'Public key cannot be zero';
    pub const ACCOUNT_NOT_FOUND: felt252 = 'Account not found';
    pub const INVALID_PUBLIC_KEY: felt252 = 'Invalid public key';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const INVALID_TOKEN_ADDRESS: felt252 = 'Invalid token address';
    pub const INVALID_BRIDGE_ADDRESS: felt252 = 'Invalid bridge address';
    pub const INVALID_STAKING_ADDRESS: felt252 = 'Invalid staking address';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const TOKEN_NOT_SUPPORTED: felt252 = 'Token not supported';
    pub const SWAP_FAILED: felt252 = 'Token swap failed';
    pub const STAKE_FAILED: felt252 = 'Staking failed';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const INVALID_DURATION: felt252 = 'Invalid lock duration';
}
