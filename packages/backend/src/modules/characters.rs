use eyre::Result;
use hyper::{Body, Client, Method, Request};
use hyper_tls::HttpsConnector;
use serde_json::json;
use std::env;
use std::path::Path;
use tokio::fs::{self, File};
use tokio::io::AsyncWriteExt;

use crate::modules::types::Character;

#[derive(Debug)]
struct CharacterData {
    name: String,
    symbol: String,
    description: String,
    image_description: String,
}

pub struct CharacterService;

impl CharacterService {
    pub fn new() -> Self {
        Self
    }

    pub async fn create_characters(&self) -> Result<Vec<Character>> {
        let api_key = env::var("GEMINI_API_KEY").expect("GEMINI_API_KEY must be set");

        // Step 1: Generate character data
        let character_data = self.generate_character_data(&api_key).await?;

        // Step 2: Generate images for each character
        let mut characters = Vec::new();
        for (idx, char_data) in character_data.iter().enumerate() {
            let image_filename = self
                .generate_character_image(&api_key, char_data, idx)
                .await?;

            characters.push(Character {
                name: char_data.name.clone(),
                symbol: char_data.symbol.clone(),
                description: char_data.description.clone(),
                avatar_file_name: image_filename,
            });
        }

        Ok(characters)
    }

    async fn generate_character_data(&self, api_key: &str) -> Result<Vec<CharacterData>> {
        let url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

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
    "image_description": "Detailed visual description for image generation, including specific colors, features, style, expression, and background"
  },
  {
    "name": "Character Name 2", 
    "ticker": "TICK2",
    "description": "Another short description under 12 words",
    "image_description": "Another detailed visual description for image generation"
  },
  {
    "name": "Character Name 3",
    "ticker": "TICK3", 
    "description": "Third short description under 12 words",
    "image_description": "Third detailed visual description for image generation"
  }
]

IMPORTANT: Return ONLY the JSON array, no other text before or after."#;

        let https = HttpsConnector::new();
        let client = Client::builder().build::<_, Body>(https);

        let req = Request::builder()
            .method(Method::POST)
            .uri(url)
            .header("x-goog-api-key", api_key)
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
                    let cleaned_text = text
                        .trim()
                        .strip_prefix("```json")
                        .unwrap_or(text)
                        .strip_suffix("```")
                        .unwrap_or(text)
                        .trim();

                    match serde_json::from_str::<Vec<serde_json::Value>>(cleaned_text) {
                        Ok(character_json) => {
                            let mut character_data = Vec::new();

                            for char_json in character_json.iter().take(3) {
                                if let (
                                    Some(name),
                                    Some(ticker),
                                    Some(description),
                                    Some(image_description),
                                ) = (
                                    char_json.get("name").and_then(|n| n.as_str()),
                                    char_json.get("ticker").and_then(|t| t.as_str()),
                                    char_json.get("description").and_then(|d| d.as_str()),
                                    char_json.get("image_description").and_then(|i| i.as_str()),
                                ) {
                                    character_data.push(CharacterData {
                                        name: name.to_string(),
                                        symbol: ticker.to_string(),
                                        description: description.to_string(),
                                        image_description: image_description.to_string(),
                                    });
                                }
                            }

                            if character_data.len() == 3 {
                                return Ok(character_data);
                            }
                        }
                        Err(e) => {
                            eprintln!("[CharacterService] Failed to parse JSON: {e}");
                        }
                    }
                }
            }
        }

        Err(eyre::eyre!("Failed to generate character data"))
    }

    async fn generate_character_image(
        &self,
        api_key: &str,
        char_data: &CharacterData,
        idx: usize,
    ) -> Result<String> {
        // Use the Imagen API for image generation
        let url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent";

        // Use the detailed image description from the first prompt
        let image_prompt = format!("Generate an image: {}", char_data.image_description);

        let https = HttpsConnector::new();
        let client = Client::builder().build::<_, Body>(https);

        let req = Request::builder()
            .method(Method::POST)
            .uri(url)
            .header("x-goog-api-key", api_key)
            .header("Content-Type", "application/json")
            .body(Body::from(
                json!({
                    "contents": [{
                        "parts": [
                            {"text": image_prompt}
                        ]
                    }],
                    "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
                })
                .to_string(),
            ))?;

        let res = client.request(req).await?;
        let body_bytes = hyper::body::to_bytes(res.into_body()).await?;
        let response: serde_json::Value = serde_json::from_slice(&body_bytes)?;

        // Check for errors
        if let Some(error) = response.get("error") {
            eprintln!("[CharacterService] Gemini API error: {}", error);
            return Err(eyre::eyre!("Gemini API error: {}", error));
        }

        // Extract base64 image data from response (like the curl example)
        let response_text = serde_json::to_string(&response)?;
        
        // Use regex to find "data": "base64string" pattern (like the curl grep command)
        let re = regex::Regex::new(r#""data":\s*"([^"]+)""#)?;
        
        if let Some(captures) = re.captures(&response_text) {
            let base64_data = &captures[1];
            
            // Decode base64 image
            use base64::{Engine as _, engine::general_purpose};
            let image_data = general_purpose::STANDARD.decode(base64_data)?;

            // Generate filename
            let filename = format!(
                "{}_{}_generated_{}.png",
                char_data.name.replace(" ", "_"),
                char_data.symbol,
                idx
            );

            // Create assets directory and save image
            fs::create_dir_all("assets").await?;
            let path = Path::new("assets").join(&filename);
            let mut file = File::create(&path).await?;
            file.write_all(&image_data).await?;

            println!(
                "[CharacterService] Generated image for {} (size: {} bytes): {} (saved to {:?})",
                char_data.name,
                image_data.len(),
                filename,
                path
            );

            return Ok(filename);
        }

        Err(eyre::eyre!("No image found in Gemini response"))
    }

    pub async fn upload_character_to_ipfs(&self, character: &Character) -> Result<String> {
        let pinata_jwt = env::var("PINATA_JWT").expect("PINATA_JWT must be set");
        let url = "https://uploads.pinata.cloud/v3/files";

        // Read the avatar file from assets directory
        let avatar_path = Path::new("assets").join(&character.avatar_file_name);
        println!(
            "[CharacterService] Uploading to IPFS - Character: {} ({}), File: {}",
            character.name, character.symbol, character.avatar_file_name
        );

        let avatar_data = tokio::fs::read(&avatar_path).await?;
        println!(
            "[CharacterService] Read file {} with size: {} bytes",
            character.avatar_file_name,
            avatar_data.len()
        );

        // Prepare keyvalues - all values must be strings for Pinata
        let keyvalues = json!({
            "name": character.name,
            "symbol": character.symbol,
            "description": character.description
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

        println!(
            "[CharacterService] Pinata response status: {}",
            res.status()
        );
        let response_text = res.text().await?;
        println!("[CharacterService] Pinata response body: {}", response_text);

        let response: serde_json::Value = serde_json::from_str(&response_text)?;

        if let Some(data) = response.get("data") {
            if let Some(cid) = data.get("cid").and_then(|c| c.as_str()) {
                // Delete the local image file after successful upload
                if let Err(e) = tokio::fs::remove_file(&avatar_path).await {
                    eprintln!("[CharacterService] Warning: Failed to delete local file {}: {}", character.avatar_file_name, e);
                } else {
                    println!("[CharacterService] Deleted local file: {}", character.avatar_file_name);
                }
                
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
