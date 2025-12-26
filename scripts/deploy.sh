#!/bin/bash

# Exit on error
set -e

# Load environment variables
if [ -f "../.env" ]; then
    export $(grep -v '^#' ../.env | xargs)
fi

# Default values
RPC_URL=${STARKNET_RPC_URL:-"https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/5QQMV6kqa3iDaH_EbNhTw"}
DEPLOYMENT_LOG="${DEPLOYMENT_LOG:-deployment_logs/$(date +%Y%m%d_%H%M%S).log}"

# Create deployment logs directory if it doesn't exist
mkdir -p "$(dirname "$DEPLOYMENT_LOG")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Package configurations
declare -A PACKAGE_PATHS
PACKAGE_PATHS[account-factory]="packages/account"
PACKAGE_PATHS[liquidity-bridge]="packages/liquidity-bridge"
PACKAGE_PATHS[sync-token]="packages/erc20"
PACKAGE_PATHS[staking]="packages/staking"

# Package names for different packages
declare -A PACKAGE_NAMES
PACKAGE_NAMES[account]="sync_account"
PACKAGE_NAMES[account-factory]="sync_account"
PACKAGE_NAMES[liquidity-bridge]="liquidity_bridge"
PACKAGE_NAMES[sync-token]="erc20"
PACKAGE_NAMES[staking]="farming"

# Contract names for different packages
declare -A CONTRACT_NAMES
CONTRACT_NAMES[account]="sync_account"
CONTRACT_NAMES[account-factory]="sync_account"
CONTRACT_NAMES[liquidity-bridge]="liquidity_bridge"
CONTRACT_NAMES[sync-token]="SyncERC20"
CONTRACT_NAMES[staking]="SyncStaking"

# Default package name for unknown contracts
DEFAULT_PACKAGE="isyncpayment"
DEFAULT_PACKAGE_PATH="."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Contract configurations with proper constructor arguments
declare -A CONTRACTS
# Format: "ContractFileName [constructor_args...]"
# Account Factory: owner, account_class_hash, liquidity_bridge, default_fiat_currency
CONTRACTS[account-factory]="account_factory \\
    0x00af7426c058322f65f99d991c023a0abbc082d0d67796f1999cea5f396dac71 \\
    0x0715b9c5434bdb216bca48c2162ec745def13bfc35df70b1be688d05c14ad4b0 \\
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27"

# Liquidity Bridge: admin, operator, fee_receiver, fee_bps, token_decimals, 
# token_address, token_decimals, token_symbol, token_name
CONTRACTS[liquidity-bridge]="liquidityBridge \\
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
    1000 \\
    0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a \\
    2 \\
    0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d \\
    2 \\
    0x4554482f555344 \\
    0x5354524b2f555344"

# Sync Token: name, symbol, decimals, initial_supply, recipient, owner, pauser, minter
CONTRACTS[sync-token]="ERC20 \
    'Sync Token' \
    'SYNC' \
    18 \
    1000000000000000000000000000 \
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27"

# Staking: owner, liquidity_bridge, reward_treasury, admin, emergency_withdrawal_fee_bps
CONTRACTS[staking]="farming \\
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
{{ ... }}
    0x079d34f36f135f787af3a0fc2556613b22f1bd4da15378ccf71b5dbb1cae5022 \\
    0x04e6a49ed6a43811b443778f129d632a752c633f6e1535c2fd15aa887263e8a9 \\
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
    1000"

# Account: owner, liquidity_bridge, staking_contract
CONTRACTS[account]="account \\
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \\
    0x4c73687f23639fdf8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27"

# Function to print usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  declare <contract>    Declare a contract"
    echo "  deploy <contract>     Deploy a contract"
    echo "  list                  List all available contracts"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  --rpc <url>          Custom RPC URL (default: $RPC_URL)"
    echo "  --log <file>         Log deployment details to file (default: $DEPLOYMENT_LOG)"
    echo ""
    echo "Available contracts:"
    for contract in "${!CONTRACTS[@]}"; do
        echo "  - $contract"
    done
    echo ""
    echo "Examples:"
    echo "  # Deploy sync-token (erc20) using a custom mainnet RPC URL"
    echo "  $0 --rpc https://your-mainnet-rpc deploy sync-token"
    echo ""
    exit 1
}

# Function to list all available contracts
list_contracts() {
    echo -e "${GREEN}Available contracts:${NC}"
    for contract in "${!CONTRACTS[@]}"; do
        echo "- $contract"
    done
}

