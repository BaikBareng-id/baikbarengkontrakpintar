// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BansosAid.sol";

contract BansosAidTest is Test {
    BansosAid public aid;
    address public owner;

    function setUp() public {
        owner = address(this); // Use test contract as owner
        aid = new BansosAid(owner);
    }

    function testIssueAidOnce() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        aid.issueAid(userHash, "BANSOS_MARET_2025");
        assertTrue(aid.hasClaimed(userHash));
    }

    function testPreventDuplicate() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        aid.issueAid(userHash, "BANSOS_MARET_2025");

        vm.expectRevert("Already claimed");
        aid.issueAid(userHash, "BANSOS_MARET_2025");
    }

    function testIssueAidWithDetails() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        string memory program = "BANSOS_MARET_2025";
        uint256 amount = 500000; // 500,000 rupiah
        string memory ipfsHash = "QmTest123";
        string memory recipientId = "1234567890123456";

        aid.issueAidWithDetails(userHash, program, amount, ipfsHash, recipientId);
        
        assertTrue(aid.hasClaimed(userHash));
        assertTrue(aid.hasClaimedForProgram(userHash, program));
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(record.program, program);
        assertEq(record.amount, amount);
        assertEq(record.ipfsHash, ipfsHash);
        assertEq(record.recipientId, recipientId);
    }

    function testUpdatePaymentDocumentation() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        aid.issueAid(userHash, "BANSOS_MARET_2025");
        
        string memory ipfsHash = "QmPayment123";
        uint256 amount = 600000;
        
        aid.updatePaymentDocumentation(1, ipfsHash, amount);
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(record.ipfsHash, ipfsHash);
        assertEq(record.amount, amount);
    }

    function testGetUserTokens() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        aid.issueAid(userHash, "BANSOS_MARET_2025");
        
        uint256[] memory tokens = aid.getUserTokens(userHash);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], 1);
    }

    function testGenerateUserHash() public view {
        bytes32 expectedHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        bytes32 actualHash = aid.generateUserHash("1234567890123456", "BANSOS_MARET_2025");
        assertEq(actualHash, expectedHash);
    }

    function testGetAidRecordsByProgram() public {
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_MARET_2025"));
        
        aid.issueAid(userHash1, "BANSOS_MARET_2025");
        aid.issueAid(userHash2, "BANSOS_MARET_2025");
        
        uint256[] memory tokens = aid.getAidRecordsByProgram("BANSOS_MARET_2025");
        assertEq(tokens.length, 2);
        assertEq(tokens[0], 1);
        assertEq(tokens[1], 2);
    }

    function testGetTotalAidIssued() public {
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_APRIL_2025"));
        
        assertEq(aid.getTotalAidIssued(), 0);
        
        aid.issueAid(userHash1, "BANSOS_MARET_2025");
        assertEq(aid.getTotalAidIssued(), 1);
        
        aid.issueAid(userHash2, "BANSOS_APRIL_2025");
        assertEq(aid.getTotalAidIssued(), 2);
    }

    function testOnlyOwnerCanIssueAid() public {
        vm.prank(address(0x123)); // Switch to non-owner address
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        
        vm.expectRevert(); // Should revert with Ownable error
        aid.issueAid(userHash, "BANSOS_MARET_2025");
    }

    function testTokenURI() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_MARET_2025"));
        aid.issueAidWithDetails(userHash, "BANSOS_MARET_2025", 500000, "QmTest123", "1234567890123456");
        
        string memory uri = aid.tokenURI(1);
        assertEq(uri, "ipfs://QmTest123");
    }

    function testRevertWhenGettingNonExistentToken() public {
        vm.expectRevert("Token does not exist");
        aid.getAidRecord(999); // Should revert
    }
}