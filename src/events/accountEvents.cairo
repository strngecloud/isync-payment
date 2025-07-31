use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct AccountFiatDeposit {
    pub user: ContractAddress,
    pub currency: felt252,
    pub amount: u128,
}

#[derive(Drop, starknet::Event)]
pub struct FiatWithdrawal {
    pub account_address: ContractAddress,
    pub currency: felt252,
    pub amount: u128,
    pub reciepient: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct PaymentMade {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub currency: felt252,
    pub amount: u128,
    pub used_bridge: bool,
}

#[derive(Drop, starknet::Event)]
pub struct TokenApproved {
    pub user: ContractAddress,
    pub symbol: felt252,
    pub token_address: ContractAddress,
    pub amount: u128,
}
