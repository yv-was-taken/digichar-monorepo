"use client";

import { useState } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { AuctionEventHistory } from "~~/components/AuctionEventHistory";
import { CharacterCard } from "~~/components/CharacterCard";
import { Address } from "~~/components/scaffold-eth";
import { Button } from "~~/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "~~/components/ui/card";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePastAuctionsSimple } from "~~/hooks/scaffold-eth/usePastAuctionsSimple";
import { useUserAuctionHistorySimple } from "~~/hooks/scaffold-eth/useUserAuctionHistorySimple";

const PastAuctions: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [showUserHistory, setShowUserHistory] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const auctionsPerPage = 10;

  // Fetch past auctions data
  const { pastAuctions, isLoading } = usePastAuctionsSimple();

  // Get user-specific auction history
  const pastAuctionIds = pastAuctions.map(auction => auction.auctionId);
  const { userAuctionHistory, userStats } = useUserAuctionHistorySimple(pastAuctionIds);

  // Contract interaction for claiming tokens
  const { writeContractAsync: claimTokens } = useScaffoldWriteContract({
    contractName: "AuctionVault",
  });

  const handleClaimTokens = async (auctionId: number) => {
    if (!connectedAddress) return;

    try {
      await claimTokens({
        functionName: "claimTokens",
        args: [BigInt(auctionId)],
      });
    } catch (error) {
      console.error("Error claiming tokens:", error);
    }
  };

  // Calculate total stats for all past auctions
  const totalStats = {
    completedAuctions: pastAuctions.length,
    charactersCreated: pastAuctions.filter(auction => auction.winnerIndex !== null).length,
    totalVolume: pastAuctions.reduce((total, auction) => {
      const winner = auction.characters.find(char => char.isWinner);
      return total + (winner ? Number(formatEther(winner.poolBalance)) : 0);
    }, 0),
  };

  // Get auctions with claimable tokens for the user
  const claimableAuctions = userAuctionHistory.filter(
    history => history.claimableTokens > 0n && !history.hasClaimedTokens,
  );

  // Filter auctions based on view mode
  const filteredAuctions = showUserHistory
    ? pastAuctions.filter(auction => userAuctionHistory.some(h => h.auctionId === auction.auctionId))
    : pastAuctions;

  // Pagination logic
  const totalPages = Math.ceil(filteredAuctions.length / auctionsPerPage);
  const startIndex = (currentPage - 1) * auctionsPerPage;
  const paginatedAuctions = filteredAuctions.slice(startIndex, startIndex + auctionsPerPage);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-black text-white p-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center py-20">
            <div className="text-2xl">Loading past auctions...</div>
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
          <h1 className="text-4xl font-bold text-red-500">PAST AUCTIONS</h1>
          <p className="text-xl text-gray-400">View previous auction results and character tokens</p>
          <div className="flex justify-center gap-4">
            <Button onClick={() => setShowUserHistory(false)} variant={!showUserHistory ? "default" : "outline"}>
              All Auctions
            </Button>
            <Button
              onClick={() => setShowUserHistory(true)}
              variant={showUserHistory ? "default" : "outline"}
              disabled={!connectedAddress}
            >
              My History
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <Card className="border-green-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-green-500">{totalStats.completedAuctions}</div>
              <div className="text-gray-400">Completed Auctions</div>
            </CardContent>
          </Card>
          <Card className="border-red-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-red-500">{totalStats.charactersCreated}</div>
              <div className="text-gray-400">Characters Created</div>
            </CardContent>
          </Card>
          <Card className="border-blue-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-blue-500">{totalStats.totalVolume.toFixed(2)}</div>
              <div className="text-gray-400">Total ETH Volume</div>
            </CardContent>
          </Card>
          {connectedAddress && (
            <Card className="border-yellow-600">
              <CardContent className="p-6 text-center">
                <div className="text-3xl font-bold text-yellow-500">{claimableAuctions.length}</div>
                <div className="text-gray-400">Claimable Auctions</div>
              </CardContent>
            </Card>
          )}
        </div>

        {/* User History View */}
        {showUserHistory && connectedAddress && (
          <div className="space-y-6">
            {/* User Stats */}
            <Card className="border-purple-600">
              <CardHeader>
                <CardTitle className="text-purple-400">Your Auction Statistics</CardTitle>
              </CardHeader>
              <CardContent className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-bold text-white">{userStats.auctionsParticipated}</div>
                  <div className="text-sm text-gray-400">Auctions Joined</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-white">{userStats.totalBids}</div>
                  <div className="text-sm text-gray-400">Total Bids</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-white">
                    {Number(formatEther(userStats.totalBidAmount)).toFixed(4)}
                  </div>
                  <div className="text-sm text-gray-400">ETH Bid</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-yellow-500">
                    {Number(formatEther(userStats.totalClaimableTokens)).toFixed(4)}
                  </div>
                  <div className="text-sm text-gray-400">Claimable Tokens</div>
                </div>
              </CardContent>
            </Card>

            {/* Claimable Tokens Section */}
            {claimableAuctions.length > 0 && (
              <Card className="border-yellow-600">
                <CardHeader>
                  <CardTitle className="text-yellow-400">🎁 Claimable Tokens</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  {claimableAuctions.map(history => {
                    const auction = pastAuctions.find(a => a.auctionId === history.auctionId);
                    if (!auction) return null;

                    return (
                      <div
                        key={history.auctionId}
                        className="flex items-center justify-between p-4 bg-gray-800 rounded-lg"
                      >
                        <div>
                          <div className="font-bold">Auction #{history.auctionId}</div>
                          <div className="text-sm text-gray-400">
                            {Number(formatEther(history.claimableTokens)).toFixed(4)} tokens available
                          </div>
                        </div>
                        <Button
                          onClick={() => handleClaimTokens(history.auctionId)}
                          className="bg-yellow-600 hover:bg-yellow-700"
                        >
                          Claim Tokens
                        </Button>
                      </div>
                    );
                  })}
                </CardContent>
              </Card>
            )}
          </div>
        )}

        {/* Past Auctions List */}
        {filteredAuctions.length > 0 ? (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h2 className="text-2xl font-bold text-white">
                {showUserHistory && connectedAddress ? "Your Auction History" : "Auction History"}
              </h2>
              <div className="text-gray-400">
                Showing {startIndex + 1}-{Math.min(startIndex + auctionsPerPage, filteredAuctions.length)} of{" "}
                {filteredAuctions.length} auctions
              </div>
            </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="flex justify-center gap-2">
                <Button
                  onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                  disabled={currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const pageNum = Math.max(1, Math.min(totalPages - 4, currentPage - 2)) + i;
                  return (
                    <Button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      variant={currentPage === pageNum ? "default" : "outline"}
                      size="sm"
                    >
                      {pageNum}
                    </Button>
                  );
                })}
                <Button
                  onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                  disabled={currentPage === totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
              </div>
            )}

            {/* Auction Cards */}
            <div className="space-y-8">
              {paginatedAuctions.map(auction => {
                const userHistory = userAuctionHistory.find(h => h.auctionId === auction.auctionId);

                return (
                  <Card key={auction.auctionId} className="border-gray-700">
                    <CardHeader>
                      <div className="flex justify-between items-center">
                        <CardTitle className="text-white">
                          Auction #{auction.auctionId}
                          {auction.winnerIndex !== null && <span className="ml-2 text-green-500">✓ Winner</span>}
                        </CardTitle>
                        <div className="text-right space-y-1">
                          <div className="text-sm text-gray-400">
                            Ended {new Date(Number(auction.endTime) * 1000).toLocaleDateString()}
                          </div>
                          {auction.tokenAddress && (
                            <div className="text-xs">
                              <Address address={auction.tokenAddress} />
                            </div>
                          )}
                        </div>
                      </div>
                      {userHistory && (
                        <div className="text-sm text-blue-400">
                          You placed {userHistory.characterBids.length} bid(s) in this auction
                          {userHistory.claimableTokens > 0n && (
                            <span className="ml-2 text-yellow-400">
                              • {Number(formatEther(userHistory.claimableTokens)).toFixed(4)} tokens claimable
                            </span>
                          )}
                        </div>
                      )}
                    </CardHeader>
                    <CardContent className="space-y-6">
                      {/* Character Cards */}
                      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        {auction.characters.map((character, index) => (
                          <CharacterCard
                            key={index}
                            character={character}
                            characterIndex={index}
                            currentAuctionId={BigInt(auction.auctionId)}
                            onBid={() => {}} // Not used for past auctions
                            onWithdrawBid={() => {}} // Not used for past auctions
                            auctionEnded={true}
                            isPastAuction={true}
                          />
                        ))}
                      </div>

                      {/* Event History */}
                      <AuctionEventHistory auctionId={auction.auctionId} />
                    </CardContent>
                  </Card>
                );
              })}
            </div>

            {/* Bottom Pagination */}
            {totalPages > 1 && (
              <div className="flex justify-center gap-2">
                <Button
                  onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                  disabled={currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const pageNum = Math.max(1, Math.min(totalPages - 4, currentPage - 2)) + i;
                  return (
                    <Button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      variant={currentPage === pageNum ? "default" : "outline"}
                      size="sm"
                    >
                      {pageNum}
                    </Button>
                  );
                })}
                <Button
                  onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                  disabled={currentPage === totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
              </div>
            )}
          </div>
        ) : (
          <Card className="border-gray-600">
            <CardContent className="p-12 text-center">
              <div className="text-6xl mb-4">🏛️</div>
              <h3 className="text-2xl font-bold text-gray-400 mb-2">No Past Auctions</h3>
              <p className="text-gray-500 mb-4">No completed auctions yet. Check back after the first auction ends!</p>
              <Link href="/">
                <Button variant="outline">Go to Current Auction</Button>
              </Link>
            </CardContent>
          </Card>
        )}

        {/* Instructions */}
        <Card className="border-gray-600">
          <CardHeader>
            <CardTitle className="text-gray-400">How to Use</CardTitle>
          </CardHeader>
          <CardContent className="text-gray-400 space-y-2">
            <p>• View all completed auctions and their winning characters</p>
            <p>• Check your personal bidding history and statistics</p>
            <p>• Claim tokens from auctions where you participated</p>
            <p>• Copy token addresses to add to your wallet or trade on DEX</p>
            <p>• Use historical data to make informed bids in future auctions</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default PastAuctions;
