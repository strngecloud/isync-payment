use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct PaymentMade {
    pub swap_order_id: felt252,
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

#[derive(Drop, starknet::Event)]
pub struct StakingExecuted {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub lock_duration: u64,
}

#[derive(Drop, starknet::Event)]
pub struct AutoStakeConfigured {
    pub token_symbol: felt252,
    pub enabled: bool,
    pub duration: u64,
    pub threshold: u256,
}
