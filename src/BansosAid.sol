// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract BansosAid {
    address public admin;
    mapping(bytes32 => bool) public claimed;

    event AidClaimed(bytes32 indexed userHash, string programName, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }

    function issueAid(bytes32 userHash, string calldata programName) external onlyAdmin {
        require(!claimed[userHash], "Already claimed");
        claimed[userHash] = true;
        emit AidClaimed(userHash, programName, block.timestamp);
    }

    function hasClaimed(bytes32 userHash) external view returns (bool) {
        return claimed[userHash];
    }
}