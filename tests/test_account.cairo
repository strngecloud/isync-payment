use crate::setup::owner;
use crate::setup::zero_address;
use crate::setup::random_user;
use crate::setup::deploy_erc20;
use crate::setup::deploy_account;
use isyncpayment::account::account::Account;
use isyncpayment::interfaces::iaccount::{IAccountDispatcherTrait, IAccountDispatcher};
use isyncpayment::interfaces::ierc20::{SyncTokenDispatcherTrait, SyncTokenDispatcher};
use snforge_std::{EventSpyAssertionsTrait, EventSpyTrait,
    spy_events, start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address,
};


#[test]
fn test_constructor() {
    let (account_address, account, _) = deploy_account();

    assert!(account_address != 0.try_into().unwrap(), "Account should be deployed");
    assert_eq!(account.get_liquidity_bridge(), 0.try_into().unwrap(), "Bridge should be zero");
}
