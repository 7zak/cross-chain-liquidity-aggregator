# Integration Guide

This guide provides comprehensive examples for integrating with the Cross-Chain Liquidity Aggregator protocol.

## Table of Contents

- [Basic Integration](#basic-integration)
- [Frontend Integration](#frontend-integration)
- [Backend Integration](#backend-integration)
- [Cross-Chain Operations](#cross-chain-operations)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## Basic Integration

### Setting Up Your Environment

```bash
# Install required dependencies
npm install @stacks/transactions @stacks/network @stacks/auth
npm install @stacks/connect @stacks/wallet-sdk

# For backend integration
npm install @stacks/blockchain-api-client
```

### Basic Contract Interaction

```javascript
import {
  makeContractCall,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  standardPrincipalCV,
  uintCV,
  contractPrincipalCV
} from '@stacks/transactions';
import { StacksTestnet, StacksMainnet } from '@stacks/network';

// Configuration
const network = new StacksTestnet(); // or StacksMainnet() for production
const contractAddress = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const contractName = 'cross-chain-liquidity-aggregator';

// Create a liquidity pool
async function createPool(senderKey, tokenA, tokenB, amountA, amountB, feeRate) {
  const txOptions = {
    contractAddress,
    contractName,
    functionName: 'create-pool',
    functionArgs: [
      contractPrincipalCV(tokenA.address, tokenA.name),
      contractPrincipalCV(tokenB.address, tokenB.name),
      uintCV(amountA),
      uintCV(amountB),
      uintCV(feeRate)
    ],
    senderKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  };

  const transaction = await makeContractCall(txOptions);
  const broadcastResponse = await broadcastTransaction(transaction, network);
  
  return broadcastResponse;
}

// Add liquidity to existing pool
async function addLiquidity(senderKey, poolId, tokenA, tokenB, amountA, amountB, minLiquidity) {
  const txOptions = {
    contractAddress,
    contractName,
    functionName: 'add-liquidity',
    functionArgs: [
      uintCV(poolId),
      contractPrincipalCV(tokenA.address, tokenA.name),
      contractPrincipalCV(tokenB.address, tokenB.name),
      uintCV(amountA),
      uintCV(amountB),
      uintCV(minLiquidity)
    ],
    senderKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  };

  const transaction = await makeContractCall(txOptions);
  return await broadcastTransaction(transaction, network);
}

// Perform token swap
async function swapTokens(senderKey, poolId, tokenIn, tokenOut, amountIn, minAmountOut) {
  const txOptions = {
    contractAddress,
    contractName,
    functionName: 'swap-tokens',
    functionArgs: [
      uintCV(poolId),
      contractPrincipalCV(tokenIn.address, tokenIn.name),
      contractPrincipalCV(tokenOut.address, tokenOut.name),
      uintCV(amountIn),
      uintCV(minAmountOut)
    ],
    senderKey,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  };

  const transaction = await makeContractCall(txOptions);
  return await broadcastTransaction(transaction, network);
}
```

## Frontend Integration

### React Component Example

```jsx
import React, { useState, useEffect } from 'react';
import { useConnect } from '@stacks/connect-react';
import {
  callReadOnlyFunction,
  cvToJSON,
  uintCV,
  standardPrincipalCV
} from '@stacks/transactions';

const LiquidityPool = ({ poolId }) => {
  const { doContractCall } = useConnect();
  const [poolData, setPoolData] = useState(null);
  const [loading, setLoading] = useState(true);

  // Fetch pool information
  useEffect(() => {
    const fetchPoolData = async () => {
      try {
        const result = await callReadOnlyFunction({
          contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
          contractName: 'cross-chain-liquidity-aggregator',
          functionName: 'get-pool',
          functionArgs: [uintCV(poolId)],
          network: new StacksTestnet(),
          senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
        });

        const poolInfo = cvToJSON(result);
        setPoolData(poolInfo.value);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching pool data:', error);
        setLoading(false);
      }
    };

    fetchPoolData();
  }, [poolId]);

  // Add liquidity function
  const handleAddLiquidity = async (amountA, amountB) => {
    try {
      await doContractCall({
        contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        contractName: 'cross-chain-liquidity-aggregator',
        functionName: 'add-liquidity',
        functionArgs: [
          uintCV(poolId),
          standardPrincipalCV(poolData['token-a'].value),
          standardPrincipalCV(poolData['token-b'].value),
          uintCV(amountA),
          uintCV(amountB),
          uintCV(1) // minimum liquidity
        ],
        onFinish: (data) => {
          console.log('Transaction successful:', data);
          // Refresh pool data
          fetchPoolData();
        },
        onCancel: () => {
          console.log('Transaction cancelled');
        }
      });
    } catch (error) {
      console.error('Error adding liquidity:', error);
    }
  };

  if (loading) return <div>Loading pool data...</div>;
  if (!poolData) return <div>Pool not found</div>;

  return (
    <div className="liquidity-pool">
      <h3>Pool #{poolId}</h3>
      <div className="pool-info">
        <p>Token A Reserve: {poolData['reserve-a'].value}</p>
        <p>Token B Reserve: {poolData['reserve-b'].value}</p>
        <p>Total Supply: {poolData['total-supply'].value}</p>
        <p>Fee Rate: {poolData['fee-rate'].value / 100}%</p>
        <p>Status: {poolData.active.value ? 'Active' : 'Inactive'}</p>
      </div>
      
      <div className="add-liquidity-form">
        <h4>Add Liquidity</h4>
        <input 
          type="number" 
          placeholder="Amount A" 
          id="amountA"
        />
        <input 
          type="number" 
          placeholder="Amount B" 
          id="amountB"
        />
        <button onClick={() => {
          const amountA = document.getElementById('amountA').value;
          const amountB = document.getElementById('amountB').value;
          handleAddLiquidity(parseInt(amountA), parseInt(amountB));
        }}>
          Add Liquidity
        </button>
      </div>
    </div>
  );
};

export default LiquidityPool;

// Enhanced Pool Analytics Component
const PoolAnalytics = ({ poolId }) => {
  const [analytics, setAnalytics] = useState(null);
  const [priceImpact, setPriceImpact] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAnalytics = async () => {
      try {
        // Get comprehensive pool analytics
        const analyticsResult = await callReadOnlyFunction({
          contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
          contractName: 'cross-chain-liquidity-aggregator',
          functionName: 'get-pool-analytics',
          functionArgs: [uintCV(poolId)],
          network: new StacksTestnet(),
          senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
        });

        const data = cvToJSON(analyticsResult);
        setAnalytics(data.value);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching analytics:', error);
        setLoading(false);
      }
    };

    fetchAnalytics();
  }, [poolId]);

  const calculatePriceImpact = async (tokenIn, amountIn) => {
    try {
      const result = await callReadOnlyFunction({
        contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        contractName: 'cross-chain-liquidity-aggregator',
        functionName: 'calculate-price-impact',
        functionArgs: [
          uintCV(poolId),
          standardPrincipalCV(tokenIn),
          uintCV(amountIn)
        ],
        network: new StacksTestnet(),
        senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
      });

      const impact = cvToJSON(result);
      setPriceImpact(impact.value);
    } catch (error) {
      console.error('Error calculating price impact:', error);
    }
  };

  if (loading) return <div>Loading analytics...</div>;
  if (!analytics) return <div>Analytics not available</div>;

  const { 'basic-stats': stats, 'health-metrics': health, 'fee-stats': fees } = analytics;

  return (
    <div className="pool-analytics">
      <h3>Pool #{poolId} Analytics</h3>

      <div className="stats-grid">
        <div className="stat-card">
          <h4>Basic Statistics</h4>
          <p>TVL: {(stats['reserve-a'].value + stats['reserve-b'].value).toLocaleString()}</p>
          <p>K-Value: {stats['k-value'].value.toLocaleString()}</p>
          <p>Utilization: {stats['utilization-rate'].value}%</p>
        </div>

        <div className="stat-card">
          <h4>Health Metrics</h4>
          <p>Balance Ratio: {health['balance-ratio'].value / 100}:1</p>
          <p>Health Score: {health['health-score'].value}/100</p>
          <p>Status: {health['is-balanced'].value ? '✅ Balanced' : '⚠️ Imbalanced'}</p>
        </div>

        <div className="stat-card">
          <h4>Fee Statistics</h4>
          <p>Total Fees A: {fees['total-fees-a'].value.toLocaleString()}</p>
          <p>Total Fees B: {fees['total-fees-b'].value.toLocaleString()}</p>
          <p>Last Updated: Block #{fees['last-updated'].value}</p>
        </div>
      </div>

      <div className="price-impact-calculator">
        <h4>Price Impact Calculator</h4>
        <input
          type="number"
          placeholder="Amount to swap"
          onChange={(e) => {
            if (e.target.value && stats) {
              calculatePriceImpact(stats['token-a'].value, parseInt(e.target.value));
            }
          }}
        />
        {priceImpact && (
          <div className="impact-result">
            <p>Price Impact: {(priceImpact['price-impact'].value / 100).toFixed(2)}%</p>
            <p>Expected Output: {priceImpact['amount-out'].value.toLocaleString()}</p>
          </div>
        )}
      </div>
    </div>
  );
};

export { PoolAnalytics };
```

### Swap Interface Component

```jsx
const SwapInterface = () => {
  const { doContractCall } = useConnect();
  const [pools, setPools] = useState([]);
  const [selectedPool, setSelectedPool] = useState(null);
  const [swapAmount, setSwapAmount] = useState('');
  const [expectedOutput, setExpectedOutput] = useState(null);

  // Calculate swap output
  const calculateOutput = async (poolId, tokenIn, amountIn) => {
    try {
      const result = await callReadOnlyFunction({
        contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        contractName: 'cross-chain-liquidity-aggregator',
        functionName: 'calculate-swap-output',
        functionArgs: [
          uintCV(poolId),
          standardPrincipalCV(tokenIn),
          uintCV(amountIn)
        ],
        network: new StacksTestnet(),
        senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
      });

      const output = cvToJSON(result);
      setExpectedOutput(output.value);
    } catch (error) {
      console.error('Error calculating output:', error);
    }
  };

  // Perform swap
  const handleSwap = async () => {
    if (!selectedPool || !swapAmount) return;

    try {
      await doContractCall({
        contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        contractName: 'cross-chain-liquidity-aggregator',
        functionName: 'swap-tokens',
        functionArgs: [
          uintCV(selectedPool.id),
          standardPrincipalCV(selectedPool.tokenA),
          standardPrincipalCV(selectedPool.tokenB),
          uintCV(parseInt(swapAmount)),
          uintCV(Math.floor(expectedOutput * 0.95)) // 5% slippage tolerance
        ],
        onFinish: (data) => {
          console.log('Swap successful:', data);
          setSwapAmount('');
          setExpectedOutput(null);
        }
      });
    } catch (error) {
      console.error('Swap failed:', error);
    }
  };

  return (
    <div className="swap-interface">
      <h3>Token Swap</h3>
      
      <select onChange={(e) => setSelectedPool(pools[e.target.value])}>
        <option value="">Select Pool</option>
        {pools.map((pool, index) => (
          <option key={pool.id} value={index}>
            Pool #{pool.id}
          </option>
        ))}
      </select>

      <input
        type="number"
        value={swapAmount}
        onChange={(e) => {
          setSwapAmount(e.target.value);
          if (selectedPool && e.target.value) {
            calculateOutput(selectedPool.id, selectedPool.tokenA, parseInt(e.target.value));
          }
        }}
        placeholder="Amount to swap"
      />

      {expectedOutput && (
        <div className="output-preview">
          <p>Expected Output: {expectedOutput}</p>
          <p>Minimum Received: {Math.floor(expectedOutput * 0.95)}</p>
        </div>
      )}

      <button onClick={handleSwap} disabled={!selectedPool || !swapAmount}>
        Swap Tokens
      </button>
    </div>
  );
};
```

## Backend Integration

### Node.js API Server

```javascript
const express = require('express');
const { 
  StacksApiSocketClient,
  connectWebSocketClient 
} = require('@stacks/blockchain-api-client');

const app = express();
app.use(express.json());

// WebSocket client for real-time updates
const client = new StacksApiSocketClient({
  url: 'wss://stacks-node-api.testnet.stacks.co/',
});

// Monitor pool events
client.subscribeAddressTransactions(
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cross-chain-liquidity-aggregator',
  (event) => {
    console.log('Pool transaction:', event);
    // Process pool updates, emit to connected clients, etc.
  }
);

// API endpoint to get pool statistics
app.get('/api/pools/:poolId/stats', async (req, res) => {
  try {
    const { poolId } = req.params;
    
    // Fetch pool data from blockchain
    const poolData = await callReadOnlyFunction({
      contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
      contractName: 'cross-chain-liquidity-aggregator',
      functionName: 'get-pool',
      functionArgs: [uintCV(parseInt(poolId))],
      network: new StacksTestnet(),
      senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
    });

    const pool = cvToJSON(poolData);
    
    // Calculate additional statistics
    const stats = {
      ...pool.value,
      tvl: pool.value['reserve-a'].value + pool.value['reserve-b'].value,
      utilization: calculateUtilization(pool.value),
      apy: calculateAPY(poolId) // Implement based on historical data
    };

    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// API endpoint for swap quotes
app.post('/api/quote', async (req, res) => {
  try {
    const { poolId, tokenIn, amountIn } = req.body;
    
    const result = await callReadOnlyFunction({
      contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
      contractName: 'cross-chain-liquidity-aggregator',
      functionName: 'calculate-swap-output',
      functionArgs: [
        uintCV(poolId),
        standardPrincipalCV(tokenIn),
        uintCV(amountIn)
      ],
      network: new StacksTestnet(),
      senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
    });

    const output = cvToJSON(result);
    
    res.json({
      amountIn,
      amountOut: output.value,
      priceImpact: calculatePriceImpact(poolId, amountIn, output.value),
      minimumReceived: Math.floor(output.value * 0.95) // 5% slippage
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => {
  console.log('API server running on port 3000');
});
```

## Cross-Chain Operations

### Initiating Cross-Chain Swaps

```javascript
// Cross-chain swap initiation
async function initiateCrossChainSwap(params) {
  const {
    senderKey,
    sourceToken,
    targetTokenAddress,
    targetChain,
    amount,
    targetAddress,
    expirationBlocks
  } = params;

  const txOptions = {
    contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    contractName: 'cross-chain-liquidity-aggregator',
    functionName: 'initiate-cross-chain-swap',
    functionArgs: [
      contractPrincipalCV(sourceToken.address, sourceToken.name),
      stringAsciiCV(targetTokenAddress),
      stringAsciiCV(targetChain),
      uintCV(amount),
      stringAsciiCV(targetAddress),
      uintCV(expirationBlocks)
    ],
    senderKey,
    network: new StacksTestnet(),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow
  };

  const transaction = await makeContractCall(txOptions);
  const result = await broadcastTransaction(transaction, network);
  
  return result;
}

// Monitor cross-chain swap status
async function monitorCrossChainSwap(swapId) {
  const result = await callReadOnlyFunction({
    contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    contractName: 'cross-chain-liquidity-aggregator',
    functionName: 'get-cross-chain-swap',
    functionArgs: [uintCV(swapId)],
    network: new StacksTestnet(),
    senderAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
  });

  return cvToJSON(result);
}
```

## Error Handling

### Comprehensive Error Handling

```javascript
const ERROR_CODES = {
  100: 'Unauthorized access',
  101: 'Insufficient balance',
  102: 'Insufficient liquidity',
  103: 'Invalid amount',
  104: 'Pool not found',
  105: 'Slippage too high',
  106: 'Swap expired',
  107: 'Invalid token',
  108: 'Protocol paused',
  109: 'Pool already exists',
  110: 'Invalid fee rate'
};

function handleContractError(error) {
  if (error.includes('(err u')) {
    const errorCode = parseInt(error.match(/\(err u(\d+)\)/)[1]);
    const errorMessage = ERROR_CODES[errorCode] || 'Unknown error';
    
    return {
      code: errorCode,
      message: errorMessage,
      type: 'contract_error'
    };
  }
  
  return {
    code: -1,
    message: error,
    type: 'general_error'
  };
}

// Usage in async functions
async function safeContractCall(contractCall) {
  try {
    const result = await contractCall();
    return { success: true, data: result };
  } catch (error) {
    const parsedError = handleContractError(error.toString());
    return { success: false, error: parsedError };
  }
}
```

## Best Practices

### 1. Transaction Monitoring

```javascript
async function waitForTransaction(txId, network) {
  const maxAttempts = 30;
  let attempts = 0;
  
  while (attempts < maxAttempts) {
    try {
      const tx = await fetch(`${network.coreApiUrl}/extended/v1/tx/${txId}`);
      const txData = await tx.json();
      
      if (txData.tx_status === 'success') {
        return { success: true, data: txData };
      } else if (txData.tx_status === 'abort_by_response' || txData.tx_status === 'abort_by_post_condition') {
        return { success: false, error: txData };
      }
      
      await new Promise(resolve => setTimeout(resolve, 2000));
      attempts++;
    } catch (error) {
      attempts++;
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
  
  return { success: false, error: 'Transaction timeout' };
}
```

### 2. Slippage Protection

```javascript
function calculateMinimumOutput(expectedOutput, slippageTolerance = 0.05) {
  return Math.floor(expectedOutput * (1 - slippageTolerance));
}

function validateSlippage(expectedOutput, actualOutput, maxSlippage = 0.05) {
  const slippage = (expectedOutput - actualOutput) / expectedOutput;
  return slippage <= maxSlippage;
}
```

### 3. Gas Estimation

```javascript
async function estimateTransactionFee(transaction, network) {
  try {
    const response = await fetch(`${network.coreApiUrl}/v2/fees/transaction`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transaction })
    });
    
    const feeData = await response.json();
    return feeData.estimated_cost;
  } catch (error) {
    console.error('Fee estimation failed:', error);
    return null;
  }
}
```

This integration guide provides comprehensive examples for building applications on top of the Cross-Chain Liquidity Aggregator protocol. Always test thoroughly on testnet before deploying to mainnet.
