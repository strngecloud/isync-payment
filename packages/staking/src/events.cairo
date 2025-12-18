//! Event definitions for the staking package

use starknet::ContractAddress;
use starknet::Event;

#[event]
#[derive(Drop, starknet::Event)]
pub enum StakingEvent {
    // Pool events
    PoolCreated: PoolCreated,
    PoolUpdated: PoolUpdated,
    PoolClosed: PoolClosed,
    
    // Staking events
    Staked: Staked,
    Unstaked: Unstaked,
    RewardsClaimed: RewardsClaimed,
    
    // Emergency events
    EmergencyWithdrawal: EmergencyWithdrawal,
    EmergencyWithdrawalInitiated: EmergencyWithdrawalInitiated,
    EmergencyWithdrawalCanceled: EmergencyWithdrawalCanceled,
    
    // Admin events
    RewardsAdded: RewardsAdded,
    PoolPaused: PoolPaused,
    PoolUnpaused: PoolUnpaused,
}

// Pool events
#[derive(Drop, starknet::Event)]
pub struct PoolCreated {
    pub token: ContractAddress,
    pub token_symbol: felt252,
    pub apy: u256,
    pub lock_period: u64,
    pub min_stake: u256,
    pub max_stake: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolUpdated {
    pub token: ContractAddress,
    pub apy: u256,
    pub lock_period: u64,
    pub min_stake: u256,
    pub max_stake: u256,
    pub is_active: bool,
}

#[derive(Drop, starknet::Event)]
pub struct PoolClosed {
    pub token: ContractAddress,
    pub remaining_rewards: u256,
}

// Staking events
#[derive(Drop, starknet::Event)]
pub struct Staked {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub stake_id: u64,
    pub unlock_time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Unstaked {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub stake_id: u64,
    pub reward: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RewardsClaimed {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub stake_id: u64,
}

// Emergency events
#[derive(Drop, starknet::Event)]
pub struct EmergencyWithdrawal {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub stake_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyWithdrawalInitiated {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub stake_id: u64,
    pub unlock_time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyWithdrawalCanceled {
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub stake_id: u64,
}

// Admin events
#[derive(Drop, starknet::Event)]
pub struct RewardsAdded {
    pub token: ContractAddress,
    pub amount: u256,
    pub total_rewards: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolPaused {
    pub token: ContractAddress,
    pub paused_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct PoolUnpaused {
    pub token: ContractAddress,
    pub unpaused_by: ContractAddress,
}
