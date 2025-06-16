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

export function usePastAuctionsSimple() {
  // Get current auction ID to determine how many past auctions exist
  const { data: currentAuctionId, isLoading: isLoadingCurrentId } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctionId",
  });

  // Calculate past auction IDs (excluding current auction)
  const pastAuctionIds = useMemo(() => {
    if (!currentAuctionId || currentAuctionId <= 1n) return [];

    const numPastAuctions = Number(currentAuctionId) - 1;
    const limit = Math.min(10, numPastAuctions); // Limit to 10 for performance

    // Get the most recent past auctions
    return Array.from({ length: limit }, (_, i) => numPastAuctions - i);
  }, [currentAuctionId]);

  // Read the first few past auctions only (to avoid hook order issues)
  const { data: auction1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    // @ts-ignore
    args: pastAuctionIds[0] ? [BigInt(pastAuctionIds[0])] : undefined,
  });

  const { data: auction2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    // @ts-ignore
    args: pastAuctionIds[1] ? [BigInt(pastAuctionIds[1])] : undefined,
  });

  const { data: auction3 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    // @ts-ignore
    args: pastAuctionIds[2] ? [BigInt(pastAuctionIds[2])] : undefined,
  });

  const { data: auction4 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    // @ts-ignore
    args: pastAuctionIds[3] ? [BigInt(pastAuctionIds[3])] : undefined,
  });

  const { data: auction5 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "auctions",
    // @ts-ignore
    args: pastAuctionIds[4] ? [BigInt(pastAuctionIds[4])] : undefined,
  });

  // Read token addresses
  const { data: tokenAddress1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[0] ? [BigInt(pastAuctionIds[0])] : undefined,
  });

  const { data: tokenAddress2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[1] ? [BigInt(pastAuctionIds[1])] : undefined,
  });

  const { data: tokenAddress3 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[2] ? [BigInt(pastAuctionIds[2])] : undefined,
  });

  const { data: tokenAddress4 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[3] ? [BigInt(pastAuctionIds[3])] : undefined,
  });

  const { data: tokenAddress5 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[4] ? [BigInt(pastAuctionIds[4])] : undefined,
  });

  // Process auction data
  const pastAuctions = useMemo(() => {
    const auctions = [
      { auctionId: pastAuctionIds[0], auctionData: auction1, tokenAddress: tokenAddress1 },
      { auctionId: pastAuctionIds[1], auctionData: auction2, tokenAddress: tokenAddress2 },
      { auctionId: pastAuctionIds[2], auctionData: auction3, tokenAddress: tokenAddress3 },
      { auctionId: pastAuctionIds[3], auctionData: auction4, tokenAddress: tokenAddress4 },
      { auctionId: pastAuctionIds[4], auctionData: auction5, tokenAddress: tokenAddress5 },
    ];

    return auctions
      .map(({ auctionId, auctionData, tokenAddress }) => {
        if (!auctionId || !auctionData) return null;

        const auction = auctionData as any;
        const characters = auction[0] as Character[];
        const endTime = auction[1] as bigint;

        // Check if characters array exists and is valid
        if (!characters || !Array.isArray(characters)) {
          return null;
        }

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
  }, [
    pastAuctionIds,
    auction1,
    auction2,
    auction3,
    auction4,
    auction5,
    tokenAddress1,
    tokenAddress2,
    tokenAddress3,
    tokenAddress4,
    tokenAddress5,
  ]);

  const isLoading = isLoadingCurrentId;

  return {
    pastAuctions,
    isLoading,
    totalPastAuctions: currentAuctionId ? Number(currentAuctionId) - 1 : 0,
  };
}
