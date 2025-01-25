// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PhonePricing is Ownable {
    // Base price for 1 year registration (in wei)
    uint256 public basePrice;

    // Mapping for country code multipliers (multiplier is in basis points, 10000 = 100%)
    mapping(string => uint256) public countryMultipliers;
    // Minimum and maximum registration periods
    uint256 public constant MIN_REGISTRATION_PERIOD = 365 days;
    uint256 public constant MAX_REGISTRATION_PERIOD = 3650 days;

    // Events
    event BasePriceUpdated(uint256 newPrice);
    event CountryMultiplierSet(string countryCode, uint256 multiplier);
    event CountryMultiplierRemoved(string countryCode);

    constructor(uint256 _basePrice) Ownable(msg.sender) {
        basePrice = _basePrice;
    }

    /**
     * @dev Calculate registration fee for a phone number and duration
     * @param countryCode The country code of the phone number being registered
     * @param duration Registration duration in seconds
     * @return uint256 The registration fee in wei
     */
    function getRegistrationFee(string calldata countryCode, uint256 duration) external view returns (uint256) {
        // Validate duration
        require(
            duration >= MIN_REGISTRATION_PERIOD && duration <= MAX_REGISTRATION_PERIOD, "Invalid registration period"
        );

        // Calculate number of years (rounded up)
        uint256 numberOfYears = (duration + 365 days - 1) / (365 days);

        // Get base yearly price with country multiplier
        uint256 yearlyPrice = getYearlyPrice(countryCode);

        // Calculate total price for all years
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < numberOfYears; i++) {
            totalPrice += yearlyPrice;
        }

        return totalPrice;
    }

    /**
     * @dev Calculate renewal fee
     * @param countryCode The country code of the phone number being renewed
     * @param duration Renewal duration in seconds
     * @return uint256 The renewal fee in wei
     */
    function getRenewalFee(string calldata countryCode, uint256 duration) external view returns (uint256) {
        return this.getRegistrationFee(countryCode, duration);
    }

    /**
     * @dev Get yearly price for a phone number (including country multiplier)
     * @param countryCode The country code of the phone number
     * @return uint256 The yearly price in wei
     */
    function getYearlyPrice(string memory countryCode) public view returns (uint256) {
        uint256 multiplier = countryMultipliers[countryCode];

        // If no multiplier is set, return the base price (normal price)
        if (multiplier == 0) {
            return basePrice;
        }

        // Apply special country multiplier
        return (basePrice * multiplier) / 10_000;
    }

    /**
     * @dev Set new base price
     * @param _basePrice New base price in wei
     */
    function setBasePrice(uint256 _basePrice) external onlyOwner {
        basePrice = _basePrice;
        emit BasePriceUpdated(_basePrice);
    }

    /**
     * @dev Set special multiplier for a country code
     * @param countryCode The country code without + (e.g., "1", "44", "234")
     * @param multiplier The price multiplier in basis points (10000 = 100%)
     */
    function setCountryMultiplier(string calldata countryCode, uint256 multiplier) external onlyOwner {
        require(multiplier > 0 && multiplier != 10_000, "Invalid multiplier or normal price");
        countryMultipliers[countryCode] = multiplier;
        emit CountryMultiplierSet(countryCode, multiplier);
    }

    /**
     * @dev Remove special multiplier for a country code
     * @param countryCode The country code to remove special pricing for
     */
    function removeCountryMultiplier(string calldata countryCode) external onlyOwner {
        delete countryMultipliers[countryCode];
        emit CountryMultiplierRemoved(countryCode);
    }

    /**
     * @dev View function to get registration fee breakdown by years
     * @param countryCode The country code of the phone number
     * @param duration Registration duration in seconds
     * @return numberOfYears Number of years
     * @return pricePerYear Price per year
     * @return totalPrice Total price for all years
     */
    function getFeeDetails(string calldata countryCode, uint256 duration)
        external
        view
        returns (uint256 numberOfYears, uint256 pricePerYear, uint256 totalPrice)
    {
        require(
            duration >= MIN_REGISTRATION_PERIOD && duration <= MAX_REGISTRATION_PERIOD, "Invalid registration period"
        );

        numberOfYears = (duration + 365 days - 1) / (365 days);
        pricePerYear = getYearlyPrice(countryCode);
        totalPrice = numberOfYears * pricePerYear;

        return (numberOfYears, pricePerYear, totalPrice);
    }
}
