#[feature("deprecated-starknet-consts")]
#[starknet::interface]
trait ISyncPayment<T> {
    fn deposit_fiat(ref self: T, symbol: felt252, amount: u256);
}

#[starknet::contract]
pub mod LiquidityBridge {
    use core::num::traits::{Pow, Zero};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
        IERC20MetadataDispatcherTrait,
    };
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use crate::Errors::*;
    use crate::errors::LiquidityBridgeErrors;
    use crate::events::liquidityBridgeEvents::{
        EmergencyModeToggled, ExchangeRateUpdated, FeeUpdated, FiatToTokenSwapExecuted, FundsLocked,
        OperatorAuthorized, OperatorRevoked, SlippageToleranceUpdated, TokenLiquidityAdded,
        TokenRegistered, TokenRemoved, TokenToFiatSwapExecuted, TokenUpdated, UserRegistered,
        WithdrawalCompleted,
    };
    use crate::interfaces::iliquidityBridge::{ILiquidityBridge, TokenInfo};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // Constants
    const BASIS_POINTS: u256 = 10000;
    const MAX_FEE_BPS: u16 = 1000; // 10% maximum fee
    const SLIPPAGE_TOLERANCE_BPS: u16 = 100; // 1% default slippage
    const RATE_LIMIT_WINDOW: u64 = 3600; // 1 hour
    const MAX_OPERATIONS_PER_WINDOW: u8 = 20; // Max 20 ops per hour per user

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
        // Token management
        supported_tokens: Map<ContractAddress, TokenInfo>, // token_address => TokenInfo
        supported_tokens_by_symbol: Map<
            felt252, ContractAddress,
        >, // (token_symbol => token_address)
        supported_tokens_list: Map<u8, ContractAddress>, // index => token_address
        supported_tokens_count: u8,
        // Liquidity pools
        token_pools_list: Map<u8, felt252>, // index => token_symbol
        token_pools_count: u8,
        token_pools: Map<felt252, u256>, // token_symbol => token_amount
        fiat_providers: Map<(ContractAddress, felt252), u256>, // (provider, fiat_symbol) => amount
        // User accounts
        user_accounts: Map<ContractAddress, bool>, // user address -> is registered
        fiat_account_id: Map<ContractAddress, felt252>, // starknet address -> fiat account id
        locked_funds: Map<(ContractAddress, felt252), u256>, // (user, token_symbol) => amount
        // Rate limiting
        user_operation_count: Map<(ContractAddress, u64), u8>, // (user, window_start) => count
        user_last_operation: Map<ContractAddress, u64>, // user => last_operation_timestamp
        // Slippage protection
        slippage_tolerance_bps: u16,
        // System config
        fee_bps: u16, // basis points (0.01%)
        treasury: ContractAddress,
        pragma_oracle_address: ContractAddress,
        // Authorized operators (for backend integration)
        authorized_operators: Map<ContractAddress, bool>, // operator => is_authorized        
        // Emergency controls
        emergency_mode: bool,
        token_decimals_cache: Map<ContractAddress, u8> // token => decimals
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
        TokenLiquidityAdded: TokenLiquidityAdded,
        FiatToTokenSwapExecuted: FiatToTokenSwapExecuted,
        TokenToFiatSwapExecuted: TokenToFiatSwapExecuted,
        ExchangeRateUpdated: ExchangeRateUpdated,
        TokenRegistered: TokenRegistered,
        UserRegistered: UserRegistered,
        WithdrawalCompleted: WithdrawalCompleted,
        FundsLocked: FundsLocked,
        OperatorAuthorized: OperatorAuthorized,
        OperatorRevoked: OperatorRevoked,
        EmergencyModeToggled: EmergencyModeToggled,
        SlippageToleranceUpdated: SlippageToleranceUpdated,
        FeeUpdated: FeeUpdated,
        TokenUpdated: TokenUpdated,
        TokenRemoved: TokenRemoved,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        treasury: ContractAddress,
        initial_fee_basis_points: u16,
        pragma_oracle_address: ContractAddress,
        supported_assets: Array<ContractAddress>,
        supported_feed_ids: Array<felt252>,
    ) {
        assert(!owner.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
        assert(!treasury.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
        assert(initial_fee_basis_points <= MAX_FEE_BPS, LiquidityBridgeErrors::FEE_TOO_HIGH);
        assert(supported_assets.len() == supported_feed_ids.len(), 'Arrays length mismatch');

        self.ownable.initializer(owner);
        self.treasury.write(treasury);
        self.fee_bps.write(initial_fee_basis_points);
        self.pragma_oracle_address.write(pragma_oracle_address);
        self.slippage_tolerance_bps.write(SLIPPAGE_TOLERANCE_BPS);
        self.emergency_mode.write(false);

        // Initialize tracking counters
        self.supported_tokens_count.write(0_u8);
        self.token_pools_count.write(0_u8);

        // // Add initial supported tokens
        // for i in 0..supported_assets.len() {
        //     self.supported_tokens.write(*supported_assets[i], *supported_feed_ids[i]);
        //     self.supported_tokens_by_symbol.write(*supported_feed_ids[i], *supported_assets[i]);

        //     // Add to tracking list
        //     let index: u8 = i.try_into().unwrap();
        //     self.supported_tokens_list.write(index, *supported_assets[i]);
        // }

        let mut i: u32 = 0;
        while i != supported_assets.len() {
            let token_address = *supported_assets[i];
            let feed_id = *supported_feed_ids[i];

            // Get decimals from token
            let decimals = IERC20MetadataDispatcher { contract_address: token_address }.decimals();

            let token_info = TokenInfo {
                symbol: feed_id,
                address: token_address,
                feed_id,
                decimals,
                is_active: true,
                added_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
            };

            self.supported_tokens.write(token_address, token_info);
            self.supported_tokens_by_symbol.write(feed_id, token_address);
            self.token_decimals_cache.write(token_address, decimals);
            // Add to tracking list
            let index: u8 = i.try_into().unwrap();
            self.supported_tokens_list.write(index, token_address);

            i += 1;
        }

        // Update counter with total number of tokens added
        let total_tokens: u8 = supported_assets.len().try_into().unwrap();
        self.supported_tokens_count.write(total_tokens);
    }

    #[abi(embed_v0)]
    impl LiquidityBridge of ILiquidityBridge<ContractState> {
        // Operator Management
        fn set_operator(ref self: ContractState, operator: ContractAddress, is_authorized: bool) {
            self.ownable.assert_only_owner();
            self.authorized_operators.write(operator, is_authorized);
            let timestamp = get_block_timestamp().try_into().unwrap();
            if is_authorized {
                self.emit(OperatorAuthorized { operator, timestamp });
            } else {
                self.emit(OperatorRevoked { operator, timestamp });
            }
        }

        // User Management
        fn register_user(ref self: ContractState, user: ContractAddress, fiat_account_id: felt252) {
            self.assert_only_operator();
            assert(!user.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            assert(!fiat_account_id.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_ID);

            self.user_accounts.write(user, true);
            self.fiat_account_id.write(user, fiat_account_id);
            self.emit(UserRegistered { name: 'UserRegistered', user, fiat_account_id });
        }

        fn is_user_registered(self: @ContractState, _user: ContractAddress) -> bool {
            self.user_accounts.read(_user)
        }

        fn get_fiat_account_id(self: @ContractState, _user: ContractAddress) -> felt252 {
            self.fiat_account_id.read(_user)
        }

        // Liquidity Management
        fn add_token_liquidity(
            ref self: ContractState, _token_symbol: felt252, _token_amount: u256,
        ) {
            self.pausable.assert_not_paused();
            self.reentrancy.start();

            assert(!_token_symbol.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_SYMBOL);
            assert(_token_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            let provider = get_caller_address();
            let token_address = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);

            let token = IERC20Dispatcher { contract_address: token_address };
            let balance_before = token.balance_of(get_contract_address());
            token.transfer_from(provider, get_contract_address(), _token_amount);
            let balance_after = token.balance_of(get_contract_address());

            // Verify actual amount transferred (handles fee-on-transfer tokens)
            let actual_amount = balance_after - balance_before;

            // Update provider liquidity
            let current_token_amount = self.token_pools.read(_token_symbol);

            // If this is a new token pool, add it to the tracking list
            if current_token_amount == 0 {
                let count = self.token_pools_count.read();
                self.token_pools_list.write(count, _token_symbol);
                self.token_pools_count.write(count + 1);
            }

            let new_token_liquidity = current_token_amount + actual_amount;
            self.token_pools.write(_token_symbol, new_token_liquidity);

            self
                .emit(
                    TokenLiquidityAdded {
                        name: 'TokenLiquidityAdded',
                        provider,
                        token_symbol: _token_symbol,
                        amount: _token_amount,
                    },
                );
            self.reentrancy.end();
        }

        fn get_token_balance(self: @ContractState, _token_symbol: felt252) -> u256 {
            // Prefer the actual ERC20 contract balance for supported tokens.
            let token_address = self.supported_tokens_by_symbol.read(_token_symbol);
            if !token_address.is_zero() {
                return IERC20Dispatcher { contract_address: token_address }
                    .balance_of(get_contract_address());
            }

            self.token_pools.read(_token_symbol)
        }

        // Swap Operations
        fn swap_fiat_to_token(
            ref self: ContractState,
            _user: ContractAddress,
            _swap_order_id: felt252,
            _fiat_symbol: felt252,
            _token_symbol: felt252,
            _fiat_amount: u256,
            _token_amount: u256,
            _fee: u128,
        ) -> bool {
            self.pausable.assert_not_paused();
            self.assert_not_emergency_mode();
            self.reentrancy.start();
            self.check_rate_limit(_user);

            assert(self.user_accounts.read(_user), LiquidityBridgeErrors::USER_NOT_REGISTERED);
            assert(_token_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);
            assert(_fiat_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            let token_address = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);

            let token_info = self.supported_tokens.read(token_address);
            assert(token_info.is_active, LiquidityBridgeErrors::TOKEN_NOT_ACTIVE);

            // Check sufficient liquidity in pool
            let contract_balance = IERC20Dispatcher { contract_address: token_address }
                .balance_of(get_contract_address());
            assert(
                contract_balance >= _token_amount,
                LiquidityBridgeErrors::INSUFFICIENT_TOKEN_LIQUIDITY,
            );

            let actual_rate = (_token_amount * self.fee_bps.read().into()) / _fiat_amount;
            IERC20Dispatcher { contract_address: token_address }.transfer(_user, _token_amount);

            // Update pool (decrease liquidity)
            let current_pool = self.token_pools.read(_token_symbol);
            if current_pool >= _token_amount {
                self.token_pools.write(_token_symbol, current_pool - _token_amount);
            }

            self
                .emit(
                    FiatToTokenSwapExecuted {
                        name: 'FiatToTokenSwapExecuted',
                        user: _user,
                        swap_order_id: _swap_order_id,
                        fiat_symbol: _fiat_symbol,
                        token_symbol: _token_symbol,
                        fiat_amount: _fiat_amount,
                        token_amount: _token_amount,
                        fee: _fee,
                        exchange_rate: actual_rate,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn swap_token_to_fiat(
            ref self: ContractState,
            _user: ContractAddress,
            _swap_order_id: felt252,
            _fiat_symbol: felt252,
            _token_symbol: felt252,
            _token_amount: u256,
        ) -> bool {
            self.pausable.assert_not_paused();
            self.assert_not_emergency_mode();
            self.reentrancy.start();
            self.check_rate_limit(_user);

            assert(self.user_accounts.read(_user), LiquidityBridgeErrors::USER_NOT_REGISTERED);
            let token_address = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_SUPPORTED_TOKEN);
            assert(_token_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            let token_info = self.supported_tokens.read(token_address);
            assert(token_info.is_active, LiquidityBridgeErrors::TOKEN_NOT_ACTIVE);

            let token_decimals = token_info.decimals;
            let decimals_power = 10_u256.pow(token_decimals.into());

            // 3. Get current price of 1 token (normalized to token's actual decimals)
            let price_per_token = self.get_token_amount_in_usd(token_address, decimals_power);
            assert(price_per_token > 0, LiquidityBridgeErrors::CANNOT_BE_ZERO);

            // 4. Calculate fiat amount and fee
            let fee = (_token_amount * self.fee_bps.read().into()) / BASIS_POINTS;
            let token_amount_after_fee = _token_amount - fee;
            let fiat_amount = (token_amount_after_fee * price_per_token) / decimals_power;

            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

            // 6. Transfer token from user to contract
            token_dispatcher.transfer_from(_user, get_contract_address(), token_amount_after_fee);

            self
                .token_pools
                .write(
                    _token_symbol,
                    self.token_pools.read(_token_symbol) + token_amount_after_fee // INCREASE tokens
                );

            // 8. Send fee to treasury
            token_dispatcher.transfer_from(_user, self.treasury.read(), fee);

            self
                .emit(
                    TokenToFiatSwapExecuted {
                        name: 'TokenToFiatSwapExecuted',
                        user: _user,
                        swap_order_id: _swap_order_id,
                        fiat_symbol: _fiat_symbol,
                        token_symbol: _token_symbol,
                        fiat_amount,
                        token_amount: token_amount_after_fee,
                        fee: fee.try_into().unwrap(),
                        timestamp: get_block_timestamp(),
                    },
                );

            self.reentrancy.end();
            true
        }

        // Withdrawal Management
        fn lock_user_funds(
            ref self: ContractState, _user: ContractAddress, _token_symbol: felt252, _amount: u256,
        ) {
            self.reentrancy.start();

            // Verify user has sufficient balance
            let token_address = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_SUPPORTED_TOKEN);

            let balance = IERC20Dispatcher { contract_address: token_address }.balance_of(_user);
            assert(balance >= _amount, LiquidityBridgeErrors::INSUFFICIENT_BALANCE);

            // Transfer to contract escrow
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher.transfer_from(_user, get_contract_address(), _amount);

            // Update locked funds
            let current_locked = self.locked_funds.read((_user, _token_symbol));
            self.locked_funds.write((_user, _token_symbol), current_locked + _amount);

            self
                .locked_funds
                .write(
                    (_user, _token_symbol),
                    self.locked_funds.read((_user, _token_symbol)) + _amount,
                );

            self
                .emit(
                    FundsLocked {
                        user: _user,
                        token_symbol: _token_symbol,
                        amount: _amount,
                        timestamp: get_block_timestamp(),
                    },
                );

            self.reentrancy.end();
        }

        fn confirm_withdrawal(
            ref self: ContractState,
            _user: ContractAddress,
            _token_symbol: felt252,
            _amount: u256,
            _fiat_reference: felt252,
        ) {
            self.assert_only_operator();
            self.reentrancy.start();

            // Verify locked funds
            let locked = self.locked_funds.read((_user, _token_symbol));
            assert(locked >= _amount, 'INSUFFICIENT_LOCKED');

            // Reduce locked amount
            self.locked_funds.write((_user, _token_symbol), locked - _amount);

            // Emit event for reconciliation
            self
                .emit(
                    WithdrawalCompleted {
                        name: 'WithdrawalCompleted',
                        user: _user,
                        token_symbol: _token_symbol,
                        amount: _amount,
                        fiat_reference: _fiat_reference,
                    },
                );
        }

        fn get_locked_funds(
            self: @ContractState, user: ContractAddress, token_symbol: felt252,
        ) -> u256 {
            self.locked_funds.read((user, token_symbol))
        }

        // Token Management
        fn add_supported_token(
            ref self: ContractState,
            _symbol: felt252,
            _token_address: ContractAddress,
            _feed_id: felt252,
        ) {
            self.ownable.assert_only_owner();
            assert(!_token_address.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            assert(!_symbol.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_SYMBOL);

            // Check if token is not already added
            let existing_token = self.supported_tokens_by_symbol.read(_symbol);
            assert(existing_token.is_zero(), LiquidityBridgeErrors::TOKEN_ALREADY_SUPPORTED);

            let decimals = IERC20MetadataDispatcher { contract_address: _token_address }.decimals();

            let token_info = TokenInfo {
                symbol: _symbol,
                address: _token_address,
                feed_id: _feed_id,
                decimals,
                is_active: true,
                added_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
            };

            self.supported_tokens.write(_token_address, token_info);
            self.supported_tokens_by_symbol.write(_symbol, _token_address);

            // Add to tracking list and increment counter
            let count = self.supported_tokens_count.read();
            self.supported_tokens_list.write(count, _token_address);
            self.supported_tokens_count.write(count + 1);

            self
                .emit(
                    TokenRegistered {
                        name: 'TokenRegistered',
                        token_symbol: _symbol,
                        token_address: _token_address,
                        feed_id: _feed_id,
                        decimals,
                    },
                );
        }

        fn update_token_status(ref self: ContractState, symbol: felt252, is_active: bool) {
            self.ownable.assert_only_owner();

            let token_address = self.supported_tokens_by_symbol.read(symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_SUPPORTED_TOKEN);

            let mut token_info = self.supported_tokens.read(token_address);
            token_info.is_active = is_active;
            token_info.last_updated = get_block_timestamp();
            self.supported_tokens.write(token_address, token_info);

            self.emit(TokenUpdated { symbol, address: token_address, is_active });
        }

        fn remove_supported_token(ref self: ContractState, symbol: felt252) {
            self.ownable.assert_only_owner();

            let token_address = self.supported_tokens_by_symbol.read(symbol);
            assert(!token_address.is_zero(), LiquidityBridgeErrors::INVALID_SUPPORTED_TOKEN);

            // Check no liquidity remains
            let pool_balance = self.token_pools.read(symbol);
            assert(pool_balance == 0, 'Pool has liquidity');

            // Remove mappings (set to default values)
            let empty_token = TokenInfo {
                symbol: 0,
                address: contract_address_const::<0>(),
                feed_id: 0,
                decimals: 0,
                is_active: false,
                added_at: 0,
                last_updated: 0,
            };
            self.supported_tokens.write(token_address, empty_token);
            self.supported_tokens_by_symbol.write(symbol, contract_address_const::<0>());

            self.emit(TokenRemoved { symbol, address: token_address });
        }

        fn get_supported_tokens_by_symbol(
            self: @ContractState, _symbol: felt252,
        ) -> ContractAddress {
            self.supported_tokens_by_symbol.read(_symbol)
        }

        fn get_token_info(self: @ContractState, token_address: ContractAddress) -> TokenInfo {
            self.supported_tokens.read(token_address)
        }

        fn get_all_supported_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut result: Array<ContractAddress> = ArrayTrait::new();
            let count = self.supported_tokens_count.read();

            if count == 0 {
                return result;
            }

            let mut i: u8 = 0;
            while i != count {
                let token_address = self.supported_tokens_list.read(i);
                result.append(token_address);
                i += 1;
            }

            result
        }

        fn get_all_token_pools(self: @ContractState) -> Array<felt252> {
            let mut result: Array<felt252> = ArrayTrait::new();
            let count = self.token_pools_count.read();

            if count == 0 {
                return result;
            }

            let mut i: u8 = 0;
            while i != count {
                let token_symbol = self.token_pools_list.read(i);
                result.append(token_symbol);
                i += 1;
            }

            result
        }

        // Pricing & Oracle
        fn get_asset_price_median(self: @ContractState, asset: DataType) -> (u128, u32) {
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_oracle_address.read(),
            };
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data(asset, AggregationMode::Median(()));
            return (output.price, output.decimals);
        }


        fn set_fee_bps(ref self: ContractState, fee_bps: u16) {
            self.ownable.assert_only_owner();
            assert(fee_bps <= 1000, LiquidityBridgeErrors::FEE_TOO_HIGH); // Max 10% fee
            self.fee_bps.write(fee_bps);
        }


        fn check_price_threshold(
            self: @ContractState,
            token: ContractAddress,
            expected_min_price: u256,
            expected_max_price: u256,
        ) -> bool {
            let decimals_power = 10_u256.pow(18_u32); // 1 token in smallest unit
            let current_price = self.get_token_amount_in_usd(token, decimals_power);
            current_price >= expected_min_price && current_price <= expected_max_price
        }

        fn get_token_amount_in_usd(
            self: @ContractState, token: ContractAddress, token_amount: u256,
        ) -> u256 {
            let token_decimals = 18_u32;
            let decimals_power = 10_u256.pow(token_decimals.into());
            let token_info = self.supported_tokens.read(token);

            if (self.pragma_oracle_address.read() == '1'.try_into().unwrap()) {
                return token_amount;
            }

            let (price, _) = self.get_asset_price_median(DataType::SpotEntry(token_info.feed_id));
            price.into() * token_amount / decimals_power
        }

        fn get_fee_bps(self: @ContractState) -> u16 {
            self.fee_bps.read()
        }

        fn update_pragma_oracle_address(ref self: ContractState, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.pragma_oracle_address.write(new_address);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_operator(ref self: ContractState) {
            let caller = get_caller_address();
            let is_authorized = self.authorized_operators.read(caller);
            assert(is_authorized, LiquidityBridgeErrors::UNAUTHORIZED_OPERATOR);
        }

        fn assert_not_emergency_mode(ref self: ContractState) {
            let emergency = self.emergency_mode.read();
            assert(!emergency, LiquidityBridgeErrors::EMERGENCY_MODE_ACTIVE);
        }

        fn check_rate_limit(ref self: ContractState, user: ContractAddress) {
            let current_timestamp = get_block_timestamp();
            let window_start = current_timestamp - (current_timestamp % RATE_LIMIT_WINDOW);
            let last_operation = self.user_last_operation.read(user);

            // Reset count if outside current window
            if last_operation < window_start {
                self.user_operation_count.write((user, window_start), 0_u8);
            }

            let current_count = self.user_operation_count.read((user, window_start));
            assert(
                current_count < MAX_OPERATIONS_PER_WINDOW,
                LiquidityBridgeErrors::RATE_LIMIT_EXCEEDED,
            );

            // Increment operation count and update last operation timestamp
            self.user_operation_count.write((user, window_start), current_count + 1);
            self.user_last_operation.write(user, current_timestamp);
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
