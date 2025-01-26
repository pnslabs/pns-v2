// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/PhoneNumberRegistrar.sol";
import "../src/PhoneNumberResolver.sol";
import "../src/PhonePricing.sol";
import "./mocks/MockNameWrapper.sol";
contract PhoneNumberTest is Test {
    PhoneNumberRegistrar public registrar;
    PhoneNumberResolver public resolver;
    PhonePricing public pricing;
    MockNameWrapper public nameWrapper;

    address public owner;
    address public user1;
    address public user2;
    address public treasury;
    uint256 public signerKey;
    address public signer;

    string public constant GATEWAY_URL = "https://gateway.example.com";
    bytes32 public constant PARENT_NODE = bytes32(uint256(0x1));
    uint256 public constant BASE_PRICE = 0.01 ether;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");
        signerKey = 0x1234;
        signer = vm.addr(signerKey);

        vm.startPrank(owner);

        // Deploy contracts
        nameWrapper = new MockNameWrapper(
            keccak256(abi.encodePacked(bytes32(0), keccak256("usepns")))
        );
        pricing = new PhonePricing(BASE_PRICE);
        resolver = new PhoneNumberResolver(GATEWAY_URL, signer);
        registrar = new PhoneNumberRegistrar(
            address(nameWrapper),
            PARENT_NODE,
            address(resolver),
            address(pricing)
        );

        vm.stopPrank();
    }

    // Pricing Contract Tests
    function testPricingBasics() public {
        assertEq(pricing.basePrice(), BASE_PRICE);
        assertEq(pricing.getYearlyPrice("1"), BASE_PRICE);
    }

    function testPricingMultipliers() public {
        vm.startPrank(owner);
        pricing.setCountryMultiplier("1", 5000); // 50%
        assertEq(pricing.getYearlyPrice("1"), BASE_PRICE / 2);

        pricing.setCountryMultiplier("44", 15000); // 150%
        assertEq(pricing.getYearlyPrice("44"), (BASE_PRICE * 15000) / 10000);
        vm.stopPrank();
    }

    function testPricingDurationCalculation() public {
        uint256 oneYear = 365 days;
        uint256 twoYears = 730 days;

        assertEq(pricing.getRegistrationFee("1", oneYear), BASE_PRICE);
        assertEq(pricing.getRegistrationFee("1", twoYears), BASE_PRICE * 2);
    }

    function testPricingAccessControl() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1);
        pricing.setBasePrice(2 ether);
    }

    // Resolver Tests
    function testResolverBasics() public {
        assertEq(resolver.gatewayUrl(), GATEWAY_URL);
        assertEq(resolver.signer(), signer);
    }

    function testResolverOffchainLookup() public {
        bytes32 node = bytes32(uint256(1));
        uint256 coinType = 60;

        vm.expectRevert(
            abi.encodeWithSelector(
                PhoneNumberResolver.OffchainLookup.selector,
                address(resolver),
                [string(abi.encodePacked(GATEWAY_URL, "/{sender}/{data}"))],
                abi.encode(node, coinType),
                PhoneNumberResolver.resolveWithProof.selector,
                abi.encode(node, coinType)
            )
        );

        resolver.addr(node, coinType);
    }

    function testResolverSignatureVerification() public {
        bytes memory result = abi.encode(true);
        uint64 expires = uint64(block.timestamp + 300);
        bytes32 messageHash = SignatureVerifier.makeSignatureHash(
            address(resolver),
            expires,
            abi.encode("request"),
            result
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory response = abi.encode(result, expires, signature);
        bytes memory proof = resolver.resolveWithProof(
            response,
            abi.encode("request")
        );
        assertEq(keccak256(proof), keccak256(result));
    }

    // Registrar Tests
    function testRegistration() public {
        string memory phoneNumber = "+1234567890";
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        uint256 duration = 365 days;
        uint256 fee = pricing.getRegistrationFee("1", duration);

        vm.deal(user1, fee);
        vm.prank(user1);
        registrar.register{value: fee}(phoneHash, "1", duration);

        bytes32 node = keccak256(abi.encodePacked(PARENT_NODE, phoneHash));
        (address owner, , ) = nameWrapper.getData(uint256(node));
        assertEq(owner, user1);
    }

    function testRegistrationWithMultiplier() public {
        vm.prank(owner);
        pricing.setCountryMultiplier("44", 15000); // 150%

        string memory phoneNumber = "+441234567890";
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        uint256 duration = 365 days;
        uint256 fee = pricing.getRegistrationFee("44", duration);

        vm.deal(user1, fee);
        vm.prank(user1);
        registrar.register{value: fee}(phoneHash, "44", duration);

        bytes32 node = keccak256(abi.encodePacked(PARENT_NODE, phoneHash));
        (address owner, , ) = nameWrapper.getData(uint256(node));
        assertEq(owner, user1);
    }

    function testRenewal() public {
        // First register
        string memory phoneNumber = "+1234567890";
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        uint256 duration = 365 days;
        uint256 fee = pricing.getRegistrationFee("1", duration);

        vm.deal(user1, fee * 2);
        vm.startPrank(user1);

        registrar.register{value: fee}(phoneHash, "1", duration);

        // Then renew
        uint256 renewalFee = pricing.getRenewalFee("1", duration);
        registrar.renew{value: renewalFee}(phoneHash, "1", uint64(duration));

        vm.stopPrank();

        bytes32 node = keccak256(abi.encodePacked(PARENT_NODE, phoneHash));
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, block.timestamp + duration * 2);
    }

    function testRegistrationFails() public {
        string memory phoneNumber = "+1234567890";
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        uint256 duration = 365 days;
        uint256 fee = pricing.getRegistrationFee("1", duration);

        // Test insufficient payment
        vm.deal(user1, fee / 2);
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        registrar.register{value: fee / 2}(phoneHash, "1", duration);

        // Test invalid duration
        vm.deal(user1, fee);
        vm.prank(user1);
        vm.expectRevert("Invalid registration period");
        registrar.register{value: fee}(phoneHash, "1", 10 days);
    }

    // Integration Tests
    function testCompleteFlow() public {
        // 1. Set country multiplier
        vm.prank(owner);
        pricing.setCountryMultiplier("44", 15000);

        // 2. Register phone number
        string memory phoneNumber = "+441234567890";
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        uint256 duration = 365 days;
        uint256 fee = pricing.getRegistrationFee("44", duration);

        vm.deal(user1, fee * 2);
        vm.startPrank(user1);

        registrar.register{value: fee}(phoneHash, "44", duration);

        // 3. Verify registration
        bytes32 node = keccak256(abi.encodePacked(PARENT_NODE, phoneHash));
        (address owner, , ) = nameWrapper.getData(uint256(node));
        assertEq(owner, user1);

        // 4. Verify resolver setup
        vm.expectRevert(); // Should revert with OffchainLookup
        resolver.addr(node, 60);

        // 5. Renew registration
        uint256 renewalFee = pricing.getRenewalFee("44", duration);
        registrar.renew{value: renewalFee}(phoneHash, "44", uint64(duration));

        vm.stopPrank();

        // 6. Verify renewal
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, block.timestamp + duration * 2);
    }
}
