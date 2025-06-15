"use client";

import Image from "next/image";
import type { NextPage } from "next";
import { formatEther } from "viem";
import { Address } from "~~/components/scaffold-eth";
import { Button } from "~~/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "~~/components/ui/card";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";

interface PastAuctionItemProps {
  auctionId: number;
  auction: any;
  onViewToken: (auctionId: number) => void;
}

const PastAuctionItem: React.FC<PastAuctionItemProps> = ({ auctionId, auction, onViewToken }) => {
  const winningCharacter = auction?.characters?.find((char: any) => char.isWinner);

  // Get token address for this auction
  const { data: tokenAddress } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    args: [BigInt(auctionId)],
  });

  return (
    <Card className="border-gray-700 hover:border-red-600 transition-colors">
      <CardHeader>
        <CardTitle className="flex justify-between items-center">
          <span className="text-white">Auction #{auctionId}</span>
          <span className="text-sm text-gray-400">
            Ended {new Date(Number(auction?.endTime || 0) * 1000).toLocaleDateString()}
          </span>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {winningCharacter ? (
          <div className="space-y-3">
            <div className="flex items-center space-x-4">
              <div className="relative w-16 h-16 bg-gray-800 rounded-lg flex items-center justify-center">
                {winningCharacter.characterURI ? (
                  <Image
                    src={winningCharacter.characterURI}
                    alt={winningCharacter.name}
                    fill
                    className="object-cover rounded-lg"
                    onError={() => {
                      // Handle error - you could set a state to show fallback
                    }}
                  />
                ) : (
                  <span className="text-2xl">👤</span>
                )}
              </div>
              <div className="flex-1">
                <h3 className="text-lg font-bold text-green-500">{winningCharacter.name}</h3>
                <p className="text-sm text-gray-400">${winningCharacter.symbol}</p>
                <p className="text-sm text-white">
                  Pool: <span className="text-green-500">{formatEther(winningCharacter.poolBalance)} ETH</span>
                </p>
              </div>
            </div>

            {tokenAddress && (
              <div className="space-y-2">
                <div className="text-sm text-gray-400">Token Address:</div>
                <Address address={tokenAddress} />
                <Button onClick={() => onViewToken(auctionId)} variant="outline" size="sm" className="w-full">
                  View Token Details
                </Button>
              </div>
            )}
          </div>
        ) : (
          <div className="text-center text-gray-500">
            <p>No winner (no bids placed)</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

const PastAuctions: NextPage = () => {
  // Read current auction ID to determine range of past auctions
  const { data: currentAuctionId } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctionId",
  });

  // For demo purposes, we'll read a few past auctions
  const pastAuctionIds =
    currentAuctionId && currentAuctionId > 1n
      ? Array.from({ length: Number(currentAuctionId) - 1 }, (_, i) => i + 1)
      : [];

  // Read auction data for first few past auctions (limit to prevent hook issues)
  const { data: auction1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    args: pastAuctionIds.length > 0 ? [BigInt(pastAuctionIds[0])] : undefined,
  });

  const { data: auction2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    args: pastAuctionIds.length > 1 ? [BigInt(pastAuctionIds[1])] : undefined,
  });

  const { data: auction3 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    args: pastAuctionIds.length > 2 ? [BigInt(pastAuctionIds[2])] : undefined,
  });

  // Combine available auction data
  const pastAuctions = [
    ...(auction1 && pastAuctionIds[0] ? [{ id: pastAuctionIds[0], auction: auction1 }] : []),
    ...(auction2 && pastAuctionIds[1] ? [{ id: pastAuctionIds[1], auction: auction2 }] : []),
    ...(auction3 && pastAuctionIds[2] ? [{ id: pastAuctionIds[2], auction: auction3 }] : []),
  ];

  const handleViewToken = (auctionId: number) => {
    // In a real app, this would open a modal or navigate to a token detail page
    alert(`Viewing token details for Auction #${auctionId}`);
  };

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-4xl font-bold text-red-500">PAST AUCTIONS</h1>
          <p className="text-xl text-gray-400">View previous auction results and token information</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <Card className="border-green-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-green-500">{pastAuctions.length}</div>
              <div className="text-gray-400">Completed Auctions</div>
            </CardContent>
          </Card>
          <Card className="border-red-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-red-500">
                {pastAuctions.filter(item => item.auction?.characters?.some((char: any) => char.isWinner)).length}
              </div>
              <div className="text-gray-400">Characters Created</div>
            </CardContent>
          </Card>
          <Card className="border-gray-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-white">
                {pastAuctions
                  .reduce((total, item) => {
                    const winningChar = item.auction?.characters?.find((char: any) => char.isWinner);
                    return total + (winningChar ? Number(formatEther(winningChar.poolBalance)) : 0);
                  }, 0)
                  .toFixed(2)}
              </div>
              <div className="text-gray-400">Total ETH Volume</div>
            </CardContent>
          </Card>
        </div>

        {/* Past Auctions List */}
        {pastAuctions.length > 0 ? (
          <div className="space-y-4">
            <h2 className="text-2xl font-bold text-white">Auction History</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {pastAuctions.reverse().map(({ id, auction }) => (
                <PastAuctionItem key={id} auctionId={id} auction={auction} onViewToken={handleViewToken} />
              ))}
            </div>
          </div>
        ) : (
          <Card className="border-gray-600">
            <CardContent className="p-12 text-center">
              <div className="text-6xl mb-4">🏛️</div>
              <h3 className="text-2xl font-bold text-gray-400 mb-2">No Past Auctions</h3>
              <p className="text-gray-500">
                {currentAuctionId && currentAuctionId > 0n
                  ? "The current auction is the first one. Check back after it ends!"
                  : "No auctions have been created yet."}
              </p>
              <Button onClick={() => (window.location.href = "/")} variant="outline" className="mt-4">
                Go to Current Auction
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Instructions */}
        <Card className="border-gray-600">
          <CardHeader>
            <CardTitle className="text-gray-400">How to Use</CardTitle>
          </CardHeader>
          <CardContent className="text-gray-400 space-y-2">
            <p>• Click on any past auction to view the winning character and token details</p>
            <p>• Copy token addresses to add to your wallet or use in DEX trading</p>
            <p>• View auction history to track the evolution of character values</p>
            <p>• Use this data to make informed bids in future auctions</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default PastAuctions;
