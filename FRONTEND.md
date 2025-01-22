# PNS Frontend Integration Guide

This guide explains how to integrate Phone Number Service (PNS) into your frontend application.

## Checking Phone Number Availability

Before registration, you'll want to check if a phone number is available:

```typescript
const checkAvailability = async (phoneNumber: string): Promise<boolean> => {
  // Get the registered address for this phone number
  const owner = await registrarContract.phoneToAddress(phoneNumber);
  
  // If address is zero address, the phone number is available
  return owner === "0x0000000000000000000000000000000000000000";
};

// Example usage
const isAvailable = await checkAvailability("+2347084462591");
if (!isAvailable) {
  console.log("This phone number is already registered");
}
```

## Getting Registration Price

To get the registration price for a phone number:

```typescript
const getRegistrationPrice = async (
  phoneNumber: string,
  durationInYears: number
): Promise<{ 
  numberOfYears: number,
  pricePerYear: bigint,
  totalPrice: bigint 
}> => {
  // Convert years to seconds
  const duration = durationInYears * 365 * 24 * 60 * 60;
  
  // Get detailed fee breakdown
  const feeDetails = await pricingContract.getFeeDetails(phoneNumber, duration);
  
  return {
    numberOfYears: feeDetails.numberOfYears,
    pricePerYear: feeDetails.pricePerYear,
    totalPrice: feeDetails.totalPrice
  };
};

// Example usage
const price = await getRegistrationPrice("+2347084462591", 1);
console.log(`Registration price: ${ethers.formatEther(price.totalPrice)} ETH`);
```

## Example Price Calculation Flow

```typescript
// 1. Get base price for a specific duration
const getBasePrice = async (phoneNumber: string, years: number) => {
  const duration = years * 365 * 24 * 60 * 60; // Convert to seconds
  const fee = await pricingContract.getRegistrationFee(phoneNumber, duration);
  return fee;
};

// 2. Check if country has special pricing
const getCountryMultiplier = async (phoneNumber: string) => {
  // Extract country code (e.g., "234" from "+2347084462591")
  const countryCode = phoneNumber.slice(1).match(/^\d+/)[0];
  const multiplier = await pricingContract.countryMultipliers(countryCode);
  return multiplier;
};

// 3. Full price check with breakdown
const getPriceBreakdown = async (phoneNumber: string, years: number) => {
  const details = await pricingContract.getFeeDetails(phoneNumber, years * 365 * 24 * 60 * 60);
  
  return {
    years: Number(details.numberOfYears),
    yearlyPrice: ethers.formatEther(details.pricePerYear),
    total: ethers.formatEther(details.totalPrice)
  };
};
```

## Registration Flow

Complete registration flow example:

```typescript
const registerPhoneNumber = async (phoneNumber: string, years: number) => {
  try {
    // 1. Check availability
    const isAvailable = await checkAvailability(phoneNumber);
    if (!isAvailable) {
      throw new Error("Phone number already registered");
    }

    // 2. Get price details
    const priceDetails = await getPriceBreakdown(phoneNumber, years);
    
    // 3. Register with the correct duration and value
    const duration = years * 365 * 24 * 60 * 60;
    const tx = await registrarContract.register(
      phoneNumber,
      duration,
      { value: ethers.parseEther(priceDetails.total) }
    );
    
    // 4. Wait for transaction
    const receipt = await tx.wait();
    
    // 5. Return registration details
    return {
      transactionHash: receipt.transactionHash,
      expiryDate: new Date(Date.now() + (duration * 1000)),
      price: priceDetails.total
    };
  } catch (error) {
    console.error("Registration failed:", error);
    throw error;
  }
};
```

## Getting Expiry Date

```typescript
const getExpiryDate = async (phoneNumber: string): Promise<Date> => {
  const expiry = await registrarContract.getExpiry(phoneNumber);
  return new Date(Number(expiry) * 1000);
};
```

## Error Handling

Common errors to handle in your frontend:

```typescript
const ERROR_MESSAGES = {
  "Phone number already registered": "This phone number is already taken",
  "Invalid phone number format": "Please enter a valid phone number with country code (e.g., +2347084462591)",
  "Insufficient payment": "The payment amount is incorrect",
  "Invalid registration period": "Please select a registration period between 1 and 10 years"
};

// Example error handling
try {
  await registerPhoneNumber(phoneNumber, years);
} catch (error) {
  const message = ERROR_MESSAGES[error.message] || "Registration failed. Please try again.";
  // Show error to user
}
```

## Useful Utility Functions

```typescript
// Format price to user-friendly string
const formatPrice = (priceWei: bigint): string => {
  const priceEth = ethers.formatEther(priceWei);
  return `${parseFloat(priceEth).toFixed(4)} ETH`;
};

// Validate phone number format
const isValidPhoneNumber = (phoneNumber: string): boolean => {
  return /^\+\d{8,15}$/.test(phoneNumber);
};

// Get registration status
const getRegistrationStatus = async (phoneNumber: string) => {
  const owner = await registrarContract.phoneToAddress(phoneNumber);
  const expiry = await registrarContract.getExpiry(phoneNumber);
  
  return {
    isRegistered: owner !== "0x0000000000000000000000000000000000000000",
    owner: owner,
    expiryDate: new Date(Number(expiry) * 1000),
    canRenew: Number(expiry) > Date.now() / 1000
  };
};
```

## Contract Events

Listen for registration and renewal events:

```typescript
registrarContract.on("PhoneNumberRegistered", (phoneNumber, owner, expiryDate) => {
  console.log(`New registration: ${phoneNumber} by ${owner}`);
});

registrarContract.on("PhoneNumberRenewed", (phoneNumber, owner, expiryDate) => {
  console.log(`Renewal: ${phoneNumber} by ${owner}`);
});
```

## Type Definitions

TypeScript types for better development experience:

```typescript
interface PriceDetails {
  numberOfYears: number;
  pricePerYear: bigint;
  totalPrice: bigint;
}

interface RegistrationStatus {
  isRegistered: boolean;
  owner: string;
  expiryDate: Date;
  canRenew: boolean;
}

interface RegistrationResult {
  transactionHash: string;
  expiryDate: Date;
  price: string;
}
```

## Testing

Example Jest test cases:

```typescript
describe('PNS Frontend Integration', () => {
  test('should check phone number availability', async () => {
    const isAvailable = await checkAvailability("+1234567890");
    expect(isAvailable).toBe(true);
  });

  test('should get correct price for registration', async () => {
    const price = await getRegistrationPrice("+1234567890", 1);
    expect(price.totalPrice).toBeDefined();
    expect(price.numberOfYears).toBe(1);
  });
});
```