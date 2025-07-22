use ethers::abi::Abi;

// Simple error decoder that focuses on error selectors
pub fn decode_contract_error(error_str: &str, abi_json: &str) -> String {
    // Parse the ABI
    let _abi: Abi = match serde_json::from_str(abi_json) {
        Ok(abi) => abi,
        Err(_) => return format!("Contract error: {} (failed to parse ABI)", error_str),
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
            // Get just the selector (0x + 8 chars)
            let selector_hex = &hex_data[..10];
            
            // Try to match against known error selectors
            match selector_hex {
                "0x6115a9ad" => return format!("OnlyProtocolAdmin: This function can only be called by the protocol admin ({})", hex_data),
                "0x64b5c437" => return format!("AlreadyClaimed: Tokens have already been claimed for this auction ({})", hex_data),
                "0xd738a887" => return format!("AmountTooLarge: The specified amount is too large ({})", hex_data),
                "0xcbb7c0e9" => return format!("AmountZero: Amount must be greater than zero ({})", hex_data),
                "0x04a5e667" => return format!("AuctionExpired: The auction has expired ({})", hex_data),
                "0x6c586317" => return format!("AuctionStillOpen: The auction is still open ({})", hex_data),
                "0x6365d4e7" => return format!("InvalidCharacter: Invalid character index specified ({})", hex_data),
                "0x319576eb" => return format!("AuctionClosed: The auction is closed ({})", hex_data),
                _ => return format!("Unknown contract error ({})", hex_data),
            }
        }
    }
    
    // If we couldn't decode it, return the original error
    format!("Contract error: {}", error_str)
}

// Load ABI from file
pub fn load_abi(path: &str) -> Result<String, std::io::Error> {
    std::fs::read_to_string(path)
}