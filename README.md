# dTSLA - Decentralized Tesla Token

A decentralized synthetic asset that tracks Tesla (TSLA) stock price, built on Arbitrum using Chainlink Functions and real-world brokerage integration.

## 🚀 Overview

dTSLA is a collateralized synthetic token that allows users to gain exposure to Tesla stock without directly owning shares. The system uses:

- **Chainlink Functions** for real-time portfolio data from Alpaca Markets
- **Chainlink Price Feeds** for accurate TSLA/USD pricing
- **200% overcollateralization** for security
- **Automated minting/redeeming** through smart contracts

## 🏗️ Architecture

### Core Components

1. **dTSLA Smart Contract** (`src/dTSLA.sol`)
   - ERC20 token with minting/burning capabilities
   - Chainlink Functions integration for external data
   - Price feed integration for TSLA/USD rates
   - Collateral ratio management (200%)

2. **Chainlink Functions**
   - `alpacaBalance.js`: Fetches portfolio balance from Alpaca Markets
   - Real-time integration with brokerage accounts
   - Secure API key management through DON-hosted secrets

3. **Price Feeds**
   - TSLA/USD price feed for accurate pricing
   - USDC/USD price feed for redemption calculations

### Key Features

- ✅ **Overcollateralized**: 200% collateral ratio for security
- ✅ **Real-time Data**: Live portfolio balance from Alpaca Markets
- ✅ **Automated Minting**: Smart contract validates collateral before minting
- ✅ **Automated Redemption**: Users can redeem dTSLA for USDC
- ✅ **Price Oracle**: Accurate TSLA pricing via Chainlink feeds
- ✅ **Multi-chain Ready**: Built for Arbitrum with CCIP support

## 🛠️ Technology Stack

- **Smart Contracts**: Solidity 0.8.30
- **Framework**: Foundry
- **Oracle**: Chainlink Functions + Price Feeds
- **Brokerage**: Alpaca Markets API
- **Network**: Arbitrum Sepolia (testnet) / Arbitrum One (mainnet)
- **Token Standard**: ERC20

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v18+)
- [Alpaca Markets Account](https://alpaca.markets/) with API keys
- [Chainlink Functions Subscription](https://functions.chain.link/)

## 🚀 Quick Start

### 1. Clone and Install

```bash
git clone <repository-url>
cd Arbitrum-Final-Project
forge install
npm install
```

### 2. Environment Setup

Create a `.env` file:
```bash
ALPACA_KEY=your_alpaca_api_key
ALPACA_SECRET=your_alpaca_secret_key
PRIVATE_KEY=your_deployment_private_key
ARBITRUM_RPC_URL=your_arbitrum_rpc_url
```

### 3. Build Contracts

```bash
forge build
```

### 4. Deploy

```bash
forge script script/DeployDTsla.s.sol:DeployDTslaScript \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## 📊 How It Works

### Minting Process
1. User requests to mint dTSLA tokens
2. Smart contract calls Chainlink Function to check Alpaca portfolio balance
3. If sufficient collateral exists (200% ratio), tokens are minted
4. Portfolio balance is updated in real-time

### Redemption Process
1. User burns dTSLA tokens
2. Smart contract calculates USDC equivalent based on TSLA price
3. Chainlink Function executes sell order on Alpaca Markets
4. USDC is transferred to user's withdrawal balance

### Price Calculation
- Uses Chainlink TSLA/USD price feed
- 8 decimal precision for accurate pricing
- Real-time updates from decentralized oracle network

## 🔧 Configuration

### Network Configurations

The system supports multiple networks:

- **Arbitrum Sepolia** (Testnet)
- **Arbitrum One** (Mainnet)
- **Polygon** (Mainnet)

### Key Parameters

```solidity
uint256 public constant COLLATERAL_RATIO = 200; // 200% overcollateralization
uint256 public constant MINIMUM_REDEMPTION_AMOUNT = 100e18; // Minimum redemption
uint32 constant GAS_LIMIT = 300000; // Functions gas limit
```

## 🧪 Testing

### Run Tests
```bash
forge test
```

### Run with Verbose Output
```bash
forge test -vvv
```

### Test Functions Locally
```bash
node functions/simulators/alpacaMintSimulator.js
```

## 🔒 Security Features

- **Overcollateralization**: 200% collateral ratio prevents undercollateralization
- **Access Control**: Only owner can initiate minting requests
- **Price Oracle**: Decentralized price feeds prevent manipulation
- **Error Handling**: Comprehensive error handling for failed operations
- **Refund Mechanism**: Failed redemptions refund dTSLA tokens

## 📈 API Integration

### Alpaca Markets Integration
- Real-time portfolio balance checking
- Automated trading execution
- Secure API key management
- Paper trading support for testing

### Chainlink Functions
- DON-hosted secrets for secure API key storage
- JavaScript execution environment
- Gas-efficient external data fetching
- Decentralized oracle network

## 🚨 Important Notes

1. **API Keys**: Store Alpaca API keys securely using DON-hosted secrets
2. **Collateral Ratio**: Maintain 200% overcollateralization for security
3. **Gas Costs**: Functions calls incur gas costs on Arbitrum
4. **Price Feeds**: Ensure price feeds are active and accurate
5. **Testing**: Always test on testnet before mainnet deployment

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues and questions:
- Open an issue on GitHub
- Check the Chainlink Functions documentation
- Review Alpaca Markets API documentation

## 🔗 Links

- [Chainlink Functions Documentation](https://docs.chain.link/chainlink-functions)
- [Alpaca Markets API](https://alpaca.markets/docs/)
- [Arbitrum Documentation](https://docs.arbitrum.io/)
- [Foundry Book](https://book.getfoundry.sh/)
