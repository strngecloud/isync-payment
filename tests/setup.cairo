use isyncpayment::interfaces::iaccountFactory::IAccountFactoryDispatcher;
use isyncpayment::interfaces::iaccount::IAccountDispatcher;
use snforge_std::declare;
use isyncpayment::interfaces::ierc20::SyncTokenDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait};
use starknet::{ClassHash, ContractAddress};

pub fn owner() -> ContractAddress {
    let owner_felt: felt252 = 000123.into();
    let owner: ContractAddress = owner_felt.try_into().unwrap();
    owner
}

pub fn random_user() -> ContractAddress {
    let random_user_felt: felt252 = 023433.into();
    let random_user: ContractAddress = random_user_felt.try_into().unwrap();
    random_user
}

pub fn zero_address() -> ContractAddress {
    let zero_address_felt: felt252 = 0.into();
    let zero_address: ContractAddress = zero_address_felt.try_into().unwrap();
    zero_address
}

// end of helpers

/// ******** SET-UP ********
///// Deploy token first for payment

pub fn deploy_erc20() -> (ContractAddress, SyncTokenDispatcher) {
    let account_class = declare("SyncToken").expect('Failed to declare SyncToken').contract_class();
    let (contract_address, _) = account_class
        .deploy(@array![owner().into(), owner().into(), owner().into(), owner().into()])
        .unwrap();
    let erc20_dispatcher = SyncTokenDispatcher { contract_address };
    (contract_address, erc20_dispatcher)
}

pub fn deploy_account() -> (ContractAddress, IAccountDispatcher, ClassHash) {
    let public_key = 0x1234567890abcde7890abcdef;
    let contract_class_hash = declare("Account")
        .expect('Failed to declare Account')
        .contract_class();
    let (contract_address, _) = contract_class_hash
        .deploy(@array![public_key.into()])
        .expect('Failed to deploy Account');
    let account_dispatcher = IAccountDispatcher { contract_address };
    (contract_address, account_dispatcher, *contract_class_hash.class_hash)
}

pub fn deploy_bridge(account_factory_address: ContractAddress) -> ContractAddress {
    let contract = declare("LiquidityBridge").unwrap().contract_class();
    let (contract_address, _) = contract
        .deploy(
            @array![
                owner().into(),
                random_user().into(),
                account_factory_address.into(),
                100_u16.into() // initial fee basis points
            ],
        )
        .unwrap();
    contract_address
}

pub fn deploy_account_factory() -> (ContractAddress, ClassHash, IAccountFactoryDispatcher) {
    let (_, _, account_class) = deploy_account();
    let liquidity_bridge_address = deploy_bridge(owner().into());
    let contract = declare("AccountFactory").expect('Failed to declare AF').contract_class();
    let (contract_address, _) = contract
        .deploy(@array![account_class.into(), liquidity_bridge_address.into(), owner().into()])
        .expect('Failed to deploy AccountFactory');

    let factory = IAccountFactoryDispatcher { contract_address };

    (contract_address, *contract.class_hash, factory)
}