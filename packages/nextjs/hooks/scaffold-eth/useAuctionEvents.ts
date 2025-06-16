import { useMemo } from "react";
import { useScaffoldEventHistory } from "./useScaffoldEventHistory";

interface BidEvent {
  bidder: string;
  auctionId: bigint;
  characterIndex: number;
  amount: bigint;
  timestamp: number;
  blockNumber: bigint;
  transactionHash: string;
}

interface WithdrawEvent {
  user: string;
  auctionId: bigint;
  withdrawAmount: bigint;
  timestamp: number;
  blockNumber: bigint;
  transactionHash: string;
}

export function useAuctionEvents(auctionId?: number) {
  // Get bid events
  const { data: bidEvents } = useScaffoldEventHistory({
    contractName: "AuctionVault",
    eventName: "BidPlaced",
    fromBlock: 0n,
    blockData: true,
    transactionData: true,
    receiptData: true,
  });

  // Get withdraw events
  const { data: withdrawEvents } = useScaffoldEventHistory({
    contractName: "AuctionVault",
    eventName: "BidWithdrawn",
    fromBlock: 0n,
    blockData: true,
    transactionData: true,
    receiptData: true,
  });

  // Get token claim events (currently unused but available for future features)
  // const { data: claimEvents } = useScaffoldEventHistory({
  //   contractName: "AuctionVault",
  //   eventName: "TokensClaimed",
  //   fromBlock: 0n,
  //   blockData: true,
  //   transactionData: true,
  //   receiptData: true,
  // });

  // Process bid events
  const processedBidEvents = useMemo(() => {
    if (!bidEvents) return [];

    return bidEvents.map(
      (event: any) =>
        ({
          bidder: event.args._user || "",
          auctionId: event.args._auctionId || 0n,
          characterIndex: Number(event.args._characterId || 0),
          amount: event.args._amount || 0n,
          timestamp: Number(event.block?.timestamp || 0),
          blockNumber: event.blockNumber || 0n,
          transactionHash: event.transactionHash || "",
        }) as BidEvent,
    );
  }, [bidEvents]);

  // Process withdraw events
  const processedWithdrawEvents = useMemo(() => {
    if (!withdrawEvents) return [];

    return withdrawEvents.map(
      (event: any) =>
        ({
          user: event.args.user || "",
          auctionId: event.args._auctionId || 0n,
          withdrawAmount: event.args._withdrawAmount || 0n,
          timestamp: Number(event.block?.timestamp || 0),
          blockNumber: event.blockNumber || 0n,
          transactionHash: event.transactionHash || "",
        }) as WithdrawEvent,
    );
  }, [withdrawEvents]);

  // Get auction activity summary
  const auctionActivity = useMemo(() => {
    if (auctionId === undefined) return null;

    const bids = processedBidEvents.filter(event => Number(event.auctionId) === auctionId);
    const withdrawals = processedWithdrawEvents.filter(event => Number(event.auctionId) === auctionId);

    // Group bids by character
    const bidsByCharacter = bids.reduce(
      (acc, bid) => {
        if (!acc[bid.characterIndex]) {
          acc[bid.characterIndex] = [];
        }
        acc[bid.characterIndex].push(bid);
        return acc;
      },
      {} as Record<number, BidEvent[]>,
    );

    // Sort bids by timestamp for each character
    Object.keys(bidsByCharacter).forEach(characterIndex => {
      bidsByCharacter[Number(characterIndex)].sort((a, b) => a.timestamp - b.timestamp);
    });

    // Get unique bidders
    const uniqueBidders = [...new Set(bids.map(bid => bid.bidder))];

    // Calculate total volume
    const totalVolume = bids.reduce((sum, bid) => sum + bid.amount, 0n);

    return {
      auctionId: BigInt(auctionId),
      bids,
      withdrawals,
      bidsByCharacter,
      uniqueBidders,
      totalBids: bids.length,
      totalVolume,
    };
  }, [auctionId, processedBidEvents, processedWithdrawEvents]);

  return {
    bidEvents: processedBidEvents,
    withdrawEvents: processedWithdrawEvents,
    auctionActivity,
    isLoading: !bidEvents || !withdrawEvents,
  };
}
