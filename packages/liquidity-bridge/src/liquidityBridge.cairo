#[starknet::contract]
pub mod LiquidityBridge {
    use core::num::traits::{Pow, Zero};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::errors::{*, bridge_errors};
    use crate::events::*;
    use crate::interfaces::{
        FEE_MANAGER_ROLE, ILiquidityBridge, PoolInfo, SwapInfo, SwapStatus, TokenInfo,
    };

    // Role definitions
    const ADMIN_ROLE: felt252 = 0;
    const OPERATOR_ROLE: felt252 = selector!("OPERATOR_ROLE");
    const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
    const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");
    
    // Components
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Token registry
        tokens: Map<ContractAddress, TokenInfo>,
        token_by_symbol: Map<felt252, ContractAddress>,
        // Swap state
        next_swap_id: u64,
        swaps: Map<u64, SwapInfo>,
        // Fee configuration
        fee_receiver: ContractAddress,
        swap_fee_rate: u256,
        // Slippage tolerance (bps)
        slippage_tolerance_bps: u16,
        // Authorized operators
        authorized_operators: Map<ContractAddress, bool>,
        // User registration
        user_accounts: Map<ContractAddress, bool>,
        fiat_account_id: Map<ContractAddress, felt252>,
        user_accounts_count: u64,
        // Fiat swap state
        pragma_oracle_address: ContractAddress,
        fee_bps: u16,
        // Locked funds for withdrawals
        locked_funds: Map<(ContractAddress, felt252), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        FeeDistributed: FeeDistributed,
        EmergencyWithdraw: EmergencyWithdraw,
        // Custom events
        TokenAdded: TokenAdded,
        TokenRemoved: TokenRemoved,
        TokenPaused: TokenPaused,
        TokenUnpaused: TokenUnpaused,
        SwapCreated: SwapCreated,
        SwapCancelled: SwapCancelled,
        SwapExecuted: SwapExecuted,
        LiquidityAdded: LiquidityAdded,
        LiquidityRemoved: LiquidityRemoved,
        FeeReceiverUpdated: FeeReceiverUpdated,
        SwapFeeUpdated: SwapFeeUpdated,
        EmergencyModeToggled: EmergencyModeToggled,
        // Operator & User events
        OperatorAuthorized: OperatorAuthorized,
        OperatorRevoked: OperatorRevoked,
        UserRegistered: UserRegistered,
        // Fiat swap events
        FundsLocked: FundsLocked,
        WithdrawalCompleted: WithdrawalCompleted,
        FundsUnlocked: FundsUnlocked,
        ExchangeRateUpdated: ExchangeRateUpdated,
        FeeUpdated: FeeUpdated,
        SlippageToleranceUpdated: SlippageToleranceUpdated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        pauser: ContractAddress,
        operator: ContractAddress,
        fee_receiver: ContractAddress,
        initial_swap_fee: u256,
    ) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);
        self.accesscontrol._grant_role(PAUSER_ROLE, pauser);
        self.accesscontrol._grant_role(OPERATOR_ROLE, operator);
        self.accesscontrol._grant_role(UPGRADER_ROLE, admin);

        // Set fee receiver and initial swap fee
        self.fee_receiver.write(fee_receiver);
        self.swap_fee_rate.write(initial_swap_fee);

        // Initialize next_swap_id
        self.next_swap_id.write(1);
        // Default slippage tolerance: 1% (100 bps)
        self.slippage_tolerance_bps.write(100);
    }

    #[abi(embed_v0)]
    impl LiquidityBridgeImpl of ILiquidityBridge<ContractState> {
        // Token management
        fn add_token(
            ref self: ContractState,
            token: ContractAddress,
            symbol: felt252,
            feed_id: felt252,
            decimals: u8,
            min_amount: u256,
            max_amount: u256,
            is_active: bool,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            assert(!token.is_zero(), bridge_errors::ZERO_ADDRESS);
            let read_token = self.tokens.read(token);
            assert(read_token.symbol.is_zero(), bridge_errors::TOKEN_ALREADY_EXISTS);

            let token_info = TokenInfo {
                symbol,
                decimals,
                min_amount,
                max_amount,
                is_active,
                total_liquidity: 0.into(),
                feed_id,
                added_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
            };

            self.tokens.write(token, token_info);
            self.token_by_symbol.write(symbol, token);

            self
                .emit(
                    TokenAdded {
                        token,
                        symbol,
                        decimals,
                        min_amount,
                        max_amount,
                        is_active,
                        feed_id,
                        added_at: get_block_timestamp(),
                    },
                );
        }

        fn remove_token(ref self: ContractState, token: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let token_info = self._get_token_info(token);

            assert(token_info.total_liquidity == 0.into(), bridge_errors::TOKEN_HAS_LIQUIDITY);

            let symbol = token_info.symbol;
            let mut cleared = token_info;
            cleared.symbol = 0;
            cleared.is_active = false;
            cleared.total_liquidity = 0.into();
            self.tokens.write(token, cleared);

            self.emit(TokenRemoved { token, symbol });
        }

        fn pause_token(ref self: ContractState, token: ContractAddress) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            let caller = get_caller_address();

            let mut token_info = self._get_token_info(token);
            assert(token_info.is_active, bridge_errors::TOKEN_ALREADY_PAUSED);
            token_info.is_active = false;
            self.tokens.write(token, token_info);
            self.emit(TokenPaused { token, by: caller });
        }

        fn unpause_token(ref self: ContractState, token: ContractAddress) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            let caller = get_caller_address();
            let mut token_info = self._get_token_info(token);
            assert(!token_info.is_active, bridge_errors::TOKEN_NOT_PAUSED);
            token_info.is_active = true;
            self.tokens.write(token, token_info);
            self.emit(TokenUnpaused { token, by: caller });
        }

        // Swap functions
        fn swap(
            ref self: ContractState,
            from_token: ContractAddress,
            to_token: ContractAddress,
            from_amount: u256,
            min_to_amount: u256,
            deadline: u64,
        ) -> u64 {
            self.pausable.assert_not_paused();

            assert(from_amount > 0, bridge_errors::ZERO_AMOUNT);
            assert(deadline > starknet::get_block_timestamp(), bridge_errors::DEADLINE_PASSED);

            let from_token_info = self._get_token_info(from_token);
            let to_token_info = self._get_token_info(to_token);

            assert(from_token_info.is_active, bridge_errors::TOKEN_NOT_ACTIVE);
            assert(to_token_info.is_active, bridge_errors::TOKEN_NOT_ACTIVE);

            assert(from_amount >= from_token_info.min_amount, bridge_errors::BELOW_MIN_AMOUNT);
            if from_token_info.max_amount > 0 {
                assert(from_amount <= from_token_info.max_amount, bridge_errors::ABOVE_MAX_AMOUNT);
            }

            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: from_token };
            token_dispatcher.transfer_from(caller, get_contract_address(), from_amount);

            // Calculate output amount (simplified - in reality, use a price oracle or AMM formula)
            let to_amount = self.calculate_swap_amount(from_token, to_token, from_amount);
            assert(to_amount >= min_to_amount, bridge_errors::INSUFFICIENT_OUTPUT_AMOUNT);

            // Create swap
            let swap_id = self.next_swap_id.read();
            let swap = SwapInfo {
                id: swap_id,
                user: caller,
                from_token,
                to_token,
                from_amount,
                to_amount,
                deadline,
                status: SwapStatus::Pending,
                created_at: starknet::get_block_timestamp(),
                completed_at: 0,
                fee_amount: 0,
                nonce: 0,
            };

            self.swaps.write(swap_id, swap);
            self.next_swap_id.write(swap_id + 1);

            self
                .emit(
                    SwapCreated {
                        swap_id,
                        user: caller,
                        token_in: from_token,
                        token_out: to_token,
                        amount_in: from_amount,
                        min_amount_out: min_to_amount,
                        deadline,
                    },
                );

            swap_id
        }

        fn set_operator(ref self: ContractState, operator: ContractAddress, is_authorized: bool) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.authorized_operators.write(operator, is_authorized);
            let timestamp = get_block_timestamp();
            if is_authorized {
                self.emit(OperatorAuthorized { operator, timestamp });
            } else {
                self.emit(OperatorRevoked { operator, timestamp });
            }
        }

        fn register_user(ref self: ContractState, user: ContractAddress, fiat_account_id: felt252) {
            // only operators can register users
            let caller = get_caller_address();
            let authorized = self.authorized_operators.read(caller);
            assert(authorized, bridge_errors::UNAUTHORIZED);
            assert(!user.is_zero(), bridge_errors::ZERO_ADDRESS);
            assert(!fiat_account_id.is_zero(), bridge_errors::INVALID_FIAT_CURRENCY);

            self.user_accounts.write(user, true);
            self.fiat_account_id.write(user, fiat_account_id);
            self.emit(UserRegistered { name: 'UserRegistered', user, fiat_account_id });
        }

        fn is_user_registered(self: @ContractState, user: ContractAddress) -> bool {
            self.user_accounts.read(user)
        }

        fn get_fiat_account_id(self: @ContractState, user: ContractAddress) -> felt252 {
            self.fiat_account_id.read(user)
        }

        // Token pool / liquidity helpers
        fn add_token_liquidity(ref self: ContractState, token: ContractAddress, amount: u256) {
            self.pausable.assert_not_paused();
            assert(amount > 0, bridge_errors::ZERO_AMOUNT);
            let caller = get_caller_address();
            let mut token_info = self._get_token_info(token);
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            // transfer tokens in
            token_dispatcher.transfer_from(caller, get_contract_address(), amount);

            // update total liquidity
            token_info.total_liquidity += amount;
            self.tokens.write(token, token_info);

            self.emit(LiquidityAdded { provider: caller, token, amount, liquidity: amount });
        }

        fn get_token_balance(self: @ContractState, token: ContractAddress) -> u256 {
            IERC20Dispatcher { contract_address: token }.balance_of(get_contract_address())
        }

        // Withdrawal / lock flows
        fn lock_user_funds(
            ref self: ContractState, user: ContractAddress, token_symbol: felt252, amount: u256,
        ) {
            self.reentrancy.start();
            let token = self.token_by_symbol.read(token_symbol);
            assert(!token.is_zero(), bridge_errors::INVALID_SUPPORTED_TOKEN);
            let balance = IERC20Dispatcher { contract_address: token }.balance_of(user);
            assert(balance >= amount, bridge_errors::INSUFFICIENT_BALANCE);

            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer_from(user, get_contract_address(), amount);

            let current_locked = self.locked_funds.read((user, token_symbol));
            self.locked_funds.write((user, token_symbol), current_locked + amount);

            self.emit(FundsLocked { user, token_symbol, amount, timestamp: get_block_timestamp() });
            self.reentrancy.end();
        }

        fn confirm_withdrawal(
            ref self: ContractState,
            user: ContractAddress,
            token_symbol: felt252,
            amount: u256,
            fiat_reference: felt252,
        ) {
            // Only operator
            let caller = get_caller_address();
            let authorized = self.authorized_operators.read(caller);
            assert(authorized, bridge_errors::UNAUTHORIZED);

            let locked = self.locked_funds.read((user, token_symbol));
            assert(locked >= amount, bridge_errors::INSUFFICIENT_AMOUNT);

            self.locked_funds.write((user, token_symbol), locked - amount);

            self
                .emit(
                    WithdrawalCompleted {
                        name: 'WithdrawalCompleted', user, token_symbol, amount, fiat_reference,
                    },
                );
        }

        fn get_locked_funds(
            self: @ContractState, user: ContractAddress, token_symbol: felt252,
        ) -> u256 {
            self.locked_funds.read((user, token_symbol))
        }

        fn emergency_unlock_locked_funds(
            ref self: ContractState, user: ContractAddress, token_symbol: felt252, amount: u256,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            let locked = self.locked_funds.read((user, token_symbol));
            assert(locked >= amount, bridge_errors::INSUFFICIENT_AMOUNT);
            self.locked_funds.write((user, token_symbol), locked - amount);
            self
                .emit(
                    FundsUnlocked {
                        user,
                        token_symbol,
                        amount,
                        reason: 'admin_unlock',
                        timestamp: get_block_timestamp(),
                    },
                );
        }

        fn set_slippage_tolerance(ref self: ContractState, bps: u16) {
            self.accesscontrol.assert_only_role(FEE_MANAGER_ROLE);
            assert(bps <= 10000, bridge_errors::INVALID_SLIPPAGE);
            let old = self.slippage_tolerance_bps.read();
            self.slippage_tolerance_bps.write(bps);
            self
                .emit(
                    SlippageToleranceUpdated {
                        old_bps: old, new_bps: bps, updated_by: get_caller_address(),
                    },
                );
        }

        // Oracle & fees
        fn set_fee_bps(ref self: ContractState, fee_bps: u16) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(fee_bps <= 1000, bridge_errors::FEE_TOO_HIGH);
            let old = self.fee_bps.read();
            self.fee_bps.write(fee_bps);
            self
                .emit(
                    FeeUpdated {
                        old_fee_bps: old, new_fee_bps: fee_bps, updated_by: get_caller_address(),
                    },
                );
        }

        fn get_fee_bps(self: @ContractState) -> u16 {
            self.fee_bps.read()
        }

        fn update_pragma_oracle_address(ref self: ContractState, new_address: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.pragma_oracle_address.write(new_address);
        }

        fn get_asset_price_median(self: @ContractState, asset: DataType) -> (u128, u32) {
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_oracle_address.read(),
            };
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data(asset, AggregationMode::Median(()));
            return (output.price, output.decimals);
        }

        fn get_token_amount_in_usd(
            self: @ContractState, token: ContractAddress, token_amount: u256,
        ) -> u256 {
            let token_info = self._get_token_info(token);

            if (self.pragma_oracle_address.read() == '1'.try_into().unwrap()) {
                return token_amount;
            }

            let (price, _) = self.get_asset_price_median(DataType::SpotEntry(token_info.feed_id));
            return price.into() * token_amount / 10_u256.pow(18_u32);
        }

        fn cancel_swap(ref self: ContractState, swap_id: u64) {
            self.pausable.assert_not_paused();

            let mut swap = self._get_swap(swap_id);
            let caller = get_caller_address();

            assert(swap.user == caller, bridge_errors::UNAUTHORIZED);

            assert(swap.status == SwapStatus::Pending, bridge_errors::INVALID_SWAP_STATUS);

            swap.status = SwapStatus::Cancelled;

            let from_token = swap.from_token;
            let from_amount = swap.from_amount;
            let user = swap.user;
            self.swaps.write(swap_id, swap);

            self.reentrancy.start();
            let token_dispatcher = IERC20Dispatcher { contract_address: from_token };
            token_dispatcher.transfer(user, from_amount);
            self.reentrancy.end();

            self
                .emit(
                    SwapCancelled {
                        swap_id, user, token: from_token, amount: from_amount, reason: 0.into(),
                    },
                );
        }

        fn execute_swap(ref self: ContractState, swap_id: u64) {
            self.pausable.assert_not_paused();

            let mut swap = self._get_swap(swap_id);

            assert(swap.status == SwapStatus::Pending, bridge_errors::INVALID_SWAP_STATUS);
            assert(swap.deadline >= starknet::get_block_timestamp(), bridge_errors::SWAP_EXPIRED);

            let caller = get_caller_address();
            let authorized = self.authorized_operators.read(caller);
            assert(authorized || swap.user == caller, bridge_errors::UNAUTHORIZED);

            // Update status
            swap.status = SwapStatus::Completed;
            swap.completed_at = starknet::get_block_timestamp();

            let to_token = swap.to_token;
            let amount_out = swap.to_amount;
            let from_token = swap.from_token;
            let from_amount = swap.from_amount;
            let fee_amount = swap.fee_amount;
            let user = swap.user;

            self.swaps.write(swap_id, swap);
            self.reentrancy.start();
            let token_dispatcher = IERC20Dispatcher { contract_address: to_token };
            token_dispatcher.transfer(user, amount_out);
            self.reentrancy.end();

            self
                .emit(
                    SwapExecuted {
                        swap_id,
                        user,
                        token_in: from_token,
                        token_out: to_token,
                        amount_in: from_amount,
                        amount_out,
                        fee_amount: fee_amount,
                    },
                );
        }

        fn add_liquidity(
            ref self: ContractState, token: ContractAddress, amount: u256, min_liquidity: u256,
        ) -> u256 {
            self.pausable.assert_not_paused();

            assert(amount > 0, bridge_errors::ZERO_AMOUNT);

            let mut token_info = self._get_token_info(token);
            assert(token_info.is_active, bridge_errors::TOKEN_NOT_ACTIVE);

            self.reentrancy.start();
            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer_from(caller, get_contract_address(), amount);

            // Calculate liquidity tokens (simplified)
            let liquidity = amount; // In a real AMM, this would be calculated differently
            assert(liquidity >= min_liquidity, bridge_errors::INSUFFICIENT_LIQUIDITY);

            let mut token_info = self._get_token_info(token);
            token_info.total_liquidity += liquidity;
            self.tokens.write(token, token_info);

            self.emit(LiquidityAdded { provider: caller, token, amount, liquidity });
            self.reentrancy.end();

            liquidity
        }

        fn remove_liquidity(
            ref self: ContractState, token: ContractAddress, liquidity: u256, min_amount: u256,
        ) -> u256 {
            self.pausable.assert_not_paused();

            assert(liquidity > 0, bridge_errors::ZERO_AMOUNT);

            let amount = liquidity; // In a real AMM, this would be calculated differently
            assert(amount >= min_amount, bridge_errors::INSUFFICIENT_AMOUNT);

            let mut token_info = self._get_token_info(token);
            token_info.total_liquidity -= liquidity;
            self.tokens.write(token, token_info);

            self.reentrancy.start();
            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(caller, amount);
            self.reentrancy.end();

            self.emit(LiquidityRemoved { provider: caller, token, amount, liquidity });

            amount
        }

        // Fee management
        fn set_fee_receiver(ref self: ContractState, receiver: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!receiver.is_zero(), bridge_errors::ZERO_ADDRESS);

            self.fee_receiver.write(receiver);
            let old = self.fee_receiver.read();
            self.emit(FeeReceiverUpdated { old_receiver: old, new_receiver: receiver });
        }

        fn set_swap_fee(ref self: ContractState, fee_rate: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(fee_rate <= 10000, bridge_errors::INVALID_FEE); // Max 100% (10000 basis points)

            let old = self.swap_fee_rate.read();
            self.swap_fee_rate.write(fee_rate);
            self
                .emit(
                    SwapFeeUpdated {
                        old_fee: old, new_fee: fee_rate, updated_by: get_caller_address(),
                    },
                );
        }

        fn withdraw_fees(ref self: ContractState, token: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let fee_receiver = self.fee_receiver.read();
            assert(!fee_receiver.is_zero(), bridge_errors::FEE_RECEIVER_NOT_SET);

            self.reentrancy.start();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(fee_receiver, amount);
            self.reentrancy.end();

            self.emit(FeeDistributed { token, amount, receiver: fee_receiver });
        }

        fn enable_emergency_mode(ref self: ContractState, enable: bool) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            if enable {
                self.pausable.pause();
            } else {
                self.pausable.unpause();
            }

            self.emit(EmergencyModeToggled { enabled: enable, by: get_caller_address() });
        }

        fn emergency_withdraw(
            ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(self.pausable.is_paused(), bridge_errors::NOT_IN_EMERGENCY_MODE);

            self.reentrancy.start();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(to, amount);
            self.reentrancy.end();

            self.emit(EmergencyWithdraw { token, to, amount });
        }

        // View functions
        fn get_swap(self: @ContractState, swap_id: u64) -> SwapInfo {
            let swap = self.swaps.read(swap_id);
            assert(swap.id != 0, bridge_errors::NO_SUCH_SWAP);
            swap
        }

        fn get_token_info(self: @ContractState, token: ContractAddress) -> TokenInfo {
            self._get_token_info(token)
        }

        fn get_pool_info(self: @ContractState, token: ContractAddress) -> PoolInfo {
            let token_info = self._get_token_info(token);

            PoolInfo {
                token,
                total_liquidity: token_info.total_liquidity,
                // In a real implementation, these would be calculated based on the AMM state
                total_supply: 0.into(), // Should be tracked in your contract
                reserve0: 0.into(), // Reserve of token0 in the pool
                reserve1: 0.into(), // Reserve of token1 in the pool
                last_update_time: starknet::get_block_timestamp(),
            }
        }

        fn calculate_swap_amount(
            self: @ContractState,
            from_token: ContractAddress,
            to_token: ContractAddress,
            from_amount: u256,
        ) -> u256 {
            // In a real implementation, this would use an oracle or AMM formula
            // This is a simplified version that returns a 1:1 ratio
            from_amount
        }
    }
    
    // Implement the InternalTrait
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_token_info(self: @ContractState, token: ContractAddress) -> TokenInfo {
            let info = self.tokens.read(token);
            assert(!info.symbol.is_zero(), bridge_errors::TOKEN_NOT_FOUND);
            info
        }

        fn _get_swap(self: @ContractState, swap_id: u64) -> SwapInfo {
            let swap = self.swaps.read(swap_id);
            assert(swap.id != 0, bridge_errors::SWAP_NOT_FOUND);
            swap
        }

        fn assert_only_operator(ref self: ContractState) {
            let caller = get_caller_address();
            let is_authorized = self.authorized_operators.read(caller);
            assert(is_authorized, bridge_errors::UNAUTHORIZED);
        }

        fn assert_not_emergency_mode(ref self: ContractState) {
            // paused state indicates emergency in this implementation
            assert(!self.pausable.is_paused(), bridge_errors::EMERGENCY_MODE_ACTIVE);
        }

        fn check_rate_limit(ref self: ContractState, user: ContractAddress) {
            // simplistic no-op for now; placeholder for rate limiting logic
            let _ = user; // silence unused variable
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableForIUpgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
