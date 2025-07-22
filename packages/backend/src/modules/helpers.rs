/// Helper function to format duration in human-readable format
pub fn format_duration(seconds: i64) -> String {
    // Handle invalid/expired auctions
    if seconds <= 0 {
        return "expired".to_string();
    }
    
    // Handle extremely large values that could cause overflow
    if seconds > i64::MAX / 2 {
        return "invalid timestamp".to_string();
    }
    
    let days = seconds / 86400;
    let hours = (seconds % 86400) / 3600;
    let minutes = (seconds % 3600) / 60;
    let secs = seconds % 60;
    
    if days > 0 {
        if hours > 0 {
            format!("{} days, {} hours", days, hours)
        } else {
            format!("{} days", days)
        }
    } else if hours > 0 {
        if minutes > 0 {
            format!("{} hours, {} minutes", hours, minutes)
        } else {
            format!("{} hours", hours)
        }
    } else if minutes > 0 {
        format!("{} minutes, {} seconds", minutes, secs)
    } else {
        format!("{} seconds", secs)
    }
}

use ethers::types::U256;

/// Helper function to safely calculate duration avoiding overflow
pub fn safe_duration_calculation(end_timestamp: U256, current_timestamp: i64) -> i64 {
    // Handle edge cases
    if end_timestamp.is_zero() {
        return -1; // Expired/invalid
    }
    
    // Convert current timestamp to U256 for comparison
    let current_time_u256 = U256::from(if current_timestamp < 0 { 0 } else { current_timestamp as u64 });
    
    // Check if already expired
    if end_timestamp <= current_time_u256 {
        return -1; // Already expired
    }
    
    // Calculate duration
    let duration = end_timestamp - current_time_u256;
    
    // Convert to i64, capping at i64::MAX if too large
    if duration > U256::from(i64::MAX as u64) {
        return i64::MAX;
    }
    
    duration.as_u64() as i64
}