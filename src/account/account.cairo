#[starknet::contract(account)]
pub mod Account {
    use core::num::traits::Zero;
    use isyncpayment::interfaces::iaccount::IAccount;
    use isyncpayment::interfaces::iliquidityBridge::{
        ILiquidityBridgeDispatcher, ILiquidityBridgeDispatcherTrait,
    };
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::extensions::SRC9Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_contract_address};
    use crate::errors::*;
    use crate::events::accountEvents::{
        AutoStakeConfigured, PaymentMade, StakingExecuted, TokenApproved,
    };
    use crate::interfaces::istaking::{ISyncStakingDispatcher, ISyncStakingDispatcherTrait};

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SRC9Component, storage: src9, event: SRC9Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OutsideExecutionV2Impl =
        SRC9Component::OutsideExecutionV2Impl<ContractState>;

    // Internal
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    impl OutsideExecutionInternalImpl = SRC9Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        src9: SRC9Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        token_address: Map<felt252, ContractAddress>, // symbol => token_address
        liquidity_bridge: ContractAddress,
        // Staking
        staking_contract: ContractAddress,
        // Auto-staking preferences
        auto_stake_enabled: Map<felt252, bool>, // token_symbol => enabled
        auto_stake_duration: Map<felt252, u64>, // token_symbol => lock_duration
        auto_stake_threshold: Map<felt252, u256> // token_symbol => min amount to auto-stake
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        SRC9Event: SRC9Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        PaymentMade: PaymentMade,
        TokenApproved: TokenApproved,
        StakingExecuted: StakingExecuted,
        AutoStakeConfigured: AutoStakeConfigured,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
        self.src9.initializer();
    }

    //
    // SyncPayment Implementation
    //

    #[abi(embed_v0)]
    impl SyncPaymentImpl of IAccount<ContractState> {
        fn set_liquidity_bridge(ref self: ContractState, bridge: ContractAddress) {
            self.account.assert_only_self();
            assert(!bridge.is_zero(), 'Invalid bridge address');
            self.liquidity_bridge.write(bridge);
        }

        fn set_staking_contract(ref self: ContractState, staking: ContractAddress) {
            self.account.assert_only_self();
            assert(!staking.is_zero(), 'Invalid staking address');
            self.staking_contract.write(staking);
        }

        fn set_token_address(
            ref self: ContractState, symbol: felt252, token_address: ContractAddress,
        ) {
            self.account.assert_only_self();
            assert(!token_address.is_zero(), 'Invalid token address');
            self.token_address.write(symbol, token_address);
        }

        fn get_liquidity_bridge(self: @ContractState) -> ContractAddress {
            self.liquidity_bridge.read()
        }

        fn get_token_address(self: @ContractState, symbol: felt252) -> ContractAddress {
            self.token_address.read(symbol)
        }

        fn swap_fiat_to_token(
            ref self: ContractState,
            swap_order_id: felt252,
            fiat_symbol: felt252,
            token_symbol: felt252,
            fiat_amount: u256,
            token_amount: u256,
            fee: u128,
        ) -> bool {
            self.account.assert_only_self();
            let bridge = self.liquidity_bridge.read();
            assert(!bridge.is_zero(), 'Liquidity bridge not set');

            let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address: bridge };
            let success = bridge_dispatcher
                .swap_fiat_to_token(
                    get_contract_address(), // User is this account
                    swap_order_id,
                    fiat_symbol,
                    token_symbol,
                    fiat_amount,
                    token_amount,
                    fee,
                );

            // Auto-stake if enabled
            if success && self.auto_stake_enabled.read(token_symbol) {
                let threshold = self.auto_stake_threshold.read(token_symbol);
                if token_amount >= threshold {
                    self.execute_auto_stake(token_symbol, token_amount);
                }
            }

            success
        }

        fn swap_token_to_fiat(
            ref self: ContractState,
            swap_order_id: felt252,
            fiat_symbol: felt252,
            token_symbol: felt252,
            token_amount: u256,
        ) -> bool {
            self.account.assert_only_self();
            let bridge = self.liquidity_bridge.read();
            assert(!bridge.is_zero(), 'Liquidity bridge not set');

            let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address: bridge };
            bridge_dispatcher
                .swap_token_to_fiat(
                    get_contract_address(), swap_order_id, fiat_symbol, token_symbol, token_amount,
                )
        }

        // Staking Functions
        fn stake_tokens(
            ref self: ContractState, token_symbol: felt252, amount: u256, lock_duration: u64,
        ) -> bool {
            self.account.assert_only_self();
            let staking = self.staking_contract.read();
            assert(!staking.is_zero(), 'Staking contract not set');

            // Approve staking contract
            let token_address = self.token_address.read(token_symbol);
            assert(!token_address.is_zero(), 'Token not configured');

            let token = IERC20Dispatcher { contract_address: token_address };
            token.approve(staking, amount);

            // Execute stake
            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.stake(token_symbol, amount, lock_duration);

            self
                .emit(
                    StakingExecuted {
                        user: get_contract_address(), token_symbol, amount, lock_duration,
                    },
                );

            true
        }

        fn unstake_tokens(ref self: ContractState, token_symbol: felt252, stake_id: u64) -> bool {
            self.account.assert_only_self();
            let staking = self.staking_contract.read();
            assert(!staking.is_zero(), 'Staking contract not set');

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.unstake(token_symbol, stake_id);

            true
        }

        fn claim_staking_rewards(
            ref self: ContractState, token_symbol: felt252, stake_id: u64,
        ) -> bool {
            self.account.assert_only_self();
            let staking = self.staking_contract.read();
            assert(!staking.is_zero(), 'Staking contract not set');

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.claim_rewards(token_symbol, stake_id);

            true
        }

        fn emergency_unstake_tokens(
            ref self: ContractState, token_symbol: felt252, stake_id: u64,
        ) -> bool {
            self.account.assert_only_self();
            let staking = self.staking_contract.read();
            assert(!staking.is_zero(), 'Staking contract not set');

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.emergency_unstake(token_symbol, stake_id);

            true
        }

        // Auto-staking configuration
        fn configure_auto_stake(
            ref self: ContractState,
            token_symbol: felt252,
            enabled: bool,
            duration: u64,
            threshold: u256,
        ) {
            self.account.assert_only_self();

            self.auto_stake_enabled.write(token_symbol, enabled);
            if enabled {
                self.auto_stake_duration.write(token_symbol, duration);
                self.auto_stake_threshold.write(token_symbol, threshold);
            }

            self.emit(AutoStakeConfigured { token_symbol, enabled, duration, threshold });
        }

        fn get_auto_stake_config(self: @ContractState, token_symbol: felt252) -> (bool, u64, u256) {
            (
                self.auto_stake_enabled.read(token_symbol),
                self.auto_stake_duration.read(token_symbol),
                self.auto_stake_threshold.read(token_symbol),
            )
        }

        // View functions
        fn get_my_stakes(self: @ContractState, token_symbol: felt252) -> Array<u64> {
            let staking = self.staking_contract.read();
            if staking.is_zero() {
                return ArrayTrait::new();
            }

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            let stake_count = staking_dispatcher
                .get_user_stake_count(get_contract_address(), token_symbol);

            let mut stakes: Array<u64> = ArrayTrait::new();
            let mut i: u64 = 0;
            while i != stake_count {
                stakes.append(i);
                i += 1;
            }

            stakes
        }

        fn get_my_total_staked(self: @ContractState, token_symbol: felt252) -> u256 {
            let staking = self.staking_contract.read();
            if staking.is_zero() {
                return 0;
            }

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.get_user_total_staked(get_contract_address(), token_symbol)
        }

        fn get_stake_rewards(self: @ContractState, token_symbol: felt252, stake_id: u64) -> u256 {
            let staking = self.staking_contract.read();
            if staking.is_zero() {
                return 0;
            }

            let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
            staking_dispatcher.calculate_rewards(get_contract_address(), token_symbol, stake_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn execute_auto_stake(ref self: ContractState, token_symbol: felt252, amount: u256) {
            let duration = self.auto_stake_duration.read(token_symbol);
            let staking = self.staking_contract.read();

            if !staking.is_zero() && duration > 0 {
                let token_address = self.token_address.read(token_symbol);
                if !token_address.is_zero() {
                    let token = IERC20Dispatcher { contract_address: token_address };
                    token.approve(staking, amount);

                    let staking_dispatcher = ISyncStakingDispatcher { contract_address: staking };
                    staking_dispatcher.stake(token_symbol, amount, duration);

                    self
                        .emit(
                            StakingExecuted {
                                user: get_contract_address(),
                                token_symbol,
                                amount,
                                lock_duration: duration,
                            },
                        );
                }
            }
        }
    }


    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.account.assert_only_self();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
