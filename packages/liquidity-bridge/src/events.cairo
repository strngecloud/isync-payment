use starknet::ContractAddress;

// Individual event structs (no wrapper enum) — contract will declare and map the events it uses.

// Token management events
#[derive(Drop, starknet::Event)]
pub struct TokenAdded {
    pub token: ContractAddress,
    pub symbol: felt252,
    pub decimals: u8,
    pub min_amount: u256,
    pub max_amount: u256,
    pub is_active: bool,
    pub feed_id: felt252,
    pub added_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TokenRemoved {
    pub token: ContractAddress,
    pub symbol: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct TokenPaused {
    pub token: ContractAddress,
    pub by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenUnpaused {
    pub token: ContractAddress,
    pub by: ContractAddress,
}

// Swap events
#[derive(Drop, starknet::Event)]
pub struct SwapCreated {
    pub swap_id: u64,
    pub user: ContractAddress,
    pub token_in: ContractAddress,
    pub token_out: ContractAddress,
    pub amount_in: u256,
    pub min_amount_out: u256,
    pub deadline: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SwapExecuted {
    pub swap_id: u64,
    pub user: ContractAddress,
    pub token_in: ContractAddress,
    pub token_out: ContractAddress,
    pub amount_in: u256,
    pub amount_out: u256,
    pub fee_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct SwapInitiated {
    pub swap_id: u64,
    pub user: ContractAddress,
    pub from_token: ContractAddress,
    pub to_token: ContractAddress,
    pub from_amount: u256,
    pub min_to_amount: u256,
    pub fee_amount: u256,
    pub nonce: u64,
    pub deadline: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SwapCompleted {
    pub swap_id: u64,
    pub user: ContractAddress,
    pub from_token: ContractAddress,
    pub to_token: ContractAddress,
    pub from_amount: u256,
    pub to_amount: u256,
    pub fee_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct SwapCancelled {
    pub swap_id: u64,
    pub user: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub reason: felt252,
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
pub struct UserRegistered {
    pub name: felt252,
    pub user: ContractAddress,
    pub fiat_account_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct FiatToTokenSwapExecuted {
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
    pub name: felt252,
    pub user: ContractAddress,
    pub swap_order_id: felt252,
    pub fiat_symbol: felt252,
    pub token_symbol: felt252,
    pub fiat_amount: u256,
    pub token_amount: u256,
    pub fee: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FundsLocked {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct WithdrawalCompleted {
    pub name: felt252,
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
    pub fiat_reference: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ExchangeRateUpdated {
    pub asset: felt252,
    pub rate: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct FeeUpdated {
    pub old_fee_bps: u16,
    pub new_fee_bps: u16,
    pub updated_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct SlippageToleranceUpdated {
    pub old_bps: u16,
    pub new_bps: u16,
    pub updated_by: ContractAddress,
}

// Liquidity events
#[derive(Drop, starknet::Event)]
pub struct LiquidityAdded {
    pub provider: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub liquidity: u256,
}

#[derive(Drop, starknet::Event)]
pub struct LiquidityRemoved {
    pub provider: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub liquidity: u256,
}

// Fee events
#[derive(Drop, starknet::Event)]
pub struct FeeCollected {
    pub token: ContractAddress,
    pub amount: u256,
    pub fee_type: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct FeeDistributed {
    pub token: ContractAddress,
    pub amount: u256,
    pub receiver: ContractAddress,
}

// Admin events
#[derive(Drop, starknet::Event)]
pub struct AdminChanged {
    pub old_admin: ContractAddress,
    pub new_admin: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct FeeReceiverUpdated {
    pub old_receiver: ContractAddress,
    pub new_receiver: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct FeeRateUpdated {
    pub old_rate: u256,
    pub new_rate: u256,
}

#[derive(Drop, starknet::Event)]
pub struct SwapFeeUpdated {
    pub old_fee: u256,
    pub new_fee: u256,
    pub updated_by: ContractAddress,
}

// Emergency events
#[derive(Drop, starknet::Event)]
pub struct EmergencyWithdraw {
    pub token: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyModeToggled {
    pub enabled: bool,
    pub by: ContractAddress,
}

// Rate limiting events
#[derive(Drop, starknet::Event)]
pub struct RateLimitUpdated {
    pub token: ContractAddress,
    pub limit: u256,
    pub interval: u64,
}

#[derive(Drop, starknet::Event)]
pub struct WithdrawalLimitUpdated {
    pub token: ContractAddress,
    pub limit: u256,
    pub interval: u64,
}

#[derive(Drop, starknet::Event)]
pub struct DepositLimitUpdated {
    pub token: ContractAddress,
    pub limit: u256,
    pub interval: u64,
}
