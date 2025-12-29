import {
  Account,
  Contract,
  RpcProvider,
  ec,
  json,
  constants,
  CallData,
  cairo,
  shortString,
  hash,
} from "starknet";
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";

// Load environment variables
dotenv.config();

// Configuration
const RPC_URL =
  process.env.STARKNET_RPC_URL ||
  "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw";
const DEPLOYMENT_LOG_DIR = "deployment_logs";
const DEPLOYMENT_LOG = path.join(
  DEPLOYMENT_LOG_DIR,
  `deploy_${new Date().toISOString().replace(/[:.]/g, "-")}.log`
);

// Package configurations
const PACKAGE_PATHS: Record<string, string> = {
  "account-factory": "packages/account",
  "liquidity-bridge": "packages/liquidity-bridge",
  "sync-token": "packages/erc20",
  staking: "packages/staking",
};

const PACKAGE_NAMES: Record<string, string> = {
  account: "sync_account",
  "account-factory": "sync_account",
  "liquidity-bridge": "liquidity_bridge",
  "sync-token": "erc20",
  staking: "sync_staking",
};

const CONTRACT_NAMES: Record<string, string> = {
  account: "sync_account",
  "account-factory": "sync_account",
  "liquidity-bridge": "liquidity_bridge",
  "sync-token": "SyncERC20",
  staking: "SyncStaking",
};

// Colors for console output
const colors = {
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  red: "\x1b[31m",
  reset: "\x1b[0m",
};

// Types
interface DeploymentLog {
  contract: string;
  address: string;
  txHash: string;
  timestamp: string;
  network: string;
}

class Deployer {
  private provider: RpcProvider;
  private account: Account;
  private deploymentLog: DeploymentLog[] = [];

  constructor() {
    this.provider = new RpcProvider({
      nodeUrl: RPC_URL,
    });

    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
    const accountAddress = process.env.DEPLOYER_ACCOUNT_ADDRESS;

    if (!privateKey || !accountAddress) {
      throw new Error(
        "DEPLOYER_PRIVATE_KEY and DEPLOYER_ACCOUNT_ADDRESS must be set in .env"
      );
    }

    this.account = new Account({
      provider: this.provider,
      address: accountAddress,
      signer: privateKey,
    });

    // Create deployment logs directory if it doesn't exist
    if (!fs.existsSync(DEPLOYMENT_LOG_DIR)) {
      fs.mkdirSync(DEPLOYMENT_LOG_DIR, { recursive: true });
    }
  }

  private log(
    message: string,
    type: "info" | "success" | "error" | "warning" = "info"
  ): void {
    const timestamp = new Date().toISOString();
    let prefix = "";

    switch (type) {
      case "success":
        prefix = `${colors.green}✓${colors.reset} `;
        break;
      case "error":
        prefix = `${colors.red}✗${colors.reset} `;
        break;
      case "warning":
        prefix = `${colors.yellow}!${colors.reset} `;
        break;
      default:
        prefix = "  ";
    }

    const logMessage = `[${timestamp}] ${prefix}${message}`;
    console.log(logMessage);

    // Append to log file
    fs.appendFileSync(DEPLOYMENT_LOG, logMessage + "\n");
  }

  /**
   * Get default resource bounds for V3 transactions
   * These values provide sufficient gas for most contract deployments
   */
  private getDefaultResourceBounds() {
    return {
      l1_gas: {
        max_amount: BigInt(1_500_000),
        max_price_per_unit: BigInt(30_000_000_000), // ~30 gwei
      },
      l2_gas: {
        max_amount: BigInt(1_500_000),
        max_price_per_unit: BigInt(1_000_000_000), // 1 gwei
      },
      l1_data_gas: {
        max_amount: BigInt(1_500_000),
        max_price_per_unit: BigInt(30_000_000_000),
      },
    };
  }

