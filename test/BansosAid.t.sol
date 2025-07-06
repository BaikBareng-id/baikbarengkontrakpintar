// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BansosAid.sol";

contract BansosAidTest is Test {
    BansosAid public aid;

    function setUp() public {
        aid = new BansosAid();
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
}
