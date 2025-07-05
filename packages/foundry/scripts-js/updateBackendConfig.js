import { readFileSync, writeFileSync, readdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { parse } from "toml";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Network configurations
const NETWORK_RPC_URLS = {
  localhost: "http://127.0.0.1:8545",
  31337: "http://127.0.0.1:8545", // Local Anvil chain ID
  // Add more networks as needed
  sepolia: "https://rpc.sepolia.org",
  mainnet: "https://eth.llamarpc.com",
  optimism: "https://mainnet.optimism.io",
  arbitrum: "https://arb1.arbitrum.io/rpc",
  polygon: "https://polygon-rpc.com",
  base: "https://mainnet.base.org"
};

function getNetworkFromArgs() {
  // Check environment variable first (set by Makefile)
  if (process.env.RPC_URL) {
    return process.env.RPC_URL;
  }
  
  // Otherwise check command line args
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--network" && args[i + 1]) {
      return args[i + 1];
    }
  }
  
  return "localhost"; // default
}

function getChainIdForNetwork(network) {
  // Map network names to chain IDs
  const networkToChainId = {
    localhost: "31337",
    sepolia: "11155111",
    mainnet: "1",
    optimism: "10",
    arbitrum: "42161",
    polygon: "137",
    base: "8453"
  };
  
  return networkToChainId[network] || "31337";
}

function getRpcUrlFromFoundryToml(network) {
  try {
    const foundryTomlPath = join(__dirname, "..", "foundry.toml");
    const tomlString = readFileSync(foundryTomlPath, "utf-8");
    const parsedToml = parse(tomlString);
    
    if (parsedToml.rpc_endpoints && parsedToml.rpc_endpoints[network]) {
      return parsedToml.rpc_endpoints[network];
    }
  } catch (error) {
    console.warn("Could not read RPC URL from foundry.toml:", error.message);
  }
  
  return null;
}

function getLatestDeployedAddresses(network) {
  const chainId = getChainIdForNetwork(network);
  const broadcastPath = join(__dirname, "..", "broadcast", "Deploy.s.sol", chainId);
  const latestRunPath = join(broadcastPath, "run-latest.json");
  
  try {
    const content = readFileSync(latestRunPath, "utf8");
    const broadcastData = JSON.parse(content);
    const transactions = broadcastData.transactions || [];
    
    const contracts = {};
    for (const tx of transactions) {
      if (tx.transactionType === "CREATE" && tx.contractName) {
        contracts[tx.contractName] = tx.contractAddress;
      }
    }
    
    return contracts;
  } catch (error) {
    console.error(`Error reading deployment data for network ${network} (chainId: ${chainId}):`, error.message);
    return null;
  }
}

function updateBackendConfig() {
  const network = getNetworkFromArgs();
  const contracts = getLatestDeployedAddresses(network);
  
  if (!contracts) {
    console.error(`❌ Could not read deployed contract addresses for network: ${network}`);
    process.exit(1);
  }
  
  // Check if we have the required contracts
  if (!contracts.AuctionVault || !contracts.Config) {
    console.error("❌ Missing required contracts (AuctionVault or Config)");
    console.log("Found contracts:", contracts);
    process.exit(1);
  }
  
  // Get RPC URL - first try foundry.toml, then use defaults
  let rpcUrl = getRpcUrlFromFoundryToml(network);
  if (!rpcUrl) {
    rpcUrl = NETWORK_RPC_URLS[network] || NETWORK_RPC_URLS[getChainIdForNetwork(network)] || "http://127.0.0.1:8545";
  }
  
  // Path to backend config module
  const configPath = join(__dirname, "..", "..", "backend", "src", "modules", "config.rs");
  
  // Generate new config content
  const configContent = `pub const AUCTION_VAULT_CONTRACT_ADDRESS: &str = "${contracts.AuctionVault}";
pub const CONFIG_CONTRACT_ADDRESS: &str = "${contracts.Config}";
pub const RPC_URL: &str = "${rpcUrl}";
`;
  
  try {
    writeFileSync(configPath, configContent);
    console.log(`✅ Updated backend config for network: ${network}`);
    console.log(`   - AuctionVault: ${contracts.AuctionVault}`);
    console.log(`   - Config: ${contracts.Config}`);
    console.log(`   - RPC URL: ${rpcUrl}`);
  } catch (error) {
    console.error("❌ Error writing config file:", error);
    process.exit(1);
  }
}

// Run the update
updateBackendConfig();