  private async getCompiledContract(
    contractName: string
  ): Promise<{ contract: any; casm?: any }> {
    // Try to find the contract in package paths (check both release and dev build dirs)
    for (const [pkg, pkgPath] of Object.entries(PACKAGE_PATHS)) {
      const packageName = PACKAGE_NAMES[pkg];
      const contractClassName = CONTRACT_NAMES[contractName];

      for (const buildType of ["release", "dev"]) {
        const buildDir = path.join(pkgPath, `target/${buildType}`);

        // Try to find contract_class.json format (newer format)
        const contractClassPath = path.join(
          buildDir,
          `${packageName}_${contractClassName}.contract_class.json`
        );

        if (fs.existsSync(contractClassPath)) {
          const contract = JSON.parse(
            fs.readFileSync(contractClassPath, "utf-8")
          );

          // Try to find the compiled_contract_class.json file
          const compiledPath = contractClassPath.replace(
            ".contract_class.json",
            ".compiled_contract_class.json"
          );
          if (fs.existsSync(compiledPath)) {
            const casm = JSON.parse(fs.readFileSync(compiledPath, "utf-8"));
            return { contract, casm };
          }

          return { contract };
        }

        // Fallback to old format
        const contractPath = path.join(buildDir, `${contractClassName}.json`);

        if (fs.existsSync(contractPath)) {
          const contract = JSON.parse(fs.readFileSync(contractPath, "utf-8"));

          // Try to find the CASM file
          const casmPath = contractPath.replace(".json", ".casm.json");
          if (fs.existsSync(casmPath)) {
            const casm = JSON.parse(fs.readFileSync(casmPath, "utf-8"));
            return { contract, casm };
          }

          return { contract };
        }
      }
    }

    // If not found in package paths, try direct lookup in top-level target dirs
    for (const buildType of ["release", "dev"]) {
      const directPath = `target/${buildType}/${contractName}.json`;
      if (fs.existsSync(directPath)) {
        const contract = JSON.parse(fs.readFileSync(directPath, "utf-8"));

        // Try to find the CASM file
        const casmPath = directPath.replace(".json", ".casm.json");
        if (fs.existsSync(casmPath)) {
          const casm = JSON.parse(fs.readFileSync(casmPath, "utf-8"));
          return { contract, casm };
        }

        return { contract };
      }
    }

    throw new Error(`Could not find compiled contract for ${contractName}`);
  }

  public async declareContract(contractName: string): Promise<string> {
    this.log(`Declaring ${contractName} contract...`);

    try {
      const { contract, casm } = await this.getCompiledContract(contractName);

      let declareTx;

      if (casm) {
        declareTx = await this.account.declare(
          { contract, casm },
          { version: 3, resourceBounds: this.getDefaultResourceBounds() }
        )
      } else {
        declareTx = await this.account.declare({
          contract,
          compiledClassHash: "0x0",
        });
      }

      await this.provider.waitForTransaction(declareTx.transaction_hash);

      this.log(
        `✓ Successfully declared ${contractName} with class hash: ${declareTx.class_hash}`,
        "success"
      );
      this.log(`   Transaction hash: ${declareTx.transaction_hash}`);

      return declareTx.class_hash;
    } catch (error) {
      this.log(`✗ Failed to declare ${contractName}: ${error}`, "error");
      throw error;
    }
  }

