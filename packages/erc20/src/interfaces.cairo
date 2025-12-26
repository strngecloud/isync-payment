//! Interface definitions for the ERC20 package

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<T> {
    // Standard ERC20 functions
    fn name(self: @T) -> ByteArray;
    fn symbol(self: @T) -> ByteArray;
    fn decimals(self: @T) -> u8;
    fn total_supply(self: @T) -> u256;
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: T, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u256) -> bool;
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u256) -> bool;

    // Mintable functions
    fn mint(ref self: T, to: ContractAddress, amount: u256);
    fn burn(ref self: T, amount: u256);
    fn burn_from(ref self: T, account: ContractAddress, amount: u256);

    // Pausable functions
    fn pause(ref self: T);
    fn unpause(ref self: T);
    fn paused(self: @T) -> bool;

    // Access control functions
    fn has_role(self: @T, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @T, role: felt252) -> felt252;
    fn grant_role(ref self: T, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: T, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: T, role: felt252, account: ContractAddress);

    // Upgradeable functions
    fn upgrade(ref self: T, new_implementation: ContractAddress, data: Array<felt252>);

    // Custom functions
    fn cap(self: @T) -> u256;
    fn is_blacklisted(self: @T, account: ContractAddress) -> bool;
    fn blacklist(ref self: T, account: ContractAddress, is_blacklisted: bool);
    fn recover_erc20(ref self: T, token_address: ContractAddress, to: ContractAddress, amount: u256);
}

// Role definitions
pub const DEFAULT_ADMIN_ROLE: felt252 = 0;
pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
pub const BLACKLISTER_ROLE: felt252 = selector!("BLACKLISTER_ROLE");
pub const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

// Data structures
#[derive(Drop, Serde)]
pub struct RoleData {
    pub members: Array<ContractAddress>,
    pub admin_role: felt252,
}

// Constants
pub const MAX_UINT256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
pub const MAX_DECIMALS: u8 = 18;
pub const MAX_NAME_LENGTH: u32 = 32;
pub const MAX_SYMBOL_LENGTH: u32 = 10;
