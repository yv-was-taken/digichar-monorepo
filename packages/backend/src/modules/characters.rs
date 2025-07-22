use eyre::Result;
use hyper::{Body, Client, Method, Request};
use hyper_tls::HttpsConnector;
use serde_json::json;
use std::env;
use std::path::Path;
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
        let url =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

        let prompt = r#"Generate EXACTLY 3 memecoin characters in JSON format. Each character should be designed like popular characters with fandoms (Sanrio, Dogecoin, Sonic, Spongebob, Naruto, etc).

Each of the 3 characters should be from a different style:
- sanrio/kawaii
- traditional crypto memecoins (doge, shib, pepe style)  
- newage meme culture (wojak, gigachad style)

Return ONLY valid JSON in this exact format:
[
  {
    "name": "Character Name",
    "ticker": "TICK",
    "description": "Short description under 12 words",
    "image_url": "https://example.com/image1.png"
  },
  {
    "name": "Character Name 2", 
    "ticker": "TICK2",
    "description": "Another short description under 12 words",
    "image_url": "https://example.com/image2.png"
  },
  {
    "name": "Character Name 3",
    "ticker": "TICK3", 
    "description": "Third short description under 12 words",
    "image_url": "https://example.com/image3.png"
  }
]

IMPORTANT: Return ONLY the JSON array, no other text before or after. Include actual image URLs for character artwork."#;

        let mut characters = Vec::new();
        let https = HttpsConnector::new();
        let client = Client::builder().build::<_, Body>(https);

        // Make a single API call to generate all 3 characters
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
                    println!("[CharacterService] Raw API response: {}", text);
                    
                    // Clean the response text (remove markdown code blocks if present)
                    let cleaned_text = text
                        .trim()
                        .strip_prefix("```json").unwrap_or(text)
                        .strip_suffix("```").unwrap_or(text)
                        .trim();
                    
                    // Parse JSON response
                    match serde_json::from_str::<Vec<serde_json::Value>>(cleaned_text) {
                        Ok(character_data) => {
                            println!("[CharacterService] Successfully parsed {} characters from JSON", character_data.len());
                            
                            for (idx, char_json) in character_data.iter().enumerate().take(3) {
                                if let (Some(name), Some(ticker), Some(description), Some(image_url)) = (
                                    char_json.get("name").and_then(|n| n.as_str()),
                                    char_json.get("ticker").and_then(|t| t.as_str()),
                                    char_json.get("description").and_then(|d| d.as_str()),
                                    char_json.get("image_url").and_then(|i| i.as_str())
                                ) {
                                    // Create unique filename based on character name and ticker
                                    let sanitized_name = name
                                        .replace(" ", "_")
                                        .replace("/", "_")
                                        .replace(":", "_");
                                    let avatar_file_name = format!("{}_{}_{}.png", sanitized_name, ticker, idx);

                                    // Download the avatar image
                                    match self.download_character_avatar(image_url, &avatar_file_name).await {
                                        Ok(_) => println!("[CharacterService] Downloaded avatar for {}", name),
                                        Err(e) => {
                                            eprintln!("[CharacterService] Failed to download avatar for {}: {}", name, e);
                                            // Continue with a placeholder file name
                                        }
                                    }

                                    characters.push(Character {
                                        name: name.to_string(),
                                        symbol: ticker.to_string(),
                                        description: description.to_string(),
                                        avatar_file_name,
                                    });
                                    
                                    println!("[CharacterService] Created character: {} ({})", name, ticker);
                                } else {
                                    eprintln!("[CharacterService] Missing required fields in character {}", idx);
                                }
                            }
                        },
                        Err(e) => {
                            eprintln!("[CharacterService] Failed to parse JSON response: {}", e);
                            eprintln!("[CharacterService] Raw response was: {}", cleaned_text);
                        }
                    }
                }
            }
        }

        // Ensure we have exactly 3 characters
        if characters.len() != 3 {
            return Err(eyre::eyre!(
                "Expected exactly 3 characters from API, but got {}",
                characters.len()
            ));
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

