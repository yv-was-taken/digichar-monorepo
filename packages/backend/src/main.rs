use eyre::Result;
use ethers::types::U256;
use tokio::time::{Duration, sleep};

mod modules;

use modules::auction_vault::AuctionVaultService;
use modules::characters::CharacterService;

#[tokio::main]
async fn main() {
    loop {
        match run_protocol_loop().await {
            Ok(_) => (),
            Err(e) => {
                eprintln!("Error in protocol loop: {e}");
                println!("Waiting 60 seconds before retrying...");
                sleep(Duration::from_secs(60)).await;
            }
        }
    }
}

async fn run_protocol_loop() -> Result<()> {
    let auction_service = AuctionVaultService::new()?;
    let character_service = CharacterService::new();

    loop {
        let current_auction_closing_timestamp = auction_service.get_current_auction_closing_timestamp().await?;
        let current_timestamp = U256::from(chrono::Utc::now().timestamp());

        let current_auction_id = auction_service.get_current_auction_id().await?;
        let mut is_current_auction_open = auction_service.is_auction_open(current_auction_id).await?;

        while is_current_auction_open {
            let mut interval_until_auction_close = tokio::time::interval(Duration::from_secs(
                (current_timestamp - current_auction_closing_timestamp).as_u64(),
            ));
            interval_until_auction_close.tick().await;

            // Analyze the auction to determine the winner
            let (top_bidder, winning_character_index) = auction_service
                .get_auction_winner(current_auction_id.as_u64())
                .await?;
            
            auction_service.close_auction(top_bidder, winning_character_index).await?;
            is_current_auction_open = auction_service.is_auction_open(current_auction_id).await?;

            let characters = character_service.create_characters().await?;

            let character_uris: [String; 3] =
                futures::future::join_all(characters.iter().map(|c| character_service.upload_character_to_ipfs(c)))
                    .await
                    .into_iter()
                    .collect::<Result<Vec<String>>>()?
                    .try_into()
                    .unwrap();

            auction_service.create_auction(characters, character_uris).await?;
        }
    }
}