# Cross-Chain Liquidity Aggregator

A comprehensive DeFi protocol for cross-chain liquidity aggregation built on Stacks blockchain, enabling seamless token swaps and liquidity provision across Bitcoin and Stacks ecosystems.

## 🌟 Features

- **Multi-Chain Liquidity Pools**: Create and manage liquidity pools for various token pairs
- **Cross-Chain Swaps**: Initiate and complete token swaps across different blockchain networks
- **Automated Market Making**: Constant product formula (x*y=k) for efficient price discovery
- **Advanced Analytics**: Comprehensive pool statistics, health metrics, and price impact calculations
- **Fee Tracking**: Detailed fee collection tracking for pools and protocol
- **Pool Health Monitoring**: Real-time health scores and balance ratio monitoring
- **Price Impact Analysis**: Calculate and display price impact before executing swaps
- **Fee Management**: Configurable protocol fees with admin controls
- **Security First**: Built-in access controls, slippage protection, and emergency mechanisms
- **SIP-010 Compatible**: Full support for Stacks fungible token standard

## 🏗️ Architecture

### Core Components

1. **Liquidity Pools**: Decentralized pools holding token pairs for trading
2. **Cross-Chain Bridge**: Mechanism for initiating and completing cross-chain transactions
3. **Fee System**: Protocol and liquidity provider fee distribution
4. **Admin Controls**: Governance functions for protocol management

### Smart Contracts

- `cross-chain-liquidity-aggregator.clar`: Main protocol contract
- `sip-010-trait.clar`: Fungible token standard interface
- `mock-token-a.clar` & `mock-token-b.clar`: Test tokens for development

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js 16+ for testing
- Git for version control

### Installation

```bash
# Clone the repository
git clone https://github.com/7zak/cross-chain-liquidity-aggregator.git
cd cross-chain-liquidity-aggregator

# Install Clarinet (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install clarinet-cli

# Check installation
clarinet --version
```

### Development Setup

```bash
# Check contract syntax
clarinet check

# Run tests
clarinet test

# Start local development environment
clarinet integrate
```

## 📖 Usage Guide

### Creating a Liquidity Pool

```clarity
;; Create a new pool with initial liquidity
(contract-call? .cross-chain-liquidity-aggregator create-pool
  .token-a-contract
  .token-b-contract
  u100000000  ;; 100 tokens A (with 6 decimals)
  u200000000  ;; 200 tokens B (with 6 decimals)
  u300        ;; 3% fee rate (in basis points)
)
```

### Adding Liquidity

```clarity
;; Add liquidity to existing pool
(contract-call? .cross-chain-liquidity-aggregator add-liquidity
  u1          ;; pool-id
  .token-a-contract
  .token-b-contract
  u50000000   ;; 50 tokens A
  u100000000  ;; 100 tokens B
  u1          ;; minimum liquidity tokens to receive
)
```

### Token Swapping

```clarity
;; Swap tokens within a pool
(contract-call? .cross-chain-liquidity-aggregator swap-tokens
  u1          ;; pool-id
  .token-a-contract  ;; input token
  .token-b-contract  ;; output token
  u10000000   ;; 10 tokens input
  u19000000   ;; minimum output (slippage protection)
)
```

### Cross-Chain Operations

```clarity
;; Initiate cross-chain swap
(contract-call? .cross-chain-liquidity-aggregator initiate-cross-chain-swap
  .source-token-contract
  "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"  ;; target token address
  "bitcoin"    ;; target chain
  u50000000    ;; amount to swap
  "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"  ;; recipient address
  u144         ;; expiration in blocks
)
```

## 🧪 Testing

The project includes comprehensive test coverage for all major functions:

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/cross-chain-liquidity-aggregator_test.ts

# Generate coverage report
clarinet test --coverage
```

### Test Categories

- **Unit Tests**: Individual function testing
- **Integration Tests**: Multi-contract interactions
- **Security Tests**: Access control and edge cases
- **Cross-Chain Tests**: Bridge functionality validation

## 🔧 Configuration

### Network Settings

Edit `Clarinet.toml` to configure different networks:

```toml
[networks]
testnet = "https://stacks-node-api.testnet.stacks.co"
mainnet = "https://stacks-node-api.mainnet.stacks.co"

[networks.devnet]
host = "localhost"
port = 20443
```

### Protocol Parameters

Key parameters can be adjusted via admin functions:

- **Protocol Fee**: 0-100% (in basis points)
- **Fee Recipient**: Address receiving protocol fees
- **Pool Status**: Active/inactive state management
- **Emergency Controls**: Pause/unpause functionality

## 🔐 Security Features

### Access Controls
- Owner-only admin functions
- Multi-signature support ready
- Role-based permissions

### Safety Mechanisms
- Slippage protection for all swaps
- Minimum liquidity requirements
- Overflow/underflow protection
- Emergency pause functionality

### Audit Considerations
- Reentrancy protection
- Input validation on all functions
- Safe math operations
- Event logging for transparency

## 📊 Economics

### Fee Structure
- **Liquidity Provider Fees**: Earned on each swap (configurable per pool)
- **Protocol Fees**: Additional fee for protocol development (0.3% default)
- **Cross-Chain Fees**: Bridge operation costs (varies by target chain)

### Tokenomics
- LP tokens represent proportional pool ownership
- Fees automatically compound into pool reserves
- Cross-chain operations require collateral locking

## 🛠️ API Reference

### Read-Only Functions

#### `get-pool(pool-id)`
Returns pool information including reserves, fees, and status.

#### `get-pool-id(token-a, token-b)`
Finds pool ID for a given token pair.

#### `calculate-swap-output(pool-id, token-in, amount-in)`
Calculates expected output for a swap including fees.

#### `get-liquidity-shares(pool-id, provider)`
Returns LP token balance for a provider.

#### `get-protocol-info()`
Returns current protocol configuration.

### Public Functions

#### `create-pool(token-a, token-b, initial-a, initial-b, fee-rate)`
Creates a new liquidity pool with initial liquidity.

#### `add-liquidity(pool-id, token-a, token-b, amount-a, amount-b, min-liquidity)`
Adds liquidity to an existing pool.

#### `remove-liquidity(pool-id, token-a, token-b, liquidity-amount, min-amount-a, min-amount-b)`
Removes liquidity from a pool.

#### `swap-tokens(pool-id, token-in, token-out, amount-in, min-amount-out)`
Performs a token swap within a pool.

#### `initiate-cross-chain-swap(...)`
Starts a cross-chain swap operation.

### Admin Functions

#### `set-protocol-fee(new-fee)`
Updates the protocol fee rate (owner only).

#### `set-fee-recipient(new-recipient)`
Changes the protocol fee recipient (owner only).

#### `set-paused(pause)`
Pauses/unpauses the protocol (owner only).

#### `deactivate-pool(pool-id)`
Deactivates a specific pool (owner only).

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Standards

- Follow Clarity best practices
- Include comprehensive tests
- Document all public functions
- Use conventional commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [SIP-010 Standard](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md)

## ⚠️ Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Always audit smart contracts before mainnet deployment.
