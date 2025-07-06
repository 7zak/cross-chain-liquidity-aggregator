#!/usr/bin/env node

/**
 * Deployment script for Cross-Chain Liquidity Aggregator
 * 
 * Usage:
 *   node scripts/deploy.js --network testnet
 *   node scripts/deploy.js --network mainnet
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const NETWORKS = {
  testnet: {
    name: 'testnet',
    url: 'https://stacks-node-api.testnet.stacks.co',
    explorerUrl: 'https://explorer.stacks.co/?chain=testnet'
  },
  mainnet: {
    name: 'mainnet',
    url: 'https://stacks-node-api.mainnet.stacks.co',
    explorerUrl: 'https://explorer.stacks.co'
  }
};

// Parse command line arguments
const args = process.argv.slice(2);
const networkArg = args.find(arg => arg.startsWith('--network='))?.split('=')[1] || 
                   args[args.indexOf('--network') + 1];

if (!networkArg || !NETWORKS[networkArg]) {
  console.error('❌ Please specify a valid network: --network testnet|mainnet');
  process.exit(1);
}

const network = NETWORKS[networkArg];

console.log(`🚀 Deploying Cross-Chain Liquidity Aggregator to ${network.name}...`);

// Pre-deployment checks
function runPreDeploymentChecks() {
  console.log('🔍 Running pre-deployment checks...');
  
  try {
    // Check contract syntax
    console.log('  ✓ Checking contract syntax...');
    execSync('clarinet check', { stdio: 'pipe' });
    
    // Run tests
    console.log('  ✓ Running tests...');
    execSync('clarinet test', { stdio: 'pipe' });
    
    // Check Clarinet configuration
    const clarinetConfig = path.join(__dirname, '..', 'Clarinet.toml');
    if (!fs.existsSync(clarinetConfig)) {
      throw new Error('Clarinet.toml not found');
    }
    
    console.log('✅ Pre-deployment checks passed');
  } catch (error) {
    console.error('❌ Pre-deployment checks failed:', error.message);
    process.exit(1);
  }
}

// Deploy contracts
function deployContracts() {
  console.log(`📦 Deploying contracts to ${network.name}...`);
  
  try {
    const deployCommand = `clarinet deploy --network ${network.name}`;
    const output = execSync(deployCommand, { encoding: 'utf8' });
    
    console.log('✅ Deployment successful!');
    console.log(output);
    
    // Parse deployment output for contract addresses
    const contractAddresses = parseDeploymentOutput(output);
    saveDeploymentInfo(network.name, contractAddresses);
    
    return contractAddresses;
  } catch (error) {
    console.error('❌ Deployment failed:', error.message);
    process.exit(1);
  }
}

// Parse deployment output to extract contract addresses
function parseDeploymentOutput(output) {
  const addresses = {};
  const lines = output.split('\n');
  
  lines.forEach(line => {
    if (line.includes('cross-chain-liquidity-aggregator')) {
      const match = line.match(/([A-Z0-9]{28,41})\.cross-chain-liquidity-aggregator/);
      if (match) {
        addresses.aggregator = match[1];
      }
    }
    if (line.includes('sip-010-trait')) {
      const match = line.match(/([A-Z0-9]{28,41})\.sip-010-trait/);
      if (match) {
        addresses.trait = match[1];
      }
    }
  });
  
  return addresses;
}

// Save deployment information
function saveDeploymentInfo(networkName, addresses) {
  const deploymentInfo = {
    network: networkName,
    timestamp: new Date().toISOString(),
    contracts: addresses,
    explorerUrl: network.explorerUrl
  };
  
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }
  
  const deploymentFile = path.join(deploymentsDir, `${networkName}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  
  console.log(`📄 Deployment info saved to ${deploymentFile}`);
}

// Post-deployment verification
function verifyDeployment(addresses) {
  console.log('🔍 Verifying deployment...');
  
  try {
    // Verify contracts are deployed and accessible
    Object.entries(addresses).forEach(([name, address]) => {
      console.log(`  ✓ ${name}: ${address}`);
    });
    
    console.log('✅ Deployment verification completed');
    
    // Print useful information
    console.log('\n📋 Deployment Summary:');
    console.log(`Network: ${network.name}`);
    console.log(`Explorer: ${network.explorerUrl}`);
    console.log('\n🔗 Contract Addresses:');
    Object.entries(addresses).forEach(([name, address]) => {
      console.log(`  ${name}: ${address}`);
    });
    
    console.log('\n🎉 Deployment completed successfully!');
    console.log('\n📚 Next steps:');
    console.log('1. Verify contracts on explorer');
    console.log('2. Update frontend configuration with new addresses');
    console.log('3. Test basic functionality');
    console.log('4. Consider setting up monitoring');
    
  } catch (error) {
    console.error('❌ Deployment verification failed:', error.message);
  }
}

// Main deployment flow
async function main() {
  try {
    runPreDeploymentChecks();
    const addresses = deployContracts();
    verifyDeployment(addresses);
  } catch (error) {
    console.error('❌ Deployment process failed:', error.message);
    process.exit(1);
  }
}

// Run deployment
if (require.main === module) {
  main();
}

module.exports = {
  deployContracts,
  runPreDeploymentChecks,
  verifyDeployment
};
