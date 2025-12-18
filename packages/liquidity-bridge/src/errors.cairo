//! Error definitions for the liquidity bridge package

pub mod bridge_errors {
    // General errors
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    pub const DEADLINE_PASSED: felt252 = 'Deadline passed';
    pub const INSUFFICIENT_OUTPUT_AMOUNT: felt252 = 'Insufficient output amount';
    pub const NOT_IN_EMERGENCY_MODE: felt252 = 'Not in emergency mode';

    // Bridge-specific errors
    // Token errors
    pub const INVALID_TOKEN: felt252 = 'Invalid token';
    pub const TOKEN_NOT_SUPPORTED: felt252 = 'Token not supported';
    pub const TOKEN_NOT_FOUND: felt252 = 'Token not found';
    pub const TOKEN_ALREADY_ADDED: felt252 = 'Token already added';
    pub const TOKEN_ALREADY_EXISTS: felt252 = 'Token already exists';
    pub const TOKEN_ALREADY_PAUSED: felt252 = 'Token already paused';
    pub const TOKEN_NOT_PAUSED: felt252 = 'Token not paused';
    pub const TOKEN_NOT_ACTIVE: felt252 = 'Token not active';
    pub const TOKEN_LIQUIDITY_EXCEEDED: felt252 = 'Token liquidity exceeded';
    pub const TOKEN_HAS_LIQUIDITY: felt252 = 'Token has liquidity';
    pub const INVALID_TOKEN_AMOUNT: felt252 = 'Invalid token amount';
    pub const INVALID_FIAT_CURRENCY: felt252 = 'Invalid fiat currency';
    pub const INVALID_TOKEN_SYMBOL: felt252 = 'Invalid token symbol';
    pub const INVALID_EXCHANGE_RATE: felt252 = 'Invalid exchange rate';
    pub const INVALID_SLIPPAGE: felt252 = 'Invalid slippage tolerance';
    pub const SLIPPAGE_EXCEEDED: felt252 = 'Slippage tolerance exceeded';

    // Swap errors
    pub const SWAP_AMOUNT_TOO_SMALL: felt252 = 'Swap amount too small';
    pub const SWAP_AMOUNT_TOO_LARGE: felt252 = 'Swap amount too large';
    pub const INSUFFICIENT_LIQUIDITY: felt252 = 'Insufficient liquidity';
    pub const SWAP_NOT_ALLOWED: felt252 = 'Swap not allowed';
    pub const SWAP_ALREADY_PROCESSED: felt252 = 'Swap already processed';
    pub const SWAP_NOT_FOUND: felt252 = 'Swap not found';
    pub const SWAP_EXPIRED: felt252 = 'Swap expired';
    pub const INVALID_SWAP_STATUS: felt252 = 'Invalid swap status';
    pub const NO_SUCH_SWAP: felt252 = 'No such swap exists';

    // Fee errors
    pub const INVALID_FEE: felt252 = 'Invalid fee';
    pub const FEE_TOO_HIGH: felt252 = 'Fee too high';
    pub const FEE_RECEIVER_NOT_SET: felt252 = 'Fee receiver not set';

    // Pausable errors
    pub const PAUSED: felt252 = 'Pausable: paused';
    pub const NOT_PAUSED: felt252 = 'Pausable: not paused';

    // Emergency errors
    pub const EMERGENCY_MODE_ACTIVE: felt252 = 'Emergency mode active';
    pub const EMERGENCY_WITHDRAWAL_ACTIVE: felt252 = 'Emergency withdrawal active';
    pub const EMERGENCY_WITHDRAWAL_NOT_ACTIVE: felt252 = 'Emergency withdrawal not active';

    // Role errors
    pub const MISSING_ROLE: felt252 = 'Missing required role';
    pub const ROLE_ALREADY_GRANTED: felt252 = 'Role already granted';
    pub const ROLE_NOT_GRANTED: felt252 = 'Role not granted';

    // Validation errors
    pub const INVALID_PARAMETER: felt252 = 'Invalid parameter';
    pub const INVALID_TIMESTAMP: felt252 = 'Invalid timestamp';
    pub const INVALID_SIGNATURE: felt252 = 'Invalid signature';
    pub const INVALID_NONCE: felt252 = 'Invalid nonce';
    pub const NONCE_ALREADY_USED: felt252 = 'Nonce already used';
    pub const BELOW_MIN_AMOUNT: felt252 = 'Amount below minimum';
    pub const ABOVE_MAX_AMOUNT: felt252 = 'Amount above maximum';
    pub const INSUFFICIENT_AMOUNT: felt252 = 'Insufficient amount';

    // Additional errors used by refactored implementation
    pub const INVALID_TOKEN_ADDRESS: felt252 = 'Invalid token address';
    pub const INVALID_FIAT_ID: felt252 = 'Invalid fiat identifier';
    pub const INVALID_FIAT_SYMBOL: felt252 = 'Invalid fiat symbol';
    pub const USER_NOT_REGISTERED: felt252 = 'User not registered';
    pub const INSUFFICIENT_TOKEN_LIQUIDITY: felt252 = 'Insufficient token liquidity';
    pub const INVALID_SUPPORTED_TOKEN: felt252 = 'Invalid supported token';
    pub const CANNOT_BE_ZERO: felt252 = 'Value cannot be zero';
    pub const UNAUTHORIZED_OPERATOR: felt252 = 'Unauthorized operator';
    pub const SLIPPAGE_TOLERANCE_EXCEEDED: felt252 = 'Slippage tolerance exceeded';

    // Rate limiting errors    
    pub const WITHDRAWAL_LIMIT_EXCEEDED: felt252 = 'Withdrawal limit exceeded';
    pub const DEPOSIT_LIMIT_EXCEEDED: felt252 = 'Deposit limit exceeded';

    // Oracle errors
    pub const ORACLE_NOT_SET: felt252 = 'Oracle not set';
    pub const STALE_PRICE: felt252 = 'Stale price data';
    pub const INVALID_PRICE: felt252 = 'Invalid price data';

    // Transfer errors
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const APPROVE_FAILED: felt252 = 'Approve failed';
    pub const CALL_FAILED: felt252 = 'Call failed';
}
