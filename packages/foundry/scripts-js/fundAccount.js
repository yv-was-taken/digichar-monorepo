#!/usr/bin/env node

import { execSync } from 'child_process';
import { ethers } from 'ethers';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env') });

async function fundAccount() {
  try {
    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
    
    if (!privateKey) {
      console.error('❌ DEPLOYER_PRIVATE_KEY not found in .env file');
      process.exit(1);
    }

    // Extract address from private key
    const wallet = new ethers.Wallet(privateKey);
    const address = wallet.address;

    console.log(`💰 Funding account ${address} with 1000 ETH on anvil...`);

    // Use anvil's setBalance to fund the account with 1000 ETH
    const command = `cast rpc anvil_setBalance ${address} 0x3635C9ADC5DEA00000`;
    
    execSync(command, { stdio: 'inherit' });
    
    console.log(`✅ Successfully funded ${address} with 1000 ETH`);
    
    // Verify the balance
    const balanceCommand = `cast balance ${address}`;
    const balance = execSync(balanceCommand, { encoding: 'utf8' }).trim();
    console.log(`📊 Current balance: ${ethers.utils.formatEther(balance)} ETH`);
    
  } catch (error) {
    console.error('❌ Error funding account:', error.message);
    process.exit(1);
  }
}

fundAccount();