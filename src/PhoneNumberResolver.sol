// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@ensdomains/resolvers/profiles/IExtendedResolver.sol";
import "./libraries/SignatureVerifier.sol";
import "./SupportsInterface.sol";

interface IResolverService {
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory result, uint64 expires, bytes memory sig);
}

/**
 * @title PhoneNumberResolver
 * @dev Implements ENS resolver functionality with CCIP-read support for offchain data retrieval
 * Uses EIP-3668 for secure offchain lookups via GET/POST requests
 * - GET requests used for read operations (addr)
 * - POST requests used for write operations (setAddr)
 */
contract PhoneNumberResolver is IExtendedResolver, SupportsInterface, Ownable {
    // Base gateway URL - will have {sender} and optionally {data} appended by clients
    string public gatewayUrl;
    // Address authorized to sign gateway responses
    address public signer;

    bytes4 constant ADDR_SELECTOR = 0xf1cb7e06;
    bytes4 constant SET_ADDR_SELECTOR = 0x8b95dd71;

    event SignerUpdated(address indexed newSigner);
    event GatewayUrlUpdated(string url);
    event AddressUpdated(bytes32 indexed node, uint256 indexed coinType, bytes newAddress);

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    constructor(string memory _gatewayUrl, address _signer) Ownable(msg.sender) {
        gatewayUrl = _gatewayUrl;
        signer = _signer;
    }

    function makeSignatureHash(address target, uint64 expires, bytes memory request, bytes memory result)
        external
        pure
        returns (bytes32)
    {
        return SignatureVerifier.makeSignatureHash(target, expires, request, result);
    }

    /**
     * @dev ENSIP-10 wildcard resolution interface
     * Handles both read (GET) and write (POST) operations via CCIP-read
     * @param name DNS-encoded name being resolved
     * @param data ABI-encoded data for resolution
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        // Decode the function selector from data
        bytes4 selector = bytes4(data[:4]);

        string[] memory urls = new string[](1);
        // For read operations (addr), append /{data}
        if (selector == ADDR_SELECTOR) {
            urls[0] = string(abi.encodePacked(gatewayUrl, "/{sender}/{data}"));
        } else {
            // For write operations (setAddr), data will be in POST body
            urls[0] = string(abi.encodePacked(gatewayUrl, "/{sender}"));
        }

        bytes memory callData = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);

        revert OffchainLookup(address(this), urls, callData, this.resolveWithProof.selector, abi.encode(name, data));
    }

    /**
     * @dev ENSIP-9 multichain address resolution
     * @param node Namehash of the name being resolved
     * @param coinType SLIP44 coin type to resolve
     */
    function addr(bytes32 node, uint256 coinType) external view returns (bytes memory) {
        return this.resolve(abi.encodePacked(node), abi.encodeWithSelector(ADDR_SELECTOR, node, coinType));
    }

    /**
     * @dev Sets the multichain address for a node
     * @param node Namehash of the name
     * @param coinType SLIP44 coin type
     * @param newAddr The new address to set
     */
    function setAddr(bytes32 node, uint256 coinType, bytes calldata newAddr) external {
        bytes memory name = abi.encodePacked(node);
        bytes memory data = abi.encodeWithSelector(SET_ADDR_SELECTOR, node, coinType, newAddr, msg.sender);

        bytes memory response = this.resolve(name, data);
        emit AddressUpdated(node, coinType, newAddr);
    }

    /**
     * @dev CCIP-read callback function to verify gateway responses
     * @param response Gateway response containing result, expiry time, and signature
     * @param extraData Original request data for verification
     */
    function resolveWithProof(bytes calldata response, bytes calldata extraData) external view returns (bytes memory) {
        (address _signer, bytes memory result) = SignatureVerifier.verify(extraData, response);
        require(_signer == signer, "SignatureVerifier: Invalid sigature");
        return result;
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == type(IExtendedResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    function updateGatewayUrl(string memory _gatewayUrl) external onlyOwner {
        gatewayUrl = _gatewayUrl;
        emit GatewayUrlUpdated(_gatewayUrl);
    }

    function addr(bytes32 node) external view returns (address payable) {}
}