# Function to log deployment details
log_deployment() {
    local contract=$1
    local contract_address=$2
    local tx_hash=$3
    local class_hash=$4
    local constructor_args=$5
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create a JSON entry for the deployment
    local log_entry="{\
        \"contract\": \"$contract\",\n        \"address\": \"$contract_address\",\n        \"tx_hash\": \"$tx_hash\",\n        \"class_hash\": \"$class_hash\",\n        \"timestamp\": \"$timestamp\",\n        \"network\": \"${RPC_URL}\",\n        \"constructor_args\": $constructor_args\n    }"
    
    # Append to deployment log
    if [ ! -f "$DEPLOYMENT_LOG" ]; then
        echo "[" > "$DEPLOYMENT_LOG"
        echo "$log_entry" >> "$DEPLOYMENT_LOG"
    else
        # Remove the last ']' and add a comma and the new entry
        sed -i '$ d' "$DEPLOYMENT_LOG"
        echo "," >> "$DEPLOYMENT_LOG"
        echo "$log_entry" >> "$DEPLOYMENT_LOG"
    fi
    
    # Close the JSON array
    echo "]" >> "$DEPLOYMENT_LOG"
    
    # Pretty print the JSON
    local temp_file=$(mktemp)
    jq . "$DEPLOYMENT_LOG" > "$temp_file" && mv "$temp_file" "$DEPLOYMENT_LOG"
    
    echo -e "${GREEN}Deployment logged to $DEPLOYMENT_LOG${NC}"
}

# Function to declare a contract
declare_contract() {
    local contract_name=$1
    local contract_config=(${CONTRACTS[$contract_name]})
    
    if [ -z "$contract_config" ]; then
        echo -e "${RED}Error: Unknown contract '$contract_name'${NC}"
        list_contracts
        exit 1
    fi

    local contract_file="${contract_config[0]}"
    local package_name="${PACKAGE_NAMES[$contract_name]:-$DEFAULT_PACKAGE}"
    local contract_name_in_source="${CONTRACT_NAMES[$contract_name]}"
    local package_path="${PACKAGE_PATHS[$contract_name]:-$DEFAULT_PACKAGE_PATH}"
    
    echo -e "${YELLOW}Declaring $contract_name from package $package_name in $package_path...${NC}"
    
    # Save current directory and change to package directory
    local original_dir=$(pwd)
    cd "$SCRIPT_DIR/../$package_path" || { echo -e "${RED}Error: Could not change to package directory $package_path${NC}"; exit 1; }
    
    # Build the package first to ensure artifacts are generated
    echo -e "${YELLOW}Building package $package_name...${NC}"
    scarb build || { 
        echo -e "${RED}Error: Failed to build package $package_name${NC}"
        cd "$original_dir"
        exit 1
    }
    
    # Run the declare command with the contract name and package
    echo -e "${YELLOW}Running: sncast declare --url $RPC_URL --contract-name $contract_name_in_source --package $package_name${NC}"
    
    local declare_output
    if ! declare_output=$(sncast declare --url "$RPC_URL" \
        --contract-name "$contract_name_in_source" \
        --package "$package_name" 2>&1); then
        echo -e "${RED}Error: sncast declare failed for $contract_name${NC}"
        echo "$declare_output"
        cd "$original_dir"
        exit 1
    fi
    
    # Display the raw output for debugging
    echo -e "${YELLOW}Declaration output:${NC}\n$declare_output"

    # Parse the text output to get class hash and transaction hash
    local class_hash=$(echo "$declare_output" | grep -oP 'Class hash: \K0x[0-9a-fA-F]+' || true)
    local tx_hash=$(echo "$declare_output" | grep -oP 'Transaction hash: \K0x[0-9a-fA-F]+' || true)
    
    if [ -z "$class_hash" ]; then
        echo -e "${RED}Error: Failed to extract class hash from declaration${NC}"
        echo "$declare_output"
        cd "$original_dir"
        exit 1
    fi
    
    echo -e "${GREEN}Successfully declared $contract_name${NC}"
    echo "  Class Hash: $class_hash"
    echo "  TX Hash: $tx_hash"
    
    # Log the declaration
    log_deployment "$contract_name-declaration" "" "$tx_hash" "$class_hash" "null"
    
    # Wait for transaction to be confirmed
    echo -e "${YELLOW}Waiting for transaction to be confirmed...${NC}"
    sncast --url "$RPC_URL" tx_status --hash "$tx_hash" --wait
    
    # Return the class hash
    echo "$class_hash"

    # Change back to original directory
    cd "$original_dir"
}

