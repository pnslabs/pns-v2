// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@ensdomains/wrapper/INameWrapper.sol";
import "@ensdomains/resolvers/PublicResolver.sol";
import "./interfaces/IPhoneNumberRegistrar.sol";
import "./libraries/PhoneNumberLib.sol";
import "./PhonePricing.sol";

contract PhoneNumberRegistrar is Ownable, ERC1155Holder {
    // Parent node (namehash of usepns.eth)
    bytes32 public immutable parentNode;

    // Registration duration (1 year in seconds)
    uint256 public constant DEFAULT_REGISTRATION_PERIOD = 365 days;

    // Fuses
    uint32 public constant CANNOT_UNWRAP = 1;
    uint32 public constant CANNOT_TRANSFER = 4;
    uint32 public constant PARENT_CANNOT_CONTROL = 65_536;

    // Treasury address
    address public immutable treasury;
    // custom resolver
    address public defaultResolver;
    // Pricing contract
    PhonePricing public pricingContract;

    // ENS registry
    ENSRegistry public immutable ens;
    // ENS Name Wrapper
    INameWrapper public immutable nameWrapper;

    mapping(bytes32 => Name) public names;

    event SubdomainRegistered(bytes32 indexed label, address indexed owner, uint64 expiry);

    event SubdomainRenewed(bytes32 indexed label, uint64 expiry);

    event FeesCollected(uint256 amount);
    event WithdrawalFailed(uint256 amount);

    error ParentNameNotSetup(bytes32 parentNode);
    error Unavailable();
    error Unauthorised(bytes32 node);
    error NameNotRegistered();

    constructor(address _nameWrapper, bytes32 _parentNode, address _defaultResolver, address _pricing)
        Ownable(msg.sender)
    {
        nameWrapper = INameWrapper(_nameWrapper);
        parentNode = _parentNode;
        defaultResolver = _defaultResolver;
        pricing = IPhonePricing(_pricing);
    }

    modifier authorised(bytes32 node) {
        if (!wrapper.canModifyName(node, msg.sender)) {
            revert Unauthorised(node);
        }
        _;
    }

    function setupDomain(bytes32 node, bool active) external virtual authorised(node) {
        names[node] = Name({pricer: pricingContract, beneficiary: treasury, active: active});
        emit NameSetup(node, address(pricingContract), treasury, active);
    }

    /**
     * @dev Register a phone number as a subname
     * @param phoneNumberHash The keccak256 hash of the phone number to register (must include country code with the leading 0 removed)
     * @param countryCode The country code of the phone number
     * @param duration Registration duration in seconds
     */
    function register(string calldata phoneNumberHash, string calldata countryCode, uint256 duration)
        external
        payable
    {
        if (!names[parentNode].active) {
            revert ParentNameNotSetup(parentNode);
        }
        bytes32 node = _makeNode(parentNode, phoneNumberHash);
        available(node);

        // Validate duration
        require(duration >= pricingContract.MIN_REGISTRATION_PERIOD(), "Invalid registration period");

        // Create subdomain initially owned by contract
        nameWrapper.setSubnodeOwner(
            parentNode,
            phoneNumber,
            address(this),
            0, // No fuses yet
            uint64(block.timestamp + 365 days)
        );

        // Get node hash for the subdomain
        bytes32 subnode = keccak256(abi.encodePacked(parentNode, keccak256(bytes(label))));

        // Set resolver and records
        nameWrapper.setResolver(subnode, defaultResolver);

        // Transfer ownership to caller with fuses
        uint32 fuses = 65_536; // PARENT_CANNOT_CONTROL (emancipated)
        nameWrapper.setSubnodeRecord(
            parentNode,
            label,
            msg.sender,
            defaultResolver,
            0, // TTL
            fuses,
            uint64(block.timestamp + 365 days)
        );

        emit SubdomainRegistered(label, msg.sender, uint64(block.timestamp + 365 days));

        // Forward fee to owner
        payable(owner()).transfer(msg.value);
    }

    function setRegistrationFee(uint256 _fee) external onlyOwner {
        registrationFee = _fee;
    }

    function setDefaultResolver(address _resolver) external onlyOwner {
        defaultResolver = _resolver;
    }

    // Check if a subdomain is available
    function available(bytes32 node) public view virtual returns (bool) {
        try wrapper.getData(uint256(node)) returns (address, uint32, uint64 expiry) {
            return expiry < block.timestamp;
        } catch {
            return true;
        }
    }

    function _makeNode(bytes32 node, bytes32 labelhash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }
}
