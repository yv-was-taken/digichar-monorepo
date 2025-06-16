"use client";

import { AuctionTimer } from "./AuctionTimer";
import { CharacterCard } from "./CharacterCard";
import { Button } from "./ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { parseEther } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface Character {
  characterURI: string;
  name: string;
  symbol: string;
  poolBalance: bigint;
  isWinner: boolean;
}

export const AuctionDashboard: React.FC = () => {
  const { address: connectedAddress } = useAccount();

  // Read current auction ID
  const { data: currentAuctionId } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctionId",
  });
  console.log("auction id: ", currentAuctionId);

  // Read character data for all three characters in parallel
  const { data: character0Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: currentAuctionId !== undefined ? [currentAuctionId, 0n] : undefined,
  });

  const { data: character1Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: currentAuctionId !== undefined ? [currentAuctionId, 1n] : undefined,
  });

  const { data: character2Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: currentAuctionId !== undefined ? [currentAuctionId, 2n] : undefined,
  });

  // Transform the data into Character objects
  const characters: Character[] = [];
  if (character0Data) {
    characters[0] = {
      characterURI: character0Data[0],
      name: character0Data[1],
      symbol: character0Data[2],
      poolBalance: character0Data[3],
      isWinner: character0Data[4],
    };
  }
  if (character1Data) {
    characters[1] = {
      characterURI: character1Data[0],
      name: character1Data[1],
      symbol: character1Data[2],
      poolBalance: character1Data[3],
      isWinner: character1Data[4],
    };
  }
  if (character2Data) {
    characters[2] = {
      characterURI: character2Data[0],
      name: character2Data[1],
      symbol: character2Data[2],
      poolBalance: character2Data[3],
      isWinner: character2Data[4],
    };
  }

  // Read auction end time
  const { data: currentAuctionEndTime } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCurrentAuctionEndTime",
  });
  console.log("auction end time: ", currentAuctionEndTime);

  // Read auction duration from Config contract
  const { data: auctionDuration } = useScaffoldReadContract({
    contractName: "Config",
    functionName: "AUCTION_DURATION_TIME",
  });

  // Write contract hook for placing bids
  const { writeContractAsync: writeBid } = useScaffoldWriteContract({
    contractName: "AuctionVault",
  });

  const handleBid = async (characterIndex: number, amount: string): Promise<void> => {
    if (!connectedAddress) {
      alert("Please connect your wallet to place a bid");
      return;
    }

    try {
      await writeBid({
        functionName: "bid",
        args: [characterIndex],
        value: parseEther(amount),
      });
    } catch (error) {
      console.error("Error placing bid:", error);
    }
  };

  const isAuctionExpired = currentAuctionEndTime ? Date.now() / 1000 >= Number(currentAuctionEndTime) : false;
  const hasCharacterData = characters.length > 0 && characters.some(char => char !== undefined);

  if (!hasCharacterData || !currentAuctionEndTime || !auctionDuration) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="text-2xl font-bold text-red-500">Loading Auction Data...</div>
          <div className="text-gray-400">Fetching current auction information</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-7xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-5xl font-bold text-red-500">DIGICHAR AUCTIONS</h1>
          <p className="text-xl text-gray-400">Bid on unique digital characters and claim their tokens</p>
        </div>

        {/* Current Auction Section */}
        <Card className="border-red-600">
          <CardHeader>
            <CardTitle className="text-center text-2xl font-bold text-white">
              Current Auction #{currentAuctionId?.toString() || "0"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {!currentAuctionId || !hasCharacterData || !currentAuctionEndTime || !auctionDuration ? (
              <div className="flex flex-col items-center justify-center py-12 space-y-4">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-500"></div>
                <p className="text-gray-400">Loading auction data...</p>
              </div>
            ) : (
              <>
                {/* Auction Timer */}
                <AuctionTimer
                  endTime={currentAuctionEndTime}
                  auctionDuration={auctionDuration}
                  className="max-w-md mx-auto"
                />

                {/* Character Cards */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {characters.map((character, index) => (
                    <CharacterCard
                      key={index}
                      character={character}
                      characterIndex={index}
                      onBid={handleBid}
                      auctionEnded={isAuctionExpired}
                      className="h-full"
                    />
                  ))}
                </div>

                {/* Action Buttons */}
                <div className="flex justify-center space-x-4 mt-8">
                  <Button
                    variant="outline"
                    size="lg"
                    onClick={() => (window.location.href = "/past-auctions")}
                    className="px-8"
                  >
                    View Past Auctions
                  </Button>
                </div>
              </>
            )}
          </CardContent>
        </Card>

        {/* Info Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card className="border-green-600">
            <CardHeader>
              <CardTitle className="text-green-500">How it Works</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-gray-300">
              <p>• Place bids on your favorite characters using ETH</p>
              <p>• The character with the highest total bid pool wins</p>
              <p>• Winning bidders receive character tokens proportional to their contribution</p>
              <p>• Non-winning bids can be withdrawn after the auction ends</p>
            </CardContent>
          </Card>

          <Card className="border-red-600">
            <CardHeader>
              <CardTitle className="text-red-500">Token Economics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-gray-300">
              <p>• Each character has 1,000,000 total tokens</p>
              <p>• 50% locked in liquidity pool for trading</p>
              <p>• 50% distributed to auction winners</p>
              <p>• Tokens have built-in trading fees for sustainability</p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};
