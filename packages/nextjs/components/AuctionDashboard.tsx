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

  // Read auction end time to determine if auction is active
  const { data: currentAuctionEndTime } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCurrentAuctionEndTime",
  });

  // Determine auction states
  const isAuctionActive = currentAuctionEndTime && Number(currentAuctionEndTime) > 0;
  const previousAuctionId = currentAuctionId && currentAuctionId > 0n ? currentAuctionId - 1n : undefined;
  const hasPreviousAuction = previousAuctionId !== undefined;

  // Read current auction character data (when auction is active)
  const { data: currentChar0Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: isAuctionActive && currentAuctionId !== undefined ? [currentAuctionId, 0n] : undefined,
  });

  const { data: currentChar1Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: isAuctionActive && currentAuctionId !== undefined ? [currentAuctionId, 1n] : undefined,
  });

  const { data: currentChar2Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: isAuctionActive && currentAuctionId !== undefined ? [currentAuctionId, 2n] : undefined,
  });

  // Read previous auction character data
  const { data: prevChar0Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: previousAuctionId !== undefined ? [previousAuctionId, 0n] : undefined,
  });

  const { data: prevChar1Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: previousAuctionId !== undefined ? [previousAuctionId, 1n] : undefined,
  });

  const { data: prevChar2Data } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore - Type assertion for scaffold-eth hook compatibility
    args: previousAuctionId !== undefined ? [previousAuctionId, 2n] : undefined,
  });

  // Transform current auction data into Character objects
  const currentCharacters: Character[] = [];
  if (currentChar0Data) {
    currentCharacters[0] = {
      characterURI: currentChar0Data[0],
      name: currentChar0Data[1],
      symbol: currentChar0Data[2],
      poolBalance: currentChar0Data[3],
      isWinner: currentChar0Data[4],
    };
  }
  if (currentChar1Data) {
    currentCharacters[1] = {
      characterURI: currentChar1Data[0],
      name: currentChar1Data[1],
      symbol: currentChar1Data[2],
      poolBalance: currentChar1Data[3],
      isWinner: currentChar1Data[4],
    };
  }
  if (currentChar2Data) {
    currentCharacters[2] = {
      characterURI: currentChar2Data[0],
      name: currentChar2Data[1],
      symbol: currentChar2Data[2],
      poolBalance: currentChar2Data[3],
      isWinner: currentChar2Data[4],
    };
  }

  // Transform previous auction data into Character objects
  const previousCharacters: Character[] = [];
  if (prevChar0Data) {
    previousCharacters[0] = {
      characterURI: prevChar0Data[0],
      name: prevChar0Data[1],
      symbol: prevChar0Data[2],
      poolBalance: prevChar0Data[3],
      isWinner: prevChar0Data[4],
    };
  }
  if (prevChar1Data) {
    previousCharacters[1] = {
      characterURI: prevChar1Data[0],
      name: prevChar1Data[1],
      symbol: prevChar1Data[2],
      poolBalance: prevChar1Data[3],
      isWinner: prevChar1Data[4],
    };
  }
  if (prevChar2Data) {
    previousCharacters[2] = {
      characterURI: prevChar2Data[0],
      name: prevChar2Data[1],
      symbol: prevChar2Data[2],
      poolBalance: prevChar2Data[3],
      isWinner: prevChar2Data[4],
    };
  }

  // Read auction duration from Config contract
  const { data: auctionDuration } = useScaffoldReadContract({
    contractName: "Config",
    functionName: "AUCTION_DURATION_TIME",
  });

  // Write contract hooks for placing and withdrawing bids
  const { writeContractAsync: writeBid } = useScaffoldWriteContract({
    contractName: "AuctionVault",
  });

  const { writeContractAsync: writeWithdrawBid } = useScaffoldWriteContract({
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

  const handleWithdrawBid = async (characterIndex: number, amount: string): Promise<void> => {
    if (!connectedAddress) {
      alert("Please connect your wallet to withdraw bid");
      return;
    }

    if (!currentAuctionId) {
      alert("No active auction found");
      return;
    }

    try {
      await writeWithdrawBid({
        functionName: "withdrawBid",
        args: [currentAuctionId, characterIndex, parseEther(amount)],
      });
    } catch (error) {
      console.error("Error withdrawing bid:", error);
    }
  };

  // Check auction states
  const isAuctionExpired = currentAuctionEndTime ? Date.now() / 1000 >= Number(currentAuctionEndTime) : false;
  const hasCurrentCharacterData = currentCharacters.length > 0 && currentCharacters.some(char => char !== undefined);
  const hasPreviousCharacterData = previousCharacters.length > 0 && previousCharacters.some(char => char !== undefined);

  // Loading state
  if (currentAuctionId === undefined || currentAuctionEndTime === undefined || !auctionDuration) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="text-2xl font-bold text-red-500">Loading Auction Data...</div>
          <div className="text-gray-400">Fetching current auction information</div>
        </div>
      </div>
    );
  }

  // No active auction state - show only past auction data
  if (!isAuctionActive && hasPreviousCharacterData) {
    return (
      <div className="min-h-screen bg-black text-white p-6">
        <div className="max-w-7xl mx-auto space-y-8">
          {/* Header */}
          <div className="text-center space-y-4">
            <h1 className="text-5xl font-bold text-red-500">DIGICHAR AUCTIONS</h1>
            <p className="text-xl text-gray-400">Bid on unique digital characters and claim their tokens</p>
          </div>

          {/* No Active Auction Notice */}
          <Card className="border-yellow-600 bg-yellow-900/20">
            <CardHeader>
              <CardTitle className="text-center text-2xl font-bold text-yellow-500">
                🎯 Past Auction Closed - New Auction Opening Soon!
              </CardTitle>
            </CardHeader>
            <CardContent className="text-center space-y-4">
              <p className="text-lg text-yellow-200">
                The previous auction has ended. A new auction will be starting soon with fresh characters!
              </p>
              <p className="text-yellow-300">
                Check back shortly or follow our updates for the next auction announcement.
              </p>
            </CardContent>
          </Card>

          {/* Past Auction Results */}
          <Card className="border-gray-600">
            <CardHeader>
              <CardTitle className="text-center text-2xl font-bold text-gray-300">
                Previous Auction Results - Auction #{previousAuctionId?.toString()}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="text-center text-gray-400 mb-6">
                <p>🏆 Final results from the completed auction</p>
              </div>

              {/* Past Character Results */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {previousCharacters.map((character, index) => (
                  <CharacterCard
                    key={index}
                    character={character}
                    characterIndex={index}
                    currentAuctionId={previousAuctionId}
                    onBid={handleBid}
                    onWithdrawBid={handleWithdrawBid}
                    auctionEnded={true}
                    className="h-full opacity-75"
                    isPastAuction={true}
                  />
                ))}
              </div>
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
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-7xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-5xl font-bold text-red-500">DIGICHAR AUCTIONS</h1>
          <p className="text-xl text-gray-400">Bid on unique digital characters and claim their tokens</p>
        </div>

        {/* Active Auction Section */}
        <Card className="border-red-600">
          <CardHeader>
            <CardTitle className="text-center text-2xl font-bold text-white">
              🔥 Live Auction #{currentAuctionId?.toString() || "0"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {!hasCurrentCharacterData ? (
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
                  {currentCharacters.map((character, index) => (
                    <CharacterCard
                      key={index}
                      character={character}
                      characterIndex={index}
                      currentAuctionId={currentAuctionId}
                      onBid={handleBid}
                      onWithdrawBid={handleWithdrawBid}
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

        {/* Previous Auction Section - Only show if there's previous auction data */}
        {hasPreviousAuction && hasPreviousCharacterData && (
          <Card className="border-gray-600">
            <CardHeader>
              <CardTitle className="text-center text-2xl font-bold text-gray-300">
                Previous Auction Results - Auction #{previousAuctionId?.toString()}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="text-center text-gray-400 mb-6">
                <p>🏆 Final results from the completed auction</p>
              </div>

              {/* Previous Character Results */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {previousCharacters.map((character, index) => (
                  <CharacterCard
                    key={`prev-${index}`}
                    character={character}
                    characterIndex={index}
                    currentAuctionId={previousAuctionId}
                    onBid={handleBid}
                    onWithdrawBid={handleWithdrawBid}
                    auctionEnded={true}
                    className="h-full opacity-75"
                    isPastAuction={true}
                  />
                ))}
              </div>
            </CardContent>
          </Card>
        )}

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
