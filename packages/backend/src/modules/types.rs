use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct Character {
    pub name: String,
    pub symbol: String,
    pub description: String,
    pub avatar_file_name: String,
}