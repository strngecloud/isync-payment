use isyncpayment::interfaces::iaccount::IAccountDispatcher;
use isyncpayment::interfaces::iaccountFactory::IAccountFactoryDispatcher;
use isyncpayment::interfaces::ierc20::SyncTokenDispatcher;
use isyncpayment::interfaces::iliquidityBridge::ILiquidityBridgeDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ClassHash, ContractAddress};

pub fn owner() -> ContractAddress {
    let owner_felt: felt252 = 0x068e7fbf0efd2e502a4b1951ecb6fa6b1a90baf7.into();
    let owner: ContractAddress = owner_felt.try_into().unwrap();
    owner
}

pub fn random_user() -> ContractAddress {
    let random_user_felt: felt252 = 23433.into();
    let random_user: ContractAddress = random_user_felt.try_into().unwrap();
    random_user
}

pub fn random_user2() -> ContractAddress {
    let random_user2_felt: felt252 = 523433.into();
    let random_user2: ContractAddress = random_user2_felt.try_into().unwrap();
    random_user2
}

pub fn zero_address() -> ContractAddress {
    let zero_address_felt: felt252 = 0.into();
    let zero_address: ContractAddress = zero_address_felt.try_into().unwrap();
    zero_address
}

pub fn eth_rich_user() -> ContractAddress {
    let eth_rich_user: ContractAddress = 0x068e7fbf0efd2e502a4b1951ecb6fa6b1a90baf7
        .try_into()
        .unwrap();
    eth_rich_user
}
// end of helpers

/// ******** SET-UP ********
///// Deploy token first for payment

pub fn deploy_erc20(name: ByteArray, symbol: ByteArray) -> (ContractAddress, SyncTokenDispatcher) {
    let account_class = declare("SyncToken").expect('Failed to declare SyncToken').contract_class();

    // let name: ByteArray = "TokenName";
    // let symbol: ByteArray = "TKN";

    let mut constructor_calldata = array![
        owner().into(), owner().into(), owner().into(), owner().into(),
    ];

    // Serialize ByteArray manually
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let (contract_address, _) = account_class.deploy(@constructor_calldata).unwrap();

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


pub fn deploy_bridge(
    eth_token_address: ContractAddress, strk_token_address: ContractAddress,
) -> (ContractAddress, ILiquidityBridgeDispatcher) {
    let bridge_class = declare("LiquidityBridge")
        .expect('Failed to declare Bridge')
        .contract_class();

    let owner = owner();
    let treasury = random_user();
    let fee_bps = 200_u16;
    let pragma_address_felt: felt252 = 1.into();
    let pragma_address: ContractAddress = pragma_address_felt.try_into().unwrap();

    let mut constructor_calldata = array![
        owner.into(), treasury.into(), fee_bps.into(), pragma_address.into(),
    ];

    let mut supported_assets = array![eth_token_address, strk_token_address];
    let mut supported_feed_ids = array!['ETH/USD', 'STRK/USD'];

    supported_assets.serialize(ref constructor_calldata);
    supported_feed_ids.serialize(ref constructor_calldata);

    let (contract_address, _) = bridge_class.deploy(@constructor_calldata).unwrap();
    let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address };

    (contract_address, bridge_dispatcher)
}

pub fn deploy_account_factory() -> (ContractAddress, ClassHash, IAccountFactoryDispatcher) {
    let (_, _, account_class) = deploy_account();

    let (ETH_token_address, _) = deploy_erc20("etherium", "ETH");
    let (STRK_token_address, _) = deploy_erc20("starknet", "STRK");

    let (liquidity_bridge_address, _) = deploy_bridge(ETH_token_address, STRK_token_address);
    let contract = declare("AccountFactory").expect('Failed to declare AF').contract_class();
    let (contract_address, _) = contract
        .deploy(@array![account_class.into(), liquidity_bridge_address.into(), owner().into()])
        .expect('Failed to deploy AccountFactory');

    let factory = IAccountFactoryDispatcher { contract_address };

    (contract_address, *contract.class_hash, factory)
}