# Function to deploy a contract
deploy_contract() {
    local contract_name=$1
    # Load contract configuration
    local contract_config=(${CONTRACTS[$contract_name]})
    
    if [ -z "$contract_config" ]; then
        echo -e "${RED}Error: Unknown contract '$contract_name'${NC}"
        list_contracts
        exit 1
    fi

    local contract_file="${contract_config[0]}"
    local constructor_args=("${contract_config[@]:1}")
    
    echo -e "${YELLOW}Deploying $contract_name...${NC}"
    
    # First declare the contract and capture the class hash
    local class_hash
    class_hash=$(declare_contract "$contract_name")
    
    if [ -z "$class_hash" ]; then
        echo -e "${RED}Error: Failed to get class hash for $contract_name${NC}"
        exit 1
    fi
    
    # Then deploy with constructor arguments if any
    echo -e "${YELLOW}Deploying $contract_name with class hash $class_hash...${NC}"
    echo -e "  Constructor args: ${constructor_args[*]}"
    
    local deploy_output
    echo -e "${YELLOW}Deploying contract with class hash: $class_hash${NC}"
    
    if [ ${#constructor_args[@]} -gt 0 ]; then
        echo -e "${YELLOW}With constructor arguments: ${constructor_args[*]}${NC}"
        if ! deploy_output=$(sncast deploy --url "$RPC_URL" \
            --class-hash "$class_hash" \
            --constructor-args "${constructor_args[@]}" 2>&1); then
            echo -e "${RED}Error: Failed to deploy $contract_name${NC}"
            echo "$deploy_output"
            exit 1
        fi
    else
        if ! deploy_output=$(sncast deploy --url "$RPC_URL" \
            --class-hash "$class_hash" 2>&1); then
            echo -e "${RED}Error: Failed to deploy $contract_name${NC}"
            echo "$deploy_output"
            exit 1
        fi
    fi
    
    # Display the raw output for debugging
    echo -e "${YELLOW}Deployment output:${NC}\n$deploy_output"
    
    # Parse the text output to get contract address and transaction hash
    local contract_address=$(echo "$deploy_output" | grep -oP 'Contract address: \K0x[0-9a-fA-F]+' || true)
    local tx_hash=$(echo "$deploy_output" | grep -oP 'Transaction hash: \K0x[0-9a-fA-F]+' || true)
    
    if [ -z "$contract_address" ] || [ -z "$tx_hash" ]; then
        echo -e "${RED}Error: Failed to extract contract address or transaction hash${NC}"
        echo "$deploy_output"
        exit 1
    fi
    
    echo -e "${GREEN}Successfully deployed $contract_name${NC}"
    echo "  Contract: $contract_file"
    echo "  Class Hash: $class_hash"
    echo "  Address: $contract_address"
    echo "  TX Hash: $tx_hash"
    
    # Format constructor args as JSON array for logging
    local json_args=$(printf '%s\n' "${constructor_args[@]}" | jq -R . | jq -s .)
    
    # Log the deployment
    log_deployment "$contract_name" "$contract_address" "$tx_hash" "$class_hash" "$json_args"
    
    # Wait for transaction to be confirmed
    echo -e "${YELLOW}Waiting for transaction to be confirmed...${NC}"
    sncast --url "$RPC_URL" tx_status --hash "$tx_hash" --wait
}

# Main execution
main() {
    # Check for required dependencies
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' is required but not installed. Please install jq.${NC}"
        exit 1
    fi

    if ! command -v sncast &> /dev/null; then
        echo -e "${RED}Error: 'sncast' is required but not installed. Install via 'cargo install sncast'.${NC}"
        exit 1
    fi

    if ! command -v scarb &> /dev/null; then
        echo -e "${YELLOW}Warning: 'scarb' not found. Builds may fail. Install scarb if needed.${NC}"
    fi

    # Parse command line arguments
    local command=""
    local contract=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --rpc)
                RPC_URL="$2"
                shift 2
                ;;
            --log)
                DEPLOYMENT_LOG="$2"
                mkdir -p "$(dirname "$DEPLOYMENT_LOG")"
                shift 2
                ;;
            declare|deploy|list)
                if [ -z "$command" ]; then
                    command="$1"
                    if [ "$1" != "list" ]; then
                        contract="$2"
                        shift 1
                    fi
                    shift 1
                else
                    echo -e "${RED}Error: Multiple commands specified${NC}"
                    usage
                fi
                ;;
            *)
                if [ -z "$contract" ] && [ -n "$command" ] && [ "$command" != "list" ]; then
                    contract="$1"
                    shift 1
                else
                    echo -e "${RED}Unknown option: $1${NC}"
                    usage
                fi
                ;;
        esac
    done

    # Execute the command
    case $command in
        list)
            list_contracts
            ;;
        declare)
            if [ -z "$contract" ]; then
                echo -e "${RED}Error: Contract name is required${NC}"
                usage
            fi
            declare_contract "$contract"
            ;;
        deploy)
            if [ -z "$contract" ]; then
                echo -e "${RED}Error: Contract name is required${NC}"
                usage
            fi
            deploy_contract "$contract"
            ;;
        *)
            echo -e "${RED}Error: No command specified${NC}"
            usage
            ;;
    esac
}

# Run the main function
main "$@"
