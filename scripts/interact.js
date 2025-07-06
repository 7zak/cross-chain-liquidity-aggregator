#!/usr/bin/env node

/**
 * Interaction script for Cross-Chain Liquidity Aggregator
 * 
 * Usage:
 *   node scripts/interact.js get-pool --pool-id 1
 *   node scripts/interact.js create-pool --token-a ST1...token-a --token-b ST1...token-b --amount-a 1000 --amount-b 2000
 *   node scripts/interact.js swap --pool-id 1 --amount-in 100 --token-in ST1...token-a
 */

const {
  makeContractCall,
  broadcastTransaction,
  callReadOnlyFunction,
  cvToJSON,
  uintCV,
  standardPrincipalCV,
  contractPrincipalCV,
  stringAsciiCV,
  AnchorMode,
  PostConditionMode
} = require('@stacks/transactions');
const { StacksTestnet, StacksMainnet } = require('@stacks/network');
const fs = require('fs');
const path = require('path');

// Configuration
const NETWORKS = {
  testnet: new StacksTestnet(),
  mainnet: new StacksMainnet()
};

// Load deployment info
function loadDeploymentInfo(networkName) {
  const deploymentFile = path.join(__dirname, '..', 'deployments', `${networkName}.json`);
  
  if (!fs.existsSync(deploymentFile)) {
    console.error(`❌ Deployment file not found: ${deploymentFile}`);
    console.log('Please run deployment first: npm run deploy:testnet');
    process.exit(1);
  }
  
  return JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
}

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const command = args[0];
  const options = {};
  
  for (let i = 1; i < args.length; i += 2) {
    const key = args[i].replace('--', '');
    const value = args[i + 1];
    options[key] = value;
  }
  
  return { command, options };
}

// Read-only function calls
async function callReadOnly(contractAddress, contractName, functionName, functionArgs, network) {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName,
      functionArgs,
      network,
      senderAddress: contractAddress
    });
    
    return cvToJSON(result);
  } catch (error) {
    console.error('❌ Read-only call failed:', error.message);
    throw error;
  }
}

