# DigiChar Backend Service

A Rust-based backend service that manages auction protocols, analyzes blockchain events, and handles character creation/IPFS uploads for the DigiChar ecosystem.

## Prerequisites

- Rust (latest stable version)
- Cargo
- Local blockchain running (`yarn chain` from project root)
- Environment variables configured (see below)

## Environment Variables

Create a `.env` file in the backend directory with:

```bash
GEMINI_API_KEY=your_gemini_api_key_here
PINATA_JWT=your_pinata_jwt_token_here
```

## Development Workflow

### 1. Start the local blockchain
From the project root:
```bash
yarn chain
```

### 2. Deploy contracts
In a new terminal, from the project root:
```bash
yarn deploy
```

This will:
- Deploy the smart contracts to your local blockchain
- Generate TypeScript ABIs for the frontend
- **Automatically update the backend config** with the deployed contract addresses and RPC URL

### 3. Run the backend service
From the project root:
```bash
yarn backend
```

Or for development with auto-reload:
```bash
yarn backend:dev  # requires cargo-watch: cargo install cargo-watch
```

### 4. Check for compilation errors
```bash
yarn backend:check
```

## Configuration

The backend configuration is automatically managed by the deployment process. When you run `yarn deploy`, the script will update `src/modules/config.rs` with:

- `AUCTION_VAULT_CONTRACT_ADDRESS`: The deployed AuctionVault contract address
- `CONFIG_CONTRACT_ADDRESS`: The deployed Config contract address  
- `RPC_URL`: The appropriate RPC URL based on the deployment network

### Manual Configuration Update

If needed, you can manually update the backend config by running:
```bash
cd packages/foundry
node scripts-js/updateBackendConfig.js --network <network-name>
```

### Supported Networks

The update script supports multiple networks and will automatically set the correct RPC URL:
- `localhost` / `31337`: http://127.0.0.1:8545
- `sepolia`: https://rpc.sepolia.org
- `mainnet`: https://eth.llamarpc.com
- `optimism`: https://mainnet.optimism.io
- `arbitrum`: https://arb1.arbitrum.io/rpc
- `polygon`: https://polygon-rpc.com
- `base`: https://mainnet.base.org

## Architecture

The backend service runs in a continuous loop, managing:

1. **Auction Lifecycle Management**
   - Monitors auction expiration
   - Closes expired auctions
   - Creates new auctions

2. **Character Generation**
   - Uses Gemini API to generate character metadata
   - Downloads and stores character avatars
   - Uploads character data to IPFS via Pinata

3. **Blockchain Integration**
   - Reads auction state from smart contracts
   - Analyzes bid events to determine winners
   - Triggers contract functions for auction management

## Key Modules

- `main.rs`: Main entry point with protocol loop
- `modules/auction_vault.rs`: AuctionVault contract interactions and bid analysis
- `modules/characters.rs`: Character generation and IPFS uploads
- `modules/config.rs`: Configuration constants (auto-updated by deploy script)
- `modules/types.rs`: Shared type definitions

## Development Tips

- Always run `cargo check` after making changes to catch compilation errors early
- The service expects contracts to be deployed - make sure to run `yarn deploy` first
- Monitor the console output for auction status and any errors
- Character generation requires valid API keys for Gemini and Pinata