use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct PoolCreated {
    pub token_symbol: felt252,
    pub token_address: ContractAddress,
    pub base_apy_bps: u16,
    pub min_stake_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolUpdated {
    pub token_symbol: felt252,
    pub base_apy_bps: u16,
    pub bonus_apy_bps: u16,
}

#[derive(Drop, starknet::Event)]
pub struct Staked {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub stake_id: u64,
    pub amount: u256,
    pub lock_duration: u64,
    pub unlock_at: u64,
    pub effective_apy_bps: u16,
}

#[derive(Drop, starknet::Event)]
pub struct Unstaked {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub stake_id: u64,
    pub amount: u256,
    pub rewards: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RewardsClaimed {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct EmergencyWithdrawal {
    pub user: ContractAddress,
    pub token_symbol: felt252,
    pub stake_id: u64,
    pub amount: u256,
    pub penalty: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RewardsDeposited {
    pub token_symbol: felt252,
    pub amount: u256,
    pub depositor: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct FiatStakeRecorded {
    pub currency: felt252,
    pub amount: u256,
    pub lock_duration: u64,
    pub stake_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct FiatUnstakeRecorded {
    pub user: ContractAddress,
    pub currency: felt252,
    pub stake_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct FiatRewardClaimRecorded {
    pub user: ContractAddress,
    pub currency: felt252,
    pub stake_id: felt252,
    pub rewards: u256,
}

#[derive(Drop, starknet::Event)]
pub struct BalanceMerkleRootUpdated {
    pub merkle_root: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ReserveSnapshotCreated {
    pub currency: felt252,
    pub balance: u256,
    pub ipfs_hash: felt252,
}