  public async deployERC20Token(
    name: string,
    symbol: string,
    decimals: number,
    initialSupply: bigint = 1000000n,
    recipient?: string,
    owner?: string,
    pauser?: string,
    minter?: string
  ): Promise<string> {
    this.log(`Deploying ERC20 Token: ${name} (${symbol})...`);

    try {
      const { contract, casm } = await this.getCompiledContract("sync-token");

      // Use the deployer account address if no specific addresses provided
      const deployerAddress = this.account.address;
      const recipientAddr = recipient || deployerAddress;
      const ownerAddr = owner || deployerAddress;
      const pauserAddr = pauser || deployerAddress;
      const minterAddr = minter || deployerAddress;

      // Format constructor arguments using starknetjs
      // For ByteArray parameters, we pass strings and starknet.js will serialize them correctly
      // The constructor expects: (name: ByteArray, symbol: ByteArray, decimals: u8, initial_supply: u256, recipient, owner, pauser, minter)
      const uint256InitialSupply = cairo.uint256(initialSupply);

      const constructorCalldata = [
        name, // ByteArray as string - will be serialized by starknet.js
        symbol, // ByteArray as string - will be serialized by starknet.js
        decimals.toString(), // u8
        uint256InitialSupply.low,
        uint256InitialSupply.high,
        recipientAddr, // ContractAddress
        ownerAddr, // ContractAddress
        pauserAddr, // ContractAddress
        minterAddr, // ContractAddress
      ];

      this.log(`Constructor args formatted successfully`, "info");
      this.log(`  Name: ${name}`, "info");
      this.log(`  Symbol: ${symbol}`, "info");
      this.log(`  Decimals: ${decimals}`, "info");
      this.log(`  Initial Supply: ${initialSupply.toString()}`, "info");
      this.log(`  Recipient: ${recipientAddr}`, "info");
      this.log(`  Owner: ${ownerAddr}`, "info");
      this.log(`  Pauser: ${pauserAddr}`, "info");
      this.log(`  Minter: ${minterAddr}`, "info");

      // First declare the contract
      let declareTx;
      this.log(`Declaring contract...`, "info");

      if (casm) {
        // Calculate the compiled class hash from the CASM
        const compiledClassHash = hash.computeCompiledClassHash(casm);

        try {
          declareTx = await this.account.declare({
            contract,
            casm,
            compiledClassHash: compiledClassHash,
          });
        } catch (error: any) {
          // If the class is already declared, extract the class hash
          if (error.message && error.message.includes("is already declared")) {
            const classHash = hash.computeContractClassHash(contract);
            this.log(`ℹ Contract class already declared: ${classHash}`, "info");
            declareTx = {
              class_hash: classHash,
              transaction_hash: "0x0",
            } as any;
          } else {
            throw error;
          }
        }
      } else {
        declareTx = await this.account.declare({
          contract,
          compiledClassHash: "0x0",
        });
      }

      // Wait for declaration to be confirmed (skip if already declared)
      if (declareTx.transaction_hash !== "0x0") {
        this.log(
          `Waiting for declaration transaction: ${declareTx.transaction_hash}...`,
          "info"
        );
        await this.provider.waitForTransaction(declareTx.transaction_hash);
      }

      // Now deploy the contract with explicit resource bounds
      this.log(`Deploying contract...`, "info");

      // Use default resource bounds with proper L1 gas and L1 data gas values
      const resourceBounds = this.getDefaultResourceBounds();

      const deployResponse = await this.account.deployContract(
        {
          classHash: declareTx.class_hash,
          constructorCalldata,
          salt: "0x0",
        },
        {
          resourceBounds,
          feeDataAvailabilityMode: "L1",
          accountDeploymentData: [],
          version: 3,
          nonceDataAvailabilityMode: "L1",
          tip: 0,
          paymasterData: [],
        }
      );

      // Wait for deployment to be confirmed
      this.log(
        `Waiting for deployment transaction: ${deployResponse.transaction_hash}...`,
        "info"
      );
      
      await this.provider.waitForTransaction(
        deployResponse.transaction_hash,
        { retryInterval: 1000 }
      );

      // Use the contract address from the deploy response
      const contractAddress = deployResponse.contract_address;

      this.log(
        `✓ Successfully deployed ERC20 token to address: ${contractAddress}`,
        "success"
      );
      this.log(`   Transaction hash: ${deployResponse.transaction_hash}`);
      this.log(`   Class hash: ${declareTx.class_hash}`);

      // Log deployment
      this.deploymentLog.push({
        contract: "sync-token",
        address: contractAddress,
        txHash: deployResponse.transaction_hash,
        timestamp: new Date().toISOString(),
        network: RPC_URL.includes("mainnet") ? "mainnet" : "testnet",
      });

      // Write deployment log to file
      fs.writeFileSync(
        path.join(DEPLOYMENT_LOG_DIR, "deployment_log.json"),
        JSON.stringify(this.deploymentLog, null, 2)
      );

      return contractAddress;
    } catch (error) {
      this.log(`✗ Failed to deploy ERC20 token: ${error}`, "error");
      throw error;
    }
  }

