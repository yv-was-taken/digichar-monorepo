/// Helper function to format duration in human-readable format
pub fn format_duration(seconds: i64) -> String {
    if seconds < 0 {
        return "expired".to_string();
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