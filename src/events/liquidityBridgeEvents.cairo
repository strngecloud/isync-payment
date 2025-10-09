use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct FiatLiquidityAdded {
    #[key]
    pub name: felt252,
    pub provider: ContractAddress,
    pub fiat_symbol: felt252,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokenLiquidityAdded {
    #[key]
    pub name: felt252,
    pub provider: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct FiatDeposit {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub fiat_account_id: felt252,
    pub fiat_symbol: felt252,
    pub amount: u256,
    pub transaction_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct FiatLiquidityRemoved {
    #[key]
    pub name: felt252,
    pub provider: ContractAddress,
    pub fiat_symbol: felt252,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct FiatToTokenSwapExecuted {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub fiat_amount: u256,
    pub token_amount: u256,
    pub fee: u128,
}

#[derive(Drop, starknet::Event)]
pub struct TokenToFiatSwapExecuted {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub fiat_amount: u256,
    pub token_amount: u256,
    pub fee: u128,
}

#[derive(Drop, starknet::Event)]
pub struct ExchangeRateUpdated {
    #[key]
    pub name: felt252,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub new_rate: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokenRegistered {
    #[key]
    pub name: felt252,
    pub token_symbol: felt252,
    pub token_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct UserRegistered {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub fiat_account_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct WithdrawalCompleted {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub fiat_reference: felt252,
}
