import * as childProcess from 'child_process';
import * as path from 'path';
import * as dotenv from 'dotenv';
import * as fs from 'fs';

// Load environment variables
dotenv.config();

// Configuration
const RPC_URL = process.env.STARKNET_RPC_URL ||
    "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw";
const DEPLOYER_ACCOUNT = process.env.DEPLOYER_ACCOUNT || "caxtonstone1";
const NETWORK = process.env.STARKNET_NETWORK || "sepolia";
const VERIFIER = process.env.VERIFIER || "walnut";
const DEPLOYMENT_LOG_DIR = "deployment_logs";
const DEPLOYMENT_LOG = path.join(
    DEPLOYMENT_LOG_DIR,
    `deploy_sncast_${new Date().toISOString().replace(/[:.]/g, "-")}.log`
);

// Contract configurations
const CONTRACTS = {
    erc20: {
        name: "SyncERC20",
        path: "packages/erc20",
        constructorArgs: (params: any) => [
            // name (ByteArray)
            `0x${Buffer.from(params.name).toString('hex')}`,
            // symbol (ByteArray)
            `0x${Buffer.from(params.symbol).toString('hex')}`,
            // decimals (u8)
            params.decimals.toString(),
            // initial_supply (u256) - split into low and high
            (params.initialSupply & 0xFFFFFFFFFFFFFFFFn).toString(),
            ((params.initialSupply >> 64n) & 0xFFFFFFFFFFFFFFFFn).toString(),
            // recipient (ContractAddress)
            params.recipient || "0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88",
            // owner (ContractAddress)
            params.owner || "0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88",
            // pauser (ContractAddress)
            params.pauser || "0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88",
            // minter (ContractAddress)
            params.minter || "0x0456e6d7184cd79e3f5cc63397a5540e8aeef7fd2f136136dfd40caf122cba88"
        ]
    }
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
    classHash?: string;
    address?: string;
    txHash?: string;
    timestamp: string;
    network: string;
    status: 'success' | 'failed';
    error?: string;
}

class SncastDeployer {
    private deploymentLog: DeploymentLog[] = [];
    private account: string;
    public network: string;
    private verifier: string;
    private rpcUrl: string;
    private contractStates: Record<string, {
        classHash?: string;
        address?: string;
    }> = {};

    constructor(options: {
        account?: string;
        network?: string;
        verifier?: string;
        rpcUrl?: string;
    } = {}) {
        this.account = options.account || DEPLOYER_ACCOUNT;
        this.network = options.network || NETWORK;
        this.verifier = options.verifier || VERIFIER;
        this.rpcUrl = options.rpcUrl || RPC_URL;

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

    private async executeCommand(command: string, cwd?: string): Promise<{ stdout: string, stderr: string }> {
        return new Promise((resolve, reject) => {
            this.log(`Executing: ${command}`, 'info');

            const child = childProcess.exec(command, { cwd }, (error, stdout, stderr) => {
                if (error) {
                    this.log(`Command failed: ${error.message}`, 'error');
                    this.log(`Stderr: ${stderr}`, 'error');
                    reject({ error, stdout, stderr });
                } else {
                    resolve({ stdout, stderr });
                }
            });

            // Stream output in real-time
            child.stdout?.on('data', (data) => {
                process.stdout.write(data);
            });

            child.stderr?.on('data', (data) => {
                process.stderr.write(data);
            });
        });
    }

    private extractClassHash(output: string): string | null {
        const match = output.match(/Class Hash:\s*(0x[0-9a-fA-F]+)/);
        return match ? match[1] : null;
    }

    private extractContractAddress(output: string): string | null {
        const match = output.match(/Contract Address:\s*(0x[0-9a-fA-F]+)/);
        return match ? match[1] : null;
    }

    private extractTxHash(output: string): string | null {
        const match = output.match(/Transaction Hash:\s*(0x[0-9a-fA-F]+)/);
        return match ? match[1] : null;
    }

    public async declareContract(contractName: string): Promise<string> {
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];
        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        const logEntry: DeploymentLog = {
            contract: contractName,
            timestamp: new Date().toISOString(),
            network: this.network,
            status: 'failed'
        };

        try {
            this.log(`Declaring ${contractName} contract...`);

            const { stdout } = await this.executeCommand(
                `sncast --account ${this.account} --network ${this.network} --url ${this.rpcUrl} ` +
                `declare --contract-name ${contractConfig.name}`,
                contractConfig.path
            );

            const classHash = this.extractClassHash(stdout);
            const txHash = this.extractTxHash(stdout);

            if (!classHash) {
                throw new Error('Failed to extract class hash from output');
            }

            this.log(`✓ Successfully declared ${contractName} with class hash: ${classHash}`, 'success');
            if (txHash) {
                this.log(`   Transaction hash: ${txHash}`);
            }

            // Update state
            this.contractStates[contractName] = {
                ...this.contractStates[contractName],
                classHash
            };

            // Update log entry
            logEntry.status = 'success';
            logEntry.classHash = classHash;
            if (txHash) logEntry.txHash = txHash;

            return classHash;
        } catch (error: any) {
            const errorMsg = error.stderr || error.message || 'Unknown error';
            this.log(`✗ Failed to declare ${contractName}: ${errorMsg}`, 'error');
            logEntry.error = errorMsg;
            throw error;
        } finally {
            this.deploymentLog.push(logEntry);
        }
    }

