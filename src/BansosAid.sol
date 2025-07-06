// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract BansosAid {
    address public admin;

    // Track which hashed identifiers have claimed
    mapping(bytes32 => bool) public claimed;

    // Events
    event AidClaimed(bytes32 indexed userHash, string programName, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @notice Allows the current admin to transfer admin rights to a new address
    /// @param newAdmin The address of the new admin
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }

    /// @notice Issue aid to a hashed identity (off-chain hash of NIK + program)
    /// @param userHash keccak256(abi.encodePacked(nik, programName))
    /// @param programName Human-readable aid program name
    function issueAid(bytes32 userHash, string calldata programName) external onlyAdmin {
        require(!claimed[userHash], "Already claimed");

        claimed[userHash] = true;

        emit AidClaimed(userHash, programName, block.timestamp);
    }

    /// @notice Helper to check if aid has already been claimed (view only)
    function hasClaimed(bytes32 userHash) external view returns (bool) {
        return claimed[userHash];
    }
}