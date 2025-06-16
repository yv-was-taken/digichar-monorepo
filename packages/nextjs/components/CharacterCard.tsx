"use client";

import { useState } from "react";
import Image from "next/image";
import { formatEther } from "viem";
import { EtherInput } from "~~/components/scaffold-eth";
import { Button } from "~~/components/ui/button";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "~~/components/ui/card";

interface CharacterCardProps {
  character: {
    characterURI: string;
    name: string;
    symbol: string;
    poolBalance: bigint;
    isWinner: boolean;
  };
  characterIndex: number;
  onBid: (characterIndex: number, amount: string) => void;
  auctionEnded: boolean;
  className?: string;
}

export const CharacterCard: React.FC<CharacterCardProps> = ({
  character,
  characterIndex,
  onBid,
  auctionEnded,
  className,
}) => {
  const [bidAmount, setBidAmount] = useState<string>("");

  const handleBid = () => {
    if (bidAmount && parseFloat(bidAmount) > 0) {
      onBid(characterIndex, bidAmount);
      setBidAmount("");
    }
  };

  const poolBalanceEth = formatEther(character.poolBalance);

  // Convert IPFS hash to full URL if needed
  const getImageUrl = (uri: string) => {
    if (uri.startsWith("http")) {
      return uri;
    }
    return `https://ipfs.io/ipfs/${uri}`;
  };

  return (
    <Card
      className={`${className} ${character.isWinner ? "border-green-500 shadow-green-500/20" : "border-red-600"} transition-all duration-300 hover:shadow-lg hover:shadow-red-500/20`}
    >
      <CardHeader className="pb-4">
        <CardTitle className="text-center text-lg font-bold text-white">{character.name}</CardTitle>
        <div className="text-center text-sm text-gray-400 uppercase tracking-wide">${character.symbol}</div>
      </CardHeader>

      <CardContent className="space-y-4">
        <div className="relative aspect-square overflow-hidden rounded-lg bg-gray-800">
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
              <div className="text-center">
                <div className="text-4xl mb-2">👤</div>
                <div className="text-sm">No Image</div>
              </div>
            </div>
          )}
          {character.isWinner && (
            <div className="absolute top-2 right-2 bg-green-600 text-white px-2 py-1 rounded-md text-xs font-bold">
              WINNER
            </div>
          )}
        </div>

        <div className="text-center">
          <div className="text-sm text-gray-400 mb-1">Current Pool</div>
          <div className="text-xl font-bold text-green-500">{Number(poolBalanceEth).toFixed(4)} ETH</div>
        </div>

        {!auctionEnded && !character.isWinner && (
          <div className="space-y-3">
            <EtherInput value={bidAmount} onChange={setBidAmount} placeholder="Enter bid amount" />
          </div>
        )}
      </CardContent>

      {!auctionEnded && !character.isWinner && (
        <CardFooter>
          <Button
            onClick={handleBid}
            disabled={!bidAmount || parseFloat(bidAmount) <= 0}
            className="w-full"
            variant="default"
          >
            Place Bid
          </Button>
        </CardFooter>
      )}
    </Card>
  );
};
