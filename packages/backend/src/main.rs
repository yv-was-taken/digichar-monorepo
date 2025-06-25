use std::sync::Arc;

use eyre::Result;

use ethers::contract::abigen;
use ethers::providers::Http;
use ethers::providers::Provider;
use ethers::types::Address;
use ethers::types::H160;
use ethers::types::U256;

const AUCTION_VAULT_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const CONFIG_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const RPC_URL: &str = "https://rpc_url_placeholder.com";

//abigen!(Config, "./abis/Config.json");
//let config_contract = AuctionVault::new(Address::CONFIG_CONTRACT_ADDRESS.parse()?, client)
//
//

struct Character {
    name: String,
    symbol: String,
    description: String,
    avatar: String,
}

fn main() {
    println!("Hello, world!");
}

//core protocol activity contract writes

fn create_auction() {}

async fn close_auction(top_bidder: Address, winning_character_index: u8) -> Result<()> {
    abigen!(AuctionVault, "./abis/AuctionVault.json");
    let provider = Provider::<Http>::try_from(RPC_URL)?;
    let client = Arc::new(provider);
    let auction_vault =
        AuctionVault::new(AUCTION_VAULT_CONTRACT_ADDRESS.parse::<Address>()?, client);
    auction_vault
        .close_current_auction(top_bidder, winning_character_index)
        .call()
        .await?;
    Ok(())
}

//core protocol activity contract reads
async fn get_current_auction_closing_timestamp() -> Result<U256> {
    abigen!(AuctionVault, "./abis/AuctionVault.json");
    let provider = Provider::<Http>::try_from(RPC_URL)?;
    let client = Arc::new(provider);
    let auction_vault =
        AuctionVault::new(AUCTION_VAULT_CONTRACT_ADDRESS.parse::<Address>()?, client);
    let current_auction_id: U256 = auction_vault.auction_id().call().await?;
    let auction_closing_timestamp: U256 = auction_vault
        .get_auction_end_time(current_auction_id)
        .call()
        .await?;
    Ok(auction_closing_timestamp)
}

fn is_auction_closed() {}

//LLM calling fns for character metadata creation
async fn create_characters() {}

async fn upload_character_to_ipfs() {}

fn download_character_avatar() {}

//config update contract actions
async fn set_weth() {}
async fn set_lp_lock_bps() {}
async fn set_swap_router() {}
async fn set_swap_factory() {}
async fn set_auction_vault() {}
async fn set_auction_duration() {}
async fn set_digichar_factory() {}
async fn update_protocol_admin() {}
async fn set_protocol_admin_tax_bps() {}
async fn set_character_owner_tax_bps() {}
async fn set_ownership_certificate() {}

//@dev is this needed? or can we bulk upload in one ipfs call...
// TBD :)
fn upload_character_avatar_to_ipfs() {}
