//! Interface definitions for the staking package

use starknet::ContractAddress;
use core::num::traits::Zero;

#[starknet::interface]
pub trait ISyncStaking<T> {
    // Pool management
    fn create_pool(
        ref self: T,
        token: ContractAddress,
        token_symbol: felt252,
        apy: u256,
        lock_period: u64,
        min_stake: u256,
        max_stake: u256,
    );

    fn update_pool(
        ref self: T,
        token: ContractAddress,
        apy: u256,
        lock_period: u64,
        min_stake: u256,
        max_stake: u256,
        is_active: bool,
    );

    fn close_pool(ref self: T, token: ContractAddress);

    // Staking functions
    fn stake(ref self: T, token: ContractAddress, amount: u256) -> u64;
    fn unstake(ref self: T, token: ContractAddress, stake_id: u64) -> u256;
    fn claim_rewards(ref self: T, token: ContractAddress, stake_id: u64) -> u256;
    
    // Emergency functions
    fn initiate_emergency_withdrawal(ref self: T, token: ContractAddress, stake_id: u64);
    fn complete_emergency_withdrawal(ref self: T, token: ContractAddress, stake_id: u64);
    fn cancel_emergency_withdrawal(ref self: T, token: ContractAddress, stake_id: u64);
    
    // Admin functions
    fn add_rewards(ref self: T, token: ContractAddress, amount: u256);
    fn recover_erc20(ref self: T, token: ContractAddress, to: ContractAddress, amount: u256);
    
    // View functions
    fn get_stake(
        self: @T,
        user: ContractAddress,
        token: ContractAddress,
        stake_id: u64,
    ) -> StakeInfo;
    
    fn get_pending_rewards(
        self: @T,
        user: ContractAddress,
        token: ContractAddress,
        stake_id: u64,
    ) -> u256;
    
    fn get_pool_info(self: @T, token: ContractAddress) -> PoolInfo;
    fn get_user_stake_count(self: @T, user: ContractAddress, token: ContractAddress) -> u64;
}

// Data structures
#[derive(Drop, Serde)]
pub struct StakeInfo {
    pub amount: u256,
    pub reward_debt: u256,
    pub unlock_time: u64,
    pub is_active: bool,
    pub emergency_withdrawal_initiated: bool,
    pub emergency_unlock_time: u64,
}

#[derive(Drop, Serde)]
pub struct PoolInfo {
    pub token: ContractAddress,
    pub token_symbol: felt252,
    pub total_staked: u256,
    pub apy: u256,
    pub lock_period: u64,
    pub min_stake: u256,
    pub max_stake: u256,
    pub is_active: bool,
    pub total_rewards: u256,
    pub rewards_paid: u256,
    pub last_update_time: u64,
    pub reward_per_token_stored: u256,
}

// Constants
const SECONDS_PER_DAY: u64 = 86400;
const SECONDS_PER_YEAR: u64 = 31536000; // 365 days
const BASIS_POINTS: u256 = 10000;
const MAX_APY: u256 = 1000; // 1000% maximum APY
const MAX_LOCK_PERIOD: u64 = 1095; // 3 years in days
const EMERGENCY_WITHDRAWAL_DELAY: u64 = 7 * SECONDS_PER_DAY; // 7 days
const EMERGENCY_WITHDRAWAL_GRACE_PERIOD: u64 = 30 * SECONDS_PER_DAY; // 30 days
