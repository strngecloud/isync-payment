#[starknet::contract]
pub mod AccountFactory {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{ClassHash, ContractAddress, SyscallResultTrait};
    use crate::errors::AccountErrors;
    use crate::events::{AccountCreated, DefaultTokenAdded};
    use crate::interfaces::IAccountFactory;

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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        account_class_hash: ClassHash,
        liquidity_bridge: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.account_class_hash.write(account_class_hash);
        self.liquidity_bridge.write(liquidity_bridge);
    }

    #[abi(embed_v0)]
    impl AccountFactoryImpl of IAccountFactory<ContractState> {
        fn create_account(ref self: ContractState, public_key: felt252, user_unique_id: felt252) {
            self.ownable.assert_only_owner();
            assert(
                self.accounts.read(user_unique_id).is_zero(), AccountErrors::ACCOUNT_ALREADY_EXIST,
            );
            assert(!public_key.is_zero(), AccountErrors::PUBLIC_KEY_CANNOT_BE_ZERO);

            // Deploy the account contract
            let mut constructor_calldata = array![public_key];

            let (deployed_address, _) = deploy_syscall(
                self.account_class_hash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap_syscall();

            // Store the account address
            self.accounts.write(user_unique_id, deployed_address);

            // Emit event
            self
                .emit(
                    AccountCreated {
                        user: user_unique_id,
                        owner: deployed_address,
                        account: deployed_address,
                        public_key,
                    },
                );
        }

        fn get_account(self: @ContractState, user_unique_id: felt252) -> ContractAddress {
            self.accounts.read(user_unique_id)
        }

        fn set_account_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.account_class_hash.write(class_hash);
        }

        fn get_account_class_hash(self: @ContractState) -> ClassHash {
            self.ownable.assert_only_owner();
            self.account_class_hash.read()
        }

        fn set_liquidity_bridge(ref self: ContractState, bridge: ContractAddress) {
            self.ownable.assert_only_owner();
            self.liquidity_bridge.write(bridge);
        }

        fn get_liquidity_bridge(self: @ContractState) -> ContractAddress {
            self.ownable.assert_only_owner();
            self.liquidity_bridge.read()
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
