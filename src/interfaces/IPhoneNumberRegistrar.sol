// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPhoneNumberRegistrar {
    /**
     * @dev Register a phone number as a subname
     * @param phoneNumberHash The keccak256 hash of the phone number to register (must include country code with the leading 0 removed)
     * @param countryCode The country code of the phone number
     * @param duration Registration duration in seconds
     */
    function register(bytes32 phoneNumberHash, string calldata countryCode, uint256 duration) external payable;

    /**
     * @dev Renew a phone number registration
     * @param phoneNumberHash The keccak256 hash of the phone number to renew
     * @param countryCode The country code of the phone number
     * @param duration Duration to extend registration for
     */
    function renew(bytes32 phoneNumberHash, string calldata countryCode, uint64 duration) external payable;
}
