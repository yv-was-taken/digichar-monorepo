use std::sync::Arc;

use eyre::Result;

use ethers::contract::abigen;
use ethers::providers::Http;
use ethers::providers::Provider;
use ethers::types::Address;
use ethers::types::U256;
use hyper::{Body, Client, Method, Request};
use hyper_tls::HttpsConnector;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use std::path::Path;
use tokio::fs::{self, File};
use tokio::io::AsyncWriteExt;

const AUCTION_VAULT_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const CONFIG_CONTRACT_ADDRESS: &str = "0x2345678901234567890123456789012345678901";
const RPC_URL: &str = "https://rpc_url_placeholder.com";
const IPFS_API_URL: &str = "http://127.0.0.1:5001";

//abigen!(Config, "./abis/Config.json");
//let config_contract = AuctionVault::new(Address::CONFIG_CONTRACT_ADDRESS.parse()?, client)
//
//

#[derive(Debug, Deserialize, Serialize)]
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

//@dev note: the 'characterURIs' input parameter in the contract level is expected to just be the
// ipfs hash, i.e. https://ipfs.com/ipfs/{HASH_GOES_HERE}
// may be worth refactoring on contract side in near future, but until then, this is what it should
// be on backend level, just FYI
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
async fn create_characters() -> Result<Vec<Character>> {
    let api_key = env::var("GEMINI_API_KEY").expect("GEMINI_API_KEY must be set");
    let url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

    let prompt = r#"generate a list of memecoins. each memecoin should be a character designed in a way that is similar to other characters throughout recent history that have accrued a fandom. think Sanrio characters, Dogecoin, Sonic, Spongebob, Naruto, things like that. Each memecoin listing you list off should include:

- name

- ticker (5 characters maximum, think like stock market company abbreviations for each character)

- description (one sentence maximum, no more than twelve words)

- image for the character (generate an image for each character, one character per image, include the image with the other attributes of the listing)

list off 3 characters from each different style from the following list of styles:

- sanrio

- kawaii

- traditional (think similar to other crypto memecoins, i.e. doge, shib, popcat, pepe)

- newage meme culture (think wojak, chud aka "nothing ever happens", gigachad, etc)

- bizarro (wild card)"#;

    let mut characters = Vec::new();
    let https = HttpsConnector::new();
    let client = Client::builder().build::<_, Body>(https);

    for _ in 0..15 {
        let req = Request::builder()
            .method(Method::POST)
            .uri(url)
            .header("x-goog-api-key", &api_key)
            .header("Content-Type", "application/json")
            .body(Body::from(
                json!({
                    "contents": [{
                        "parts": [{
                            "text": prompt
                        }]
                    }]
                })
                .to_string(),
            ))?;

        let res = client.request(req).await?;
        let body_bytes = hyper::body::to_bytes(res.into_body()).await?;
        let response: serde_json::Value = serde_json::from_slice(&body_bytes)?;

        if let Some(candidates) = response.get("candidates").and_then(|c| c.as_array()) {
            for candidate in candidates {
                if let Some(content) = candidate.get("content").and_then(|c| c.get("parts")) {
                    if let Some(text) = content[0].get("text").and_then(|t| t.as_str()) {
                        let lines: Vec<&str> = text.lines().collect();
                        for i in (0..lines.len()).step_by(5) {
                            if i + 4 < lines.len() {
                                let name = lines[i].replace("- name: ", "");
                                let ticker = lines[i + 1].replace("- ticker: ", "");
                                let description = lines[i + 2].replace("- description: ", "");
                                let image = lines[i + 3].replace("- image: ", "");
                                characters.push(Character {
                                    name,
                                    symbol: ticker,
                                    description,
                                    avatar: image,
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(characters)
}

async fn upload_character_to_ipfs(character: &Character) -> Result<String> {
    let client = Client::new();
    let url = format!("{}/api/v0/add", IPFS_API_URL);

    let character_json = serde_json::to_string(character)?;

    let boundary = "------------------------7d8f3e0e1b2a3c4";
    let mut body = Vec::new();
    body.extend_from_slice(b"--");
    body.extend_from_slice(boundary.as_bytes());
    body.extend_from_slice(b"\r\n");
    body.extend_from_slice(b"Content-Disposition: form-data; name=\"file\"\r\n");
    body.extend_from_slice(b"Content-Type: application/json\r\n\r\n");
    body.extend_from_slice(character_json.as_bytes());
    body.extend_from_slice(b"\r\n--");
    body.extend_from_slice(boundary.as_bytes());
    body.extend_from_slice(b"--\r\n");

    let req = Request::builder()
        .method(Method::POST)
        .uri(url)
        .header(
            "Content-Type",
            format!("multipart/form-data; boundary={}", boundary),
        )
        .body(Body::from(body))?;

    let res = client.request(req).await?;
    let body_bytes = hyper::body::to_bytes(res.into_body()).await?;
    let response: serde_json::Value = serde_json::from_slice(&body_bytes)?;

    if let Some(hash) = response.get("Hash").and_then(|h| h.as_str()) {
        Ok(format!("ipfs://{}", hash))
    } else {
        Err(eyre::eyre!("Failed to get IPFS hash from response"))
    }
}

async fn download_character_avatar(character: &Character) -> Result<()> {
    let https = HttpsConnector::new();
    let client = Client::builder().build::<_, Body>(https);
    let req = Request::builder()
        .method(Method::GET)
        .uri(&character.avatar)
        .body(Body::empty())?;
    let res = client.request(req).await?;
    let body_bytes = hyper::body::to_bytes(res.into_body()).await?;

    let file_extension = Path::new(&character.avatar)
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("png");
    let file_name = format!("{}.{}", character.name, file_extension);

    fs::create_dir_all("images").await?;
    let path = Path::new("images").join(file_name);
    let mut file = File::create(&path).await?;
    file.write_all(&body_bytes).await?;

    Ok(())
}

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
