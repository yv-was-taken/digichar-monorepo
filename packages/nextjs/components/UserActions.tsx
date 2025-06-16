"use client";

import { useState } from "react";
import { Button } from "./ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

export const UserActions: React.FC = () => {
  const { address: connectedAddress } = useAccount();
  const [isLoading, setIsLoading] = useState<{ [key: string]: boolean }>({});

  // Read current auction ID to determine past auctions
  const { data: currentAuctionId } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctionId",
  });

  // Write contract hooks
  const { writeContractAsync: writeClaimTokens } = useScaffoldWriteContract({
    contractName: "AuctionVault",
  });

  const { writeContractAsync: writeWithdrawBid } = useScaffoldWriteContract({
    contractName: "AuctionVault",
  });

  // Check unclaimed tokens for a specific auction
  const { data: unclaimedTokens } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "checkUnclaimedTokens",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: connectedAddress && currentAuctionId ? [connectedAddress, currentAuctionId - 1n] : undefined,
  });

  const handleClaimTokens = async (auctionId: number): Promise<void> => {
    if (!connectedAddress) {
      alert("Please connect your wallet to claim tokens");
      return;
    }

    setIsLoading(prev => ({ ...prev, [`claim-${auctionId}`]: true }));

    try {
      await writeClaimTokens({
        functionName: "claimTokens",
        args: [BigInt(auctionId)],
      });
    } catch (error) {
      console.error("Error claiming tokens:", error);
    } finally {
      setIsLoading(prev => ({ ...prev, [`claim-${auctionId}`]: false }));
    }
  };

  /* eslint-disable  */
  const handleWithdrawBid = async (auctionId: number, characterIndex: number, amount: string): Promise<void> => {
    if (!connectedAddress) {
      alert("Please connect your wallet to withdraw bids");
      return;
    }

    setIsLoading(prev => ({ ...prev, [`withdraw-${auctionId}-${characterIndex}`]: true }));

    try {
      await writeWithdrawBid({
        functionName: "withdrawBid",
        args: [BigInt(auctionId), characterIndex, BigInt(amount)],
      });
    } catch (error) {
      console.error("Error withdrawing bid:", error);
    } finally {
      setIsLoading(prev => ({ ...prev, [`withdraw-${auctionId}-${characterIndex}`]: false }));
    }
  };
  /* eslint-enable */

  if (!connectedAddress) {
    return null; // Don't show user actions if wallet not connected
  }

  const hasUnclaimedTokens = Boolean(unclaimedTokens && unclaimedTokens > 0n);
  const previousAuctionId = currentAuctionId && currentAuctionId > 1n ? Number(currentAuctionId) - 1 : null;

  return (
    <div className="space-y-4">
      {/* Claim Tokens Section */}
      {hasUnclaimedTokens && previousAuctionId && (
        <Card className="border-green-600">
          <CardHeader>
            <CardTitle className="text-green-500 flex items-center space-x-2">
              <span>🎉</span>
              <span>Unclaimed Tokens Available</span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-gray-300">
              <p>
                You have <span className="text-green-500 font-bold">{formatEther(unclaimedTokens || 0n)} tokens</span>{" "}
                to claim from Auction #{previousAuctionId}
              </p>
            </div>
            <Button
              onClick={() => handleClaimTokens(previousAuctionId)}
              disabled={isLoading[`claim-${previousAuctionId}`]}
              variant="success"
              className="w-full"
            >
              {isLoading[`claim-${previousAuctionId}`] ? "Claiming..." : "Claim Tokens"}
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Quick Actions */}
      <Card className="border-red-600">
        <CardHeader>
          <CardTitle className="text-red-500">Quick Actions</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button
            onClick={() => {
              // This would open a modal or navigate to a detailed view
              // For now, we'll just alert
              alert("Feature coming soon: View all your bid history and claimable tokens");
            }}
            variant="outline"
            className="w-full"
          >
            View All My Bids
          </Button>

          <Button
            onClick={() => {
              alert("Feature coming soon: Bulk claim all available tokens");
            }}
            variant="outline"
            className="w-full"
          >
            Claim All Available Tokens
          </Button>

          <Button
            onClick={() => {
              alert("Feature coming soon: Withdraw all non-winning bids");
            }}
            variant="outline"
            className="w-full"
          >
            Withdraw All Failed Bids
          </Button>
        </CardContent>
      </Card>

      {/* Instructions */}
      <Card className="border-gray-600">
        <CardHeader>
          <CardTitle className="text-gray-400">Instructions</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-gray-400 space-y-2">
          <p>
            • <strong>Claim Tokens:</strong> Receive your share of character tokens from winning auctions
          </p>
          <p>
            • <strong>Withdraw Bids:</strong> Get back your ETH from unsuccessful character bids
          </p>
          <p>
            • <strong>Check Regularly:</strong> New tokens become claimable after each auction ends
          </p>
        </CardContent>
      </Card>
    </div>
  );
};
