// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/PhoneNumberRegistrar.sol";
import "../src/PhonePricing.sol";
import "@ensdomains/registry/ENSRegistry.sol";
import "@ensdomains/wrapper/INameWrapper.sol";
import "./mocks/MockNameWrapper.sol";

contract PhoneNumberRegistrarTest is Test {
    PhoneNumberRegistrar public registrar;
    PhonePricing public pricing;
    ENSRegistry public ens;
    MockNameWrapper public wrapper;

    address public owner;
    address public user;
    address public treasury;

    bytes32 public constant PARENT_NODE = keccak256(abi.encodePacked(bytes32(0), keccak256("usepns")));
    uint256 public constant BASE_PRICE = 0.01 ether;
    uint256 public constant YEAR_IN_SECONDS = 365 days;

    event PhoneNumberRegistered(string phoneNumber, address indexed owner, uint256 expiryDate);
    event PhoneNumberRenewed(string phoneNumber, address indexed owner, uint256 expiryDate);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        treasury = makeAddr("treasury");

        vm.startPrank(owner);

        // Deploy contracts
        ens = new ENSRegistry();
        wrapper = new MockNameWrapper(PARENT_NODE);
        pricing = new PhonePricing(BASE_PRICE);
        registrar = new PhoneNumberRegistrar(ens, INameWrapper(address(wrapper)), PARENT_NODE, pricing, treasury);

        // Set up ENS ownership
        ens.setOwner(bytes32(0), owner);
        ens.setSubnodeOwner(bytes32(0), keccak256("usepns"), owner);
        ens.setOwner(PARENT_NODE, address(registrar));

        vm.stopPrank();

        // Fund user
        vm.deal(user, 100 ether);
    }

    function test_Registration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.expectEmit(true, true, true, true);
        emit PhoneNumberRegistered(phoneNumber, user, block.timestamp + duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        // Verify registration
        assertEq(registrar.phoneToAddress(phoneNumber), user);

        // Verify wrapper data
        bytes32 labelhash = keccak256(bytes(phoneNumber));
        uint256 tokenId = uint256(keccak256(abi.encodePacked(PARENT_NODE, labelhash)));
        (address owner, uint32 fuses, uint64 expiry) = wrapper.getData(tokenId);

        assertEq(owner, user);
        assertTrue(fuses & registrar.PARENT_CANNOT_CONTROL() != 0);
        assertTrue(fuses & registrar.CANNOT_UNWRAP() != 0);
        assertTrue(fuses & registrar.CANNOT_TRANSFER() != 0);
        assertEq(expiry, block.timestamp + duration);
    }

    function testFail_Registration_InvalidPhoneNumber() public {
        vm.prank(user);
        registrar.register{value: BASE_PRICE}("11234567890", YEAR_IN_SECONDS); // Missing +
    }

    function testFail_Registration_AlreadyRegistered() public {
        string memory phoneNumber = "+11234567890";
        uint256 fee = pricing.getRegistrationFee(phoneNumber, YEAR_IN_SECONDS);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, YEAR_IN_SECONDS);

        vm.prank(makeAddr("other"));
        registrar.register{value: fee}(phoneNumber, YEAR_IN_SECONDS);
    }

    function testFail_Registration_InsufficientPayment() public {
        vm.prank(user);
        registrar.register{value: BASE_PRICE - 1}("+11234567890", YEAR_IN_SECONDS);
    }

    function test_Renewal() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;

        // First register
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);
        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        // Then renew
        fee = pricing.getRenewalFee(phoneNumber, duration);

        vm.expectEmit(true, true, true, true);
        emit PhoneNumberRenewed(phoneNumber, user, block.timestamp + 2 * duration);

        vm.prank(user);
        registrar.renew{value: fee}(phoneNumber, duration);

        // Verify renewal
        bytes32 labelhash = keccak256(bytes(phoneNumber));
        uint256 tokenId = uint256(keccak256(abi.encodePacked(PARENT_NODE, labelhash)));
        (,, uint64 expiry) = wrapper.getData(tokenId);

        assertEq(expiry, block.timestamp + 2 * duration);
    }

    function testFail_Renewal_Unregistered() public {
        vm.prank(user);
        registrar.renew{value: BASE_PRICE}("+11234567890", YEAR_IN_SECONDS);
    }

    function test_Renewal_AfterExpiry() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;

        // Register
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);
        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        // Fast forward past expiry
        vm.warp(block.timestamp + duration + 1 days);

        // Renew
        fee = pricing.getRenewalFee(phoneNumber, duration);
        vm.prank(user);
        registrar.renew{value: fee}(phoneNumber, duration);

        // Verify renewal from current time
        bytes32 labelhash = keccak256(bytes(phoneNumber));
        uint256 tokenId = uint256(keccak256(abi.encodePacked(PARENT_NODE, labelhash)));
        (,, uint64 expiry) = wrapper.getData(tokenId);

        assertEq(expiry, vm.getBlockTimestamp() + duration);
    }

    function test_RefundExcessPayment() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);
        uint256 excess = 0.5 ether;

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        registrar.register{value: fee + excess}(phoneNumber, duration);

        assertEq(user.balance, balanceBefore - fee);
    }

    function test_GetExpiry() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        uint64 expiry = registrar.getExpiry(phoneNumber);
        assertEq(expiry, block.timestamp + duration);
    }

    function test_MultiYearRegistration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = 3 * YEAR_IN_SECONDS; // 3 years
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        uint64 expiry = registrar.getExpiry(phoneNumber);
        assertEq(expiry, block.timestamp + duration);

        // Verify fee calculation
        assertEq(fee, 3 * BASE_PRICE);
    }

    function test_RegistrationWithCountryMultiplier() public {
        string memory phoneNumber = "+2341234567890"; // Nigerian number
        uint256 duration = YEAR_IN_SECONDS;
        uint256 multiplier = 8000; // 80%

        // Set country multiplier
        vm.prank(owner);
        pricing.setCountryMultiplier("234", multiplier);

        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);
        assertEq(fee, (BASE_PRICE * multiplier) / 10_000);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        assertEq(registrar.phoneToAddress(phoneNumber), user);
    }

    function test_RenewalWithCountryMultiplier() public {
        string memory phoneNumber = "+2341234567890";
        uint256 duration = YEAR_IN_SECONDS;
        uint256 multiplier = 8000;

        // Set country multiplier
        vm.prank(owner);
        pricing.setCountryMultiplier("234", multiplier);

        // Register first
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        // Renew
        fee = pricing.getRenewalFee(phoneNumber, duration);
        vm.prank(user);
        registrar.renew{value: fee}(phoneNumber, duration);

        uint64 expiry = registrar.getExpiry(phoneNumber);
        assertEq(expiry, block.timestamp + 2 * duration);
    }

    function test_MaxDurationRegistration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = 10 * YEAR_IN_SECONDS; // Max duration
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        uint64 expiry = registrar.getExpiry(phoneNumber);
        assertEq(expiry, block.timestamp + duration);
    }

    function testFail_ExceedMaxDuration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = 11 * YEAR_IN_SECONDS; // Exceeds max
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);
    }

    function testFail_BelowMinDuration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = 364 days; // Below min
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);
    }

    function test_CannotOverwriteRegistration() public {
        string memory phoneNumber = "+11234567890";
        uint256 duration = YEAR_IN_SECONDS;
        uint256 fee = pricing.getRegistrationFee(phoneNumber, duration);

        // First registration
        vm.prank(user);
        registrar.register{value: fee}(phoneNumber, duration);

        address attacker = makeAddr("attacker");
        vm.deal(attacker, 100 ether);

        // Attempt to overwrite with higher payment
        vm.prank(attacker);
        vm.expectRevert("Phone number already registered");
        registrar.register{value: fee * 2}(phoneNumber, duration);

        // Verify original registration remains
        assertEq(registrar.phoneToAddress(phoneNumber), user);
    }

    function test_BatchOperations() public {
        // Test multiple registrations and renewals in sequence
        string[3] memory phoneNumbers = ["+11234567890", "+2349876543210", "+441234567890"];
        uint256 duration = YEAR_IN_SECONDS;

        // Set multiplier for Nigerian numbers
        vm.prank(owner);
        pricing.setCountryMultiplier("234", 8000);

        // Register all numbers
        for (uint256 i = 0; i < phoneNumbers.length; i++) {
            uint256 fee = pricing.getRegistrationFee(phoneNumbers[i], duration);
            vm.prank(user);
            registrar.register{value: fee}(phoneNumbers[i], duration);

            assertEq(registrar.phoneToAddress(phoneNumbers[i]), user);
        }

        // Renew all numbers
        for (uint256 i = 0; i < phoneNumbers.length; i++) {
            uint256 fee = pricing.getRenewalFee(phoneNumbers[i], duration);
            vm.prank(user);
            registrar.renew{value: fee}(phoneNumbers[i], duration);

            uint64 expiry = registrar.getExpiry(phoneNumbers[i]);
            assertEq(expiry, block.timestamp + 2 * duration);
        }
    }

    receive() external payable {}
}
