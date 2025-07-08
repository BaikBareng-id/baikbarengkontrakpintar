// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BansosAidv2.sol";

contract BansosAidv2Test is Test {
    BansosAid public aid;
    address public admin;
    address public supervisor;
    address public operator;
    address public regular;
    
    // Constants for testing
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    function setUp() public {
        admin = address(this);
        supervisor = address(0x1);
        operator = address(0x2);
        regular = address(0x3);
        
        aid = new BansosAid("Government Aid Program", "AID", admin);
        
        // Setup roles
        aid.grantRole(SUPERVISOR_ROLE, supervisor);
        aid.grantRole(OPERATOR_ROLE, operator);
    }
    
    // ============ Role Management Tests ============
    
    function testRoleAssignment() public {
        assertTrue(aid.hasRole(ADMIN_ROLE, admin));
        assertTrue(aid.hasRole(SUPERVISOR_ROLE, supervisor));
        assertTrue(aid.hasRole(OPERATOR_ROLE, operator));
        assertFalse(aid.hasRole(ADMIN_ROLE, regular));
    }
    
    function testRoleRevocation() public {
        aid.revokeRole(OPERATOR_ROLE, operator);
        assertFalse(aid.hasRole(OPERATOR_ROLE, operator));
    }
    
    // ============ Program Management Tests ============
    
    function testCreateProgram() public {
        aid.createProgram(
            "BANSOS_2025",
            "National Social Aid 2025",
            1000000000, // 1 billion budget
            true
        );
        
        assertTrue(aid.isProgramApproved("BANSOS_2025"));
        
        // Verify program details
        BansosAid.Program memory program = aid.getProgram("BANSOS_2025");
        assertEq(program.name, "BANSOS_2025");
        assertEq(program.description, "National Social Aid 2025");
        assertEq(program.totalBudget, 1000000000);
        assertEq(program.budgetUsed, 0);
        assertEq(program.isActive, true);
    }
    
    function testUpdateProgram() public {
        aid.createProgram(
            "BANSOS_2025",
            "National Social Aid 2025",
            1000000000,
            true
        );
        
        aid.updateProgram(
            "BANSOS_2025",
            "Updated National Social Aid 2025",
            2000000000,
            false
        );
        
        BansosAid.Program memory program = aid.getProgram("BANSOS_2025");
        assertEq(program.description, "Updated National Social Aid 2025");
        assertEq(program.totalBudget, 2000000000);
        assertEq(program.isActive, false);
    }
    
    function testOnlyAdminCanCreateProgram() public {
        vm.prank(regular);
        vm.expectRevert();
        aid.createProgram(
            "BANSOS_2025",
            "National Social Aid 2025",
            1000000000,
            true
        );
    }
    
    // ============ Aid Issuance Tests ============
    
    function testIssueAid() public {
        // Create program first
        aid.createProgram(
            "BANSOS_2025",
            "National Social Aid 2025",
            1000000000,
            true
        );
        
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000, // 500,000 IDR
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        // Verify token was minted
        assertEq(aid.getTotalAidIssued(), 1);
        assertTrue(aid.ownerOf(1) == address(aid)); // Contract owns the NFT
        
        // Verify aid record details
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(record.program, "BANSOS_2025");
        assertEq(record.recipientId, "1234567890123456");
        assertEq(record.recipientName, "John Doe");
        assertEq(record.location, "Jakarta");
        assertEq(record.amount, 500000);
        assertEq(uint(record.category), uint(BansosAid.BeneficiaryCategory.PoorFamily));
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Pending));
    }
    
    function testPreventDuplicateAid() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        vm.expectRevert("Already claimed aid for this program");
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
    }
    
    function testCannotExceedProgramBudget() public {
        aid.createProgram("SMALL_PROGRAM", "Small Budget Program", 1000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "SMALL_PROGRAM"));
        
        vm.expectRevert("Exceeds program budget");
        aid.issueAid(
            userHash,
            "SMALL_PROGRAM",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            2000, // Exceeds the 1000 budget
            BansosAid.BeneficiaryCategory.PoorFamily
        );
    }
    
    // ============ Status Management Tests ============
    
    function testUpdateAidStatus() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        // Now update the status as supervisor
        vm.prank(supervisor);
        aid.updateAidStatus(
            1,
            BansosAid.AidStatus.Approved,
            "Approved by supervisor"
        );
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Approved));
        
        // Check status tracking
        uint256[] memory approvedRecords = aid.getAidRecordsByStatus(BansosAid.AidStatus.Approved);
        assertEq(approvedRecords.length, 1);
        assertEq(approvedRecords[0], 1);
    }
    
    function testStatusWorkflow() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        // Complete workflow: Pending -> Approved -> Disbursed -> Completed
        vm.startPrank(supervisor);
        
        aid.updateAidStatus(1, BansosAid.AidStatus.Approved, "Approved by supervisor");
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Approved));
        
        aid.updateAidStatus(1, BansosAid.AidStatus.Disbursed, "Money sent");
        record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Disbursed));
        
        aid.updateAidStatus(1, BansosAid.AidStatus.Completed, "Confirmation received");
        record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Completed));
        
        vm.stopPrank();
    }
    
    // ============ Payment Documentation Tests ============
    
    function testUpdatePaymentDocumentation() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        vm.prank(operator);
        aid.updatePaymentDocumentation(
            1,
            "QmPaymentDoc123",
            "Bank Transfer"
        );
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(record.ipfsHash, "QmPaymentDoc123");
        assertEq(record.disbursementMethod, "Bank Transfer");
    }
    
    function testTokenURI() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        vm.prank(operator);
        aid.updatePaymentDocumentation(
            1,
            "QmPaymentDoc123",
            "Bank Transfer"
        );
        
        string memory uri = aid.tokenURI(1);
        assertEq(uri, "ipfs://QmPaymentDoc123");
    }
    
    // ============ Query Function Tests ============
    
    function testGetUserTokens() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        aid.createProgram("PKH_2025", "Family Hope Program 2025", 1000000000, true);
        
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("1234567890123456", "PKH_2025"));
        
        aid.issueAid(
            userHash1,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        aid.issueAid(
            userHash2,
            "PKH_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            700000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        // User has claimed both programs
        bytes32 userIdentifier = keccak256(abi.encodePacked("1234567890123456"));
        uint256[] memory tokens = aid.getUserTokens(userIdentifier);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], 1);
        assertEq(tokens[1], 2);
    }
    
    function testGetAidRecordsByProgram() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_2025"));
        
        aid.issueAid(
            userHash1,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        aid.issueAid(
            userHash2,
            "BANSOS_2025",
            "9876543210987654",
            "Jane Doe",
            "Surabaya",
            500000,
            BansosAid.BeneficiaryCategory.ElderlyPerson
        );
        
        uint256[] memory tokens = aid.getAidRecordsByProgram("BANSOS_2025");
        assertEq(tokens.length, 2);
        assertEq(tokens[0], 1);
        assertEq(tokens[1], 2);
    }
    
    function testGetAidRecordsByCategory() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_2025"));
        
        aid.issueAid(
            userHash1,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        aid.issueAid(
            userHash2,
            "BANSOS_2025",
            "9876543210987654",
            "Jane Doe",
            "Surabaya",
            500000,
            BansosAid.BeneficiaryCategory.ElderlyPerson
        );
        
        uint256[] memory poorFamilyRecords = aid.getAidRecordsByCategory(BansosAid.BeneficiaryCategory.PoorFamily);
        assertEq(poorFamilyRecords.length, 1);
        assertEq(poorFamilyRecords[0], 1);
        
        uint256[] memory elderlyRecords = aid.getAidRecordsByCategory(BansosAid.BeneficiaryCategory.ElderlyPerson);
        assertEq(elderlyRecords.length, 1);
        assertEq(elderlyRecords[0], 2);
    }
    
    function testGetAidRecordsByLocation() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_2025"));
        
        aid.issueAid(
            userHash1,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        aid.issueAid(
            userHash2,
            "BANSOS_2025",
            "9876543210987654",
            "Jane Doe",
            "Surabaya",
            500000,
            BansosAid.BeneficiaryCategory.ElderlyPerson
        );
        
        uint256[] memory jakartaRecords = aid.getAidRecordsByLocation("Jakarta");
        assertEq(jakartaRecords.length, 1);
        assertEq(jakartaRecords[0], 1);
        
        uint256[] memory surabayaRecords = aid.getAidRecordsByLocation("Surabaya");
        assertEq(surabayaRecords.length, 1);
        assertEq(surabayaRecords[0], 2);
    }
    
    function testGetStatistics() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        aid.createProgram("PKH_2025", "Family Hope Program 2025", 1000000000, true);
        
        bytes32 userHash1 = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 userHash2 = keccak256(abi.encodePacked("9876543210987654", "BANSOS_2025"));
        
        aid.issueAid(
            userHash1,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        aid.issueAid(
            userHash2,
            "BANSOS_2025",
            "9876543210987654",
            "Jane Doe",
            "Surabaya",
            500000,
            BansosAid.BeneficiaryCategory.ElderlyPerson
        );
        
        // Update status to completed for one record
        vm.prank(supervisor);
        aid.updateAidStatus(1, BansosAid.AidStatus.Completed, "Completed");
        
        BansosAid.Statistics memory stats = aid.getStatistics();
        assertEq(stats.totalRecords, 2);
        assertEq(stats.activePrograms, 2);
        assertEq(stats.pendingApplications, 1);
        assertEq(stats.completedApplications, 1);
    }
    
    // ============ Emergency Function Tests ============
    
    function testEmergencyPause() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        
        aid.emergencyPause();
        assertTrue(aid.paused());
        
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        vm.expectRevert("Pausable: paused");
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
    }
    
    function testEmergencyUnpause() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        
        aid.emergencyPause();
        assertTrue(aid.paused());
        
        aid.emergencyUnpause();
        assertFalse(aid.paused());
        
        // Should work after unpausing
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        assertEq(aid.getTotalAidIssued(), 1);
    }
    
    function testEmergencyCancel() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        vm.prank(supervisor);
        aid.updateAidStatus(1, BansosAid.AidStatus.Approved, "Approved");
        
        aid.emergencyCancel(1, "Suspected fraud");
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Cancelled));
        assertEq(record.notes, "Suspected fraud");
        
        // Verify budget was returned to program
        BansosAid.Program memory program = aid.getProgram("BANSOS_2025");
        assertEq(program.budgetUsed, 0);
    }
    
    // ============ Admin Function Tests ============
    
    function testSetMaxAidPerBeneficiary() public {
        aid.setMaxAidPerBeneficiary(5);
        
        // Create a way to get the max aid (not in the contract yet, may need to add this function)
        // assertEq(aid.maxAidPerBeneficiary(), 5);
    }
    
    function testSetMinWaitingPeriod() public {
        aid.setMinWaitingPeriod(30 days);
        
        // Create a way to get the waiting period (not in the contract yet, may need to add this function)
        // assertEq(aid.minWaitingPeriod(), 30 days);
    }
    
    function testSetRequireSupervisorApproval() public {
        aid.setRequireSupervisorApproval(false);
        
        // Create a way to get this setting (not in the contract yet, may need to add this function)
        // assertEq(aid.requireSupervisorApproval(), false);
    }
    
    // ============ Access Control Tests ============
    
    function testOnlyAuthorizedCanUpdateStatus() public {
        aid.createProgram("BANSOS_2025", "National Social Aid 2025", 1000000000, true);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        
        aid.issueAid(
            userHash,
            "BANSOS_2025",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
        
        // Regular user cannot update status
        vm.prank(regular);
        vm.expectRevert();
        aid.updateAidStatus(1, BansosAid.AidStatus.Approved, "Approved");
        
        // Operator can update status
        vm.prank(operator);
        aid.updateAidStatus(1, BansosAid.AidStatus.Approved, "Approved by operator");
        
        BansosAid.AidRecord memory record = aid.getAidRecord(1);
        assertEq(uint(record.status), uint(BansosAid.AidStatus.Approved));
    }
    
    function testOnlyAdminCanCreateProgram() public {
        vm.prank(operator);
        vm.expectRevert();
        aid.createProgram(
            "BANSOS_2025",
            "National Social Aid 2025",
            1000000000,
            true
        );
    }
    
    // ============ Edge Case Tests ============
    
    function testGetNonExistentToken() public {
        vm.expectRevert("Token does not exist");
        aid.getAidRecord(999);
    }
    
    function testNonExistentProgram() public {
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "NONEXISTENT"));
        
        vm.expectRevert("Program not approved");
        aid.issueAid(
            userHash,
            "NONEXISTENT",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
    }
    
    function testInactiveProgram() public {
        aid.createProgram("INACTIVE_PROGRAM", "Inactive Program", 1000000000, false);
        bytes32 userHash = keccak256(abi.encodePacked("1234567890123456", "INACTIVE_PROGRAM"));
        
        vm.expectRevert("Program is not active");
        aid.issueAid(
            userHash,
            "INACTIVE_PROGRAM",
            "1234567890123456",
            "John Doe",
            "Jakarta",
            500000,
            BansosAid.BeneficiaryCategory.PoorFamily
        );
    }
    
    function testGenerateUserHash() public view {
        bytes32 expectedHash = keccak256(abi.encodePacked("1234567890123456", "BANSOS_2025"));
        bytes32 generatedHash = aid.generateUserHash("1234567890123456", "BANSOS_2025");
        assertEq(generatedHash, expectedHash);
    }
}