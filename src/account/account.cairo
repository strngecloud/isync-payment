#[starknet::contract(account)]
pub mod Account {
    use core::num::traits::Zero;
    use isyncpayment::interfaces::iaccount::IAccount;
    use isyncpayment::interfaces::iliquidityBridge::{
        ILiquidityBridgeDispatcher, ILiquidityBridgeDispatcherTrait,
    };
    use isyncpayment::structs::PaymentRecord;
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
        AccountFiatDeposit, FiatWithdrawal, PaymentMade, TokenApproved,
    };

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
        // Custom storage for SyncPayment functionality
        fiat_balance: Map<(ContractAddress, felt252), u128>, // (user, currency) => balance
        token_address: Map<felt252, ContractAddress>, // symbol => token_address
        default_fiat_currency: felt252,
        liquidity_bridge: ContractAddress,
        payment_history: Map<u128, PaymentRecord>, // payment_id => PaymentRecord
        next_payment_id: u128,
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
        // Custom events for SyncPayment functionality
        AccountFiatDeposit: AccountFiatDeposit,
        FiatWithdrawal: FiatWithdrawal,
        PaymentMade: PaymentMade,
        TokenApproved: TokenApproved,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
        self.src9.initializer();
        self.next_payment_id.write(1);
    }

    //
    // SyncPayment Implementation
    //

    #[abi(embed_v0)]
    impl SyncPaymentImpl of IAccount<ContractState> {
        fn get_fiat_balance(self: @ContractState, currency: felt252) -> u128 {
            let account_address = get_contract_address();
            assert(!account_address.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);
            let balance = self.fiat_balance.read((account_address, currency));
            balance
        }

        fn get_token_balance(self: @ContractState, token_symbol: felt252) -> u256 {
            let token_address = self.token_address.read(token_symbol);
            assert(!token_address.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);

            let account_address = get_contract_address();
            IERC20Dispatcher { contract_address: token_address }.balance_of(account_address)
        }

        fn approve_token(ref self: ContractState, symbol: felt252, token_address: ContractAddress) {
            self.account.assert_only_self();
            assert(!token_address.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);
            self.token_address.write(symbol, token_address);
            self
                .emit(
                    TokenApproved {
                        user: get_contract_address(), symbol, token_address, amount: 0,
                    },
                );
        }

        fn deposit_fiat(ref self: ContractState, currency: felt252, amount: u128) {
            self.account.assert_only_self();
            assert(!amount.is_zero(), AccountErrors::AMOUNT_CANNOT_BE_ZERO);
            assert(!currency.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);
            let account_address = get_contract_address();
            let current_balance = self.fiat_balance.read((account_address, currency));
            self.fiat_balance.write((account_address, currency), current_balance + amount);
            self
                .emit(
                    AccountFiatDeposit {
                        user: account_address, currency, amount: current_balance + amount,
                    },
                );
        }

        fn withdraw_fiat(
            ref self: ContractState, currency: felt252, amount: u128, recipient: ContractAddress,
        ) {
            self.account.assert_only_self();
            assert(!amount.is_zero(), AccountErrors::AMOUNT_CANNOT_BE_ZERO);
            assert(!currency.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);
            assert(!recipient.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);

            let account_address = get_contract_address();
            let current_balance = self.fiat_balance.read((account_address, currency));
            assert(current_balance >= amount, 'Insufficient balance');

            self.fiat_balance.write((account_address, currency), current_balance - amount);
            self
                .emit(
                    FiatWithdrawal {
                        account_address,
                        currency,
                        amount: current_balance - amount,
                        reciepient: recipient,
                    },
                );
        }

        fn make_payment(
            ref self: ContractState,
            recipient: ContractAddress,
            currency: felt252,
            amount: u128,
            use_liquidity_bridge: bool,
        ) -> bool {
            self.account.assert_only_self();
            let account_address = get_contract_address();
            assert(!recipient.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);
            assert(!amount.is_zero(), AccountErrors::AMOUNT_CANNOT_BE_ZERO);
            assert(!currency.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);

            let payment_id = self.next_payment_id.read();
            let current_balance = self.fiat_balance.read((account_address, currency));

            if current_balance >= amount {
                self.fiat_balance.write((account_address, currency), current_balance - amount);
                let recipient_balance = self.fiat_balance.read((recipient, currency));
                self.fiat_balance.write((recipient, currency), recipient_balance + amount);

                let payment_record = PaymentRecord {
                    from: account_address,
                    to: recipient,
                    currency,
                    amount,
                    timestamp: starknet::get_block_timestamp(),
                    used_bridge: false,
                };
                self.payment_history.write(payment_id, payment_record);
                self.next_payment_id.write(payment_id + 1);

                self
                    .emit(
                        PaymentMade {
                            from: account_address,
                            to: recipient,
                            currency,
                            amount: current_balance - amount,
                            used_bridge: use_liquidity_bridge,
                        },
                    );

                return true;
            } else if use_liquidity_bridge && current_balance < amount {
                // If the balance is insufficient, try to swap crypto to fiat using the liquidity
                // bridge
                let bridge = self.liquidity_bridge.read();
                assert(!bridge.is_zero(), 'Liquidity bridge not set');

                let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address: bridge };

                let crypto_symbol = 'STRK';
                assert(!crypto_symbol.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);

                // The amount to swap will be the difference between the current balance and the
                // amount
                let amount_to_swap = amount - current_balance;
                assert(amount_to_swap > 0, AccountErrors::AMOUNT_CANNOT_BE_ZERO);

                // The swap_token_to_fiat will use the liquidity bridge to swap crypto to fiat
                // It will use the account_address to see if the user has enough crypto to swap
                // Deduct the amount from the token account after successful swap
                // Credit user with the amount required to complete the payment
                let success = bridge_dispatcher
                    .swap_token_to_fiat(
                        currency, crypto_symbol, amount_to_swap.into(),
                    ); // the swap_token_to_fiat will use the liquidity bridge to swap crypto to fiat 

                if success {
                    // If the swap was successful, update the fiat balance
                    let new_balance = self.get_fiat_balance(currency);
                    assert(new_balance >= amount, 'Insufficient balance after swap');

                    // Deduct the amount after successful swap
                    self.fiat_balance.write((account_address, currency), new_balance - amount);

                    // Credit recipient
                    let recipient_balance = self.fiat_balance.read((recipient, currency));
                    self.fiat_balance.write((recipient, currency), recipient_balance + amount);

                    let payment_record = PaymentRecord {
                        from: account_address,
                        to: recipient,
                        currency,
                        amount,
                        timestamp: starknet::get_block_timestamp(),
                        used_bridge: true,
                    };
                    self.payment_history.write(payment_id, payment_record);
                    self.next_payment_id.write(payment_id + 1);

                    self
                        .emit(
                            PaymentMade {
                                from: account_address,
                                to: recipient,
                                currency,
                                amount,
                                used_bridge: true,
                            },
                        );
                    return true;
                }
            }
            return false;
        }

        fn get_default_fiat_currency(self: @ContractState) -> felt252 {
            self.default_fiat_currency.read()
        }

        fn set_default_fiat_currency(ref self: ContractState, currency: felt252) {
            self.account.assert_only_self();
            self.default_fiat_currency.write(currency);
        }

        fn get_liquidity_bridge(self: @ContractState) -> ContractAddress {
            self.liquidity_bridge.read()
        }

        fn get_payment_history(self: @ContractState, payment_id: u128) -> PaymentRecord {
            self.payment_history.read(payment_id)
        }

        fn get_next_payment_id(self: @ContractState) -> u128 {
            self.next_payment_id.read()
        }

        fn get_token_address(self: @ContractState, symbol: felt252) -> ContractAddress {
            self.token_address.read(symbol)
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
