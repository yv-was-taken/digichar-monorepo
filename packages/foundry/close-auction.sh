#!/bin/bash

# Script to advance anvil chain timestamp past auction end time
# Usage: ./advance-time.sh [optional_timestamp]

RPC_URL="http://localhost:8545"

echo "🕒 Advancing Anvil chain timestamp..."

# Get AuctionVault address from deployment
AUCTION_VAULT_ADDRESS=$(jq -r '.transactions[1].contractAddress' broadcast/Deploy.s.sol/31337/run-latest.json)
echo "📍 AuctionVault address: $AUCTION_VAULT_ADDRESS"

# Get current auction end time
AUCTION_END_TIME_HEX=$(cast call $AUCTION_VAULT_ADDRESS "getCurrentAuctionEndTime()" --rpc-url $RPC_URL)
AUCTION_END_TIME=$(cast to-dec $AUCTION_END_TIME_HEX)
echo "⏰ Current auction end time: $AUCTION_END_TIME"

# Calculate new timestamp (1 second after auction ends, or use provided timestamp)
if [ -z "$1" ]; then
    NEW_TIMESTAMP=$((AUCTION_END_TIME + 1))
    echo "🎯 Setting timestamp to: $NEW_TIMESTAMP (1 second after auction end)"
else
    NEW_TIMESTAMP=$1
    echo "🎯 Setting timestamp to: $NEW_TIMESTAMP (custom timestamp)"
fi

# Set the new timestamp and mine a block
echo "⛏️  Setting next block timestamp and mining..."
cast rpc anvil_setNextBlockTimestamp $NEW_TIMESTAMP --rpc-url $RPC_URL > /dev/null
cast rpc anvil_mine 1 --rpc-url $RPC_URL > /dev/null

echo "✅ Timestamp advanced successfully!"
echo "🔗 Running CloseAuction script..."

# Run the CloseAuction script
if forge script script/CloseAuction.s.sol --rpc-url $RPC_URL --broadcast; then
    echo "🎉 Auction closed successfully!"
else
    echo "❌ Failed to close auction. Please check the error messages above."
    exit 1
fi