  public async deployContract(
    contractName: string,
    constructorCalldata: any[] = []
  ): Promise<string> {
    this.log(`Deploying ${contractName} contract...`);

    try {
      const { contract, casm } = await this.getCompiledContract(contractName);

      // First declare the contract
      let declareTx;
      if (casm) {
        // Calculate the compiled class hash from the CASM
        const compiledClassHash = hash.computeCompiledClassHash(casm);

        declareTx = await this.account.declare({
          contract,
          casm,
          compiledClassHash: compiledClassHash,
        });
      } else {
        declareTx = await this.account.declare({
          contract,
          compiledClassHash: "0x0",
        });
      }

      // Wait for declaration to be confirmed
      await this.provider.waitForTransaction(declareTx.transaction_hash);

      // Use default resource bounds
      const resourceBounds = this.getDefaultResourceBounds();

      const deployResponse = await this.account.deployContract(
        {
          classHash: declareTx.class_hash,
          constructorCalldata: constructorCalldata,
          salt: "0x0",
        },
        { resourceBounds }
      );

      await this.provider.waitForTransaction(deployResponse.transaction_hash);

      // Use the contract address from the deploy response
      const contractAddress = deployResponse.contract_address;

      this.log(
        `✓ Successfully deployed ${contractName} to address: ${contractAddress}`,
        "success"
      );
      this.log(`   Transaction hash: ${deployResponse.transaction_hash}`);

      // Log deployment
      this.deploymentLog.push({
        contract: contractName,
        address: contractAddress,
        txHash: deployResponse.transaction_hash,
        timestamp: new Date().toISOString(),
        network: RPC_URL.includes("mainnet") ? "mainnet" : "testnet",
      });

      // Write deployment log to file
      fs.writeFileSync(
        path.join(DEPLOYMENT_LOG_DIR, "deployment_log.json"),
        JSON.stringify(this.deploymentLog, null, 2)
      );

      return contractAddress;
    } catch (error) {
      this.log(`✗ Failed to deploy ${contractName}: ${error}`, "error");
      throw error;
    }
  }

  public async verifyContract(
    contractAddress: string,
    contractName: string
  ): Promise<void> {
    this.log(`Verifying ${contractName} at ${contractAddress}...`);

    try {
      // In a real implementation, you would call a verification service API here
      // For example, if using a service like Voyager or Starscan
      this.log("Contract verification would be implemented here", "warning");
      this.log(
        "Please verify the contract manually using a block explorer",
        "warning"
      );
    } catch (error) {
      this.log(`✗ Failed to verify ${contractName}: ${error}`, "error");
      throw error;
    }
  }
}

// Helper function to parse command line arguments
function parseArgs(args: string[]): Record<string, string> {
  const parsed: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--") && i + 1 < args.length) {
      const key = args[i].slice(2).replace(/-/g, "_");
      parsed[key] = args[++i];
    }
  }
  return parsed;
}

