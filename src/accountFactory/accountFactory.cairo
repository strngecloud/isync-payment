#[starknet::contract]
pub mod AccountFactory {
    use core::num::traits::Zero;
    use isyncpayment::interfaces::iaccountFactory::IAccountFactory;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{ClassHash, ContractAddress};
    use crate::events::accountFactoryEvents::{AccountCreated, DefaultTokenAdded};
    use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
    // use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
    use super::*;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        accounts: Map<felt252, ContractAddress>, // user address -> account address
        account_class_hash: ClassHash,
        liquidity_bridge: ContractAddress,
        default_fiat_currency: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        AccountCreated: AccountCreated,
        DefaultTokenAdded: DefaultTokenAdded,
    }

    // Custom errors
    const ACCOUNT_ALREADY_EXIST: felt252 = 'Account already exists';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        account_class_hash: ClassHash,
        liquidity_bridge: ContractAddress,
        owner: ContractAddress,
    ) {
        self.account_class_hash.write(account_class_hash);
        self.liquidity_bridge.write(liquidity_bridge);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl AccountFactoryImpl of IAccountFactory<ContractState> {
        fn create_account(ref self: ContractState, public_key: felt252, user_unique_id: felt252) {
            assert(self.accounts.read(user_unique_id).is_zero(), ACCOUNT_ALREADY_EXIST);

            //Deploy proxy for upgradable account
            let (account, _) = deploy_syscall(
                self.account_class_hash.read(), 2, array![public_key].span(), false,
            )
                .expect('failed to deploy account');

            let token_address: ContractAddress =
                0x06ab048153cdf6ee3ab9328fa0b8d16c09670581a5a446749facfd229362bf0e
                .try_into()
                .unwrap(); // TODO: will add it to contract initialization

            self.accounts.write(user_unique_id, account);
            self.default_fiat_currency.write('NAIRA'.try_into().unwrap());
            let mut accountDispatcher = IAccountDispatcher { contract_address: account };
            accountDispatcher.set_default_fiat_currency(self.default_fiat_currency.read());
            accountDispatcher.approve_token('SYNC'.into(), token_address);

            self.emit(AccountCreated { user: user_unique_id, address: account, public_key });
        }

        fn get_account(self: @ContractState, user: felt252) -> ContractAddress {
            self.accounts.read(user)
        }

        fn set_liquidity_bridge(ref self: ContractState, new_bridge: ContractAddress) {
            self.ownable.assert_only_owner();
            self.liquidity_bridge.write(new_bridge);
        }

        fn set_account_class_hash(ref self: ContractState, new_account_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.account_class_hash.write(new_account_class_hash);
        }

        fn get_liquidity_bridge(self: @ContractState) -> ContractAddress {
            self.liquidity_bridge.read()
        }

        fn get_account_class_hash(self: @ContractState) -> ClassHash {
            self.account_class_hash.read()
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
