use isyncpayment::interfaces::iaccountFactory::IAccountFactoryDispatcherTrait;
use snforge_std::{EventSpyTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::class_hash::class_hash_const;
use starknet::contract_address_const;
use super::setup::{deploy_account_factory, owner, random_user, zero_address};

#[test]
fn test_initialization() {
    let (_, _, factory) = deploy_account_factory();

    assert(factory.get_liquidity_bridge() != zero_address(), 'Bridge address not set');
    assert(factory.get_account(0) == zero_address(), 'Initial account should be zero');
}

#[test]
fn test_create_account_success() {
    let (factory_address, _, factory) = deploy_account_factory();

    let public_key = 0x1234567890abcdef;
    let user_unique_id = 0x111222333;
    let mut spy = spy_events();

    // Cheat caller to be owner
    start_cheat_caller_address(factory_address, owner());

    factory.create_account(public_key, user_unique_id);

    let account_address = factory.get_account(user_unique_id);
    assert(account_address != zero_address(), 'Account not created');

    let events = spy.get_events();
    let _last_event = events.events.at(events.events.len() - 1);

    println!("last event is {:?}", _last_event);
    let (_, event) = _last_event;
    let expected_address = account_address;
    assert_eq!(event.data[1], @expected_address.into(), "Account address should match");
    let expected_public_key = public_key;
    assert_eq!(event.data[2], @expected_public_key.into(), "Public key should match");
    let expected_user_unique_id = user_unique_id;
    assert_eq!(event.data[0], @expected_user_unique_id.into(), "User unique id should match");

    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'Account already exists')]
fn test_create_account_already_exists() {
    let (factory_address, _, factory) = deploy_account_factory();

    let public_key = 0x1234567890abcdef;
    let user_unique_id = 0x111222333;

    start_cheat_caller_address(factory_address, owner());
    factory.create_account(public_key, user_unique_id);
    // Try creating same account again
    factory.create_account(public_key, user_unique_id);
    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_liquidity_bridge_unauthorized() {
    let (factory_address, _, factory) = deploy_account_factory();

    start_cheat_caller_address(factory_address, random_user());
    factory.set_liquidity_bridge(contract_address_const::<123>());
    stop_cheat_caller_address(factory_address);
}

#[test]
fn test_set_liquidity_bridge_success() {
    let (factory_address, _, factory) = deploy_account_factory();

    let new_bridge = contract_address_const::<123>();
    start_cheat_caller_address(factory_address, owner());

    factory.set_liquidity_bridge(new_bridge);
    assert(factory.get_liquidity_bridge() == new_bridge, 'Bridge not updated');

    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_account_class_hash_unauthorized() {
    let (factory_address, _, factory) = deploy_account_factory();

    start_cheat_caller_address(factory_address, random_user());
    factory.set_account_class_hash(class_hash_const::<123>());
    stop_cheat_caller_address(factory_address);
}

#[test]
fn test_set_account_class_hash_success() {
    let (factory_address, _, factory) = deploy_account_factory();

    let new_class_hash = class_hash_const::<123>();
    start_cheat_caller_address(factory_address, owner());

    factory.set_account_class_hash(new_class_hash);
    // Note: We can't directly verify class hash, but we can create a new account
    // and verify it uses the new class hash
    stop_cheat_caller_address(factory_address);
}