// Main function
async function main() {
  const args = process.argv.slice(2);
  const contractName = args[0];

  if (!contractName) {
    console.log("Usage: ts-node scripts/deploy.ts <contract-name> [options]");
    console.log("\nAvailable contracts:");
    console.log("  - sync-token");
    console.log("  - staking");
    console.log("  - liquidity-bridge");
    console.log("  - account-factory");
    console.log("\nExamples:");
    console.log('  # Deploy ERC20 Token:');
    console.log('  pnpm deploy:sync-token');
    console.log('  # Or with custom params:');
    console.log('  ts-node scripts/deploy.ts sync-token --name "MyToken" --symbol "MTK" --decimals 18');
    console.log('\n  # Deploy Staking Contract:');
    console.log('  ts-node scripts/deploy.ts staking --owner <address> --liquidity-bridge <address> --account-factory <address> --reward-treasury <address> --emergency-withdrawal-fee-bps 100');
    console.log('\n  # Deploy Liquidity Bridge:');
    console.log('  ts-node scripts/deploy.ts liquidity-bridge --admin <address> --pauser <address> --operator <address> --fee-receiver <address> --initial-swap-fee 300');
    console.log('\n  # Deploy Account Factory:');
    console.log('  ts-node scripts/deploy.ts account-factory --owner <address> --account-class-hash <hash> --liquidity-bridge <address> --default-fiat-currency "NGN"');
    process.exit(1);
  }

  const deployer = new Deployer();
  const parsedArgs = parseArgs(args.slice(1));
  const deployerAddress = process.env.DEPLOYER_ACCOUNT_ADDRESS || "";

  try {
    if (contractName === "sync-token") {
      // Parse ERC20 specific arguments
      const name = parsedArgs.name || "SyncToken";
      const symbol = parsedArgs.symbol || "sNGN";
      const decimals = parsedArgs.decimals ? parseInt(parsedArgs.decimals) : 2;
      const initialSupply = parsedArgs.initial_supply
        ? BigInt(parsedArgs.initial_supply)
        : BigInt(1000000);
      const recipient = parsedArgs.recipient || deployerAddress;
      const owner = parsedArgs.owner || deployerAddress;
      const pauser = parsedArgs.pauser || deployerAddress;
      const minter = parsedArgs.minter || deployerAddress;

      const address = await deployer.deployERC20Token(
        name,
        symbol,
        decimals,
        initialSupply,
        recipient,
        owner,
        pauser,
        minter
      );

      console.log(`\n✓ ERC20 Token Deployment Complete!`);
      console.log(`Contract: ${contractName}`);
      console.log(`Address: ${address}`);
      console.log(`Token Details: ${name} (${symbol}) - ${decimals} decimals`);
    } else if (contractName === "staking") {
      // Staking contract constructor: owner, liquidity_bridge, account_factory, reward_treasury, emergency_withdrawal_fee_bps
      const owner = parsedArgs.owner || deployerAddress;
      const liquidityBridge = parsedArgs.liquidity_bridge || deployerAddress;
      const accountFactory = parsedArgs.account_factory || deployerAddress;
      const rewardTreasury = parsedArgs.reward_treasury || deployerAddress;
      const emergencyWithdrawalFeeBps = parsedArgs.emergency_withdrawal_fee_bps
        ? parseInt(parsedArgs.emergency_withdrawal_fee_bps)
        : 100; // 1% default

      if (!owner || owner === deployerAddress) {
        console.warn("Warning: Using deployer address as owner. Consider setting --owner");
      }

      const constructorCalldata = [
        owner,
        liquidityBridge,
        accountFactory,
        rewardTreasury,
        emergencyWithdrawalFeeBps.toString(),
      ];

      const address = await deployer.deployContract(
        contractName,
        constructorCalldata
      );

      console.log(`\n✓ Staking Contract Deployment Complete!`);
      console.log(`Contract: ${contractName}`);
      console.log(`Address: ${address}`);
    } else if (contractName === "liquidity-bridge") {
      // Liquidity bridge constructor: admin, pauser, operator, fee_receiver, initial_swap_fee
      const admin = parsedArgs.admin || deployerAddress;
      const pauser = parsedArgs.pauser || deployerAddress;
      const operator = parsedArgs.operator || deployerAddress;
      const feeReceiver = parsedArgs.fee_receiver || deployerAddress;
      const initialSwapFee = parsedArgs.initial_swap_fee
        ? parsedArgs.initial_swap_fee
        : "300"; // 0.03% in basis points (300/10000)

      const constructorCalldata = [
        admin,
        pauser,
        operator,
        feeReceiver,
        initialSwapFee,
      ];

      const address = await deployer.deployContract(
        contractName,
        constructorCalldata
      );

      console.log(`\n✓ Liquidity Bridge Deployment Complete!`);
      console.log(`Contract: ${contractName}`);
      console.log(`Address: ${address}`);
    } else if (contractName === "account-factory") {
      // Account factory constructor: owner, account_class_hash, liquidity_bridge, default_fiat_currency
      const owner = parsedArgs.owner || deployerAddress;
      const accountClassHash = parsedArgs.account_class_hash;
      const liquidityBridge = parsedArgs.liquidity_bridge || deployerAddress;
      const defaultFiatCurrency = parsedArgs.default_fiat_currency || "NGN";

      if (!accountClassHash) {
        throw new Error(
          "account-class-hash is required. Deploy the account contract first and use its class hash."
        );
      }

      // Convert default_fiat_currency string to felt252 (shortString)
      const fiatCurrencyFelt = shortString.encodeShortString(defaultFiatCurrency);

      const constructorCalldata = [
        owner,
        accountClassHash,
        liquidityBridge,
        fiatCurrencyFelt,
      ];

      const address = await deployer.deployContract(
        contractName,
        constructorCalldata
      );

      console.log(`\n✓ Account Factory Deployment Complete!`);
      console.log(`Contract: ${contractName}`);
      console.log(`Address: ${address}`);
    } else {
      // Generic deployment for other contracts
      const constructorArgs = args.slice(1).filter(
        (arg) => !arg.startsWith("--")
      );

      const address = await deployer.deployContract(
        contractName,
        constructorArgs
      );

      console.log(`\n✓ Deployment Complete!`);
      console.log(`Contract: ${contractName}`);
      console.log(`Address: ${address}`);
    }

    console.log(`\nLog file: ${DEPLOYMENT_LOG}`);
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

// Run the main function
main().catch(console.error);
