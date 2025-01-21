// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library PhoneNumberLib {
    /**
     * @dev Validates a phone number format
     * @param phoneNumber The phone number to validate
     * @return bool True if the phone number is valid
     */
    function isValidPhoneNumber(string memory phoneNumber) internal pure returns (bool) {
        bytes memory b = bytes(phoneNumber);

        // Check minimum length (country code + number)
        if (b.length < 8 || b.length > 15) return false;

        // Must start with +
        if (b[0] != "+") return false;

        // Rest must be digits
        for (uint256 i = 1; i < b.length; i++) {
            if (b[i] < "0" || b[i] > "9") return false;
        }

        return true;
    }

    /**
     * @dev Normalizes a phone number by removing spaces and hyphens
     * @param phoneNumber The phone number to normalize
     * @return string The normalized phone number
     */
    function normalizePhoneNumber(string memory phoneNumber) internal pure returns (string memory) {
        bytes memory b = bytes(phoneNumber);
        bytes memory result = new bytes(b.length);

        uint256 resultIndex = 0;
        for (uint256 i = 0; i < b.length; i++) {
            // Skip spaces and hyphens
            if (b[i] != " " && b[i] != "-") {
                result[resultIndex] = b[i];
                resultIndex++;
            }
        }
        // Create new bytes array of correct length
        bytes memory normalized = new bytes(resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            normalized[i] = result[i];
        }
        return string(normalized);
    }
}
