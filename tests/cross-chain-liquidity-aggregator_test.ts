import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Test pool creation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // First, mint tokens to user1 for testing
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000), // 1000 tokens with 6 decimals
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000), // 2000 tokens with 6 decimals
        types.principal(user1.address)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts.forEach(receipt => {
      receipt.result.expectOk().expectBool(true);
    });
    
    // Create a new liquidity pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(100000000), // 100 tokens A
        types.uint(200000000), // 200 tokens B
        types.uint(300) // 3% fee
      ], user1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify pool was created
    let poolInfo = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool',
      [types.uint(1)],
      user1.address
    );
    
    const pool = poolInfo.result.expectSome().expectTuple();
    assertEquals(pool['reserve-a'], types.uint(100000000));
    assertEquals(pool['reserve-b'], types.uint(200000000));
    assertEquals(pool['fee-rate'], types.uint(300));
    assertEquals(pool['active'], types.bool(true));
  }
});

Clarinet.test({
  name: "Test adding liquidity to existing pool",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;
    
    // Setup: mint tokens and create pool
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(500000000),
        types.principal(user2.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(1000000000),
        types.principal(user2.address)
      ], deployer.address)
    ]);
    
    // Create pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(100000000),
        types.uint(200000000),
        types.uint(300)
      ], user1.address)
    ]);
    
    // Add liquidity from user2
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'add-liquidity', [
        types.uint(1), // pool-id
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(50000000), // 50 tokens A
        types.uint(100000000), // 100 tokens B
        types.uint(1) // min liquidity
      ], user2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk();
    
    // Verify updated pool reserves
    let poolInfo = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool',
      [types.uint(1)],
      user2.address
    );
    
    const pool = poolInfo.result.expectSome().expectTuple();
    assertEquals(pool['reserve-a'], types.uint(150000000)); // 100 + 50
    assertEquals(pool['reserve-b'], types.uint(300000000)); // 200 + 100
  }
});

Clarinet.test({
  name: "Test token swap functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;
    
    // Setup: mint tokens, create pool
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(100000000),
        types.principal(user2.address)
      ], deployer.address)
    ]);
    
    // Create pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(500000000), // 500 tokens A
        types.uint(1000000000), // 1000 tokens B
        types.uint(300)
      ], user1.address)
    ]);
    
    // Calculate expected output before swap
    let expectedOutput = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'calculate-swap-output',
      [
        types.uint(1),
        types.principal(deployer.address + '.mock-token-a'),
        types.uint(10000000) // 10 tokens A
      ],
      user2.address
    );
    
    expectedOutput.result.expectOk();
    
    // Perform swap
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'swap-tokens', [
        types.uint(1), // pool-id
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(10000000), // 10 tokens A
        types.uint(1) // min amount out
      ], user2.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Test cross-chain swap initiation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Setup: mint tokens
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    
    // Initiate cross-chain swap
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'initiate-cross-chain-swap', [
        types.principal(deployer.address + '.mock-token-a'),
        types.ascii("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"), // target token address
        types.ascii("bitcoin"), // target chain
        types.uint(50000000), // 50 tokens
        types.ascii("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"), // target address
        types.uint(144) // expires in 144 blocks (1 day)
      ], user1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify swap was recorded
    let swapInfo = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-cross-chain-swap',
      [types.uint(1)],
      user1.address
    );
    
    const swap = swapInfo.result.expectSome().expectTuple();
    assertEquals(swap['initiator'], types.principal(user1.address));
    assertEquals(swap['source-amount'], types.uint(50000000));
    assertEquals(swap['status'], types.ascii("pending"));
  }
});

Clarinet.test({
  name: "Test admin functions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Test setting protocol fee (only owner)
    let block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'set-protocol-fee', [
        types.uint(50) // 0.5%
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test unauthorized fee setting (should fail)
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'set-protocol-fee', [
        types.uint(100)
      ], user1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectErr().expectUint(100); // ERR_UNAUTHORIZED
    
    // Test pausing protocol
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'set-paused', [
        types.bool(true)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify protocol info
    let protocolInfo = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-protocol-info',
      [],
      deployer.address
    );
    
    const info = protocolInfo.result.expectTuple();
    assertEquals(info['protocol-fee'], types.uint(50));
    assertEquals(info['paused'], types.bool(true));
  }
});

