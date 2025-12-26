//! Error definitions for the ERC20 package

pub mod erc20_errors {
    // Standard ERC20 errors
    pub const ZERO_ADDRESS: felt252 = 'ERC20: zero address';
    pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: allowance too low';
    pub const INVALID_AMOUNT: felt252 = 'ERC20: zero amount';
    pub const APPROVE_FROM_ZERO: felt252 = 'ERC20: approver is zero';
    pub const APPROVE_TO_ZERO: felt252 = 'ERC20: spender is zero';
    pub const BURN_EXCEEDS_BALANCE: felt252 = 'ERC20: burn > balance';
    pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from zero';
    pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to zero';
    
    // Access control errors
    pub const MISSING_ROLE: felt252 = 'AC: no role';
    pub const ROLE_GRANTED: felt252 = 'AC: role exists';
    pub const ROLE_NOT_GRANTED: felt252 = 'AC: role missing';
    pub const ROLE_REVOKED: felt252 = 'AC: role revoked';
    pub const INVALID_ROLE: felt252 = 'AC: bad role';
    
    // Pausable errors
    pub const PAUSED: felt252 = 'Paused';
    pub const NOT_PAUSED: felt252 = 'Not paused';
    pub const ENFORCE_PAUSE: felt252 = 'Pause required';
    
    // Upgradeable errors
    pub const NOT_INITIALIZING: felt252 = 'Init: not initializing';
    pub const ALREADY_INITIALIZED: felt252 = 'Init: already done';
    pub const INVALID_INITIALIZATION: felt252 = 'Init: bad state';
    
    // Custom errors
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const APPROVE_FAILED: felt252 = 'Approve failed';
    pub const MINT_FAILED: felt252 = 'Mint failed';
    pub const BURN_FAILED: felt252 = 'ERC20: burn failed';
    pub const NAME_TOO_LONG: felt252 = 'ERC20: name too long';
    pub const SYMBOL_TOO_LONG: felt252 = 'ERC20: symbol too long';
    pub const DECIMALS_TOO_HIGH: felt252 = 'ERC20: decimals too high';
    pub const CAP_EXCEEDED: felt252 = 'ERC20: cap exceeded';
    pub const NOT_WHITELISTED: felt252 = 'ERC20: address not whitelisted';
    pub const BLACKLISTED: felt252 = 'ERC20: address blacklisted';
    pub const SELF_DESTRUCT_DISABLED: felt252 = 'ERC20: self-destruct disabled';
}
