use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct TokenLiquidityAdded {
    #[key]
    pub name: felt252,
    pub provider: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct FiatToTokenSwapExecuted {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub swap_order_id: felt252,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub fiat_amount: u256,
    pub token_amount: u256,
    pub fee: u128,
    pub exchange_rate: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TokenToFiatSwapExecuted {
    #[key]
    pub name: felt252,
    pub user: ContractAddress,
    pub swap_order_id: felt252,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub fiat_amount: u256,
    pub token_amount: u256,
    pub fee: u128,
    pub timestamp: u64
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
    pub feed_id: felt252,
    pub decimals: u8
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

#[derive(Drop, starknet::Event)]
pub struct TokenUpdated {
    pub symbol: felt252,
    pub address: ContractAddress,
    pub is_active: bool,
}

#[derive(Drop, starknet::Event)]
pub struct TokenRemoved {
    pub symbol: felt252,
    pub address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct FundsLocked {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OperatorAuthorized {
    pub operator: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct OperatorRevoked {
    pub operator: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyModeToggled {
    pub enabled: bool,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SlippageToleranceUpdated {
    pub old_tolerance: u16,
    pub new_tolerance: u16,
}

#[derive(Drop, starknet::Event)]
pub struct FeeUpdated {
    pub old_fee: u16,
    pub new_fee: u16,
}

