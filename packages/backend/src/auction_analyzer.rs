use ethers::{
    prelude::*,
    providers::{Provider, Http},
    types::{Address, Filter, U256},
    abi::RawLog,
};
use std::collections::HashMap;
use std::sync::Arc;
use eyre::Result;

abigen!(
    AuctionVaultEvents,
    r#"[
        event BidPlaced(uint256 indexed auctionId, address indexed user, uint256 amount, uint256 characterId)
        event BidWithdrawn(uint256 auctionId, address user, uint256 withdrawAmount)
    ]"#
);

#[derive(Debug, Clone)]
struct BidderData {
    address: Address,
    total_bid_amount: U256,
    bid_count: u32,
}

#[derive(Debug, Clone)]
struct CharacterData {
    character_index: u8,
    total_pool_balance: U256,
    unique_bidders: u32,
    bid_count: u32,
}

pub struct AuctionAnalyzer {
    provider: Arc<Provider<Http>>,
    auction_vault_address: Address,
}

impl AuctionAnalyzer {
    pub fn new(provider: Arc<Provider<Http>>, auction_vault_address: Address) -> Self {
        Self {
            provider,
            auction_vault_address,
        }
    }

    async fn analyze_auction(
        &self,
        auction_id: u64,
        from_block: Option<u64>,
        to_block: Option<BlockNumber>,
    ) -> Result<(Address, u8)> {
        let mut character_pools: HashMap<u8, CharacterData> = HashMap::new();
        let mut bidders_per_character: HashMap<u8, HashMap<Address, BidderData>> = HashMap::new();

        // Initialize character data for indices 0, 1, 2
        for i in 0u8..3u8 {
            character_pools.insert(i, CharacterData {
                character_index: i,
                total_pool_balance: U256::zero(),
                unique_bidders: 0,
                bid_count: 0,
            });
            bidders_per_character.insert(i, HashMap::new());
        }

        // Query BidPlaced events for the specific auction
        let bid_filter = Filter::new()
            .address(self.auction_vault_address)
            .topic0(BidPlacedFilter::signature())
            .topic1(U256::from(auction_id))
            .from_block(from_block.unwrap_or(0))
            .to_block(to_block.unwrap_or(BlockNumber::Latest));

        let bid_logs = self.provider.get_logs(&bid_filter).await?;
        
        for log in bid_logs {
            if let Ok(bid_event) = <BidPlacedFilter as EthLogDecode>::decode_log(&RawLog {
                topics: log.topics,
                data: log.data.to_vec(),
            }) {
                let character_idx = bid_event.character_id.as_u64() as u8;
                
                // Update character pool data
                if let Some(character_data) = character_pools.get_mut(&character_idx) {
                    character_data.total_pool_balance += bid_event.amount;
                    character_data.bid_count += 1;
                }

                // Update bidder data for this character
                let bidders_map = bidders_per_character.get_mut(&character_idx).unwrap();
                let bidder_entry = bidders_map.entry(bid_event.user).or_insert(BidderData {
                    address: bid_event.user,
                    total_bid_amount: U256::zero(),
                    bid_count: 0,
                });

                bidder_entry.total_bid_amount += bid_event.amount;
                bidder_entry.bid_count += 1;
            }
        }

        // Update unique bidder counts
        for (char_idx, bidders_map) in &bidders_per_character {
            if let Some(character_data) = character_pools.get_mut(char_idx) {
                character_data.unique_bidders = bidders_map.len() as u32;
            }
        }

        // Handle bid withdrawals
        let withdrawal_filter = Filter::new()
            .address(self.auction_vault_address)
            .topic0(BidWithdrawnFilter::signature())
            .from_block(from_block.unwrap_or(0))
            .to_block(to_block.unwrap_or(BlockNumber::Latest));

        let withdrawal_logs = self.provider.get_logs(&withdrawal_filter).await?;
        
        for log in withdrawal_logs {
            if let Ok(withdrawal_event) = <BidWithdrawnFilter as EthLogDecode>::decode_log(&RawLog {
                topics: log.topics,
                data: log.data.to_vec(),
            }) {
                // Extract auction_id from the event data
                if withdrawal_event.auction_id == U256::from(auction_id) {
                    // Note: The withdrawal event doesn't include character index
                    // We'd need to track this differently or query contract state
                    println!("Warning: Withdrawal detected for auction {} but character index not available in event", auction_id);
                }
            }
        }

        // Find winning character (highest pool balance)
        let winning_character = character_pools
            .values()
            .max_by_key(|char_data| char_data.total_pool_balance)
            .cloned()
            .unwrap_or(CharacterData {
                character_index: 0,
                total_pool_balance: U256::zero(),
                unique_bidders: 0,
                bid_count: 0,
            });

        // Find top bidder for the winning character
        let top_bidder_address = bidders_per_character
            .get(&winning_character.character_index)
            .and_then(|bidders| bidders
                .values()
                .max_by_key(|bidder| bidder.total_bid_amount)
                .map(|bidder| bidder.address))
            .unwrap_or(Address::zero());

        Ok((top_bidder_address, winning_character.character_index))
    }

    pub async fn get_auction_winner(
        &self,
        auction_id: u64,
    ) -> Result<(Address, u8)> {
        self.analyze_auction(auction_id, None, None).await
    }
}