import { useMemo } from "react";
import { useScaffoldReadContract } from "./useScaffoldReadContract";

interface Character {
  characterURI: string;
  name: string;
  symbol: string;
  poolBalance: bigint;
  isWinner: boolean;
}

interface PastAuction {
  auctionId: number;
  characters: Character[];
  endTime: bigint;
  winnerIndex: number | null;
  tokenAddress?: string;
}

export function usePastAuctions(limit: number = 10) {
  // Get current auction ID to determine how many past auctions exist
  const { data: currentAuctionId, isLoading: isLoadingCurrentId } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctionId",
  });

  // Calculate past auction IDs (excluding current auction)
  const pastAuctionIds = useMemo(() => {
    if (!currentAuctionId || currentAuctionId <= 1n) return [];

    const numPastAuctions = Number(currentAuctionId) - 1;
    const actualLimit = Math.min(limit, numPastAuctions);

    // Get the most recent past auctions
    return Array.from({ length: actualLimit }, (_, i) => numPastAuctions - i);
  }, [currentAuctionId, limit]);

  // Fixed number of auction queries to avoid hook order issues
  const maxAuctions = 50;
  const auctionQueries = Array.from({ length: maxAuctions }, (_, index) => {
    const auctionId = pastAuctionIds[index];

    // eslint-disable-next-line react-hooks/rules-of-hooks
    const { data: auctionData } = useScaffoldReadContract({
      contractName: "AuctionVault",
      functionName: "auctions",
      // @ts-ignore
      args: auctionId ? [BigInt(auctionId)] : undefined,
    });

    // eslint-disable-next-line react-hooks/rules-of-hooks
    const { data: tokenAddress } = useScaffoldReadContract({
      contractName: "AuctionVault",
      functionName: "getCharacterTokenAddress",
      // @ts-ignore
      args: auctionId ? [BigInt(auctionId)] : undefined,
    });

    return {
      auctionId,
      auctionData,
      tokenAddress,
    };
  });

  // Process the auction data
  const pastAuctions = useMemo(() => {
    return auctionQueries
      .map(({ auctionId, auctionData, tokenAddress }) => {
        if (!auctionId || !auctionData) return null;

        const auction = auctionData as any;
        const characters = auction[0] as Character[];
        const endTime = auction[1] as bigint;

        // Find the winner (character with highest pool balance)
        let winnerIndex: number | null = null;
        let maxBalance = 0n;

        characters.forEach((char, index) => {
          if (char.poolBalance > maxBalance) {
            maxBalance = char.poolBalance;
            winnerIndex = index;
          }
        });

        // Mark the winner
        const processedCharacters = characters.map((char, index) => ({
          ...char,
          isWinner: index === winnerIndex && char.poolBalance > 0n,
        }));

        return {
          auctionId,
          characters: processedCharacters,
          endTime,
          winnerIndex: winnerIndex && maxBalance > 0n ? winnerIndex : null,
          tokenAddress,
        } as PastAuction;
      })
      .filter((auction): auction is PastAuction => auction !== null);
  }, [auctionQueries]);

  const isLoading =
    isLoadingCurrentId ||
    auctionQueries.some(query => query.auctionData === undefined && query.auctionId <= Number(currentAuctionId) - 1);

  return {
    pastAuctions,
    isLoading,
    totalPastAuctions: currentAuctionId ? Number(currentAuctionId) - 1 : 0,
  };
}
