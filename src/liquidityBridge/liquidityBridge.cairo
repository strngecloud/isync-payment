#[starknet::interface]
trait ISyncPayment<T> {
    fn deposit_fiat(ref self: T, symbol: felt252, amount: u256);
}

#[starknet::contract]
pub mod LiquidityBridge {
    use alexandria_math::fast_power::fast_power;
    use core::num::traits::{Pow, Zero};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::Errors::*;
    use crate::errors::LiquidityBridgeErrors;
    use crate::events::liquidityBridgeEvents::{
        ExchangeRateUpdated, FiatDeposit, FiatLiquidityAdded, FiatLiquidityRemoved,
        FiatToTokenSwapExecuted, TokenLiquidityAdded, TokenRegistered, TokenToFiatSwapExecuted,
        UserRegistered, WithdrawalCompleted,
    };
    use crate::interfaces::iliquidityBridge::ILiquidityBridge;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        should_succeed: bool,
        supported_tokens: Map<ContractAddress, felt252>, // (token_address => token_symbol)
        supported_tokens_by_symbol: Map<
            felt252, ContractAddress,
        >, // (token_symbol => token_address)
        // Liquidity pools (fiat-token pairs)
        fiat_pools: Map<felt252, u256>, // fiat_symbol => fiat_amount
        token_pools: Map<felt252, u256>, // token_symbol => token_amount
        fiat_providers: Map<(ContractAddress, felt252), u256>, // (provider, fiat_symbol) => amount
        token_count: u8, // Number of supported tokens
        // User accounts
        user_accounts: Map<ContractAddress, bool>, // user address -> is registered
        fiat_account_id: Map<ContractAddress, felt252>, // starknet address -> fiat account id
        locked_funds: Map<(ContractAddress, felt252), u256>, // (user, token_symbol) => amount
        // System config
        fee_bps: u16, // basis points (0.01%)
        treasury: ContractAddress,
        owner: ContractAddress,
        pragma_oracle_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        FiatLiquidityAdded: FiatLiquidityAdded,
        TokenLiquidityAdded: TokenLiquidityAdded,
        FiatLiquidityRemoved: FiatLiquidityRemoved,
        FiatDeposit: FiatDeposit,
        FiatToTokenSwapExecuted: FiatToTokenSwapExecuted,
        TokenToFiatSwapExecuted: TokenToFiatSwapExecuted,
        ExchangeRateUpdated: ExchangeRateUpdated,
        TokenRegistered: TokenRegistered,
        UserRegistered: UserRegistered,
        WithdrawalCompleted: WithdrawalCompleted,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        treasury: ContractAddress,
        initial_fee_basis_points: u16,
        pragma_oracle_address: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.treasury.write(treasury);
        self.fee_bps.write(initial_fee_basis_points);
        self.should_succeed.write(true);
        self.token_count.write(0_u8);
        self.pragma_oracle_address.write(pragma_oracle_address);
    }

    #[abi(embed_v0)]
    impl LiquidityBridge of ILiquidityBridge<ContractState> {
        fn register_user(ref self: ContractState, user: ContractAddress, fiat_account_id: felt252) {
            assert(!user.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            assert(!fiat_account_id.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_ID);

            // Register user
            self.user_accounts.write(user, true);
            self.fiat_account_id.write(user, fiat_account_id);
            self.emit(UserRegistered { user, fiat_account_id });
        }

        fn add_fiat_liquidity(ref self: ContractState, _fiat_symbol: felt252, _fiat_amount: u256) {
            assert(!_fiat_symbol.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_SYMBOL);
            // TODO: check if fiat_symbol is supported
            assert(_fiat_amount != 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            // Update provider liquidity
            let provider = get_caller_address();
            let current_fiat_liquidity = self.fiat_providers.read((provider, _fiat_symbol));
            let new_fiat_liquidity = current_fiat_liquidity + _fiat_amount;
            self.fiat_providers.write((provider, _fiat_symbol), new_fiat_liquidity);

            // Update pool liquidity
            let old_fiat_liquidity = self.fiat_pools.read((_fiat_symbol));
            let new_fiat_liquidity = old_fiat_liquidity + _fiat_amount;
            self.fiat_pools.write((_fiat_symbol), new_fiat_liquidity);

            self
                .emit(
                    FiatLiquidityAdded {
                        provider, fiat_symbol: _fiat_symbol, amount: _fiat_amount,
                    },
                );
        }

        fn add_token_liquidity(
            ref self: ContractState, _token_symbol: felt252, _token_amount: u256,
        ) {
            assert(!_token_symbol.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_SYMBOL);
            // TODO: check if cypto_symbol is supported
            assert(_token_amount != 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            let provider = get_caller_address();
            let token = self.supported_tokens_by_symbol.read(_token_symbol);

            assert(!token.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);

            // I will add erc20 approve here
            IERC20Dispatcher { contract_address: token }
                .approve(get_contract_address(), _token_amount);

            IERC20Dispatcher { contract_address: token }
                .transfer_from(provider, get_contract_address(), _token_amount);

            // Update provider liquidity
            let current_token_amount = self.token_pools.read(_token_symbol);
            let new_token_liquidity = current_token_amount + _token_amount;
            self.token_pools.write(_token_symbol, new_token_liquidity);

            self
                .emit(
                    TokenLiquidityAdded {
                        provider, token_symbol: _token_symbol, amount: _token_amount,
                    },
                );
        }

        fn process_fiat_deposit(
            ref self: ContractState,
            _user: ContractAddress,
            _fiat_symbol: felt252,
            _amount: u256,
            _transaction_id: felt252,
        ) {
            assert(self.user_accounts.read(_user), 'USER_NOT_REGISTERED');

            let fiat_account_id = self.fiat_account_id.read(_user);

            self
                .emit(
                    FiatDeposit {
                        user: _user,
                        fiat_account_id,
                        fiat_symbol: _fiat_symbol,
                        amount: _amount,
                        transaction_id: _transaction_id,
                    },
                );
        }

        fn add_supported_token(
            ref self: ContractState, _symbol: felt252, _token_address: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            assert(!_token_address.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);

            let current_token_count = self.token_count.read();
            self.supported_tokens.write(_token_address, _symbol);
            self.supported_tokens_by_symbol.write(_symbol, _token_address);
            self.token_count.write(current_token_count + 1);
        }

        // fn update_exchange_rate(
        //     ref self: ContractState, _fiat_symbol: felt252, _token_symbol: felt252, _new_rate:
        //     u256,
        // ) {
        //     // Only owner or payment gateway can update rates
        //     let caller = get_caller_address();
        //     assert(caller == self.owner.read(), LiquidityBridgeErrors::UNAUTHORIZED);

        //     self.exchange_rates.write((_fiat_symbol, _token_symbol), _new_rate);

        //     self
        //         .emit(
        //             ExchangeRateUpdated {
        //                 fiat_symbol: _fiat_symbol, token_symbol: _token_symbol, new_rate:
        //                 _new_rate,
        //             },
        //         );
        // }

        fn set_fee(ref self: ContractState, fee_bps: u16) {
            self.ownable.assert_only_owner();
            assert(fee_bps <= 1000, LiquidityBridgeErrors::FEE_TOO_HIGH); // Max 10% fee
            self.fee_bps.write(fee_bps);
        }

        fn get_token_balance(self: @ContractState, _token_symbol: felt252) -> u256 {
            self.token_pools.read(_token_symbol)
        }

        fn get_fiat_balance(self: @ContractState, _fiat_symbol: felt252) -> u256 {
            self.fiat_pools.read((_fiat_symbol))
        }

        fn is_user_registered(self: @ContractState, _user: ContractAddress) -> bool {
            self.user_accounts.read(_user)
        }

        fn get_fiat_account_id(self: @ContractState, _user: ContractAddress) -> felt252 {
            self.fiat_account_id.read(_user)
        }

        fn lock_user_funds(
            ref self: ContractState, _user: ContractAddress, _token_symbol: felt252, _amount: u256,
        ) {
            // Verify user has sufficient balance
            let token = self.supported_tokens_by_symbol.read(_token_symbol);
            let balance = IERC20Dispatcher { contract_address: token }.balance_of(_user);
            assert(balance >= _amount, LiquidityBridgeErrors::INSUFFICIENT_BALANCE);

            // Transfer to contract escrow
            IERC20Dispatcher { contract_address: token }
                .transfer_from(_user, get_contract_address(), _amount);

            self
                .locked_funds
                .write(
                    (_user, _token_symbol),
                    self.locked_funds.read((_user, _token_symbol)) + _amount,
                );
        }

        fn confirm_withdrawal(
            ref self: ContractState,
            _user: ContractAddress,
            _token_symbol: felt252,
            _amount: u256,
            _fiat_reference: felt252,
        ) {
            // Verify locked funds
            let locked = self.locked_funds.read((_user, _token_symbol));
            assert(locked >= _amount, 'INSUFFICIENT_LOCKED');

            // Reduce locked amount
            self.locked_funds.write((_user, _token_symbol), locked - _amount);

            // Emit event for reconciliation
            self
                .emit(
                    WithdrawalCompleted {
                        user: _user,
                        token_symbol: _token_symbol,
                        amount: _amount,
                        fiat_reference: _fiat_reference,
                    },
                );
        }

        fn remove_fiat_liquidity(
            ref self: ContractState, _fiat_symbol: felt252, _fiat_amount: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(!_fiat_symbol.is_zero(), LiquidityBridgeErrors::INVALID_FIAT_SYMBOL);
            assert(_fiat_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            // Update provider liquidity
            let provider = get_caller_address();
            let current_liquidity = self.fiat_providers.read((provider, _fiat_symbol));
            assert(current_liquidity >= _fiat_amount, LiquidityBridgeErrors::INVALID_AMOUNT);
            let new_liquidity = current_liquidity - _fiat_amount;
            self.fiat_providers.write((provider, _fiat_symbol), new_liquidity);

            // Update pool liquidity
            let pool_liquidity = self.fiat_pools.read((_fiat_symbol));
            assert(pool_liquidity >= _fiat_amount, LiquidityBridgeErrors::INVALID_AMOUNT);
            let new_pool_liquidity = pool_liquidity - _fiat_amount;
            self.fiat_pools.write((_fiat_symbol), new_pool_liquidity);

            self
                .emit(
                    FiatLiquidityRemoved {
                        provider, fiat_symbol: _fiat_symbol, amount: _fiat_amount,
                    },
                );
        }

        fn swap_fiat_to_token(
            ref self: ContractState,
            _user: ContractAddress,
            _fiat_symbol: felt252,
            _token_symbol: felt252,
            _fiat_amount: u256,
        ) -> bool {
            if !self.should_succeed.read() {
                return false;
            }

            assert(self.user_accounts.read(_user), LiquidityBridgeErrors::USER_NOT_REGISTERED);
            let token = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            assert(_fiat_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            // let rate = self.get_token_amount_in_usd(token, _fiat_amount);
            let price_per_token = self.get_token_amount_in_usd(token, 10_u256.pow(18));
            assert(price_per_token > 0, LiquidityBridgeErrors::INVALID_EXCHANGE_RATE);

            // 3. Calculate token amount and fee (1e18 precision)
            let token_amount = (_fiat_amount * 10_u256.pow(18)) / price_per_token;
            let fee = (token_amount * self.fee_bps.read().into()) / 10000_u256;
            let token_amount_after_fee = token_amount - fee;

            // 4. Verify pool liquidity
            let available_token = self.token_pools.read(_token_symbol);
            assert(
                available_token >= token_amount_after_fee,
                LiquidityBridgeErrors::INSUFFICIENT_TOKEN_LIQUIDITY,
            );

            // 5. Update pools
            self
                .fiat_pools
                .write((_fiat_symbol), self.fiat_pools.read((_fiat_symbol)) + _fiat_amount);
            self.token_pools.write(_token_symbol, available_token - token_amount_after_fee);

            // 6. Transfer tokens to user
            IERC20Dispatcher { contract_address: token }.transfer(_user, token_amount_after_fee);

            // 7. Send fee to treasury
            IERC20Dispatcher { contract_address: token }.transfer(self.treasury.read(), fee);

            self
                .emit(
                    FiatToTokenSwapExecuted {
                        user: _user,
                        fiat_symbol: _fiat_symbol,
                        token_symbol: _token_symbol,
                        fiat_amount: _fiat_amount,
                        token_amount: token_amount_after_fee,
                        fee: fee.try_into().unwrap(),
                    },
                );

            true
        }

        fn swap_token_to_fiat(
            ref self: ContractState,
            _fiat_symbol: felt252,
            _token_symbol: felt252,
            _token_amount: u256,
        ) -> bool {
            if !self.should_succeed.read() {
                return false;
            }

            // 1. Verify inputs
            let user = get_caller_address();
            assert(self.user_accounts.read(user), LiquidityBridgeErrors::USER_NOT_REGISTERED);
            let token = self.supported_tokens_by_symbol.read(_token_symbol);
            assert(!token.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            assert(_token_amount > 0, LiquidityBridgeErrors::INVALID_AMOUNT);

            // 2. Get current rate of token
            let price_per_token = self.get_token_amount_in_usd(token, 10_u256.pow(18));
            assert(price_per_token > 0, LiquidityBridgeErrors::CANNOT_BE_ZERO);

            // 3. Calculate fiat amount and fee
            let fee = (_token_amount * self.fee_bps.read().into()) / 10000_u256;
            let token_amount_after_fee = _token_amount - fee;
            let fiat_amount = (token_amount_after_fee * price_per_token) / 10_u256.pow(18);

            // 4. Verify fiat liquidity
            let available_fiat = self.fiat_pools.read((_fiat_symbol));
            assert(
                available_fiat >= fiat_amount, LiquidityBridgeErrors::INSUFFICIENT_FIAT_LIQUIDITY,
            );

            // 5. Verify token liquidity
            let available_token = self.token_pools.read(_token_symbol);
            assert(
                available_token >= token_amount_after_fee,
                LiquidityBridgeErrors::INSUFFICIENT_TOKEN_LIQUIDITY,
            );

            // 6. Transfer token from user to contract
            IERC20Dispatcher { contract_address: token }
                .transfer_from(user, get_contract_address(), _token_amount);

            // 7. Update pools
            // self.fiat_pools.write((_fiat_symbol), available_fiat + fiat_amount);
            // self
            //     .token_pools
            //     .write(
            //         _token_symbol, self.token_pools.read(_token_symbol) - token_amount_after_fee,
            //     );

            self.fiat_pools.write((_fiat_symbol), available_fiat - fiat_amount); // DECREASE fiat
            self
                .token_pools
                .write(
                    _token_symbol,
                    self.token_pools.read(_token_symbol) + token_amount_after_fee // INCREASE tokens
                );

            // 8. Send fee to treasury
            IERC20Dispatcher { contract_address: token }.transfer(self.treasury.read(), fee);

            self
                .emit(
                    TokenToFiatSwapExecuted {
                        user,
                        fiat_symbol: _fiat_symbol,
                        token_symbol: _token_symbol,
                        fiat_amount,
                        token_amount: token_amount_after_fee,
                        fee: fee.try_into().unwrap(),
                    },
                );

            true
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
            let token_symbol = self.supported_tokens.read(token);

            // // For testing: use mock prices (comment out for production)
            // if token_symbol == 'ETH' {
            //     return 3000_u256 * 10_u256.pow(18); // $3000 per ETH
            // } else if token_symbol == 'STRK' {
            //     return 2_u256 * 10_u256.pow(18); // $2 per STRK
            // } else {
            //     return 10_u256.pow(18); // $1 default
            // }

            // Production oracle code (currently commented out):
            let feed_id: felt252 = if token_symbol == 'ETH' {
                19514442401534788 // ETH/USD Pragma feed ID
            } else if token_symbol == 'BTC' {
                18669995996566340 // BTC/USD Pragma feed ID
            } else if token_symbol == 'STRK' {
                6004514686061859652
            } else {
                0
            };

            assert(!feed_id.is_zero(), LiquidityBridgeErrors::INVALID_TOKEN_ADDRESS);
            let (price, decimals) = self.get_asset_price_median(DataType::SpotEntry(feed_id));
            price.into() * token_amount / fast_power(10_u32, decimals).into()
        }

        fn fee_bps(self: @ContractState) -> u16 {
            self.fee_bps.read()
        }
    }
}
