# Smart Contract Lottery

## Description

This project is a decentralized lottery application built in Solidity. The contract uses Chainlink VRF to ensure provably fair randomness in selecting lottery winners. The application also implements best practices in smart contract development, including security patterns like Checks-Effects-Interactions (CEI) and error handling with custom errors.

## Technologies Used

- **Solidity (v0.8.19)**: Core smart contract language.
- **Chainlink VRFv2.5**: Used for verifiable randomness.
- **Foundry**: Development framework for testing, building, and deploying smart contracts.

## Key Features

- **Fairness**: Leverages Chainlink VRF to guarantee randomness.
- **Efficiency**: Uses optimized libraries for reduced gas consumption.
- **Security**: Implements best practices, including the Checks-Effects-Interactions pattern and custom error handling.

## Installation

To set up the project locally, follow the steps below:

1. Clone the repository:

   ```bash
   git clone https://github.com/ianwright27/lottery-smart-contract.git
   ```

2. Navigate to the project directory:

   ```bash
   cd smart-contract-lottery
   ```

3. Install dependencies:
   ```bash
   make install
   ```

## Testing

Run the tests to ensure everything is working correctly:

```bash
make test
```

## Deployment

To deploy the contract to Sepolia testnet:

```bash
make deploy-sepolia
```

Ensure you have set your environment variables correctly in a `.env` file:

```
SEPOLIA_RPC_URL=<your_rpc_url>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
```