    public async deployContract(
        contractName: string,
        constructorArgs: any[] = []
    ): Promise<string> {
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];
        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        const logEntry: DeploymentLog = {
            contract: contractName,
            timestamp: new Date().toISOString(),
            network: this.network,
            status: 'failed'
        };

        try {
            // Ensure the contract is declared first
            const classHash = this.contractStates[contractName]?.classHash ||
                await this.declareContract(contractName);

            this.log(`Deploying ${contractName} contract...`);

            // Format constructor arguments for the command line
            const argsString = constructorArgs.map(arg => `"${arg}"`).join(' ');

            const { stdout } = await this.executeCommand(
                `sncast --account ${this.account} --network ${this.network} --url ${this.rpcUrl} ` +
                `deploy --class-hash ${classHash} ` +
                `--constructor-calldata ${argsString}`,
                contractConfig.path
            );

            const contractAddress = this.extractContractAddress(stdout);
            const txHash = this.extractTxHash(stdout);

            if (!contractAddress) {
                throw new Error('Failed to extract contract address from output');
            }

            this.log(`✓ Successfully deployed ${contractName} at address: ${contractAddress}`, 'success');
            if (txHash) {
                this.log(`   Transaction hash: ${txHash}`);
            }

            // Update state
            this.contractStates[contractName] = {
                ...this.contractStates[contractName],
                address: contractAddress
            };

            // Update log entry
            logEntry.status = 'success';
            logEntry.address = contractAddress;
            if (txHash) logEntry.txHash = txHash;
            if (classHash) logEntry.classHash = classHash;

            return contractAddress;
        } catch (error: any) {
            const errorMsg = error.stderr || error.message || 'Unknown error';
            this.log(`✗ Failed to deploy ${contractName}: ${errorMsg}`, 'error');
            logEntry.error = errorMsg;
            throw error;
        } finally {
            this.deploymentLog.push(logEntry);
        }
    }

    public async verifyContract(
        contractName: string,
        contractAddress: string
    ): Promise<void> {
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];
        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        const logEntry: DeploymentLog = {
            contract: contractName,
            address: contractAddress,
            timestamp: new Date().toISOString(),
            network: this.network,
            status: 'failed'
        };

        try {
            this.log(`Verifying ${contractName} at ${contractAddress}...`);

            // First, build the contract to ensure we have the latest version
            await this.executeCommand('scarb build', contractConfig.path);

            // Run the verification
            const { stdout } = await this.executeCommand(
                `sncast --account ${this.account} --network ${this.network} --url ${this.rpcUrl} ` +
                `verify --contract-name ${contractConfig.name} ` +
                `--contract-address ${contractAddress} ` +
                `--verifier ${this.verifier}`,
                contractConfig.path
            );

            this.log(`✓ Successfully verified ${contractName} on ${this.verifier}`, 'success');

            // Try to extract verification URL from output
            const urlMatch = stdout.match(/https?:\/\/[^\s]+/);
            if (urlMatch) {
                this.log(`   Verification URL: ${urlMatch[0]}`);
            }

            // Update log entry
            logEntry.status = 'success';
        } catch (error: any) {
            const errorMsg = error.stderr || error.message || 'Unknown error';
            this.log(`✗ Failed to verify ${contractName}: ${errorMsg}`, 'error');
            logEntry.error = errorMsg;
            throw error;
        } finally {
            this.deploymentLog.push(logEntry);
        }
    }

    public async deployERC20Token(params: {
        name: string;
        symbol: string;
        decimals: number;
        initialSupply?: bigint;
        recipient?: string;
        owner?: string;
        pauser?: string;
        minter?: string;
    }): Promise<{
        classHash: string;
        address: string;
        txHash?: string;
    }> {
        const contractName = 'erc20';
        const contractConfig = CONTRACTS[contractName as keyof typeof CONTRACTS];

        if (!contractConfig) {
            throw new Error(`No configuration found for contract: ${contractName}`);
        }

        // Set default values
        const initialSupply = params.initialSupply || 1000000n;

        // Generate constructor arguments
        const constructorArgs = contractConfig.constructorArgs({
            ...params,
            initialSupply
        });

        this.log(`Deploying ERC20 Token: ${params.name} (${params.symbol})...`);
        this.log(`  Decimals: ${params.decimals}`);
        this.log(`  Initial Supply: ${initialSupply.toString()}`);
        this.log(`  Recipient: ${params.recipient || 'Deployer'}`);
        this.log(`  Owner: ${params.owner || 'Deployer'}`);
        this.log(`  Pauser: ${params.pauser || 'Deployer'}`);
        this.log(`  Minter: ${params.minter || 'Deployer'}`);

        // Deploy the contract
        const address = await this.deployContract(contractName, constructorArgs);

        // Verify the contract
        try {
            await this.verifyContract(contractName, address);
        } catch (error) {
            this.log('Warning: Contract deployment succeeded but verification failed', 'warning');
            this.log('You can try verifying manually with:', 'warning');
            this.log(`  cd ${contractConfig.path} && sncast --account ${this.account} --network ${this.network} --url ${this.rpcUrl} verify --contract-name ${contractConfig.name} --contract-address ${address} --verifier ${this.verifier}`, 'info');
        }

        return {
            classHash: this.contractStates[contractName]?.classHash || '',
            address,
            txHash: this.deploymentLog.find(
                log => log.contract === contractName && log.status === 'success' && log.txHash
            )?.txHash
        };
    }

    public getDeploymentLogs(): DeploymentLog[] {
        return [...this.deploymentLog];
    }

    public saveDeploymentLogs(filePath: string = DEPLOYMENT_LOG): void {
        const logContent = JSON.stringify(this.deploymentLog, null, 2);
        fs.writeFileSync(filePath, logContent);
        this.log(`Deployment logs saved to: ${filePath}`, 'success');
    }
}

