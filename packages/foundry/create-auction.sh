#!/bin/bash

# Script to advance anvil chain timestamp past auction end time
# Usage: ./advance-time.sh [optional_timestamp]

RPC_URL="http://localhost:8545"

# Get AuctionVault address from deployment
AUCTION_VAULT_ADDRESS=$(jq -r '.transactions[1].contractAddress' broadcast/Deploy.s.sol/31337/run-latest.json)
echo "📍 AuctionVault address: $AUCTION_VAULT_ADDRESS"

echo "🔗 Running CreateAuction script..."

# Run the CloseAuction script
forge script script/CreateAuction.s.sol --rpc-url $RPC_URL --broadcast

echo "🎉 Auction created successfully!"
