use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct AccountCreated {
    pub user: felt252,
    pub address: ContractAddress,
    pub public_key: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct DefaultTokenAdded {
    pub symbol: felt252,
    pub token_address: ContractAddress,
}
