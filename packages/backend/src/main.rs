use std::sync::Arc;

use eyre::Result;

use ethers::contract::abigen;
use ethers::providers::Http;
use ethers::providers::Provider;
use ethers::types::Address;

const AUCTION_VAULT_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const CONFIG_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const RPC_URL: &str = "https://rpc_url_placeholder.com";

abigen!(Config, "./abis/Config.json");

//let config_contract = AuctionVault::new(Address::CONFIG_CONTRACT_ADDRESS.parse()?, client)
fn main() {
    println!("Hello, world!");
}

//main protocol activity contract actions

fn get_current_auction_closing_timestamp() -> Result<u256, Err> {
    abigen!(AuctionVault, "./abis/AuctionVault.json");
    let provider = Provider::<Http>::try_from(RPC_URL)?;
    let client = Arc::new(provider);
    let auction_vault =
        AuctionVault::new(Address::AUCTION_VAULT_CONTRACT_ADDRESS.parse()?, client);
    current_auction_id: u256 = auction_vault.auction_id();
    auction_closing_timestamp: u256 = match auction_vault.get_auction_end_time(current_auction_id) {
        Ok(_auction_closing_timestamp) => Ok(_auction_closing_timestamp),
        Err(err) => Err(err)
    };
}

fn is_auction_closed() {}

fn create_auction() {}

fn close_auction(Address top_bidder, uint winning_character_index) -> Result<(), Err> {
        abigen!(AuctionVault, "./abis/AuctionVault.json");
        let provider = Provider::<Http>::try_from(RPC_URL)?;
        let client = Arc::new(provider);
        let auction_vault =
            AuctionVault::new(Address::AUCTION_VAULT_CONTRACT_ADDRESS.parse()?, client);
        match auction_vault.close_auction() {
            Ok(_) => Ok(()),
            Err(err) => Err(err)
        }

}

fn create_characters() {}

fn upload_character_to_ipfs() {}

fn download_character_avatar() {}

//config update contract actions
fn set_weth() {}
fn set_lp_lock_bps() {}
fn set_swap_router() {}
fn set_swap_factory() {}
fn set_auction_vault() {}
fn set_auction_duration() {}
fn set_digichar_factory() {}
fn update_protocol_admin() {}
fn set_protocol_admin_tax_bps() {}
fn set_character_owner_tax_bps() {}
fn set_ownership_certificate() {}

//@dev is this needed? or can we bulk upload in one ipfs call...
// TBD :)
fn upload_character_avatar_to_ipfs() {}

struct Character {
    name: String,
    symbol: String,
    description: String,
    avatar: String,
}
