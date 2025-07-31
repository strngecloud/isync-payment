use isyncpayment::events::accountFactoryEvents::{AccountCreated, DefaultTokenAdded};
use isyncpayment::interfaces::iaccountFactory::{
    IAccountFactoryDispatcher, IAccountFactoryDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};
use super::setup::{
    deploy_account, deploy_account_factory, deploy_erc20, owner, random_user, zero_address,
};

#[test]
fn test_initialization() {
    let (_, _, factory) = deploy_account_factory();

    // let (account_address, _, account_class) = deploy_account();
    assert(factory.get_liquidity_bridge() != zero_address(), 'Bridge address not set');
    assert(factory.get_account(0) == zero_address(), 'Initial account should be zero');
}

#[test]
fn test_create_account_success() {
    let (factory_address, _, factory) = deploy_account_factory();

    let public_key = 0x1234567890abcdef;
    let user_unique_id = 0x111222333;

    // Cheat caller to be owner
    start_cheat_caller_address(factory_address, owner());

    factory.create_account(public_key, user_unique_id);

    let account_address = factory.get_account(user_unique_id);
    assert(account_address != zero_address(), 'Account not created');

    let events = spy.get_events();
    let _last_event = events.events.at(events.events.len() - 1);

    println!("last event is {:?}", _last_event);
    let (_, event) = _last_event;
    // The amount should be at index 2 in the event data
    // Convert the numeric literal to felt252 using the 'into_felt252' function
    let expected_amount = 700_u128;
    assert_eq!(event.data[2], @expected_amount.into(), "Withdrawal amount should match");

    // Verify event
    // let event = snforge_std::get_last_event(factory_address);
    // match event {
    //     snforge_std::Event::Custom(custom) => {
    //         assert(custom.name == 'AccountCreated', 'Wrong event name');
    //         assert(custom.keys[0] == user_unique_id, 'Wrong user id');
    //         assert(custom.data[0] == account_address.into(), 'Wrong account address');
    //         assert(custom.data[1] == public_key, 'Wrong public key');
    //     },
    //     _ => panic!("Expected AccountCreated event")
    // }

    stop_cheat_caller_address(factory_address);
}
// #[test]
// #[should_panic(expected = ('Account already exists',))]
// fn test_create_account_already_exists() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     let public_key = 0x1234567890abcdef;
//     let user_unique_id = 0x111222333;

//     start_cheat_caller_address(factory_address, owner());
//     factory.create_account(public_key, user_unique_id);
//     // Try creating same account again
//     factory.create_account(public_key, user_unique_id);
//     stop_cheat_caller_address(factory_address);
// }

// #[test]
// #[should_panic(expected = ('CALLER_IS_NOT_OWNER',))]
// fn test_set_liquidity_bridge_unauthorized() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     start_cheat_caller_address(factory_address, random_user());
//     factory.set_liquidity_bridge(contract_address_const::<123>());
//     stop_cheat_caller_address(factory_address);
// }

// #[test]
// fn test_set_liquidity_bridge_success() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     let new_bridge = contract_address_const::<123>();
//     start_cheat_caller_address(factory_address, owner());

//     factory.set_liquidity_bridge(new_bridge);
//     assert(factory.get_liquidity_bridge() == new_bridge, 'Bridge not updated');

//     stop_cheat_caller_address(factory_address);
// }

// #[test]
// #[should_panic(expected = ('CALLER_IS_NOT_OWNER',))]
// fn test_set_account_class_hash_unauthorized() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     start_cheat_caller_address(factory_address, random_user());
//     factory.set_account_class_hash(123.into());
//     stop_cheat_caller_address(factory_address);
// }

// #[test]
// fn test_set_account_class_hash_success() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     let new_class_hash = 123.into();
//     start_cheat_caller_address(factory_address, owner());

//     factory.set_account_class_hash(new_class_hash);
//     // Note: We can't directly verify class hash, but we can create a new account
//     // and verify it uses the new class hash
//     stop_cheat_caller_address(factory_address);
// }

// #[test]
// #[should_panic(expected = ('CALLER_IS_NOT_OWNER',))]
// fn test_upgrade_unauthorized() {
//     let (factory_address, _) = deploy_account_factory();
//     let factory = IAccountFactoryDispatcher { contract_address: factory_address };

//     start_cheat_caller_address(factory_address, random_user());
//     factory.upgrade(123.into());
//     stop_cheat_caller_address(factory_address);
// }


