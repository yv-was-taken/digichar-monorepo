"use client";

import { useMemo } from "react";
import Image from "next/image";
import type { NextPage } from "next";
import { formatEther } from "viem";
import { Address } from "~~/components/scaffold-eth";
import { Card, CardContent, CardHeader, CardTitle } from "~~/components/ui/card";
import { usePastAuctions } from "~~/hooks/scaffold-eth/usePastAuctions";

interface LiveCharacter {
  name: string;
  symbol: string;
  characterURI: string;
  poolBalance: bigint;
  tokenAddress: string;
  auctionId: number;
  rank: number;
}

const LiveDigichars: NextPage = () => {
  const { pastAuctions, isLoading } = usePastAuctions();

  const liveCharacters = useMemo(() => {
    const characters: LiveCharacter[] = [];

    pastAuctions.forEach(auction => {
      const winner = auction.characters.find(char => char.isWinner);
      if (winner && auction.tokenAddress) {
        characters.push({
          name: winner.name,
          symbol: winner.symbol,
          characterURI: winner.characterURI,
          poolBalance: winner.poolBalance,
          tokenAddress: auction.tokenAddress,
          auctionId: auction.auctionId,
          rank: 0, // Will be set after sorting
        });
      }
    });

    // Sort by pool balance (volume) in descending order
    characters.sort((a, b) => (b.poolBalance > a.poolBalance ? 1 : -1));

    // Assign ranks
    return characters.map((char, index) => ({
      ...char,
      rank: index + 1,
    }));
  }, [pastAuctions]);

  const getImageUrl = (uri: string) => {
    if (uri.startsWith("http")) {
      return uri;
    }
    return `https://ipfs.io/ipfs/${uri}`;
  };

  const getRankIcon = (rank: number) => {
    switch (rank) {
      case 1:
        return "🥇";
      case 2:
        return "🥈";
      case 3:
        return "🥉";
      default:
        return `#${rank}`;
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-black text-white p-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center py-20">
            <div className="text-2xl">Loading live characters...</div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="text-center space-y-4">
          <h1 className="text-4xl font-bold text-red-500">LIVE DIGICHARS</h1>
          <p className="text-xl text-gray-400">Character leaderboard ranked by token volume</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <Card className="border-green-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-green-500">{liveCharacters.length}</div>
              <div className="text-gray-400">Live Characters</div>
            </CardContent>
          </Card>
          <Card className="border-blue-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-blue-500">
                {liveCharacters.reduce((total, char) => total + Number(formatEther(char.poolBalance)), 0).toFixed(2)}
              </div>
              <div className="text-gray-400">Total Volume (ETH)</div>
            </CardContent>
          </Card>
          <Card className="border-purple-600">
            <CardContent className="p-6 text-center">
              <div className="text-3xl font-bold text-purple-500">
                {liveCharacters.length > 0
                  ? (
                      liveCharacters.reduce((total, char) => total + Number(formatEther(char.poolBalance)), 0) /
                      liveCharacters.length
                    ).toFixed(2)
                  : "0.00"}
              </div>
              <div className="text-gray-400">Average Volume (ETH)</div>
            </CardContent>
          </Card>
        </div>

        {/* Leaderboard */}
        {liveCharacters.length > 0 ? (
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-white text-center">Character Leaderboard</h2>

            <div className="space-y-4">
              {liveCharacters.map((character, index) => (
                <Card
                  key={`${character.auctionId}-${character.symbol}`}
                  className={`border-gray-700 transition-all duration-300 hover:shadow-lg ${
                    index < 3 ? "hover:shadow-yellow-500/20 border-yellow-500/50" : "hover:shadow-red-500/20"
                  }`}
                >
                  <CardContent className="p-6">
                    <div className="flex items-center gap-6">
                      {/* Rank */}
                      <div className="text-center min-w-[80px]">
                        <div className="text-3xl font-bold">{getRankIcon(character.rank)}</div>
                        <div className="text-sm text-gray-400">Rank</div>
                      </div>

                      {/* Character Image */}
                      <div className="relative w-20 h-20 rounded-lg overflow-hidden bg-gray-800 flex-shrink-0">
                        {character.characterURI ? (
                          <Image
                            src={getImageUrl(character.characterURI)}
                            alt={character.name}
                            fill
                            className="object-cover"
                            onError={e => {
                              const target = e.target as HTMLImageElement;
                              target.src = "/placeholder-character.png";
                            }}
                          />
                        ) : (
                          <div className="flex items-center justify-center h-full text-gray-500">
                            <div className="text-2xl">👤</div>
                          </div>
                        )}
                      </div>

                      {/* Character Info */}
                      <div className="flex-grow">
                        <div className="flex justify-between items-start">
                          <div>
                            <h3 className="text-xl font-bold text-white">{character.name}</h3>
                            <p className="text-sm text-gray-400 uppercase tracking-wide">${character.symbol}</p>
                            <div className="text-xs text-gray-500 mt-1">Auction #{character.auctionId}</div>
                          </div>

                          <div className="text-right">
                            <div className="text-2xl font-bold text-green-500">
                              {Number(formatEther(character.poolBalance)).toFixed(4)} ETH
                            </div>
                            <div className="text-sm text-gray-400">Token Volume</div>
                          </div>
                        </div>

                        {/* Token Address */}
                        <div className="mt-3 p-2 bg-gray-800 rounded-lg">
                          <div className="text-xs text-gray-400 mb-1">Token Contract:</div>
                          <Address address={character.tokenAddress} />
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        ) : (
          <Card className="border-gray-600">
            <CardContent className="p-12 text-center">
              <div className="text-6xl mb-4">🎭</div>
              <h3 className="text-2xl font-bold text-gray-400 mb-2">No Live Characters</h3>
              <p className="text-gray-500 mb-4">
                No characters have been created yet. Check back after the first auction ends!
              </p>
            </CardContent>
          </Card>
        )}

        {/* Instructions */}
        <Card className="border-gray-600">
          <CardHeader>
            <CardTitle className="text-gray-400">About Live Digichars</CardTitle>
          </CardHeader>
          <CardContent className="text-gray-400 space-y-2">
            <p>• Live characters are winning characters from completed auctions</p>
            <p>• Rankings are based on token volume (final pool balance)</p>
            <p>• Each character has an associated ERC-20 token that can be traded</p>
            <p>• Token contracts are displayed for each character for easy access</p>
            <p>• Higher volume indicates more bidding interest during the auction</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default LiveDigichars;
