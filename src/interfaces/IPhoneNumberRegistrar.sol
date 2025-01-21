// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPhoneNumberRegistrar {
    /**
     * @dev Register a phone number as a subname
     * @param phoneNumber The phone number to register (must include country code)
     * @param registrationPeriod The period of registration in seconds
     */
    function register(string calldata phoneNumber, uint256 registrationPeriod) external payable;

    /**
     * @dev Renew a phone number registration
     * @param phoneNumber The phone number to renew
     */
    function renew(string calldata phoneNumber, uint256 duration) external payable;
}
