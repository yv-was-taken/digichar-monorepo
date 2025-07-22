use ethers::abi::Abi;
use ethers::types::Bytes;

// Proper error decoder using ABI
pub fn decode_contract_error(error_str: &str, abi_json: &str) -> String {
    // Parse the ABI from the contract JSON
    let contract_abi = match parse_contract_abi(abi_json) {
        Ok(abi) => abi,
        Err(e) => return format!("Contract error: {} (ABI parse error: {})", error_str, e),
    };
    
    // Extract hex data from error string
    if let Some(start) = error_str.find("0x") {
        let hex_part = &error_str[start..];
        // Find the end of hex data (usually a space or end of string)
        let end = hex_part.find(|c: char| !c.is_ascii_hexdigit() && c != 'x')
            .unwrap_or(hex_part.len());
        let hex_data = &hex_part[..end];
        
        // Decode the hex data
        if hex_data.len() >= 10 { // At least 0x + 8 chars for selector
            if let Ok(error_bytes) = hex::decode(&hex_data[2..]) {
                let error_data = Bytes::from(error_bytes);
                
                // Try to decode using each error in the ABI
                for error_abi in contract_abi.errors() {
                    if let Ok(decoded_tokens) = error_abi.decode(&error_data) {
                        if decoded_tokens.is_empty() {
                            return format!("{}: {} ({})", 
                                error_abi.name, 
                                get_error_description(&error_abi.name),
                                hex_data
                            );
                        } else {
                            let params: Vec<String> = decoded_tokens.into_iter()
                                .map(|token| format!("{:?}", token))
                                .collect();
                            return format!("{}: {} - params: [{}] ({})", 
                                error_abi.name, 
                                get_error_description(&error_abi.name),
                                params.join(", "),
                                hex_data
                            );
                        }
                    }
                }
                
                // If no match found
                return format!("Unknown contract error ({})", hex_data);
            }
        }
    }
    
    // If we couldn't decode it, return the original error
    format!("Contract error: {}", error_str)
}

// Parse ABI from contract JSON file
fn parse_contract_abi(abi_json: &str) -> Result<Abi, String> {
    // First try parsing as raw ABI array
    if let Ok(abi) = serde_json::from_str::<Abi>(abi_json) {
        return Ok(abi);
    }
    
    // Try parsing as contract JSON with "abi" field
    let contract_json: serde_json::Value = serde_json::from_str(abi_json)
        .map_err(|e| format!("Invalid JSON: {}", e))?;
    
    if let Some(abi_value) = contract_json.get("abi") {
        let abi: Abi = serde_json::from_value(abi_value.clone())
            .map_err(|e| format!("Invalid ABI format: {}", e))?;
        return Ok(abi);
    }
    
    Err("No ABI found in JSON".to_string())
}

fn get_error_description(error_name: &str) -> &'static str {
    match error_name {
        "OnlyProtocolAdmin" => "This function can only be called by the protocol admin",
        "AlreadyClaimed" => "Tokens have already been claimed for this auction",
        "AmountTooLarge" => "The specified amount is too large",
        "AmountZero" => "Amount must be greater than zero",
        "AuctionExpired" => "The auction has expired",
        "AuctionStillOpen" => "The auction is still open",
        "InvalidCharacter" => "Invalid character index specified",
        "AuctionClosed" => "The auction is closed",
        _ => "Unknown error type"
    }
}

// Load ABI from file
pub fn load_abi(path: &str) -> Result<String, std::io::Error> {
    std::fs::read_to_string(path)
}