"use client";

import { useState } from "react";
import { formatEther } from "viem";
import { Address } from "~~/components/scaffold-eth";
import { Button } from "~~/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "~~/components/ui/card";
import { useAuctionEvents } from "~~/hooks/scaffold-eth/useAuctionEvents";

interface AuctionEventHistoryProps {
  auctionId: number;
}

export const AuctionEventHistory: React.FC<AuctionEventHistoryProps> = ({ auctionId }) => {
  const [showDetails, setShowDetails] = useState(false);
  const { auctionActivity, isLoading } = useAuctionEvents(auctionId);

  if (isLoading || !auctionActivity) {
    return (
      <Card className="border-gray-600">
        <CardContent className="p-6 text-center">
          <div className="text-gray-400">Loading auction activity...</div>
        </CardContent>
      </Card>
    );
  }

  const { bids, bidsByCharacter, uniqueBidders, totalBids, totalVolume, withdrawals } = auctionActivity;

  if (!showDetails) {
    return (
      <Card className="border-gray-600">
        <CardHeader>
          <div className="flex justify-between items-center">
            <CardTitle className="text-gray-400">Auction Activity</CardTitle>
            <Button onClick={() => setShowDetails(true)} variant="outline" size="sm">
              View Details
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-xl font-bold text-white">{totalBids}</div>
            <div className="text-sm text-gray-400">Total Bids</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{uniqueBidders.length}</div>
            <div className="text-sm text-gray-400">Unique Bidders</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{Number(formatEther(totalVolume)).toFixed(4)}</div>
            <div className="text-sm text-gray-400">Total Volume (ETH)</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{Object.keys(bidsByCharacter).length}</div>
            <div className="text-sm text-gray-400">Characters Bid On</div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="border-gray-600">
      <CardHeader>
        <div className="flex justify-between items-center">
          <CardTitle className="text-gray-400">Auction #{auctionId} - Detailed Activity</CardTitle>
          <Button onClick={() => setShowDetails(false)} variant="outline" size="sm">
            Hide Details
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Activity Summary */}
        <div className="space-y-4">
          <h4 className="text-lg font-semibold text-white">Activity Summary</h4>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="p-3 bg-gray-800 rounded-lg text-center">
              <div className="text-xl font-bold text-blue-400">{totalBids}</div>
              <div className="text-sm text-gray-400">Total Bids</div>
            </div>
            <div className="p-3 bg-gray-800 rounded-lg text-center">
              <div className="text-xl font-bold text-purple-400">{withdrawals.length}</div>
              <div className="text-sm text-gray-400">Withdrawals</div>
            </div>
            <div className="p-3 bg-gray-800 rounded-lg text-center">
              <div className="text-xl font-bold text-green-400">{uniqueBidders.length}</div>
              <div className="text-sm text-gray-400">Unique Bidders</div>
            </div>
            <div className="p-3 bg-gray-800 rounded-lg text-center">
              <div className="text-xl font-bold text-yellow-400">{Number(formatEther(totalVolume)).toFixed(4)}</div>
              <div className="text-sm text-gray-400">Total Volume (ETH)</div>
            </div>
          </div>
        </div>

        {/* Bidding Activity by Character */}
        <div className="space-y-4">
          <h4 className="text-lg font-semibold text-white">Bidding Activity</h4>
          {Object.entries(bidsByCharacter).map(([characterIndex, characterBids]) => (
            <div key={characterIndex} className="space-y-2">
              <h5 className="text-md font-medium text-blue-400">
                Character {characterIndex} ({characterBids.length} bids)
              </h5>
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {characterBids.map((bid, index) => (
                  <div key={index} className="flex items-center justify-between p-3 bg-gray-800 rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className="w-1.5 h-1.5 bg-blue-500 rounded-full"></div>
                      <Address address={bid.bidder} />
                    </div>
                    <div className="text-right">
                      <div className="text-white font-medium">{Number(formatEther(bid.amount)).toFixed(4)} ETH</div>
                      <div className="text-xs text-gray-400">{new Date(bid.timestamp * 1000).toLocaleString()}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Top Bidders */}
        {uniqueBidders.length > 0 && (
          <div className="space-y-4">
            <h4 className="text-lg font-semibold text-white">Top Bidders</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {uniqueBidders.slice(0, 6).map((bidder, index) => {
                const bidderBids = bids.filter(bid => bid.bidder === bidder);
                const totalBidAmount = bidderBids.reduce((sum, bid) => sum + bid.amount, 0n);

                return (
                  <div key={bidder} className="flex items-center justify-between p-3 bg-gray-800 rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className="text-sm font-bold text-purple-400">#{index + 1}</div>
                      <Address address={bidder} />
                    </div>
                    <div className="text-right">
                      <div className="text-white font-medium">{Number(formatEther(totalBidAmount)).toFixed(4)} ETH</div>
                      <div className="text-xs text-gray-400">
                        {bidderBids.length} bid{bidderBids.length !== 1 ? "s" : ""}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Summary Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-gray-800 rounded-lg">
          <div className="text-center">
            <div className="text-xl font-bold text-white">{totalBids}</div>
            <div className="text-sm text-gray-400">Total Bids</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{uniqueBidders.length}</div>
            <div className="text-sm text-gray-400">Unique Bidders</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{Number(formatEther(totalVolume)).toFixed(4)}</div>
            <div className="text-sm text-gray-400">Total Volume (ETH)</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">
              {totalBids > 0 ? Number(formatEther(totalVolume / BigInt(totalBids))).toFixed(4) : "0"}
            </div>
            <div className="text-sm text-gray-400">Avg Bid (ETH)</div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};
