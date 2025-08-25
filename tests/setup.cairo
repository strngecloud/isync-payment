use isyncpayment::interfaces::iliquidityBridge::ILiquidityBridgeDispatcher;
use isyncpayment::interfaces::iaccount::IAccountDispatcher;
use isyncpayment::interfaces::iaccountFactory::IAccountFactoryDispatcher;
use isyncpayment::interfaces::ierc20::SyncTokenDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ClassHash, ContractAddress};

pub fn owner() -> ContractAddress {
    let owner_felt: felt252 = 0x68e7fbf0efd2e502a4b1951ecb6fa6b1a90baf70.into();
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

pub fn eth_rich_user() -> ContractAddress {
    let eth_rich_user: ContractAddress = 0x68e7fbf0efd2e502a4b1951ecb6fa6b1a90baf70
        .try_into()
        .unwrap();
    eth_rich_user
}

pub fn deploy_pragma_mock() -> ContractAddress {
    let contract = declare("Pragma").unwrap().contract_class();
    let oracle_address: ContractAddress =
        0x06df335982dddce41008e4c03f2546fa27276567b5274c7d0c1262f3c2b5d167
        .try_into()
        .unwrap();
    let summary_stats_address: ContractAddress =
        0x06df335982dddce41008e4c03f2546fa27276567b5274c7d0c1262f3c2b5d167
        .try_into()
        .unwrap();
    let (contract_address, _) = contract
        .deploy(@array![oracle_address.into(), summary_stats_address.into()])
        .unwrap();
    contract_address
}

// end of helpers

/// ******** SET-UP ********
///// Deploy token first for payment

pub fn deploy_erc20(name: ByteArray, symbol: ByteArray) -> (ContractAddress, SyncTokenDispatcher) {
    let account_class = declare("SyncToken").expect('Failed to declare SyncToken').contract_class();
    
        let name: ByteArray = "TokenName";
    let symbol: ByteArray = "TKN";
    
    let mut constructor_calldata = array![
        owner().into(),    
        owner().into(),            
        owner().into(),          
        owner().into(),        
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

pub fn deploy_bridge() -> (ContractAddress, ILiquidityBridgeDispatcher) {
    let contract = declare("LiquidityBridge").unwrap().contract_class();
    let pragma_address = deploy_pragma_mock();
    let (contract_address, _) = contract
        .deploy(
            @array![
                owner().into(),
                random_user().into(), // treasury
                200_u16.into(), // initial fee basis points
                pragma_address.into(),
            ],
        )
        .unwrap();
    let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address };
    (contract_address, bridge_dispatcher)
}

pub fn deploy_account_factory() -> (ContractAddress, ClassHash, IAccountFactoryDispatcher) {
    let (_, _, account_class) = deploy_account();
    let (liquidity_bridge_address, _) = deploy_bridge();
    let contract = declare("AccountFactory").expect('Failed to declare AF').contract_class();
    let (contract_address, _) = contract
        .deploy(@array![account_class.into(), liquidity_bridge_address.into(), owner().into()])
        .expect('Failed to deploy AccountFactory');

    let factory = IAccountFactoryDispatcher { contract_address };

    (contract_address, *contract.class_hash, factory)
}
