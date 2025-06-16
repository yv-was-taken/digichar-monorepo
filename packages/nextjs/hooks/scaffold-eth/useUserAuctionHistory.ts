import { useMemo } from "react";
import { useScaffoldReadContract } from "./useScaffoldReadContract";
import { useAccount } from "wagmi";

interface UserAuctionData {
  auctionId: number;
  characterBids: {
    characterIndex: number;
    bidAmount: bigint;
  }[];
  claimableTokens: bigint;
  hasClaimedTokens: boolean;
}

export function useUserAuctionHistory(pastAuctionIds: number[]) {
  const { address: connectedAddress } = useAccount();

  // Read user's bid balances for each past auction and character
  const userBidQueries = pastAuctionIds.flatMap(auctionId =>
    [0, 1, 2].map(characterIndex => {
      // eslint-disable-next-line react-hooks/rules-of-hooks
      const { data: bidBalance } = useScaffoldReadContract({
        contractName: "AuctionVault",
        functionName: "getUserBidBalance",
        // @ts-ignore - Type assertion for scaffold-eth hook compatibility
        args: connectedAddress ? [connectedAddress, BigInt(auctionId), characterIndex] : undefined,
      });

      return {
        auctionId,
        characterIndex,
        bidBalance: bidBalance || 0n,
      };
    }),
  );

  // Read claimable tokens for each past auction
  const claimableQueries = pastAuctionIds.map(auctionId => {
    // eslint-disable-next-line react-hooks/rules-of-hooks
    const { data: claimableTokens } = useScaffoldReadContract({
      contractName: "AuctionVault",
      functionName: "checkUnclaimedTokens",
      // @ts-ignore - Type assertion for scaffold-eth hook compatibility
      args: connectedAddress ? [connectedAddress, BigInt(auctionId)] : undefined,
    });

    // Note: hasClaimedTokens function doesn't exist in the contract, we'll track this via events instead
    const hasClaimedTokens = false;

    return {
      auctionId,
      claimableTokens: claimableTokens || 0n,
      hasClaimedTokens,
    };
  });

  // Process user auction data
  const userAuctionHistory = useMemo(() => {
    if (!connectedAddress) return [];

    return pastAuctionIds
      .map(auctionId => {
        // Get bids for this auction
        const characterBids = userBidQueries
          .filter(query => query.auctionId === auctionId && query.bidBalance > 0n)
          .map(query => ({
            characterIndex: query.characterIndex,
            bidAmount: query.bidBalance,
          }));

        // Get claimable data for this auction
        const claimData = claimableQueries.find(query => query.auctionId === auctionId);

        return {
          auctionId,
          characterBids,
          claimableTokens: claimData?.claimableTokens || 0n,
          hasClaimedTokens: claimData?.hasClaimedTokens || false,
        } as UserAuctionData;
      })
      .filter(data => data.characterBids.length > 0 || data.claimableTokens > 0n);
  }, [connectedAddress, pastAuctionIds, userBidQueries, claimableQueries]);

  // Calculate summary statistics
  const userStats = useMemo(() => {
    const totalBids = userAuctionHistory.reduce((sum, auction) => sum + auction.characterBids.length, 0);

    const totalBidAmount = userAuctionHistory.reduce(
      (sum, auction) => sum + auction.characterBids.reduce((auctionSum, bid) => auctionSum + bid.bidAmount, 0n),
      0n,
    );

    const totalClaimableTokens = userAuctionHistory.reduce((sum, auction) => sum + auction.claimableTokens, 0n);

    const auctionsWithClaimableTokens = userAuctionHistory.filter(
      auction => auction.claimableTokens > 0n && !auction.hasClaimedTokens,
    ).length;

    return {
      totalBids,
      totalBidAmount,
      totalClaimableTokens,
      auctionsWithClaimableTokens,
      auctionsParticipated: userAuctionHistory.length,
    };
  }, [userAuctionHistory]);

  return {
    userAuctionHistory,
    userStats,
    isConnected: !!connectedAddress,
  };
}