// Helper function to parse command line arguments
function parseArgs(args: string[]): Record<string, string> {
    const result: Record<string, string> = {};

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg.startsWith('--')) {
            const key = arg.slice(2);
            const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : 'true';
            result[key] = value;
        }
    }

    return result;
}

// Main function
async function main() {
    const args = parseArgs(process.argv.slice(2));

    const deployer = new SncastDeployer({
        account: args.account,
        network: args.network,
        verifier: args.verifier,
        rpcUrl: args.rpcUrl
    });

    try {
        // Example: Deploy an ERC20 token
        if (args.token) {
            const tokenParams = {
                name: args.name || 'SyncToken',
                symbol: args.symbol || 'SYNC',
                decimals: parseInt(args.decimals || '18'),
                initialSupply: args.supply ? BigInt(args.supply) : undefined,
                recipient: args.recipient,
                owner: args.owner,
                pauser: args.pauser,
                minter: args.minter
            };

            const result = await deployer.deployERC20Token(tokenParams);
            console.log('\nDeployment successful!');
            console.log('====================');
            console.log(`Contract: ${tokenParams.name} (${tokenParams.symbol})`);
            console.log(`Address: ${result.address}`);
            if (result.txHash) {
                console.log(`Transaction: https://${deployer.network}.starkscan.co/tx/${result.txHash}`);
            }
            console.log(`Class Hash: ${result.classHash}`);
            console.log('====================\n');
        }

        // Save deployment logs
        deployer.saveDeploymentLogs();

    } catch (error) {
        console.error('\nDeployment failed:', error);
        // Save logs even if deployment fails
        deployer.saveDeploymentLogs();
        process.exit(1);
    }
}

// Run the main function if this file is executed directly
if (require.main === module) {
    main().catch(console.error);
}

export { SncastDeployer };


// npx ts - node scripts / deployWithSncast.ts--token

// npx ts - node scripts / deployWithSncast.ts--token \
// --name "MyToken" \
// --symbol "MTK" \
// --decimals 18 \
// --supply "1000000000000000000000000" \
// --recipient "0x123..." \
// --owner "0x123..." \
// --pauser "0x123..." \
// --minter "0x123..."

