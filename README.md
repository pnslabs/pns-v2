# Phone Number Service (PNS)

## Overview

Phone Number Service (PNS) is a decentralized protocol built on top of ENS (Ethereum Name Service) that enables users to register their phone numbers as ENS subnames under the `usepns.eth` domain. This allows users to link their phone numbers to their Ethereum addresses, creating a simple and memorable way to send and receive cryptocurrency using phone numbers.

For example: `+2349089062991.usepns.eth` could resolve to `0x742d35Cc6634C0532925a3b844Bc454e4438f44e`

## Features

- Phone number registration and renewal
- Country-specific pricing
- Multi-year registrations (1-10 years)
- Secure and non-custodial
- Integrates with existing ENS infrastructure
- Immutable registrations with ENS Wrapper's fuse system

## Contract Architecture

### Core Contracts

1. **PhoneNumberRegistrar.sol**
   - Main contract for managing phone number registrations
   - Handles registration, renewal, and name management
   - Integrates with ENS NameWrapper for fuse controls
   - Ensures secure and non-custodial ownership

2. **PhonePricing.sol**
   - Manages pricing logic for registrations and renewals
   - Supports country-specific price multipliers
   - Handles multi-year registration pricing
   - Configurable base prices and multipliers

3. **PhoneNumberResolver.sol**
   - Implements ENSIP-9 and ENSIP-10 for multichain address resolution
   - Uses CCIP-read (EIP-3668) for secure offchain data retrieval
   - Supports both read (GET) and write (POST) operations
   - Includes signature verification for gateway responses

### Key Functions

#### PhoneNumberRegistrar.sol

```solidity
// Register a phone number
function register(bytes32 phoneNumberHash, string calldata countryCode, uint256 duration) external payable

// Renew a phone number registration
function renew(bytes32 phoneNumberHash, string calldata countryCode, uint64 duration) external payable

// Get current expiry of a phone number
function getCurrentExpiry(string calldata phoneNumber) public view returns (uint64)
```

#### PhonePricing.sol

```solidity
// Get registration fee for a phone number and duration
function getRegistrationFee(string calldata phoneNumber, uint256 duration) external view returns (uint256)

// Get renewal fee for a phone number and duration
function getRenewalFee(string calldata phoneNumber, uint256 duration) external view returns (uint256)
```

#### PhoneNumberResolver.sol

```solidity
// Resolve a name using CCIP-read
function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory)

// Get address for a specific coin type
function addr(bytes32 node, uint256 coinType) external view returns (bytes memory)

// Set address for a specific coin type
function setAddr(bytes32 node, uint256 coinType, bytes calldata newAddr) external
```

## Security Features

1. **Fuse System**
   - PARENT_CANNOT_CONTROL: Ensures registrations are "unruggable"
   - CANNOT_UNWRAP: Prevents unwrapping of names
   - CANNOT_TRANSFER: Makes names non-transferable

2. **Phone Number Validation**
   - Strict format validation (E.164 format)
   - Country code verification
   - Length validation

3. **Privacy and Security**
   - No reverse lookups: Users can't query an address to find associated phone numbers
   - No public address-to-phone mapping
   - Secure offchain data retrieval using CCIP-read (EIP-3668)
   - Signed gateway responses for data integrity
   - Separate read (GET) and write (POST) operations

## Registration Process

1. **Pre-registration**
   - Check phone number availability
   - Calculate registration fee
   - Ensure proper phone number format

2. **Registration**
   - Submit phone number and desired duration
   - Pay registration fee
   - Receive wrapped ENS subname

## Pricing Model

1. **Base Price**
   - Set in constructor
   - Applied per year of registration

2. **Country Multipliers**
   - Default: 100% of base price (multiplier = 10000)
   - Special pricing for specific country codes
   - Configurable by contract owner

3. **Duration Based**
   - Minimum: 1 year
   - Maximum: 10 years
   - Linear pricing (no bulk discounts)

Example:
```
Base Price: 0.01 ETH/year
Normal Registration: 0.01 ETH/year
Country with 80% multiplier: 0.008 ETH/year
2-year registration: 2 * yearly price
```

## Usage Examples

### Registration
```javascript
// Register a phone number for 2 years
const phoneNumber = "+2347084462591";
const phoneNumberHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(phoneNumber));
const countryCode = "234"; // Nigeria
const duration = 2 * 365 * 24 * 60 * 60; // 2 years in seconds

// Get registration fee
const fee = await pricingContract.getRegistrationFee(countryCode, duration);

// Register
await registrar.register(phoneNumberHash, countryCode, duration, { value: fee });
```

### Resolver Usage
```javascript
// Get ETH address for a phone number
const node = namehash(phoneNumber + '.usepns.eth');
const address = await resolver.addr(node, 60); // 60 is COIN_TYPE_ETH

// Set ETH address
await resolver.setAddr(node, 60, newAddress);
```

### Renewal
```javascript
// Renew a phone number for 1 year
const duration = 365 * 24 * 60 * 60; // 1 year in seconds
const fee = await pricingContract.getRenewalFee(phoneNumber, duration);

await registrar.renew(phoneNumber, duration, { value: fee });
```

## Deployment

1. **Prerequisites**
   - Own and wrap `usepns.eth` name
   - Deploy pricing contract
   - Configure ENS resolver

2. **Deployment Steps**
```bash
# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Deploy
forge script script/Deploy.s.sol:DeployPNS --rpc-url $RPC_URL --broadcast
```

## Testing

Run the test suite:
```bash
forge test
```

Run with verbosity for more details:
```bash
forge test -vvv
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## Contact

For questions and support, please open an issue in the GitHub repository.