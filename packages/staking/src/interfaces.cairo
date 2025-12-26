use core::array::ArrayTrait;
use core::num::traits::Zero;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISyncStaking<TContractState> {
    // Pool management
    fn create_staking_pool(
        ref self: TContractState,
        token_symbol: felt252,
        token_address: ContractAddress,
        base_apy_bps: u16,
        bonus_apy_bps: u16,
        min_stake_amount: u256,
        max_stake_amount: u256,
    );
    fn update_pool_apy(
        ref self: TContractState, token_symbol: felt252, base_apy_bps: u16, bonus_apy_bps: u16,
    );
    fn toggle_pool(ref self: TContractState, token_symbol: felt252);
    fn get_pool(self: @TContractState, token_symbol: felt252) -> StakingPool;
    fn get_all_pools(self: @TContractState) -> Array<StakingPool>;


    // Staking operations
    fn stake(
        ref self: TContractState,
        user: ContractAddress,
        token_symbol: felt252,
        amount: u256,
        lock_duration: u64,
    );
    fn unstake(
        ref self: TContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
    );
    fn claim_rewards(
        ref self: TContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
    );
    fn emergency_unstake(
        ref self: TContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
    );


    // View functions
    fn calculate_rewards(
        self: @TContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
    ) -> u256;
    fn get_stake(
        self: @TContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
    ) -> StakePosition;

    fn get_all_user_stakes_by_symbol(
        self: @TContractState, user: ContractAddress, token_symbol: felt252,
    ) -> Array<StakePosition>;
    fn get_all_user_stakes(self: @TContractState, user: ContractAddress) -> Array<StakePosition>;
    fn get_all_user_fiat_stakes(
        self: @TContractState, user: ContractAddress, currency: felt252,
    ) -> Array<FiatStake>;
    fn get_user_total_staked(
        self: @TContractState, user: ContractAddress, token_symbol: felt252,
    ) -> u256;
    fn get_user_stake_count(
        self: @TContractState, user: ContractAddress, token_symbol: felt252,
    ) -> u64;


    // Admin functions
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);

    // Fiat Staking
    fn record_fiat_stake(
        ref self: TContractState,
        user: ContractAddress,
        currency: felt252,
        amount: u256,
        lock_duration: u64,
        stake_id: u64,
    );
    fn record_fiat_unstake(
        ref self: TContractState, user: ContractAddress, currency: felt252, stake_id: u64,
    );
    fn record_fiat_reward_claim(
        ref self: TContractState,
        user: ContractAddress,
        currency: felt252,
        stake_id: u64,
        rewards: u256,
    );

    // Admin
    fn update_balance_merkle_root(ref self: TContractState, merkle_root: felt252);
    fn create_reserve_snapshot(
        ref self: TContractState, currency: felt252, balance: u256, ipfs_hash: felt252,
    );

    // View
    fn get_version(self: @TContractState) -> felt252;
}

/// Represents a staking pool for a specific token
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct StakingPool {
    pub token_symbol: felt252,
    pub token_address: ContractAddress,
    pub base_apy_bps: u16,
    pub bonus_apy_bps: u16,
    pub total_staked: u256,
    pub total_stakers: u64,
    pub min_stake_amount: u256,
    pub max_stake_amount: u256,
    pub is_active: bool,
    pub created_at: u64,
    pub last_updated: u64,
}

/// Represents a user's stake position in a staking pool
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct StakePosition {
    pub stake_id: u64,
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub staked_at: u64,
    pub unlock_at: u64,
    pub last_reward_claim: u64,
    pub accumulated_rewards: u256,
    pub is_active: bool,
    pub lock_duration: u64,
    pub effective_apy_bps: u16,
}

/// Represents a fiat currency stake
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct FiatStake {
    pub user: ContractAddress,
    pub currency: felt252,
    pub amount: u256,
    pub staked_at: u64,
    pub lock_duration: u64,
    pub is_active: bool,
}

/// Represents a reserve snapshot for fiat staking
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct ReserveSnapshot {
    pub currency: felt252,
    pub balance: u256,
    pub ipfs_hash: felt252,
    pub timestamp: u64,
}

// Constants
const SECONDS_PER_YEAR: u64 = 31536000; // 365 days
const BASIS_POINTS: u256 = 10000_u256;
const MIN_STAKE_DURATION: u64 = 86400; // 1 day in seconds
const MAX_STAKE_DURATION: u64 = 94608000; // 3 years in seconds
