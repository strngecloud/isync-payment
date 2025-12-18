//! Staking contract implementation for Sync Protocol

use core::num::traits::Zero;
use sync_core::interfaces::ISyncStaking;
use sync_core::interfaces::IERC20Dispatcher;
use sync_core::interfaces::IERC20DispatcherTrait;
use sync_core::errors::staking_errors::*;
use sync_core::events::staking_events::{
    PoolCreated, PoolUpdated, Staked, Unstaked, RewardsClaimed, EmergencyWithdrawal, 
    RewardsDeposited, FiatStakeRecorded, FiatUnstakeRecorded, FiatRewardClaimRecorded,
    BalanceMerkleRootUpdated, ReserveSnapshotCreated
};

use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::security::pausable::PausableComponent;
use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
use openzeppelin::upgrades::UpgradeableComponent;
use openzeppelin::upgrades::interface::IUpgradeable;

use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};

#[starknet::contract]
pub mod SyncStaking {
    use super::*;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Constants
    const SECONDS_PER_YEAR: u64 = 31536000; // 365 days
    const BASIS_POINTS: u256 = 10000;
    const MIN_STAKE_DURATION: u64 = 86400; // 1 day minimum
    const MAX_STAKE_DURATION: u64 = 31536000; // 1 year maximum

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        
        // Pool management
        pools: Map<felt252, StakingPool>, // token_symbol => StakingPool
        pool_tokens: Array<felt252>,
        
        // User stakes
        user_stakes: Map<(ContractAddress, felt252, u64), StakePosition>, // (user, token_symbol, stake_id) => StakePosition
        user_stake_count: Map<(ContractAddress, felt252), u64>, // (user, token_symbol) => count
        
        // Rewards
        rewards: Map<(ContractAddress, felt252), u256>, // (user, token_symbol) => pending_rewards
        
        // Fiat staking
        fiat_stakes: Map<(ContractAddress, felt252, u64), FiatStake>, // (user, currency, stake_id) => FiatStake
        user_fiat_stake_count: Map<(ContractAddress, felt252), u64>, // (user, token_symbol) => count
        
        // Merkle root for off-chain balances
        balance_merkle_root: felt252,
        
        // Versioning
        version: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        
        // Staking events
        PoolCreated: PoolCreated,
        PoolUpdated: PoolUpdated,
        Staked: Staked,
        Unstaked: Unstaked,
        RewardsClaimed: RewardsClaimed,
        EmergencyWithdrawal: EmergencyWithdrawal,
        RewardsDeposited: RewardsDeposited,
        
        // Fiat staking events
        FiatStakeRecorded: FiatStakeRecorded,
        FiatUnstakeRecorded: FiatUnstakeRecorded,
        FiatRewardClaimRecorded: FiatRewardClaimRecorded,
        BalanceMerkleRootUpdated: BalanceMerkleRootUpdated,
        ReserveSnapshotCreated: ReserveSnapshotCreated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        version: felt252,
    ) {
        self.ownable.initializer(owner);
        self.version.write(version);
    }

    #[abi(embed_v0)]
    impl SyncStakingImpl of ISyncStaking<ContractState> {
        fn create_staking_pool(
            ref self: ContractState,
            token_symbol: felt252,
            token_address: ContractAddress,
            base_apy_bps: u256,
            bonus_apy_bps: u256,
            min_stake_amount: u256,
            max_stake_amount: u256,
            lock_duration: u64,
            is_active: bool,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.pools.read(token_symbol).is_active, POOL_ALREADY_EXISTS);
            
            let pool = StakingPool {
                token_address,
                base_apy_bps,
                bonus_apy_bps,
                min_stake_amount,
                max_stake_amount,
                lock_duration,
                is_active,
                total_staked: 0,
                last_update_time: get_block_timestamp(),
                reward_per_token_stored: 0,
                total_rewards: 0,
                total_rewards_paid: 0,
            };
            
            self.pools.write(token_symbol, pool);
            self.pool_tokens.append(token_symbol);
            
            self.emit(PoolCreated {
                token_symbol,
                token_address,
                base_apy_bps,
                bonus_apy_bps,
                min_stake_amount,
                max_stake_amount,
                lock_duration,
                is_active,
            });
        }

        fn stake(
            ref self: ContractState,
            user: ContractAddress,
            token_symbol: felt252,
            amount: u256,
            lock_duration: u64,
        ) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();
            
            let pool = self.pools.read(token_symbol);
            assert(pool.is_active, POOL_NOT_ACTIVE);
            assert(amount >= pool.min_stake_amount, STAKE_AMOUNT_TOO_LOW);
            assert(amount <= pool.max_stake_amount, STAKE_AMOUNT_TOO_HIGH);
            assert(lock_duration >= MIN_STAKE_DURATION, INVALID_LOCK_DURATION);
            assert(lock_duration <= MAX_STAKE_DURATION, INVALID_LOCK_DURATION);
            
            // Transfer tokens from user to this contract
            let token = IERC20Dispatcher { contract_address: pool.token_address };
            token.transfer_from(user, get_contract_address(), amount);
            
            // Create new stake position
            let stake_id = self.user_stake_count.read((user, token_symbol)) + 1;
            let unlock_time = get_block_timestamp() + lock_duration;
            
            let position = StakePosition {
                amount,
                unlock_time,
                reward_debt: 0,
                pending_rewards: 0,
                is_active: true,
            };
            
            self.user_stakes.write((user, token_symbol, stake_id), position);
            self.user_stake_count.write((user, token_symbol), stake_id);
            
            // Update pool totals
            self.pools.write(token_symbol, StakingPool {
                total_staked: pool.total_staked + amount,
                ..pool
            });
            
            self.emit(Staked {
                user,
                token_symbol,
                amount,
                stake_id,
                unlock_time,
            });
        }
        
        // ... (other functions from the original implementation)
        
        fn get_stake_position(
            self: @ContractState,
            user: ContractAddress,
            token_symbol: felt252,
            stake_id: u64,
        ) -> StakePosition {
            self.user_stakes.read((user, token_symbol, stake_id))
        }
        
        fn get_user_stake_count(
            self: @ContractState,
            user: ContractAddress,
            token_symbol: felt252,
        ) -> u64 {
            self.user_stake_count.read((user, token_symbol))
        }
        
        fn get_pool_info(self: @ContractState, token_symbol: felt252) -> StakingPool {
            self.pools.read(token_symbol)
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn calculate_rewards(
            self: @ContractState,
            user: ContractAddress,
            token_symbol: felt252,
            stake_id: u64,
        ) -> u256 {
            let stake = self.user_stakes.read((user, token_symbol, stake_id));
            if !stake.is_active {
                return 0;
            }
            
            let pool = self.pools.read(token_symbol);
            let time_elapsed = get_block_timestamp() - pool.last_update_time;
            
            if time_elapsed == 0 || pool.total_staked == 0 {
                return 0;
            }
            
            let reward_rate = (pool.base_apy_bps * pool.total_staked) / (SECONDS_PER_YEAR * BASIS_POINTS);
            let rewards = reward_rate * time_elapsed * stake.amount / pool.total_staked;
            
            rewards + stake.pending_rewards
        }
    }
    
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