Clarinet.test({
  name: "Test enhanced pool statistics and analytics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    // Setup: mint tokens and create pool
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000),
        types.principal(user1.address)
      ], deployer.address)
    ]);

    // Create pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(500000000), // 500 tokens A
        types.uint(1000000000), // 1000 tokens B
        types.uint(300)
      ], user1.address)
    ]);

    // Test pool statistics
    let poolStats = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool-stats',
      [types.uint(1)],
      user1.address
    );

    poolStats.result.expectOk();
    const stats = poolStats.result.expectOk().expectTuple();
    assertEquals(stats['reserve-a'], types.uint(500000000));
    assertEquals(stats['reserve-b'], types.uint(1000000000));

    // Test pool health
    let poolHealth = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool-health',
      [types.uint(1)],
      user1.address
    );

    poolHealth.result.expectOk();
    const health = poolHealth.result.expectOk().expectTuple();
    assertEquals(health['is-balanced'], types.bool(true));
    assertEquals(health['min-liquidity-met'], types.bool(true));

    // Test comprehensive analytics
    let analytics = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool-analytics',
      [types.uint(1)],
      user1.address
    );

    analytics.result.expectOk();
  }
});

Clarinet.test({
  name: "Test price impact calculation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    // Setup: mint tokens and create pool
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000),
        types.principal(user1.address)
      ], deployer.address)
    ]);

    // Create pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(1000000000), // 1000 tokens A
        types.uint(2000000000), // 2000 tokens B
        types.uint(300)
      ], user1.address)
    ]);

    // Test price impact for small swap (should be low)
    let smallSwapImpact = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'calculate-price-impact',
      [
        types.uint(1),
        types.principal(deployer.address + '.mock-token-a'),
        types.uint(10000000) // 10 tokens (1% of pool)
      ],
      user1.address
    );

    smallSwapImpact.result.expectOk();

    // Test price impact for large swap (should be higher)
    let largeSwapImpact = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'calculate-price-impact',
      [
        types.uint(1),
        types.principal(deployer.address + '.mock-token-a'),
        types.uint(100000000) // 100 tokens (10% of pool)
      ],
      user1.address
    );

    largeSwapImpact.result.expectOk();
  }
});

Clarinet.test({
  name: "Test fee tracking functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;

    // Setup: mint tokens and create pool
    let block = chain.mineBlock([
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(1000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-b', 'mint', [
        types.uint(2000000000),
        types.principal(user1.address)
      ], deployer.address),
      Tx.contractCall('mock-token-a', 'mint', [
        types.uint(100000000),
        types.principal(user2.address)
      ], deployer.address)
    ]);

    // Create pool
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'create-pool', [
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(500000000),
        types.uint(1000000000),
        types.uint(300) // 3% fee
      ], user1.address)
    ]);

    // Perform swap to generate fees
    block = chain.mineBlock([
      Tx.contractCall('cross-chain-liquidity-aggregator', 'swap-tokens', [
        types.uint(1),
        types.principal(deployer.address + '.mock-token-a'),
        types.principal(deployer.address + '.mock-token-b'),
        types.uint(10000000), // 10 tokens
        types.uint(1)
      ], user2.address)
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk();

    // Check pool fees
    let poolFees = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-pool-fees',
      [types.uint(1)],
      user2.address
    );

    poolFees.result.expectOk();
    const fees = poolFees.result.expectOk().expectTuple();
    // Should have collected fees from the swap

    // Check protocol fees
    let protocolFees = chain.callReadOnlyFn(
      'cross-chain-liquidity-aggregator',
      'get-protocol-fees',
      [types.principal(deployer.address + '.mock-token-a')],
      user2.address
    );

    protocolFees.result.expectOk();
  }
});
