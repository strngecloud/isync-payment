# ERC20 Token Deployment Guide

This guide explains how to deploy the SyncToken (ERC20) contract with the specified parameters.

## Prerequisites

1. **Environment Variables**: Create or update your `.env` file with:
   ```env
   STARKNET_RPC_URL=https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/YOUR_API_KEY
   DEPLOYER_PRIVATE_KEY=your_private_key_here
   DEPLOYER_ACCOUNT_ADDRESS=your_account_address_here
   ```

2. **Build the Contract**: First, compile the ERC20 contract:
   ```bash
   cd packages/erc20
   scarb build
   cd ../..
   ```

## Deployment

### Deploy with Default Parameters (SyncToken, sNGN, 2 decimals)

```bash
pnpm deploy sync-token
```

This will deploy with the default configuration:
- **Name**: SyncToken
- **Symbol**: sNGN
- **Decimals**: 2
- **Initial Supply**: 0
- **All roles assigned to deployer account**

### Deploy with Custom Parameters

```bash
pnpm deploy sync-token --name "CustomToken" --symbol "CTK" --decimals 6 --initial-supply 1000000000
```

### Available Options

- `--name <string>`: Token name (default: "SyncToken")
- `--symbol <string>`: Token symbol (default: "sNGN")
- `--decimals <number>`: Number of decimals (default: 2)
- `--initial-supply <number>`: Initial supply in smallest unit (default: 0)
- `--recipient <address>`: Address to receive initial supply (default: deployer)
- `--owner <address>`: Owner/admin address (default: deployer)
- `--pauser <address>`: Pauser role address (default: deployer)
- `--minter <address>`: Minter role address (default: deployer)

## Deployment Process

The deployment script performs the following steps:

1. **Formats Constructor Arguments**: Uses `starknetjs` to properly format all constructor parameters:
   - Converts token name and symbol to Cairo short strings
   - Formats numeric values (decimals, initial supply)
   - Converts addresses to the correct format

2. **Declares the Contract**: Submits the contract class to Starknet for declaration
   - Waits for the declaration transaction to be confirmed
   - Obtains the class hash for deployment

3. **Deploys the Contract**: Uses the class hash to deploy an instance
   - Passes the formatted constructor arguments
   - Waits for the deployment transaction to be confirmed
   - Returns the deployed contract address

4. **Logs the Deployment**: Records deployment details in:
   - Console output (color-coded for readability)
   - Log file: `deployment_logs/deploy_[timestamp].log`
   - JSON record: `deployment_logs/deployment_log.json`

## Contract Constructor Parameters

The ERC20 contract constructor expects 8 parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | ByteArray | Token name (e.g., "SyncToken") |
| `symbol` | ByteArray | Token symbol (e.g., "sNGN") |
| `decimals` | u8 | Number of decimal places |
| `initial_supply` | u256 | Initial token supply in smallest units |
| `recipient` | ContractAddress | Address to receive initial supply |
| `owner` | ContractAddress | Admin/owner role (DEFAULT_ADMIN_ROLE) |
| `pauser` | ContractAddress | Pauser role (can pause/unpause) |
| `minter` | ContractAddress | Minter role (can mint new tokens) |

## Formatted Constructor Arguments Example

For deployment with name="SyncToken", symbol="sNGN", decimals=2:

```typescript
// These are properly formatted by the deployment script:
{
  name: "SyncToken",           // Short string format
  symbol: "sNGN",              // Short string format
  decimals: 2,                 // u8
  initial_supply: 0n,          // u256 (BigInt)
  recipient: "0x...",          // Contract address
  owner: "0x...",              // Contract address
  pauser: "0x...",             // Contract address
  minter: "0x...",             // Contract address
}
```

## After Deployment

Once deployed, the contract address will be:
- Printed to console
- Saved to `deployment_logs/deployment_log.json`
- Available in the color-coded log output

You can then:
1. Verify the contract on a block explorer
2. Interact with the token using the deployment address
3. Grant or revoke roles as needed

## Troubleshooting

### Contract Not Found
- Ensure you've built the contract: `cd packages/erc20 && scarb build && cd ../..`
- Check that compiled artifacts exist in `packages/erc20/target/release/`

### Transaction Failures
- Verify your account has sufficient funds for gas
- Check your RPC URL is correct and accessible
- Ensure DEPLOYER_ACCOUNT_ADDRESS matches your private key

### Invalid Constructor Arguments
- The deployment script automatically formats arguments correctly
- If using custom addresses, ensure they are valid Starknet addresses
- Token name and symbol must be valid ByteArray/short strings

## Default Deployment Command

```bash
# Deploys SyncToken (sNGN) with 2 decimals
pnpm deploy sync-token
```

This is the recommended command for your specified parameters.
