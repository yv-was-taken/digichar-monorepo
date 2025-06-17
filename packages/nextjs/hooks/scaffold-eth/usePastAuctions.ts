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
    if (currentAuctionId === undefined || currentAuctionId === null) {
      return [];
    }

    const currentId = Number(currentAuctionId);

    if (currentId === 0) {
      // Current auction is #0, no past auctions
      return [];
    }

    // Past auctions are 0 to (currentId - 1)
    const numPastAuctions = currentId;
    const actualLimit = Math.min(limit, numPastAuctions);

    // Get the most recent past auctions (working backwards from currentId - 1)
    return Array.from({ length: actualLimit }, (_, i) => currentId - 1 - i);
  }, [currentAuctionId, limit]);

  // Read auction end times for past auctions
  const { data: endTime0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionEndTime",
    // @ts-ignore
    args: pastAuctionIds[0] !== undefined ? [BigInt(pastAuctionIds[0])] : undefined,
  });

  const { data: endTime1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionEndTime",
    // @ts-ignore
    args: pastAuctionIds[1] !== undefined ? [BigInt(pastAuctionIds[1])] : undefined,
  });

  const { data: endTime2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionEndTime",
    // @ts-ignore
    args: pastAuctionIds[2] !== undefined ? [BigInt(pastAuctionIds[2])] : undefined,
  });

  const { data: endTime3 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionEndTime",
    // @ts-ignore
    args: pastAuctionIds[3] !== undefined ? [BigInt(pastAuctionIds[3])] : undefined,
  });

  const { data: endTime4 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionEndTime",
    // @ts-ignore
    args: pastAuctionIds[4] !== undefined ? [BigInt(pastAuctionIds[4])] : undefined,
  });

  // Read character data for past auction #0
  const { data: auction0Char0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[0] !== undefined ? [BigInt(pastAuctionIds[0]), BigInt(0)] : undefined,
  });

  const { data: auction0Char1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[0] !== undefined ? [BigInt(pastAuctionIds[0]), BigInt(1)] : undefined,
  });

  const { data: auction0Char2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[0] !== undefined ? [BigInt(pastAuctionIds[0]), BigInt(2)] : undefined,
  });

  // Read character data for past auction #1
  const { data: auction1Char0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[1] !== undefined ? [BigInt(pastAuctionIds[1]), BigInt(0)] : undefined,
  });

  const { data: auction1Char1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[1] !== undefined ? [BigInt(pastAuctionIds[1]), BigInt(1)] : undefined,
  });

  const { data: auction1Char2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[1] !== undefined ? [BigInt(pastAuctionIds[1]), BigInt(2)] : undefined,
  });

  // Read character data for past auction #2
  const { data: auction2Char0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[2] !== undefined ? [BigInt(pastAuctionIds[2]), BigInt(0)] : undefined,
  });

  const { data: auction2Char1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[2] !== undefined ? [BigInt(pastAuctionIds[2]), BigInt(1)] : undefined,
  });

  const { data: auction2Char2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[2] !== undefined ? [BigInt(pastAuctionIds[2]), BigInt(2)] : undefined,
  });

  // Read character data for past auction #3
  const { data: auction3Char0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[3] !== undefined ? [BigInt(pastAuctionIds[3]), BigInt(0)] : undefined,
  });

  const { data: auction3Char1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[3] !== undefined ? [BigInt(pastAuctionIds[3]), BigInt(1)] : undefined,
  });

  const { data: auction3Char2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[3] !== undefined ? [BigInt(pastAuctionIds[3]), BigInt(2)] : undefined,
  });

  // Read character data for past auction #4
  const { data: auction4Char0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[4] !== undefined ? [BigInt(pastAuctionIds[4]), BigInt(0)] : undefined,
  });

  const { data: auction4Char1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[4] !== undefined ? [BigInt(pastAuctionIds[4]), BigInt(1)] : undefined,
  });

  const { data: auction4Char2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getAuctionCharacterData",
    // @ts-ignore
    args: pastAuctionIds[4] !== undefined ? [BigInt(pastAuctionIds[4]), BigInt(2)] : undefined,
  });

  // Read token addresses
  const { data: tokenAddress0 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[0] !== undefined ? [BigInt(pastAuctionIds[0])] : undefined,
  });

  const { data: tokenAddress1 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[1] !== undefined ? [BigInt(pastAuctionIds[1])] : undefined,
  });

  const { data: tokenAddress2 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[2] !== undefined ? [BigInt(pastAuctionIds[2])] : undefined,
  });

  const { data: tokenAddress3 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[3] !== undefined ? [BigInt(pastAuctionIds[3])] : undefined,
  });

  const { data: tokenAddress4 } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getCharacterTokenAddress",
    // @ts-ignore
    args: pastAuctionIds[4] !== undefined ? [BigInt(pastAuctionIds[4])] : undefined,
  });

  // Helper function to build auction data
  const buildAuction = (
    auctionId: number,
    endTime: bigint | undefined,
    char0: any,
    char1: any,
    char2: any,
    tokenAddress: string | undefined,
  ): PastAuction | null => {
    if (!endTime) return null;

    const characters: Character[] = [];

    if (char0) {
      characters[0] = {
        characterURI: char0[0],
        name: char0[1],
        symbol: char0[2],
        poolBalance: char0[3],
        isWinner: char0[4],
      };
    }
    if (char1) {
      characters[1] = {
        characterURI: char1[0],
        name: char1[1],
        symbol: char1[2],
        poolBalance: char1[3],
        isWinner: char1[4],
      };
    }
    if (char2) {
      characters[2] = {
        characterURI: char2[0],
        name: char2[1],
        symbol: char2[2],
        poolBalance: char2[3],
        isWinner: char2[4],
      };
    }

    // Filter out undefined characters
    const validCharacters = characters.filter(char => char !== undefined);

    if (validCharacters.length === 0) return null;

    // Find winner index
    let winnerIndex: number | null = null;
    validCharacters.forEach((char, index) => {
      if (char.isWinner) {
        winnerIndex = index;
      }
    });

    return {
      auctionId,
      characters: validCharacters,
      endTime,
      winnerIndex,
      tokenAddress,
    };
  };

  // Process auction data
  const pastAuctions = useMemo(() => {
    const auctions: PastAuction[] = [];

    // Process each past auction
    const auctionConfigs = [
      {
        id: pastAuctionIds[0],
        endTime: endTime0,
        chars: [auction0Char0, auction0Char1, auction0Char2],
        tokenAddress: tokenAddress0,
      },
      {
        id: pastAuctionIds[1],
        endTime: endTime1,
        chars: [auction1Char0, auction1Char1, auction1Char2],
        tokenAddress: tokenAddress1,
      },
      {
        id: pastAuctionIds[2],
        endTime: endTime2,
        chars: [auction2Char0, auction2Char1, auction2Char2],
        tokenAddress: tokenAddress2,
      },
      {
        id: pastAuctionIds[3],
        endTime: endTime3,
        chars: [auction3Char0, auction3Char1, auction3Char2],
        tokenAddress: tokenAddress3,
      },
      {
        id: pastAuctionIds[4],
        endTime: endTime4,
        chars: [auction4Char0, auction4Char1, auction4Char2],
        tokenAddress: tokenAddress4,
      },
    ];

    for (const config of auctionConfigs) {
      if (config.id !== undefined) {
        const auction = buildAuction(
          config.id,
          config.endTime,
          config.chars[0],
          config.chars[1],
          config.chars[2],
          config.tokenAddress,
        );
        if (auction) {
          auctions.push(auction);
        }
      }
    }

    return auctions;
  }, [
    pastAuctionIds,
    endTime0,
    endTime1,
    endTime2,
    endTime3,
    endTime4,
    auction0Char0,
    auction0Char1,
    auction0Char2,
    auction1Char0,
    auction1Char1,
    auction1Char2,
    auction2Char0,
    auction2Char1,
    auction2Char2,
    auction3Char0,
    auction3Char1,
    auction3Char2,
    auction4Char0,
    auction4Char1,
    auction4Char2,
    tokenAddress0,
    tokenAddress1,
    tokenAddress2,
    tokenAddress3,
    tokenAddress4,
  ]);

  const isLoading = isLoadingCurrentId;

  return {
    pastAuctions,
    isLoading,
    totalPastAuctions: currentAuctionId ? Number(currentAuctionId) : 0,
  };
}
