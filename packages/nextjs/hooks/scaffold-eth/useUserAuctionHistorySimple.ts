import { useMemo } from "react";
import { useScaffoldReadContract } from "./useScaffoldReadContract";
import { useAccount } from "wagmi";

export function useUserAuctionHistorySimple(pastAuctionIds: number[]) {
  const { address: connectedAddress } = useAccount();

  // Limit to first 2 auctions to avoid hook order issues
  const auction1Id = pastAuctionIds[0];
  const auction2Id = pastAuctionIds[1];

  // Read user bid balances for auction 1
  const { data: auction1Char0Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction1Id ? [connectedAddress, BigInt(auction1Id), 0] : undefined,
  });

  const { data: auction1Char1Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction1Id ? [connectedAddress, BigInt(auction1Id), 1] : undefined,
  });

  const { data: auction1Char2Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction1Id ? [connectedAddress, BigInt(auction1Id), 2] : undefined,
  });

  // Read user bid balances for auction 2
  const { data: auction2Char0Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction2Id ? [connectedAddress, BigInt(auction2Id), 0] : undefined,
  });

  const { data: auction2Char1Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction2Id ? [connectedAddress, BigInt(auction2Id), 1] : undefined,
  });

  const { data: auction2Char2Bid } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "getUserBidBalance",
    // @ts-ignore
    args: connectedAddress && auction2Id ? [connectedAddress, BigInt(auction2Id), 2] : undefined,
  });

  // Read claimable tokens
  const { data: auction1ClaimableTokens } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "checkUnclaimedTokens",
    // @ts-ignore
    args: connectedAddress && auction1Id ? [connectedAddress, BigInt(auction1Id)] : undefined,
  });

  const { data: auction2ClaimableTokens } = useScaffoldReadContract({
    contractName: "AuctionVault",
    functionName: "checkUnclaimedTokens",
    // @ts-ignore
    args: connectedAddress && auction2Id ? [connectedAddress, BigInt(auction2Id)] : undefined,
  });

  // Process user auction data
  const userAuctionHistory = useMemo(() => {
    if (!connectedAddress) return [];

    const auctions = [];

    // Process auction 1
    if (auction1Id) {
      const characterBids = [];
      if (auction1Char0Bid && auction1Char0Bid > 0n) {
        characterBids.push({ characterIndex: 0, bidAmount: auction1Char0Bid });
      }
      if (auction1Char1Bid && auction1Char1Bid > 0n) {
        characterBids.push({ characterIndex: 1, bidAmount: auction1Char1Bid });
      }
      if (auction1Char2Bid && auction1Char2Bid > 0n) {
        characterBids.push({ characterIndex: 2, bidAmount: auction1Char2Bid });
      }

      if (characterBids.length > 0 || (auction1ClaimableTokens && auction1ClaimableTokens > 0n)) {
        auctions.push({
          auctionId: auction1Id,
          characterBids,
          claimableTokens: auction1ClaimableTokens || 0n,
          hasClaimedTokens: false,
        });
      }
    }

    // Process auction 2
    if (auction2Id) {
      const characterBids = [];
      if (auction2Char0Bid && auction2Char0Bid > 0n) {
        characterBids.push({ characterIndex: 0, bidAmount: auction2Char0Bid });
      }
      if (auction2Char1Bid && auction2Char1Bid > 0n) {
        characterBids.push({ characterIndex: 1, bidAmount: auction2Char1Bid });
      }
      if (auction2Char2Bid && auction2Char2Bid > 0n) {
        characterBids.push({ characterIndex: 2, bidAmount: auction2Char2Bid });
      }

      if (characterBids.length > 0 || (auction2ClaimableTokens && auction2ClaimableTokens > 0n)) {
        auctions.push({
          auctionId: auction2Id,
          characterBids,
          claimableTokens: auction2ClaimableTokens || 0n,
          hasClaimedTokens: false,
        });
      }
    }

    return auctions;
  }, [
    connectedAddress,
    auction1Id,
    auction2Id,
    auction1Char0Bid,
    auction1Char1Bid,
    auction1Char2Bid,
    auction2Char0Bid,
    auction2Char1Bid,
    auction2Char2Bid,
    auction1ClaimableTokens,
    auction2ClaimableTokens,
  ]);

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
