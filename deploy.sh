#!/bin/bash

# Check if the network argument is provided
if [ -z "$1" ]; then
    echo "Please provide a network (e.g., sepolia, mainnet)"
    exit 1
fi

NETWORK=$1

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
    export ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY
    export RPC_URL=$ETH_RPC_URL
    export ACCOUNT_NAME=$ACCOUNT_NAME
else
    echo ".env file not found"
    exit 1
fi

# Verify required environment variables are set
required_vars=(
    "ACCOUNT_NAME"
    "TREASURY_ADDRESS"
    "PARENT_NODE"
    "BASE_PRICE"
    "ETHERSCAN_API_KEY"
)


for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env file"
        exit 1
    fi
done

# Retrieve wallet address
SENDER_ADDRESS=$(cast wallet address --account "$ACCOUNT_NAME")

# Run the deployment script
echo "Deploying to $NETWORK..."
forge script script/deploy.s.sol:DeployPNS \
    --rpc-url $RPC_URL \
    --account $ACCOUNT_NAME \
    --sender $SENDER_ADDRESS \
    --broadcast \
    --verify \
    -vvvv

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo "Deployment completed successfully!"
else
    echo "Deployment failed!"
    exit 1
fi