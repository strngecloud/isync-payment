//! Error definitions for the ERC20 package

pub mod erc20_errors {
    // Standard ERC20 errors
    pub const ZERO_ADDRESS: felt252 = 'ERC20: transfer to the zero address';
    pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: transfer amount exceeds balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
    pub const INVALID_AMOUNT: felt252 = 'ERC20: amount must be greater than zero';
    pub const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from the zero address';
    pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to the zero address';
    pub const BURN_EXCEEDS_BALANCE: felt252 = 'ERC20: burn amount exceeds balance';
    pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from the zero address';
    pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to the zero address';
    
    // Access control errors
    pub const MISSING_ROLE: felt252 = 'AccessControl: missing role';
    pub const ROLE_GRANTED: felt252 = 'AccessControl: role already granted';
    pub const ROLE_NOT_GRANTED: felt252 = 'AccessControl: role not granted';
    pub const ROLE_REVOKED: felt252 = 'AccessControl: role already revoked';
    pub const INVALID_ROLE: felt252 = 'AccessControl: invalid role';
    
    // Pausable errors
    pub const PAUSED: felt252 = 'Pausable: paused';
    pub const NOT_PAUSED: felt252 = 'Pausable: not paused';
    pub const ENFORCE_PAUSE: felt252 = 'Pausable: enforce pause';
    
    // Upgradeable errors
    pub const NOT_INITIALIZING: felt252 = 'Initializable: contract is not initializing';
    pub const ALREADY_INITIALIZED: felt252 = 'Initializable: contract is already initialized';
    pub const INVALID_INITIALIZATION: felt252 = 'Initializable: contract is not initializing';
    
    // Custom errors
    pub const TRANSFER_FAILED: felt252 = 'ERC20: transfer failed';
    pub const APPROVE_FAILED: felt252 = 'ERC20: approve failed';
    pub const MINT_FAILED: felt252 = 'ERC20: mint failed';
    pub const BURN_FAILED: felt252 = 'ERC20: burn failed';
    pub const NAME_TOO_LONG: felt252 = 'ERC20: name too long';
    pub const SYMBOL_TOO_LONG: felt252 = 'ERC20: symbol too long';
    pub const DECIMALS_TOO_HIGH: felt252 = 'ERC20: decimals too high';
    pub const CAP_EXCEEDED: felt252 = 'ERC20: cap exceeded';
    pub const NOT_WHITELISTED: felt252 = 'ERC20: address not whitelisted';
    pub const BLACKLISTED: felt252 = 'ERC20: address blacklisted';
    pub const SELF_DESTRUCT_DISABLED: felt252 = 'ERC20: self-destruct disabled';
}