// Contract interaction functions
const interactions = {
  // Get pool information
  async 'get-pool'(options, deployment, network) {
    const { 'pool-id': poolId } = options;
    
    if (!poolId) {
      console.error('❌ Please specify --pool-id');
      return;
    }
    
    console.log(`🔍 Getting pool ${poolId} information...`);
    
    const result = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'get-pool',
      [uintCV(parseInt(poolId))],
      network
    );
    
    if (result.value) {
      console.log('✅ Pool found:');
      console.log(JSON.stringify(result.value, null, 2));
    } else {
      console.log('❌ Pool not found');
    }
  },

  // Get protocol information
  async 'get-protocol-info'(options, deployment, network) {
    console.log('🔍 Getting protocol information...');
    
    const result = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'get-protocol-info',
      [],
      network
    );
    
    console.log('✅ Protocol info:');
    console.log(JSON.stringify(result.value, null, 2));
  },

  // Calculate swap output
  async 'calculate-swap'(options, deployment, network) {
    const { 'pool-id': poolId, 'token-in': tokenIn, 'amount-in': amountIn } = options;
    
    if (!poolId || !tokenIn || !amountIn) {
      console.error('❌ Please specify --pool-id, --token-in, and --amount-in');
      return;
    }
    
    console.log(`🔍 Calculating swap output for pool ${poolId}...`);
    
    const result = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'calculate-swap-output',
      [
        uintCV(parseInt(poolId)),
        standardPrincipalCV(tokenIn),
        uintCV(parseInt(amountIn))
      ],
      network
    );
    
    if (result.success) {
      console.log(`✅ Expected output: ${result.value}`);
      console.log(`💡 Price impact: ${calculatePriceImpact(amountIn, result.value)}%`);
    } else {
      console.log('❌ Swap calculation failed:', result.value);
    }
  },

  // Get liquidity shares
  async 'get-shares'(options, deployment, network) {
    const { 'pool-id': poolId, provider } = options;
    
    if (!poolId || !provider) {
      console.error('❌ Please specify --pool-id and --provider');
      return;
    }
    
    console.log(`🔍 Getting liquidity shares for ${provider} in pool ${poolId}...`);
    
    const result = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'get-liquidity-shares',
      [
        uintCV(parseInt(poolId)),
        standardPrincipalCV(provider)
      ],
      network
    );
    
    console.log(`✅ Liquidity shares: ${result.value}`);
  },

  // List all pools (simplified - would need to iterate through pool IDs)
  async 'list-pools'(options, deployment, network) {
    console.log('🔍 Listing available pools...');
    
    // Get protocol info to see next pool ID
    const protocolInfo = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'get-protocol-info',
      [],
      network
    );
    
    const nextPoolId = protocolInfo.value['next-pool-id'].value;
    console.log(`📊 Total pools created: ${nextPoolId - 1}`);
    
    // List first few pools
    for (let i = 1; i < Math.min(nextPoolId, 6); i++) {
      try {
        const pool = await callReadOnly(
          deployment.contracts.aggregator,
          'cross-chain-liquidity-aggregator',
          'get-pool',
          [uintCV(i)],
          network
        );
        
        if (pool.value) {
          console.log(`\n📋 Pool ${i}:`);
          console.log(`  Token A: ${pool.value['token-a'].value}`);
          console.log(`  Token B: ${pool.value['token-b'].value}`);
          console.log(`  Reserve A: ${pool.value['reserve-a'].value}`);
          console.log(`  Reserve B: ${pool.value['reserve-b'].value}`);
          console.log(`  Fee Rate: ${pool.value['fee-rate'].value / 100}%`);
          console.log(`  Active: ${pool.value.active.value}`);
        }
      } catch (error) {
        // Pool doesn't exist, continue
      }
    }
  },

  // Get cross-chain swap info
  async 'get-swap'(options, deployment, network) {
    const { 'swap-id': swapId } = options;
    
    if (!swapId) {
      console.error('❌ Please specify --swap-id');
      return;
    }
    
    console.log(`🔍 Getting cross-chain swap ${swapId} information...`);
    
    const result = await callReadOnly(
      deployment.contracts.aggregator,
      'cross-chain-liquidity-aggregator',
      'get-cross-chain-swap',
      [uintCV(parseInt(swapId))],
      network
    );
    
    if (result.value) {
      console.log('✅ Cross-chain swap found:');
      console.log(JSON.stringify(result.value, null, 2));
    } else {
      console.log('❌ Cross-chain swap not found');
    }
  },

  // Help command
  async help() {
    console.log(`
📚 Cross-Chain Liquidity Aggregator CLI

Available commands:

📊 Query Commands:
  get-pool --pool-id <id>                    Get pool information
  get-protocol-info                          Get protocol configuration
  calculate-swap --pool-id <id> --token-in <address> --amount-in <amount>
  get-shares --pool-id <id> --provider <address>
  list-pools                                 List all available pools
  get-swap --swap-id <id>                   Get cross-chain swap info

🔧 Network Options:
  --network testnet|mainnet                  Specify network (default: testnet)

📝 Examples:
  node scripts/interact.js get-pool --pool-id 1
  node scripts/interact.js get-protocol-info
  node scripts/interact.js calculate-swap --pool-id 1 --token-in ST1...token-a --amount-in 1000000
  node scripts/interact.js list-pools
  node scripts/interact.js get-shares --pool-id 1 --provider ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

💡 Note: For write operations (create-pool, swap, etc.), use the web interface or implement with proper private key handling.
    `);
  }
};

// Helper functions
function calculatePriceImpact(amountIn, amountOut) {
  // Simplified price impact calculation
  // In production, you'd need the pool reserves to calculate this properly
  return ((amountIn - amountOut) / amountIn * 100).toFixed(2);
}

// Main function
async function main() {
  const { command, options } = parseArgs();
  const networkName = options.network || 'testnet';
  
  if (!command) {
    console.error('❌ Please specify a command. Use "help" for available commands.');
    process.exit(1);
  }
  
  if (command === 'help') {
    await interactions.help();
    return;
  }
  
  if (!interactions[command]) {
    console.error(`❌ Unknown command: ${command}`);
    console.log('Use "help" for available commands.');
    process.exit(1);
  }
  
  try {
    const deployment = loadDeploymentInfo(networkName);
    const network = NETWORKS[networkName];
    
    console.log(`🌐 Using ${networkName} network`);
    console.log(`📋 Contract: ${deployment.contracts.aggregator}.cross-chain-liquidity-aggregator`);
    
    await interactions[command](options, deployment, network);
    
  } catch (error) {
    console.error('❌ Command failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { interactions, loadDeploymentInfo };
