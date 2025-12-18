use starknet::ContractAddress;

#[event]
#[derive(Drop, starknet::Event)]
pub enum AccountEvent {
    // Account events
    AccountCreated: AccountCreated,
    TokenAdded: TokenAdded,
    BridgeSet: BridgeSet,
    StakingSet: StakingSet,
    TokensReceived: TokensReceived,
    TokensSent: TokensSent,
    Staked: Staked,
    Unstaked: Unstaked,
    RewardsClaimed: RewardsClaimed,
    AutoStakeConfigured: AutoStakeConfigured,
}

#[derive(Drop, starknet::Event)]
pub struct DefaultTokenAdded {
    pub symbol: felt252,
    pub token_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AccountCreated {
    pub user: felt252,
    pub owner: ContractAddress,
    pub account: ContractAddress,
    pub public_key: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct TokenAdded {
    pub symbol: felt252,
    pub token_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct BridgeSet {
    pub bridge_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct StakingSet {
    pub staking_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokensReceived {
    pub from: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokensSent {
    pub to: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Staked {
    pub token: ContractAddress,
    pub amount: u256,
    pub duration: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Unstaked {
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RewardsClaimed {
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct AutoStakeConfigured {
    pub token: ContractAddress,
    pub enabled: bool,
    pub min_amount: u256,
    pub duration: u64,
}
