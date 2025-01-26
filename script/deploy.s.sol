// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/PhoneNumberRegistrar.sol";
import "../src/PhonePricing.sol";
import "@ensdomains/utils/NameEncoder.sol";

contract DeployPNS is Script {
    // Mainnet addresses
    address constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;
    address constant NAME_WRAPPER = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    struct CountryMultiplier {
        string countryCode;
        uint256 multiplier;
    }

    CountryMultiplier[] internal countryMultipliers;

    function setUp() public {
        // Initialize country multipliers
        countryMultipliers.push(CountryMultiplier("1", 15_000)); // US/Canada: 150%
        countryMultipliers.push(CountryMultiplier("44", 15_000)); // UK: 150%
        countryMultipliers.push(CountryMultiplier("86", 15_000)); // China: 150%
    }

    function run() external {
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        string memory parentNodeName = vm.envString("PARENT_NODE");
        (, bytes32 parentNode) = NameEncoder.dnsEncodeName(parentNodeName);
        uint256 basePrice = vm.envUint("BASE_PRICE");

        vm.startBroadcast();

        // Deploy Pricing Contract
        PhonePricing pricing = new PhonePricing(basePrice);
        console.log("PhonePricing deployed at:", address(pricing));

        // Set country multipliers
        for (uint256 i = 0; i < countryMultipliers.length; i++) {
            CountryMultiplier memory cm = countryMultipliers[i];
            pricing.setCountryMultiplier(cm.countryCode, cm.multiplier);
            console.log("Set multiplier for country %s to %d basis points", cm.countryCode, cm.multiplier);
        }

        // Deploy Resolver
        PhoneNumberResolver resolver = new PhoneNumberResolver("https://", treasury);
        console.log("PhoneNumberResolver deployed at:", address(resolver));

        // Deploy Registrar with updated constructor params
        PhoneNumberRegistrar registrar =
            new PhoneNumberRegistrar(address(NAME_WRAPPER), parentNode, address(resolver), address(pricing));
        console.log("PhoneNumberRegistrar deployed at:", address(registrar));

        // Set up approvals
        INameWrapper(NAME_WRAPPER).setApprovalForAll(address(registrar), true);
        console.log("Approved registrar in NameWrapper");

        // Transfer pricing ownership
        pricing.transferOwnership(registrar.owner());
        console.log("Transferred pricing ownership to registrar owner");

        vm.stopBroadcast();

        // Print final configuration summary
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("Base Price: %d wei", basePrice);
        console.log("Premium Countries (150%):");
        console.log("- United States/Canada (+1)");
        console.log("- United Kingdom (+44)");
        console.log("- China (+86)");
        console.log("\nAll other countries: 100% of base price");
    }
}
