use ethers::abi::RawLog;
use ethers::contract::abigen;
use ethers::prelude::{EthEvent, EthLogDecode};
use ethers::providers::{Http, Middleware, Provider};
use ethers::types::{Address, BlockNumber, Filter, U256};
use eyre::Result;
use std::collections::HashMap;
use std::sync::Arc;

use crate::modules::config::{AUCTION_VAULT_CONTRACT_ADDRESS, RPC_URL};
use crate::modules::types::Character;

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

pub struct AuctionVaultService {
    provider: Arc<Provider<Http>>,
    auction_vault_address: Address,
}

impl AuctionVaultService {
    pub fn new() -> Result<Self> {
        let provider = Provider::<Http>::try_from(RPC_URL)?;
        let client = Arc::new(provider);
        let auction_vault_address = AUCTION_VAULT_CONTRACT_ADDRESS.parse::<Address>()?;

        Ok(Self {
            provider: client,
            auction_vault_address,
        })
    }

    pub async fn create_auction(
        &self,
        character_uris: [String; 3],
        character_names: [String; 3],
        character_symbols: [String; 3],
    ) -> Result<()> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let auction_vault = AuctionVault::new(self.auction_vault_address, self.provider.clone());
        auction_vault
            .create_auction(character_uris, character_names, character_symbols)
            .call()
            .await?;
        Ok(())
    }

    pub async fn close_auction(
        &self,
        top_bidder: Address,
        winning_character_index: u8,
    ) -> Result<()> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let auction_vault = AuctionVault::new(self.auction_vault_address, self.provider.clone());
        auction_vault
            .close_current_auction(top_bidder, winning_character_index)
            .call()
            .await?;
        Ok(())
    }

    pub async fn get_current_auction_id(&self) -> Result<U256> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let auction_vault = AuctionVault::new(self.auction_vault_address, self.provider.clone());
        let current_auction_id: U256 = auction_vault.auction_id().call().await?;
        Ok(current_auction_id)
    }

    pub async fn get_current_auction_closing_timestamp(&self) -> Result<U256> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let auction_vault = AuctionVault::new(self.auction_vault_address, self.provider.clone());
        let current_auction_id: U256 = auction_vault.auction_id().call().await?;
        let auction_closing_timestamp: U256 = auction_vault
            .get_auction_end_time(current_auction_id)
            .call()
            .await?;
        Ok(auction_closing_timestamp)
    }

    pub async fn is_current_auction_expired(&self) -> Result<bool> {
        let current_auction_ending_timestamp: U256 =
            self.get_current_auction_closing_timestamp().await?;
        let current_timestamp = U256::from(chrono::Utc::now().timestamp());
        Ok(current_timestamp > current_auction_ending_timestamp)
    }

    pub async fn is_auction_open(&self, auction_id: U256) -> Result<bool> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let auction_vault = AuctionVault::new(self.auction_vault_address, self.provider.clone());
        match auction_vault.is_auction_open(auction_id).call().await {
            Ok(result) => Ok(result),
            Err(err) => Err(eyre::eyre!(format!(
                "failed reading contract while calling `is_auction_open` with err {}",
                err
            ))),
        }
    }

    pub fn get_provider(&self) -> Arc<Provider<Http>> {
        self.provider.clone()
    }

    pub fn get_auction_vault_address(&self) -> Address {
        self.auction_vault_address
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
            character_pools.insert(
                i,
                CharacterData {
                    character_index: i,
                    total_pool_balance: U256::zero(),
                    unique_bidders: 0,
                    bid_count: 0,
                },
            );
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
            if let Ok(withdrawal_event) =
                <BidWithdrawnFilter as EthLogDecode>::decode_log(&RawLog {
                    topics: log.topics,
                    data: log.data.to_vec(),
                })
            {
                // Extract auction_id from the event data
                if withdrawal_event.auction_id == U256::from(auction_id) {
                    // Note: The withdrawal event doesn't include character index
                    // We'd need to track this differently or query contract state
                    println!(
                        "Warning: Withdrawal detected for auction {auction_id} but character index not available in event"
                    );
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
            .and_then(|bidders| {
                bidders
                    .values()
                    .max_by_key(|bidder| bidder.total_bid_amount)
                    .map(|bidder| bidder.address)
            })
            .unwrap_or(Address::zero());

        Ok((top_bidder_address, winning_character.character_index))
    }

    pub async fn get_auction_winner(&self, auction_id: u64) -> Result<(Address, u8)> {
        self.analyze_auction(auction_id, None, None).await
    }
}
