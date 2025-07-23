use eyre::Result;
use tokio::time::{Duration, sleep};

mod modules;

use modules::auction_vault::AuctionVaultService;
use modules::characters::CharacterService;
use modules::error_decoder::{decode_contract_error, load_abi};
use modules::helpers::{format_duration, safe_duration_calculation};

#[tokio::main]
async fn main() {
    // Load environment variables from .env file
    dotenv::dotenv().ok();

    println!("[Main] Starting DigiChar backend service...");
    loop {
        match run_protocol_loop().await {
            Ok(_) => (),
            Err(e) => {
                eprintln!("[Main] Error in protocol loop: {e}");

                // Try to decode contract errors using the ABI
                let err_str = e.to_string();
                if err_str.contains("Contract call reverted") || err_str.contains("0x") {
                    if let Ok(abi_content) = load_abi("./abis/AuctionVault.json") {
                        let decoded_error = decode_contract_error(&err_str, &abi_content);
                        eprintln!("[Main] Decoded error: {}", decoded_error);

                        if decoded_error.contains("OnlyProtocolAdmin") {
                            eprintln!(
                                "[Main] Make sure PROTOCOL_ADMIN_PRIVATE_KEY env var is set correctly"
                            );
                        }
                    }
                }

                println!("[Main] Waiting 10 seconds before retrying...");
                sleep(Duration::from_secs(10)).await;
            }
        }
    }
}

async fn run_protocol_loop() -> Result<()> {
    println!("[Protocol] Initializing services...");
    let auction_service = AuctionVaultService::new()?;
    let character_service = CharacterService::new();
    println!("[Protocol] Services initialized successfully");

    loop {
        println!("[Protocol] Starting new protocol loop iteration");

        let current_auction_closing_timestamp = auction_service
            .get_current_auction_closing_timestamp()
            .await?;

        let current_auction_id = auction_service.get_current_auction_id().await?;
        let mut is_current_auction_open =
            auction_service.is_auction_open(current_auction_id).await?;

        while is_current_auction_open {
            println!(
                "[Protocol] Auction {} is open, waiting for it to close...",
                current_auction_id
            );
            let current_time = chrono::Utc::now().timestamp();
            let duration_secs =
                safe_duration_calculation(current_auction_closing_timestamp, current_time);

            if duration_secs <= 0 {
                println!("[Protocol] Auction has already expired, proceeding to close it");
                // Don't break - continue to close the auction
            } else {
                let duration_str = format_duration(duration_secs);
                println!("[Protocol] Waiting {} until auction closes", duration_str);

                // Sleep until the auction closes
                tokio::time::sleep(Duration::from_secs(duration_secs as u64)).await;
            }

            println!("[Protocol] Auction closing time reached, analyzing auction results...");

            // Analyze the auction to determine the winner
            let (top_bidder, winning_character_index) = auction_service
                .get_auction_winner(current_auction_id.as_u64())
                .await?;

            println!(
                "[Protocol] Attempting to close auction with winner: {} (character: {})",
                top_bidder, winning_character_index
            );

            auction_service
                .close_auction(top_bidder, winning_character_index)
                .await?;

            println!("[Protocol] Checking if auction is still open after close attempt...");
            is_current_auction_open = auction_service.is_auction_open(current_auction_id).await?;

            if !is_current_auction_open {
                println!("[Protocol] Auction closed successfully, creating new characters...");
            } else {
                println!(
                    "[Protocol] WARNING: Auction still appears to be open after close attempt!"
                );
            }

            let characters = character_service.create_characters().await?;
            println!("[Protocol] Created {} new characters", characters.len());

            println!("[Protocol] Uploading characters to IPFS...");
            let character_uris: [String; 3] = futures::future::join_all(
                characters
                    .iter()
                    .map(|c| character_service.upload_character_to_ipfs(c)),
            )
            .await
            .into_iter()
            .collect::<Result<Vec<String>>>()?
            .try_into()
            .unwrap();

            let character_names: [String; 3] = characters
                .iter()
                .map(|character| character.name.clone())
                .collect::<Vec<String>>()
                .try_into()
                .unwrap();
            let character_symbols: [String; 3] = characters
                .iter()
                .map(|character| character.symbol.clone())
                .collect::<Vec<String>>()
                .try_into()
                .unwrap();

            auction_service
                .create_auction(character_uris, character_names, character_symbols)
                .await?;
        }
    }
}
