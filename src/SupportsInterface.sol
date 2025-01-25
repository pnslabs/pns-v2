// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract SupportsInterface {
    function supportsInterface(bytes4 interfaceID) public pure virtual returns (bool) {
        return interfaceID == type(SupportsInterface).interfaceId;
    }
}
