// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import "../src/PhonePricing.sol";

// contract PhonePricingTest is Test {
//     PhonePricing public pricing;
//     address public owner;
//     address public user;

//     // Test values
//     uint256 constant BASE_PRICE = 0.01 ether;
//     uint256 constant YEAR_IN_SECONDS = 365 days;

//     event BasePriceUpdated(uint256 newPrice);
//     event CountryMultiplierSet(string countryCode, uint256 multiplier);
//     event CountryMultiplierRemoved(string countryCode);

//     function setUp() public {
//         owner = makeAddr("owner");
//         user = makeAddr("user");

//         vm.prank(owner);
//         pricing = new PhonePricing(BASE_PRICE);
//     }

//     function test_Constructor() public {
//         assertEq(pricing.basePrice(), BASE_PRICE);
//         assertEq(pricing.owner(), owner);
//     }

//     function test_SetBasePrice() public {
//         uint256 newPrice = 0.02 ether;

//         vm.expectEmit(true, true, true, true);
//         emit BasePriceUpdated(newPrice);

//         vm.prank(owner);
//         pricing.setBasePrice(newPrice);

//         assertEq(pricing.basePrice(), newPrice);
//     }

//     function testFail_SetBasePrice_NonOwner() public {
//         vm.prank(user);
//         pricing.setBasePrice(0.02 ether);
//     }

//     function test_SetAndRemoveCountryMultiplier() public {
//         string memory countryCode = "234"; // Nigeria
//         uint256 multiplier = 8000; // 80%

//         vm.startPrank(owner);

//         // Set multiplier
//         vm.expectEmit(true, true, true, true);
//         emit CountryMultiplierSet(countryCode, multiplier);
//         pricing.setCountryMultiplier(countryCode, multiplier);

//         assertEq(pricing.countryMultipliers(countryCode), multiplier);

//         // Remove multiplier
//         vm.expectEmit(true, true, true, true);
//         emit CountryMultiplierRemoved(countryCode);
//         pricing.removeCountryMultiplier(countryCode);

//         assertEq(pricing.countryMultipliers(countryCode), 0);

//         vm.stopPrank();
//     }

//     function testFail_SetCountryMultiplier_InvalidMultiplier() public {
//         vm.startPrank(owner);

//         // Can't set multiplier to 0
//         pricing.setCountryMultiplier("234", 0);

//         // Can't set multiplier to 100% (10000) as it's the default
//         pricing.setCountryMultiplier("234", 10_000);

//         vm.stopPrank();
//     }

//     function test_ExtractCountryCode() public {
//         assertEq(pricing.extractCountryCode("+11234567890"), "1");
//         assertEq(pricing.extractCountryCode("+441234567890"), "44");
//         assertEq(pricing.extractCountryCode("+2341234567890"), "234");
//     }

//     function testFail_ExtractCountryCode_InvalidFormat() public {
//         // Missing plus
//         pricing.extractCountryCode("11234567890");
//     }

//     function test_GetRegistrationFee_StandardPrice() public {
//         string memory phoneNumber = "+11234567890";
//         uint256 duration = YEAR_IN_SECONDS;

//         uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);
//         assertEq(fee, BASE_PRICE);

//         // Test 2 years
//         fee = pricing.getRegistrationFee(phoneNumber, 2 * YEAR_IN_SECONDS);
//         assertEq(fee, 2 * BASE_PRICE);
//     }

//     function test_GetRegistrationFee_WithMultiplier() public {
//         string memory phoneNumber = "+2341234567890";
//         uint256 multiplier = 8000; // 80%

//         vm.prank(owner);
//         pricing.setCountryMultiplier("234", multiplier);

//         uint256 fee = pricing.getRegistrationFee(phoneNumber, YEAR_IN_SECONDS);
//         assertEq(fee, (BASE_PRICE * multiplier) / 10_000);
//     }

//     function testFail_GetRegistrationFee_InvalidDuration() public {
//         string memory phoneNumber = "+11234567890";

//         // Too short
//         pricing.getRegistrationFee(phoneNumber, 364 days);

//         // Too long
//         pricing.getRegistrationFee(phoneNumber, 3651 days);
//     }

//     function test_GetFeeDetails() public {
//         string memory phoneNumber = "+2341234567890";
//         uint256 duration = 2 * YEAR_IN_SECONDS;
//         uint256 multiplier = 8000; // 80%

//         vm.prank(owner);
//         pricing.setCountryMultiplier("234", multiplier);

//         (uint256 numberOfYears, uint256 pricePerYear, uint256 totalPrice) = pricing.getFeeDetails(phoneNumber, duration);

//         assertEq(numberOfYears, 2);
//         assertEq(pricePerYear, (BASE_PRICE * multiplier) / 10_000);
//         assertEq(totalPrice, 2 * ((BASE_PRICE * multiplier) / 10_000));
//     }

//     function test_RenewalFeeMatchesRegistration() public {
//         string memory phoneNumber = "+11234567890";
//         uint256 duration = YEAR_IN_SECONDS;

//         uint256 regFee = pricing.getRegistrationFee(phoneNumber, duration);
//         uint256 renewFee = pricing.getRenewalFee(phoneNumber, duration);

//         assertEq(regFee, renewFee);
//     }
// }
