// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@ensdomains/wrapper/INameWrapper.sol";
import "@ensdomains/registry/ENS.sol";
import "@ensdomains/ethregistrar/IBaseRegistrar.sol";
import "@ensdomains/wrapper/IMetadataService.sol";
import "@ensdomains/wrapper/INameWrapperUpgrade.sol";

contract MockNameWrapper is INameWrapper {
    struct NameData {
        address owner;
        uint32 fuses;
        uint64 expiry;
    }

    mapping(uint256 => NameData) public names_;

    ENS public ens;
    IBaseRegistrar public registrar;
    IMetadataService public metadataService;
    INameWrapperUpgrade public override upgradeContract;

    bytes32 public immutable parentNode;

    constructor(bytes32 _parentNode) {
        parentNode = _parentNode;
    }

     function names(bytes32) external view returns (bytes memory) {
        return hex"";
     }

    function setSubnodeRecord(
        bytes32 parentNode,
        string memory label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external override returns (bytes32) {
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(parentNode, keccak256(bytes(label))))
        );
        names_[tokenId] = NameData(owner, fuses, expiry);
        return bytes32(tokenId);
    }

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) external override {
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(parentNode, labelhash))
        );
        names_[tokenId].fuses = fuses;
        names_[tokenId].expiry = expiry;
    }

    function getData(
        uint256 id
    )
        external
        view
        override
        returns (address owner, uint32 fuses, uint64 expiry)
    {
        NameData memory data = names_[id];
        return (data.owner, data.fuses, data.expiry);
    }

    function name() external pure override returns (string memory) {
        return "";
    }

    function ownerOf(uint256 id) external view override returns (address) {
        return names_[id].owner;
    }

    function approve(address to, uint256 tokenId) external override {}

    function getApproved(
        uint256 tokenId
    ) external view override returns (address) {
        return address(0);
    }

    function setRecord(uint256, address, address, uint64) external pure {}

    function setSubnodeOwner(
        bytes32 node,
        string memory label,
        address newOwner,
        uint32 fuses,
        uint64 expiry
    ) external override returns (bytes32) {
        return bytes32(0);
    }

    function setResolver(bytes32 node, address resolver) external override {}

    function setTTL(bytes32 node, uint64 ttl) external override {}

    function wrap(
        bytes calldata name,
        address wrappedOwner,
        address resolver
    ) external override  {
    }

    function wrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint16 ownerControlledFuses,
        address resolver
    ) external override returns (uint64) {
        return 0;
    }

    function unwrap(
        bytes32 node,
        bytes32 label,
        address owner
    ) external override {}

    function unwrapETH2LD(
        bytes32 labelhash,
        address newRegistrant,
        address newController
    ) external override {}

    function upgrade(
        bytes calldata name,
        bytes calldata extraData
    ) external override {}

    function registerAndWrapETH2LD(
        string calldata label,
        address wrappedOwner,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external override returns (uint256) {
        return 0;
    }

    function renew(
        uint256 labelHash,
        uint256 duration
    ) external override returns (uint256) {
        return 0;
    }

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    ) external override returns (uint32) {
        return 0;
    }

    function extendExpiry(
        bytes32 node,
        bytes32 labelhash,
        uint64 expiry
    ) external override returns (uint64) {
        return 0;
    }

    function canModifyName(
        bytes32 node,
        address addr
    ) external view override returns (bool) {
        return true;
    }

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) external view override returns (bool) {
        return false;
    }

    function isWrapped(bytes32) external pure override returns (bool) {
        return true;
    }

    function isWrapped(bytes32, bytes32) external pure override returns (bool) {
        return true;
    }

    function uri(uint256) external pure override returns (string memory) {
        return "";
    }

    function setMetadataService(
        IMetadataService _metadataService
    ) external override {}

    function setUpgradeContract(
        INameWrapperUpgrade _upgradeAddress
    ) external override {}

    // IERC1155 implementation
    function balanceOf(address, uint256) external pure returns (uint256) {
        return 1;
    }

    function balanceOfBatch(
        address[] memory,
        uint256[] memory
    ) external pure returns (uint256[] memory r) {
        r = new uint256[](1);
        r[0] = 1;
        return r;
    }

    function setApprovalForAll(address, bool) external {}

    function isApprovedForAll(address, address) external pure returns (bool) {
        return true;
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external {}

    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external {}

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return true;
    }

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external override {}
}
