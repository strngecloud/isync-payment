//! Event definitions for the ERC20 package

use starknet::ContractAddress;

#[event]
#[derive(Drop, starknet::Event)]
pub enum ERC20Event {
    // Standard ERC20 events
    Transfer: Transfer,
    Approval: Approval,
    
    // Mintable events
    Mint: Mint,
    Burn: Burn,
    
    // Pausable events
    Paused: Paused,
    Unpaused: Unpaused,
    
    // Role events
    RoleGranted: RoleGranted,
    RoleRevoked: RoleRevoked,
    
    // Upgrade events
    Upgraded: Upgraded,
    
    // Custom events
    TokensRecovered: TokensRecovered,
    Blacklisted: Blacklisted,
    Unblacklisted: Unblacklisted,
}

// Standard ERC20 events
#[derive(Drop, starknet::Event)]
pub struct Transfer {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Approval {
    pub owner: ContractAddress,
    pub spender: ContractAddress,
    pub value: u256,
}

// Mintable events
#[derive(Drop, starknet::Event)]
pub struct Mint {
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Burn {
    pub from: ContractAddress,
    pub amount: u256,
}

// Pausable events
#[derive(Drop, starknet::Event)]
pub struct Paused {
    pub account: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Unpaused {
    pub account: ContractAddress,
}

// Role events
#[derive(Drop, starknet::Event)]
pub struct RoleGranted {
    pub role: felt252,
    pub account: ContractAddress,
    pub sender: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct RoleRevoked {
    pub role: felt252,
    pub account: ContractAddress,
    pub sender: ContractAddress,
}

// Upgrade events
#[derive(Drop, starknet::Event)]
pub struct Upgraded {
    pub implementation: ContractAddress,
}

// Custom events
#[derive(Drop, starknet::Event)]
pub struct TokensRecovered {
    pub token: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Blacklisted {
    pub account: ContractAddress,
    pub is_blacklisted: bool,
}

#[derive(Drop, starknet::Event)]
pub struct Unblacklisted {
    pub account: ContractAddress,
    pub is_blacklisted: bool,
}
