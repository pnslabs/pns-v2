// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper} from "@ensdomains/contracts/wrapper/INameWrapper.sol";
import {ENSRegistry} from "@ensdomains/contracts/registry/ENSRegistry.sol";
import {BaseRegistrarImplementation} from "@ensdomains/contracts/ethregistrar/BaseRegistrarImplementation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./interfaces/IPhoneNumberRegistrar.sol";
import "./libraries/PhoneNumberLib.sol";
import "./PhonePricing.sol";

contract PhoneNumberRegistrar is IPhoneNumberRegistrar, Ownable, IERC1155Receiver {
    // ENS registry
    ENSRegistry public immutable ens;
    // ENS Name Wrapper
    INameWrapper public immutable nameWrapper;
    // Base Registrar
    BaseRegistrarImplementation public immutable baseRegistrar;
    // Pricing contract
    PhonePricing public pricingContract;

    // Parent node (namehash of usepns.eth)
    bytes32 public immutable parentNode;

    // Registration duration (1 year in seconds)
    uint256 public constant DEFAULT_REGISTRATION_PERIOD = 365 days;

    // Fuses
    uint32 public constant CANNOT_UNWRAP = 1;
    uint32 public constant CANNOT_TRANSFER = 4;
    uint32 public constant PARENT_CANNOT_CONTROL = 65_536;

    // Mappings to track phone number registrations
    mapping(string => address) public phoneToAddress;
    mapping(address => string) public addressToPhone;

    // Events
    event PhoneNumberRegistered(string phoneNumber, address indexed owner, uint256 expiryDate);
    event PhoneNumberRenewed(string phoneNumber, address indexed owner, uint256 expiryDate);

    constructor(
        ENSRegistry _ens,
        INameWrapper _nameWrapper,
        BaseRegistrarImplementation _baseRegistrar,
        bytes32 _parentNode,
        PhonePricing _pricingContract
    ) {
        ens = _ens;
        nameWrapper = _nameWrapper;
        baseRegistrar = _baseRegistrar;
        parentNode = _parentNode;
        pricingContract = _pricingContract;
    }

    /**
     * @dev Register a phone number as a subname
     * @param phoneNumber The phone number to register (must include country code)
     * @param duration Registration duration in seconds
     */
    function register(string calldata phoneNumber, uint256 duration) external payable {
        // Validate phone number format
        require(PhoneNumberLib.isValidPhoneNumber(phoneNumber), "Invalid phone number format");

        // Check if phone number is available
        require(phoneToAddress[phoneNumber] == address(0), "Phone number already registered");

        // Validate duration
        require(
            duration >= pricingContract.MIN_REGISTRATION_PERIOD()
                && duration <= pricingContract.MAX_REGISTRATION_PERIOD(),
            "Invalid registration period"
        );

        // Calculate registration fee
        uint256 fee = pricingContract.getRegistrationFee(phoneNumber, duration);
        require(msg.value >= fee, "Insufficient payment");

        // Calculate expiry time
        uint64 expiry = uint64(block.timestamp + duration);

        // Create subname with appropriate fuses
        uint32 fuses = PARENT_CANNOT_CONTROL | CANNOT_UNWRAP | CANNOT_TRANSFER;

        // Set up name in the wrapper
        nameWrapper.setSubnodeRecord(
            parentNode,
            phoneNumber,
            msg.sender,
            address(nameWrapper), // Use NameWrapper as resolver
            0, // TTL
            fuses,
            expiry
        );

        // Update mappings
        phoneToAddress[phoneNumber] = msg.sender;
        addressToPhone[msg.sender] = phoneNumber;

        emit PhoneNumberRegistered(phoneNumber, msg.sender, expiry);

        // Refund excess payment
        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    /**
     * @dev Renew a phone number registration
     * @param phoneNumber The phone number to renew
     */
    function renew(string calldata phoneNumber) external payable override {
        require(phoneToAddress[phoneNumber] != address(0), "Phone number not registered");

        uint256 fee = pricingContract.getRenewalFee(phoneNumber);
        require(msg.value >= fee, "Insufficient payment");

        uint64 expiry = uint64(block.timestamp + registrationPeriod);
        nameWrapper.setChildFuses(parentNode, phoneNumber, uint32(0), expiry);

        emit PhoneNumberRenewed(phoneNumber, msg.sender, expiry);

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    /**
     * @dev Get the expiry date of a phone number
     * @param phoneNumber The phone number to check
     * @return The expiry date as a timestamp
     */
    function getExpiry(string calldata phoneNumber) external view returns (uint64) {
        (, uint64 expiry) =
            nameWrapper.getData(uint256(keccak256(abi.encodePacked(parentNode, keccak256(bytes(phoneNumber))))));
        return expiry;
    }

    // Implementation of IERC1155Receiver
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
