#[starknet::contract]
pub mod SyncStaking {
use starknet::get_contract_address;
use crate::events::stakingEvents::RewardsDeposited;
    use crate::events::stakingEvents::EmergencyWithdrawal;
    use crate::events::stakingEvents::RewardsClaimed;
    use crate::events::stakingEvents::PoolUpdated;
    use crate::events::stakingEvents::Unstaked;
    use crate::events::stakingEvents::Staked;
    use crate::events::stakingEvents::PoolCreated;
    use crate::events::stakingEvents::{FiatStakeRecorded, FiatUnstakeRecorded, FiatRewardClaimRecorded, BalanceMerkleRootUpdated, ReserveSnapshotCreated};
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::istaking::{ISyncStaking, StakePosition, StakingPool, FiatStake};
    use crate::errors::StakingErrors;

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
        // Staking pools per token
        staking_pools: Map<felt252, StakingPool>, // token_symbol => StakingPool
        // User stakes
        user_stakes: Map<
            (ContractAddress, felt252, u64), StakePosition,
        >, // (user, token_symbol, stake_id) => StakePosition
        user_stake_count: Map<(ContractAddress, felt252), u64>, // (user, token_symbol) => count
        user_total_staked: Map<
            (ContractAddress, felt252), u256,
        >, // (user, token_symbol) => total_amount
        // Rewards tracking
        total_rewards_distributed: Map<felt252, u256>, // token_symbol => total_rewards
        user_claimed_rewards: Map<
            (ContractAddress, felt252), u256,
        >, // (user, token_symbol) => claimed_amount
        // Pool tracking
        supported_tokens_list: Map<u8, felt252>, // index => token_symbol
        supported_tokens_count: u8,
        // Integration with LiquidityBridge
        liquidity_bridge: ContractAddress,
        account_factory: ContractAddress,
        // Reward treasury
        reward_treasury: ContractAddress,
        // Emergency withdrawal fee (basis points)
        emergency_withdrawal_fee_bps: u16,
        // Fiat staking
user_fiat_stake_count: Map<(ContractAddress, felt252), u64>, // (user, token_symbol) => count        
        fiat_stakes: Map<(ContractAddress, felt252, u64), FiatStake>, // (user, currency, stake_id) => FiatStake
        balance_merkle_root: felt252, // Merkle root for off-chain balances
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
        PoolCreated: PoolCreated,
        PoolUpdated: PoolUpdated,
        Staked: Staked,
        Unstaked: Unstaked,
        RewardsClaimed: RewardsClaimed,
        EmergencyWithdrawal: EmergencyWithdrawal,
        RewardsDeposited: RewardsDeposited,
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
        liquidity_bridge: ContractAddress,
        account_factory: ContractAddress,
        reward_treasury: ContractAddress,
        emergency_withdrawal_fee_bps: u16,
    ) {
        assert(!owner.is_zero(), StakingErrors::ZERO_ADDRESS);
        assert(!liquidity_bridge.is_zero(), StakingErrors::ZERO_ADDRESS);
        assert(!reward_treasury.is_zero(), StakingErrors::ZERO_ADDRESS);

        self.ownable.initializer(owner);
        self.liquidity_bridge.write(liquidity_bridge);
        self.account_factory.write(account_factory);
        self.reward_treasury.write(reward_treasury);
        self.emergency_withdrawal_fee_bps.write(emergency_withdrawal_fee_bps);
        self.supported_tokens_count.write(0_u8);
        self.version.write('1.0.0');
    }

    #[abi(embed_v0)]
    impl SyncStakingImpl of ISyncStaking<ContractState> {
        /// Create a new staking pool for a token
        fn create_staking_pool(
            ref self: ContractState,
            token_symbol: felt252,
            token_address: ContractAddress,
            base_apy_bps: u16,
            bonus_apy_bps: u16,
            min_stake_amount: u256,
            max_stake_amount: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(!token_symbol.is_zero(), StakingErrors::ZERO_ADDRESS);
            assert(!token_address.is_zero(), StakingErrors::ZERO_ADDRESS);
            assert(base_apy_bps <= 5000, StakingErrors::INVALID_APY); // Max 50% base APY
            assert(bonus_apy_bps <= 5000, StakingErrors::INVALID_APY); // Max 50% bonus APY
            assert(min_stake_amount > 0, StakingErrors::INVALID_AMOUNT);
            assert(max_stake_amount >= min_stake_amount, StakingErrors::INVALID_AMOUNT);

            let existing_pool = self.staking_pools.read(token_symbol);
            assert(!existing_pool.is_active, StakingErrors::POOL_ALREADY_EXISTS);

            let pool = StakingPool {
                token_symbol,
                token_address,
                base_apy_bps,
                bonus_apy_bps,
                total_staked: 0,
                total_stakers: 0,
                min_stake_amount,
                max_stake_amount,
                is_active: true,
                created_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
            };

            self.staking_pools.write(token_symbol, pool);

            // Add to tracking list
            let count = self.supported_tokens_count.read();
            self.supported_tokens_list.write(count, token_symbol);
            self.supported_tokens_count.write(count + 1);

            self.emit(PoolCreated { token_symbol, token_address, base_apy_bps, min_stake_amount });
        }

        /// Stake tokens with a lock period
        fn stake(ref self: ContractState, user: ContractAddress, token_symbol: felt252, amount: u256, lock_duration: u64) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();

            let mut pool = self.staking_pools.read(token_symbol);

            // Validations
            assert(pool.is_active, StakingErrors::POOL_NOT_ACTIVE);
            assert(amount >= pool.min_stake_amount, StakingErrors::AMOUNT_TOO_LOW);
            assert(amount <= pool.max_stake_amount, StakingErrors::AMOUNT_TOO_HIGH);
            assert(lock_duration >= MIN_STAKE_DURATION, StakingErrors::INVALID_DURATION);
            assert(lock_duration <= MAX_STAKE_DURATION, StakingErrors::INVALID_DURATION);

            // Calculate effective APY based on lock duration
            let effective_apy_bps = self
                .calculate_effective_apy(pool.base_apy_bps, pool.bonus_apy_bps, lock_duration);

            // Transfer tokens from user to contract
            let token = IERC20Dispatcher { contract_address: pool.token_address };
            token.transfer_from(user, get_contract_address(), amount);

            // Create stake position
            let current_time = get_block_timestamp();
            let stake_id = self.user_stake_count.read((user, token_symbol));

            let stake = StakePosition {
                stake_id,
                user,
                token_symbol,
                amount,
                staked_at: current_time,
                unlock_at: current_time + lock_duration,
                last_reward_claim: current_time,
                accumulated_rewards: 0,
                is_active: true,
                lock_duration,
                effective_apy_bps,
            };

            self.user_stakes.write((user, token_symbol, stake_id), stake);
            self.user_stake_count.write((user, token_symbol), stake_id + 1);

            // Update pool stats
            pool.total_staked += amount;
            if stake_id == 0 {
                pool.total_stakers += 1;
            }
            pool.last_updated = current_time;
            self.staking_pools.write(token_symbol, pool);

            // Update user total
            let user_total = self.user_total_staked.read((user, token_symbol));
            self.user_total_staked.write((user, token_symbol), user_total + amount);

            self
                .emit(
                    Staked {
                        user,
                        token_symbol,
                        stake_id,
                        amount,
                        lock_duration,
                        unlock_at: current_time + lock_duration,
                        effective_apy_bps,
                    },
                );

            self.reentrancy.end();
        }

        /// Unstake tokens after lock period
        fn unstake(ref self: ContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();

            let mut stake = self.user_stakes.read((user, token_symbol, stake_id));

            // Validations
            assert(stake.is_active, StakingErrors::STAKE_NOT_ACTIVE);
            assert(get_block_timestamp() >= stake.unlock_at, StakingErrors::STAKE_LOCKED);

            // Calculate final rewards
            let rewards = self.calculate_rewards_internal(stake);

            // Update stake
            stake.is_active = false;
            stake.accumulated_rewards += rewards;
            self.user_stakes.write((user, token_symbol, stake_id), stake);

            // Update pool stats
            let mut pool = self.staking_pools.read(token_symbol);
            pool.total_staked -= stake.amount;
            pool.last_updated = get_block_timestamp();
            self.staking_pools.write(token_symbol, pool);

            // Update user total
            let user_total = self.user_total_staked.read((user, token_symbol));
            self.user_total_staked.write((user, token_symbol), user_total - stake.amount);

            // Transfer principal + rewards
            let token = IERC20Dispatcher { contract_address: pool.token_address };
            let total_amount = stake.amount + stake.accumulated_rewards;

            // Check reward treasury has enough balance
            let treasury_balance = token.balance_of(self.reward_treasury.read());
            assert(treasury_balance >= stake.accumulated_rewards, StakingErrors::INSUFFICIENT_REWARDS);

            // Transfer from treasury to contract, then to user
            if stake.accumulated_rewards > 0 {
                token
                    .transfer_from(
                        self.reward_treasury.read(),
                        starknet::get_contract_address(),
                        stake.accumulated_rewards,
                    );
            }

            token.transfer(user, total_amount);

            // Update tracking
            self
                .total_rewards_distributed
                .write(
                    token_symbol,
                    self.total_rewards_distributed.read(token_symbol) + stake.accumulated_rewards,
                );

            let user_claimed = self.user_claimed_rewards.read((user, token_symbol));
            self
                .user_claimed_rewards
                .write((user, token_symbol), user_claimed + stake.accumulated_rewards);

            self
                .emit(
                    Unstaked {
                        user,
                        token_symbol,
                        stake_id,
                        amount: stake.amount,
                        rewards: stake.accumulated_rewards,
                    },
                );

            self.reentrancy.end();
        }

        /// Claim accumulated rewards without unstaking
        fn claim_rewards(ref self: ContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();

            let mut stake = self.user_stakes.read((user, token_symbol, stake_id));

            assert(stake.is_active, StakingErrors::STAKE_NOT_ACTIVE);

            let rewards = self.calculate_rewards_internal(stake);
            assert(rewards > 0, StakingErrors::NO_REWARDS);

            // Update stake
            stake.last_reward_claim = get_block_timestamp();
            stake.accumulated_rewards += rewards;
            self.user_stakes.write((user, token_symbol, stake_id), stake);

            // Transfer rewards
            let pool = self.staking_pools.read(token_symbol);
            let token = IERC20Dispatcher { contract_address: pool.token_address };

            // Transfer from treasury
            token
                .transfer_from(
                    self.reward_treasury.read(), starknet::get_contract_address(), rewards,
                );
            token.transfer(user, rewards);

            // Update tracking
            self
                .total_rewards_distributed
                .write(token_symbol, self.total_rewards_distributed.read(token_symbol) + rewards);

            let user_claimed = self.user_claimed_rewards.read((user, token_symbol));
            self.user_claimed_rewards.write((user, token_symbol), user_claimed + rewards);

            self.emit(RewardsClaimed { user, token_symbol, amount: rewards });

            self.reentrancy.end();
        }

        /// Emergency unstake with penalty
        fn emergency_unstake(ref self: ContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();

            let mut stake = self.user_stakes.read((user, token_symbol, stake_id));

            assert(stake.is_active, StakingErrors::STAKE_NOT_ACTIVE);

            // Calculate penalty
            let penalty = (stake.amount * self.emergency_withdrawal_fee_bps.read().into())
                / BASIS_POINTS;
            let amount_after_penalty = stake.amount - penalty;

            // Update stake
            stake.is_active = false;
            self.user_stakes.write((user, token_symbol, stake_id), stake);

            // Update pool stats
            let mut pool = self.staking_pools.read(token_symbol);
            pool.total_staked -= stake.amount;
            pool.last_updated = get_block_timestamp();
            self.staking_pools.write(token_symbol, pool);

            // Update user total
            let user_total = self.user_total_staked.read((user, token_symbol));
            self.user_total_staked.write((user, token_symbol), user_total - stake.amount);

            // Transfer tokens
            let token = IERC20Dispatcher { contract_address: pool.token_address };
            token.transfer(user, amount_after_penalty);
            token.transfer(self.reward_treasury.read(), penalty); // Penalty goes to treasury

            self
                .emit(
                    EmergencyWithdrawal {
                        user, token_symbol, stake_id, amount: stake.amount, penalty,
                    },
                );

            self.reentrancy.end();
        }

        fn calculate_rewards(
            self: @ContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
        ) -> u256 {
            let stake = self.user_stakes.read((user, token_symbol, stake_id));
            if !stake.is_active {
                return 0;
            }
            self.calculate_rewards_internal(stake)
        }

        /// Get user's stake position
        fn get_stake(
            self: @ContractState, user: ContractAddress, token_symbol: felt252, stake_id: u64,
        ) -> StakePosition {
            self.user_stakes.read((user, token_symbol, stake_id))
        }

        fn get_all_user_stakes_by_symbol(
            self: @ContractState, user: ContractAddress, token_symbol: felt252,
        ) -> Array<StakePosition> {
            let mut result: Array<StakePosition> = ArrayTrait::new();
            let count = self.user_stake_count.read((user, token_symbol));
            for i in 0..count {
                result.append(self.user_stakes.read((user, token_symbol, i)));
            }
            result
        }

        fn get_all_user_stakes(
            self: @ContractState, user: ContractAddress,
        ) -> Array<StakePosition> {
            let mut result: Array<StakePosition> = ArrayTrait::new();
            let supported_tokens_count = self.supported_tokens_count.read();
            
            let mut token_idx = 0_u8;
            while token_idx != supported_tokens_count {
                
                let token_symbol = self.supported_tokens_list.read(token_idx);
                let stake_count = self.user_stake_count.read((user, token_symbol));
                
                let mut stake_idx = 0_u64;
                while stake_idx != stake_count {
                    result.append(self.user_stakes.read((user, token_symbol, stake_idx)));
                    stake_idx += 1;
                };
                
                token_idx += 1;
            };
            
            result
        }

        fn get_pool(self: @ContractState, token_symbol: felt252) -> StakingPool {
            self.staking_pools.read(token_symbol)
        }

        fn get_user_total_staked(
            self: @ContractState, user: ContractAddress, token_symbol: felt252,
        ) -> u256 {
            self.user_total_staked.read((user, token_symbol))
        }

        fn get_user_stake_count(
            self: @ContractState, user: ContractAddress, token_symbol: felt252,
        ) -> u64 {
            self.user_stake_count.read((user, token_symbol))
        }

        fn update_pool_apy(
            ref self: ContractState, token_symbol: felt252, base_apy_bps: u16, bonus_apy_bps: u16,
        ) {
            self.ownable.assert_only_owner();
            assert(base_apy_bps <= 5000, StakingErrors::INVALID_APY);
            assert(bonus_apy_bps <= 5000, StakingErrors::INVALID_APY);

            let mut pool = self.staking_pools.read(token_symbol);
            assert(pool.is_active, StakingErrors::POOL_DOES_NOT_EXIST);

            pool.base_apy_bps = base_apy_bps;
            pool.bonus_apy_bps = bonus_apy_bps;
            pool.last_updated = get_block_timestamp();
            self.staking_pools.write(token_symbol, pool);

            self.emit(PoolUpdated { token_symbol, base_apy_bps, bonus_apy_bps });
        }

        /// Toggle pool active status
        fn toggle_pool(ref self: ContractState, token_symbol: felt252) {
            self.ownable.assert_only_owner();
            let mut pool = self.staking_pools.read(token_symbol);
            pool.is_active = !pool.is_active;
            self.staking_pools.write(token_symbol, pool);
        }

        /// Get all supported tokens
        fn get_all_pools(self: @ContractState) -> Array<StakingPool> {
            let mut result: Array<StakingPool> = ArrayTrait::new();
            let count = self.supported_tokens_count.read();

            let mut i: u8 = 0;
            while i != count {
                let token_symbol = self.supported_tokens_list.read(i);
                let pool = self.staking_pools.read(token_symbol);
                result.append(pool);
                i += 1;
            }

            result
        }

        /// Pause contract
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        /// Unpause contract
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        // Fiat Staking
        fn record_fiat_stake(
            ref self: ContractState, 
            user: ContractAddress, 
            currency: felt252, 
            amount: u256, 
            lock_duration: u64, 
            stake_id: u64
        ) {
            self.ownable.assert_only_owner();
            let new_stake = FiatStake {
                user,
                currency,
                amount,
                staked_at: get_block_timestamp(),
                lock_duration,
                is_active: true
            };
            // Convert felt252 stake_id to u64 for storage
            self.fiat_stakes.write((user, currency, stake_id), new_stake);
            self.emit(FiatStakeRecorded { currency, amount, lock_duration, stake_id });
        }

        fn record_fiat_unstake(ref self: ContractState, user: ContractAddress, currency: felt252, stake_id: u64) {
            self.ownable.assert_only_owner();
            let mut stake = self.fiat_stakes.read((user, currency, stake_id));
            stake.is_active = false;
            self.fiat_stakes.write((user, currency, stake_id), stake);
            self.emit(FiatUnstakeRecorded { user, currency, stake_id });
        }

        fn record_fiat_reward_claim(ref self: ContractState, user: ContractAddress, currency: felt252, stake_id: u64, rewards: u256) {
            self.ownable.assert_only_owner();
            self.emit(FiatRewardClaimRecorded { user, currency, stake_id, rewards });
        }

        fn get_all_user_fiat_stakes(self: @ContractState, user: ContractAddress, currency: felt252) -> Array<FiatStake> {
            let mut result: Array<FiatStake> = ArrayTrait::new();
            let count = self.user_fiat_stake_count.read((user, currency));
            for i in 0..count {
                result.append(self.fiat_stakes.read((user, currency, i)));
            }
            result
        }

        // Admin
        fn update_balance_merkle_root(ref self: ContractState, merkle_root: felt252) {
            self.ownable.assert_only_owner();
            self.balance_merkle_root.write(merkle_root);
            self.emit(BalanceMerkleRootUpdated { merkle_root });
        }

        fn create_reserve_snapshot(ref self: ContractState, currency: felt252, balance: u256, ipfs_hash: felt252) {
            self.ownable.assert_only_owner();
            self.emit(ReserveSnapshotCreated { currency, balance, ipfs_hash });
        }

        fn get_version(self: @ContractState) -> felt252 {
            self.version.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Internal: Calculate rewards for a stake position
        fn calculate_rewards_internal(self: @ContractState, stake: StakePosition) -> u256 {
            let current_time = get_block_timestamp();
            let time_elapsed = current_time - stake.last_reward_claim;

            if time_elapsed == 0 {
                return 0;
            }

            // Reward = (amount * APY * time_elapsed) / (BASIS_POINTS * SECONDS_PER_YEAR)
            let reward = (stake.amount * stake.effective_apy_bps.into() * time_elapsed.into())
                / (BASIS_POINTS * SECONDS_PER_YEAR.into());

            reward
        }

        /// Internal: Calculate effective APY with bonus
        fn calculate_effective_apy(
            self: @ContractState, base_apy_bps: u16, bonus_apy_bps: u16, lock_duration: u64,
        ) -> u16 {
            // Bonus scales linearly from 0% at MIN_STAKE_DURATION to 100% at MAX_STAKE_DURATION
            let duration_range = MAX_STAKE_DURATION - MIN_STAKE_DURATION;
            let user_range = lock_duration - MIN_STAKE_DURATION;

            let bonus_multiplier = (user_range * 10000_u64) / duration_range; // in basis points

            let bonus = (bonus_apy_bps.into() * bonus_multiplier.into()) / 10000_u256;
            base_apy_bps + bonus.try_into().unwrap()
        }
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
