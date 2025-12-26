# Contract Deployment Scripts

This repository provides two ways to deploy StarkNet contracts:
1. **TypeScript-based deployment script** (`deploy.ts`)
2. **Bash-based deployment script** (`deployment.sh`)

## Prerequisites

- Node.js and npm/pnpm installed
- StarkNet CLI (`sncast`) installed
- Environment variables set (see [Configuration](#configuration))

## Configuration

1. Create a `.env` file in the project root with the following variables:
   ```env
   # Required
   STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n
   
   # Optional (default shown)
   PACKAGE_NAME=isyncpayment
   ```

## Available Contracts

- `account`: Account contract (declare only)
- `account-factory`: Account Factory contract
- `liquidity-bridge`: Liquidity Bridge contract
- `sync-token`: Sync Token contract
- `staking`: Staking contract

## TypeScript Deployment Script

### Setup
```bash
pnpm add -D ts-node typescript dotenv
```

### Usage
```bash
# Deploy a contract
ts-node scripts/deploy.ts <contract-name>

# Only declare a contract (without deploying)
ts-node scripts/deploy.ts <contract-name> --declare-only
```

### Examples
```bash
# Deploy the Liquidity Bridge
ts-node scripts/deploy.ts liquidity-bridge

# Only declare the Account contract
ts-node scripts/deploy.ts account --declare-only
```

## Bash Deployment Script

### Setup
```bash
chmod +x scripts/deployment.sh
```

### Usage
```bash
# List available contracts
./scripts/deploy.sh list

# Declare a contract
./scripts/deploy.sh declare <contract-name>

# Deploy a contract (automatically declares first if needed)
./scripts/deploy.sh deploy <contract-name>

# Use a custom RPC URL
./scripts/deploy.sh --rpc <custom-rpc-url> deploy <contract-name>
```

### Examples
```bash
# Deploy the Liquidity Bridge
./scripts/deploy.sh deploy liquidity-bridge

# Only declare the Account contract
./scripts/deploy.sh declare account

# Deploy with custom RPC
./scripts/deploy.sh --rpc https://custom-rpc.example.com deploy staking

# Deploy `sync-token` (ERC20) to mainnet (requires confirmation and a proper account configuration)
# Example: CONFIRM_MAINNET=true ./scripts/deployment.sh --rpc https://starknet-mainnet-rpc.example deploy sync-token
```

## Common Issues

1. **Permission Denied**
   ```bash
   chmod +x scripts/deploy.sh
   ```

2. **Dependencies Missing**
   ```bash
   pnpm install
   ```

3. **Environment Variables Not Set**
   Ensure your `.env` file exists and contains the required variables.

## Notes

- Both scripts handle contract declaration and deployment in the correct order
- All contract addresses and transaction hashes are displayed in the console
- The scripts include error handling and helpful error messages
- The bash script provides color-coded output for better readability

**Mainnet safety note:** Mainnet deployments are irreversible and can cost real funds. Ensure your account is configured and funded in `sncast` (or via your preferred CLI), and **test using Sepolia first**. To prevent accidental mainnet deployment, the bash script requires `CONFIRM_MAINNET=true` when using a mainnet RPC URL.
