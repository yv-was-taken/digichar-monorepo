use std::env;
use std::path::Path;
use eyre::Result;
use hyper::{Body, Client, Method, Request};
use hyper_tls::HttpsConnector;
use serde_json::json;
use tokio::fs::{self, File};
use tokio::io::AsyncWriteExt;

use crate::modules::types::Character;

pub struct CharacterService;

impl CharacterService {
    pub fn new() -> Self {
        Self
    }

    pub async fn create_characters(&self) -> Result<Vec<Character>> {
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

        for idx in 0..15 {
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
                    if let Some(content) = candidate.get("content").and_then(|c| c.get("parts"))
                        && let Some(text) = content[0].get("text").and_then(|t| t.as_str())
                    {
                        let lines: Vec<&str> = text.lines().collect();
                        for i in (0..lines.len()).step_by(5) {
                            if i + 4 < lines.len() {
                                let name = lines[i].replace("- name: ", "");
                                let ticker = lines[i + 1].replace("- ticker: ", "");
                                let description = lines[i + 2].replace("- description: ", "");
                                let image_url = lines[i + 3].replace("- image: ", "");
                                
                                // Create unique filename based on character name and ticker
                                let sanitized_name = name.replace(" ", "_").replace("/", "_").replace(":", "_");
                                let avatar_file_name = format!("{}_{}_{}.png", sanitized_name, ticker, idx);
                                
                                // Download the avatar image
                                self.download_character_avatar(&image_url, &avatar_file_name).await?;
                                
                                characters.push(Character {
                                    name,
                                    symbol: ticker,
                                    description,
                                    avatar_file_name,
                                });
                            }
                        }
                    }
                }
            }
        }

        Ok(characters)
    }

    pub async fn upload_character_to_ipfs(&self, character: &Character) -> Result<String> {
        let pinata_jwt = env::var("PINATA_JWT").expect("PINATA_JWT must be set");
        let url = "https://uploads.pinata.cloud/v3/files";

        // Read the avatar file from assets directory
        let avatar_path = Path::new("assets").join(&character.avatar_file_name);
        let avatar_data = tokio::fs::read(&avatar_path).await?;

        // Prepare keyvalues
        let keyvalues = json!({
            "keyvalues": {
                "name": &character.name,
                "symbol": &character.symbol,
                "description": &character.description
            }
        });

        // Create multipart form
        let avatar_for_character_upload = reqwest::multipart::Part::bytes(avatar_data)
            .file_name(character.avatar_file_name.clone())
            .mime_str("image/png")?;

        let form = reqwest::multipart::Form::new()
            .text("network", "public")
            .part("file", avatar_for_character_upload)
            .text("keyvalues", serde_json::to_string(&keyvalues)?);

        // Send request
        let client = reqwest::Client::new();
        let res = client
            .post(url)
            .header("Authorization", format!("Bearer {pinata_jwt}"))
            .multipart(form)
            .send()
            .await?;

        let response: serde_json::Value = res.json().await?;

        if let Some(data) = response.get("data") {
            if let Some(cid) = data.get("cid").and_then(|c| c.as_str()) {
                Ok(format!("ipfs://{cid}"))
            } else {
                Err(eyre::eyre!("Failed to get CID from response"))
            }
        } else {
            Err(eyre::eyre!(
                "Failed to parse Pinata response: {:?}",
                response
            ))
        }
    }

    pub async fn download_character_avatar(&self, image_url: &str, file_name: &str) -> Result<()> {
        let https = HttpsConnector::new();
        let client = Client::builder().build::<_, Body>(https);
        let req = Request::builder()
            .method(Method::GET)
            .uri(image_url)
            .body(Body::empty())?;
        let res = client.request(req).await?;
        let body_bytes = hyper::body::to_bytes(res.into_body()).await?;

        fs::create_dir_all("assets").await?;
        let path = Path::new("assets").join(file_name);
        let mut file = File::create(&path).await?;
        file.write_all(&body_bytes).await?;

        Ok(())
    }
}