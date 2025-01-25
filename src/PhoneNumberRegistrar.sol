// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@ensdomains/wrapper/INameWrapper.sol";
import "@ensdomains/resolvers/PublicResolver.sol";
import "./interfaces/IPhoneNumberRegistrar.sol";
import "./libraries/PhoneNumberLib.sol";
import "./PhonePricing.sol";
import "./PhoneNumberResolver.sol";

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

    uint256 constant COIN_TYPE_ETH = 60;
    // custom resolver
    PhoneNumberResolver public defaultResolver;
    // Pricing contract
    PhonePricing public pricingContract;

    // ENS registry
    ENSRegistry public immutable ens;
    // ENS Name Wrapper
    INameWrapper public immutable nameWrapper;

    mapping(bytes32 => Name) public names;

    event PhoneNumberRegistered(bytes32 indexed label, address indexed owner, uint64 expiry);

    event Phone(bytes32 indexed label, uint64 expiry);

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
        defaultResolver = PhoneNumberResolver(_defaultResolver);
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
    function register(bytes32 phoneNumberHash, string calldata countryCode, uint256 duration) external payable {
        if (!names[parentNode].active) {
            revert ParentNameNotSetup(parentNode);
        }
        bytes32 node = _makeNode(parentNode, phoneNumberHash);
        available(node);

        // Validate duration
        require(
            duration >= pricingContract.MIN_REGISTRATION_PERIOD()
                && duration <= pricingContract.MAX_REGISTRATION_PERIOD(),
            "Invalid registration period"
        );

        // Calculate registration fee
        uint256 fee = pricingContract.getRegistrationFee(countryCode, duration);
        require(msg.value >= fee, "Insufficient payment");

        // Calculate expiry time
        uint64 expiry = uint64(block.timestamp + duration);

        // Create subdomain initially owned by contract
        nameWrapper.setSubnodeOwner(
            parentNode,
            string(phoneNumberHash),
            address(this),
            0, // No fuses yet
            expiry
        );

        // Get node hash for the subdomain
        bytes32 subnode = _makeNode(parentNode, phoneNumberHash);
        // Set resolver and records
        nameWrapper.setResolver(subnode, address(defaultResolver));

        // Transfer ownership to caller with fuses
        uint32 fuses = 65_536; // PARENT_CANNOT_CONTROL (emancipated)
        nameWrapper.setSubnodeRecord(
            parentNode,
            string(phoneNumberHash),
            msg.sender,
            address(defaultResolver),
            0, // TTL
            fuses,
            expiry
        );

        // Register ETH address to resolver
        defaultResolver.setAddr(subnode, COIN_TYPE_ETH, abi.encodePacked(msg.sender));

        emit PhoneNumberRegistered(phoneNumberHash, msg.sender, expiry);

        // Forward fee to treasury
        (bool success,) = treasury.call{value: fee}("");
        if (!success) {
            emit WithdrawalFailed(fee);
        }

        // Refund excess payment if any
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool refundSuccess,) = msg.sender.call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
    }
    /**
     * @dev Renew a phone number registration
     * @param phoneNumberHash The keccak256 hash of the phone number to renew
     * @param countryCode The country code of the phone number
     * @param duration Duration to extend registration for
     */

    function renew(bytes32 phoneNumberHash, string calldata countryCode, uint64 duration) external payable {
        require(duration >= MIN_REGISTRATION_PERIOD && duration <= MAX_REGISTRATION_PERIOD, "Invalid duration");

        uint256 fee = pricingContract.getRenewalFee(countryCode, duration);
        require(msg.value >= fee, "Insufficient payment");

        bytes32 node = _makeNode(parentNode, phoneNumberHash);
        (,, uint64 expiry) = nameWrapper.getData(uint256(node));
        require(expiry >= block.timestamp, "Phone Number expired");

        uint64 newExpiry = expiry + duration;

        // extend the registration
        nameWrapper.setChildFuses(
            parentNode,
            string(phoneNumberHash),
            0, // No new fuses needed for renewal
            newExpiry
        );

        // Forward fee to treasury
        (bool success,) = treasury.call{value: fee}("");
        if (!success) {
            emit WithdrawalFailed(fee);
        }

        // Refund excess payment if any
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool refundSuccess,) = msg.sender.call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }

        emit PhoneNumberRenewed(phoneNumberHash, newExpiry);

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    /**
     * @dev Emergency withdrawal in case direct transfer fails
     * @notice This function should only be used if the automatic transfer fails
     */
    function withdrawStuckFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success,) = treasury.call{value: balance}("");
        require(success, "Withdrawal failed");

        emit FeesCollected(balance);
    }

    function setDefaultResolver(address _resolver) external onlyOwner {
        defaultResolver = PhoneNumberResolver(_resolver);
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
