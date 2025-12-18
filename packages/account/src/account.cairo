#[starknet::contract(account)]
pub mod Account {
    use core::num::traits::Zero;
    use sync_account::interfaces::IAccount;
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::extensions::SRC9Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use sync_account::errors::account_errors::*;
    use sync_account::events::{
        TokenAdded, BridgeSet, StakingSet
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SRC9Component, storage: src9, event: SRC9Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OutsideExecutionV2Impl = SRC9Component::OutsideExecutionV2Impl<ContractState>;

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
        staking_contract: ContractAddress,
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
        TokenAdded: TokenAdded,
        BridgeSet: BridgeSet,
        StakingSet: StakingSet,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
        self.src9.initializer();
    }

    #[abi(embed_v0)]
    impl AccountImpl of IAccount<ContractState> {
        fn set_bridge(ref self: ContractState, bridge: ContractAddress) {
            self.account.assert_only_self();
            assert(!bridge.is_zero(), 'Invalid bridge address');
            self.liquidity_bridge.write(bridge);
            self.emit(BridgeSet { bridge_address: bridge });
        }

        fn set_staking_contract(ref self: ContractState, staking: ContractAddress) {
            self.account.assert_only_self();
            assert(!staking.is_zero(), 'Invalid staking address');
            self.staking_contract.write(staking);
            self.emit(StakingSet { staking_address: staking });
        }

        fn set_token_address(
            ref self: ContractState, symbol: felt252, token_address: ContractAddress,
        ) {
            self.account.assert_only_self();
            assert(!token_address.is_zero(), 'Invalid token address');
            self.token_address.write(symbol, token_address);
            self.emit(TokenAdded { symbol, token_address });
        }

        fn get_bridge(self: @ContractState) -> ContractAddress {
            self.liquidity_bridge.read()
        }

        fn get_token_address(self: @ContractState, symbol: felt252) -> ContractAddress {
            self.token_address.read(symbol)
        }

        fn get_staking_contract(self: @ContractState) -> ContractAddress {
            self.staking_contract.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
       
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
