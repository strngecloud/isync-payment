# iSync Payment

[![StarkNet](https://img.shields.io/badge/StarkNet-0052FF?style=flat&logo=starknet&logoColor=white)](https://starknet.io/)
[![Cairo](https://img.shields.io/badge/Cairo-0052FF?style=flat&logo=starknet&logoColor=white)](https://cairo-lang.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-4E5EE4?style=flat&logo=openzeppelin&logoColor=white)](https://openzeppelin.com/)

## Overview

iSync Payment is a collection of Cairo smart contracts deployed on the StarkNet ecosystem, implementing the core payment and liquidity management functionality for the Sync decentralized payment system. These contracts enable secure, decentralized fiat-to-crypto transactions, automated liquidity bridging, and merchant payment processing.

Key contracts include:
- **Payment Contracts**: Handle fiat-to-crypto conversions and merchant settlements.
- **Liquidity Pool Contracts**: Manage automated funding and reserve allocations.
- **Token Contracts**: Custom tokens for the Sync ecosystem ($XPAY and others).
- **Access Control**: Role-based permissions for secure contract interactions.

## Features

- **Decentralized Payments**: Smart contracts for instant fiat-to-crypto swaps and settlements.
- **Liquidity Management**: Automated bridging between fiat reserves and crypto liquidity pools.
- **Merchant Integration**: QR code-based payment processing with instant finality.
- **Security**: Built with OpenZeppelin standards for access control, pausability, and upgradability.
- **Oracle Integration**: Uses Pragma for real-time price feeds and oracle data.
- **Testing Suite**: Comprehensive tests using Snforge for reliability.

## Tech Stack

- **Language**: Cairo (StarkNet's native language)
- **Framework**: StarkNet 2.11.4
- **Libraries**:
  - OpenZeppelin 2.0.0 (access control, security)
  - Pragma (decentralized oracles)
  - Alexandria Math (mathematical operations)
- **Development Tools**:
  - Scarb (package manager)
  - Snforge (testing framework)
  - Foundry (deployment and interactions)

## Installation

### Prerequisites

- Rust (for Scarb and Cairo tools)
- Scarb package manager
- StarkNet CLI tools (for deployment)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd sync/isyncpayment
   ```

2. **Install dependencies**
   ```bash
   scarb build
   ```

3. **Run Tests**
   ```bash
   scarb test
   ```

   Or run specific tests:
   ```bash
   snforge test
   ```

## Usage

### Development

- **Build Contracts**: `scarb build` - Compiles all Cairo contracts to Sierra.
- **Run Tests**: `scarb test` - Executes the test suite with Snforge.
- **Check Contract Sizes**: Ensure contracts fit within StarkNet's deployment limits.

### Deployment

1. **Configure Network**
   - Update deployment scripts with target network (mainnet, testnet).
   - Set environment variables for private keys and RPC URLs.

2. **Deploy Contracts**
   ```bash
   # Example using Foundry or StarkNet CLI
   starkli contract deploy <contract-class> <constructor-args> --network mainnet
   ```

3. **Verify Deployment**
   - Use StarkScan or similar explorers to verify contracts.
   - Run integration tests against deployed contracts.

### Key Contracts

- **PaymentProcessor**: Main contract for handling payment flows and swaps.
- **LiquidityManager**: Manages fiat reserves and crypto liquidity bridging.
- **Token Contracts**: ERC-20 compatible tokens for the ecosystem.
- **AccessControl**: Defines roles for admin, user, and merchant interactions.

### Integration with Sync Ecosystem

- **Backend Integration**: Sync Backend interacts with these contracts for transaction processing.
- **Indexer Integration**: SyncPay Indexer monitors events emitted by these contracts.
- **Frontend Integration**: SyncWeb and Sync Mobile provide UIs for contract interactions.

## Project Structure

```
isyncpayment/
├── src/                    # Cairo source files
│   ├── contracts/         # Main contract implementations
│   │   ├── payment.cairo
│   │   ├── liquidity.cairo
│   │   └── ...
│   ├── interfaces/        # Contract interfaces
│   ├── libraries/         # Shared utility libraries
│   └── ...
├── tests/                 # Test files for contracts
├── Scarb.toml            # Project configuration
├── snfoundry.toml        # Testing configuration
└── ...
```

## Security Considerations

- **Audit Status**: Contracts should undergo security audits before mainnet deployment.
- **Access Control**: Uses OpenZeppelin patterns for secure role management.
- **Pausability**: Contracts include pause mechanisms for emergency stops.
- **Upgradeability**: Designed with proxy patterns for future upgrades.

## Testing

- **Unit Tests**: Test individual contract functions using Snforge.
- **Integration Tests**: Deploy contracts to testnet and test end-to-end flows.
- **Fork Testing**: Use forked mainnet state for realistic testing scenarios.

### Running Tests

```bash
# Run all tests
snforge test

# Run with coverage (if configured)
snforge test --coverage

# Run specific test file
snforge test tests/test_payment.cairo
```

## Deployment Guide

1. **Development Deployment**: Deploy to StarkNet testnet (Sepolia or Goerli).
2. **Mainnet Deployment**: Use multi-sig wallets and gradual rollouts.
3. **Verification**: Publish contract source code on explorers for transparency.

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-contract`.
3. Implement the contract logic in Cairo.
4. Write comprehensive tests.
5. Deploy to testnet and verify functionality.
6. Push to the branch: `git push origin feature/your-contract`.
7. Open a pull request.

Follow Cairo best practices and ensure all contracts are thoroughly tested.

## License

This project is licensed under the MIT License.

## Support

For issues, security concerns, or contributions, please contact the development team or open an issue in the repository.

---

*Built with Cairo and StarkNet for decentralized payment processing in the Sync ecosystem.*
