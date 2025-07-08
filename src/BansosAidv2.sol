// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract BansosAid is ERC721, AccessControl, Pausable, ReentrancyGuard {
    
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant AID_OFFICER_ROLE = keccak256("AID_OFFICER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    
    uint256 private _tokenIds;
    
    // Enums
    enum AidStatus { Pending, Approved, Disbursed, Completed, Rejected, Cancelled }
    enum BeneficiaryCategory { General, Elderly, Disabled, SingleParent, Veteran, Student }
    enum PriorityLevel { Low, Medium, High, Critical }
    
    // Structs
    struct AidRecord {
        string program;
        uint256 timestamp;
        uint256 createdAt;
        uint256 updatedAt;
        string ipfsHash;
        uint256 amount;
        string recipientId;
        string recipientName;
        BeneficiaryCategory category;
        AidStatus status;
        PriorityLevel priority;
        string province;
        string city;
        string district;
        string village;
        address distributedBy;
        address approvedBy;
        address supervisedBy;
        string notes;
        uint256 disbursedAt;
        string disbursementMethod; // Cash, Transfer, Voucher
        string phoneNumber;
        string emergencyContact;
    }
    
    struct Program {
        string name;
        string description;
        uint256 budget;
        uint256 budgetUsed;
        uint256 maxAmountPerBeneficiary;
        uint256 minAmountPerBeneficiary;
        bool isActive;
        uint256 startDate;
        uint256 endDate;
        address programManager;
        BeneficiaryCategory[] eligibleCategories;
    }
    
    struct Statistics {
        uint256 totalRecords;
        uint256 totalDisbursed;
        uint256 totalBeneficiaries;
        uint256 activePrograms;
        uint256 pendingApplications;
        uint256 completedApplications;
    }
    
    // Mappings
    mapping(bytes32 => bool) public hasClaimed;
    mapping(bytes32 => mapping(string => bool)) public hasClaimedProgram;
    mapping(uint256 => AidRecord) public aidRecords;
    mapping(bytes32 => uint256[]) public userTokens;
    mapping(string => Program) public programs;
    mapping(string => bool) public approvedPrograms;
    mapping(address => bool) public authorizedOfficers;
    mapping(string => uint256[]) public programRecords;
    mapping(BeneficiaryCategory => uint256[]) public categoryRecords;
    mapping(AidStatus => uint256[]) public statusRecords;
    mapping(string => uint256[]) public locationRecords; // province -> tokenIds
    mapping(uint256 => string[]) public recordHistory; // tokenId -> history of status changes
    
    // Arrays for iteration
    string[] public programNames;
    uint256[] public allTokenIds;
    
    // Configuration
    uint256 public maxAidPerBeneficiary = 10000000; // 10 million rupiah default
    uint256 public minWaitingPeriod = 90 days; // 3 months between claims
    bool public requireSupervisorApproval = true;
    
    // Events
    event AidIssued(
        bytes32 indexed userHash,
        uint256 indexed tokenId,
        string program,
        uint256 amount,
        string ipfsHash,
        address indexed distributedBy
    );
    
    event AidStatusUpdated(
        uint256 indexed tokenId,
        AidStatus oldStatus,
        AidStatus newStatus,
        address indexed updatedBy,
        string notes
    );
    
    event PaymentDocumented(
        uint256 indexed tokenId,
        string ipfsHash,
        uint256 amount,
        string disbursementMethod
    );
    
    event ProgramCreated(
        string indexed programName,
        uint256 budget,
        address indexed programManager
    );
    
    event ProgramUpdated(
        string indexed programName,
        uint256 newBudget,
        bool isActive
    );
    
    event BeneficiaryUpdated(
        uint256 indexed tokenId,
        string recipientId,
        address indexed updatedBy
    );
    
    event EmergencyAction(
        string action,
        uint256 indexed tokenId,
        address indexed executedBy,
        string reason
    );
    
    // Modifiers
    modifier onlyAuthorized() {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            hasRole(AID_OFFICER_ROLE, msg.sender) ||
            hasRole(SUPERVISOR_ROLE, msg.sender),
            "Not authorized"
        );
        _;
    }
    
    modifier onlyActiveProgram(string memory programName) {
        require(approvedPrograms[programName], "Program not approved");
        require(programs[programName].isActive, "Program not active");
        require(
            block.timestamp >= programs[programName].startDate &&
            block.timestamp <= programs[programName].endDate,
            "Program not in valid time period"
        );
        _;
    }
    
    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }
    
    // Constructor
    constructor(address admin) ERC721("BansosAid", "BANSOS") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(AID_OFFICER_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
        _grantRole(SUPERVISOR_ROLE, admin);
    }
    
    // Program Management
    function createProgram(
        string memory name,
        string memory description,
        uint256 budget,
        uint256 maxAmount,
        uint256 minAmount,
        uint256 startDate,
        uint256 endDate,
        address programManager,
        BeneficiaryCategory[] memory eligibleCategories
    ) external onlyRole(ADMIN_ROLE) {
        require(bytes(name).length > 0, "Program name required");
        require(budget > 0, "Budget must be greater than 0");
        require(maxAmount >= minAmount, "Invalid amount range");
        require(endDate > startDate, "Invalid date range");
        require(programManager != address(0), "Invalid program manager");
        
        programs[name] = Program({
            name: name,
            description: description,
            budget: budget,
            budgetUsed: 0,
            maxAmountPerBeneficiary: maxAmount,
            minAmountPerBeneficiary: minAmount,
            isActive: true,
            startDate: startDate,
            endDate: endDate,
            programManager: programManager,
            eligibleCategories: eligibleCategories
        });
        
        approvedPrograms[name] = true;
        programNames.push(name);
        
        emit ProgramCreated(name, budget, programManager);
    }
    
    function updateProgram(
        string memory name,
        uint256 newBudget,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(approvedPrograms[name], "Program does not exist");
        
        programs[name].budget = newBudget;
        programs[name].isActive = isActive;
        
        emit ProgramUpdated(name, newBudget, isActive);
    }
    
    // Aid Distribution - Refactored to avoid stack too deep
    function issueAid(
        bytes32 userHash,
        string memory program,
        uint256 amount,
        string memory recipientId,
        string memory recipientName,
        BeneficiaryCategory category,
        PriorityLevel priority,
        string memory province,
        string memory city,
        string memory district,
        string memory village,
        string memory phoneNumber,
        string memory emergencyContact,
        string memory notes
    ) external onlyAuthorized onlyActiveProgram(program) whenNotPaused nonReentrant {
        // Validate basic requirements
        _validateAidRequirements(userHash, program, amount, recipientId, recipientName, category);
        
        uint256 tokenId = ++_tokenIds;
        
        // Create aid record
        _createAidRecord(
            tokenId,
            program,
            amount,
            recipientId,
            recipientName,
            category,
            priority,
            province,
            city,
            district,
            village,
            phoneNumber,
            emergencyContact,
            notes
        );
        
        // Update mappings and state
        _updateAidMappings(userHash, tokenId, program, category, province);
        
        // Update program budget
        programs[program].budgetUsed += amount;
        
        // Add to history
        recordHistory[tokenId].push(string(abi.encodePacked(
            "Created by ",
            _addressToString(msg.sender),
            " at ",
            _uint256ToString(block.timestamp)
        )));
        
        // Mint NFT to contract for government custody
        _mint(address(this), tokenId);
        
        emit AidIssued(userHash, tokenId, program, amount, "", msg.sender);
    }
    
    // Helper function to validate aid requirements
    function _validateAidRequirements(
        bytes32 userHash,
        string memory program,
        uint256 amount,
        string memory recipientId,
        string memory recipientName,
        BeneficiaryCategory category
    ) internal view {
        require(!hasClaimedProgram[userHash][program], "Already claimed for this program");
        require(amount > 0, "Amount must be greater than 0");
        require(bytes(recipientId).length > 0, "Recipient ID required");
        require(bytes(recipientName).length > 0, "Recipient name required");
        
        Program storage prog = programs[program];
        require(amount >= prog.minAmountPerBeneficiary, "Amount below minimum");
        require(amount <= prog.maxAmountPerBeneficiary, "Amount exceeds maximum");
        require(prog.budgetUsed + amount <= prog.budget, "Insufficient program budget");
        
        // Check if category is eligible
        bool categoryEligible = false;
        for (uint i = 0; i < prog.eligibleCategories.length; i++) {
            if (prog.eligibleCategories[i] == category) {
                categoryEligible = true;
                break;
            }
        }
        require(categoryEligible, "Category not eligible for this program");
    }
    
    // Helper function to create aid record
    function _createAidRecord(
        uint256 tokenId,
        string memory program,
        uint256 amount,
        string memory recipientId,
        string memory recipientName,
        BeneficiaryCategory category,
        PriorityLevel priority,
        string memory province,
        string memory city,
        string memory district,
        string memory village,
        string memory phoneNumber,
        string memory emergencyContact,
        string memory notes
    ) internal {
        aidRecords[tokenId] = AidRecord({
            program: program,
            timestamp: block.timestamp,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            ipfsHash: "",
            amount: amount,
            recipientId: recipientId,
            recipientName: recipientName,
            category: category,
            status: requireSupervisorApproval ? AidStatus.Pending : AidStatus.Approved,
            priority: priority,
            province: province,
            city: city,
            district: district,
            village: village,
            distributedBy: msg.sender,
            approvedBy: address(0),
            supervisedBy: address(0),
            notes: notes,
            disbursedAt: 0,
            disbursementMethod: "",
            phoneNumber: phoneNumber,
            emergencyContact: emergencyContact
        });
    }
    
    // Helper function to update mappings
    function _updateAidMappings(
        bytes32 userHash,
        uint256 tokenId,
        string memory program,
        BeneficiaryCategory category,
        string memory province
    ) internal {
        hasClaimed[userHash] = true;
        hasClaimedProgram[userHash][program] = true;
        userTokens[userHash].push(tokenId);
        programRecords[program].push(tokenId);
        categoryRecords[category].push(tokenId);
        
        AidStatus initialStatus = requireSupervisorApproval ? AidStatus.Pending : AidStatus.Approved;
        statusRecords[initialStatus].push(tokenId);
        locationRecords[province].push(tokenId);
        allTokenIds.push(tokenId);
    }
    
    // Status Management
    function updateAidStatus(
        uint256 tokenId,
        AidStatus newStatus,
        string memory notes
    ) external onlyAuthorized validTokenId(tokenId) whenNotPaused {
        AidRecord storage record = aidRecords[tokenId];
        AidStatus oldStatus = record.status;
        
        require(oldStatus != newStatus, "Status already set");
        
        // Role-based status change validation
        if (newStatus == AidStatus.Approved) {
            require(
                hasRole(SUPERVISOR_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
                "Only supervisor can approve"
            );
            record.approvedBy = msg.sender;
        }
        
        if (newStatus == AidStatus.Disbursed) {
            require(oldStatus == AidStatus.Approved, "Must be approved first");
            record.disbursedAt = block.timestamp;
        }
        
        if (newStatus == AidStatus.Completed) {
            require(oldStatus == AidStatus.Disbursed, "Must be disbursed first");
        }
        
        // Update status
        record.status = newStatus;
        record.updatedAt = block.timestamp;
        if (bytes(notes).length > 0) {
            record.notes = notes;
        }
        
        // Update status tracking
        _removeFromStatusArray(oldStatus, tokenId);
        statusRecords[newStatus].push(tokenId);
        
        // Add to history
        recordHistory[tokenId].push(string(abi.encodePacked(
            "Status changed from ",
            _statusToString(oldStatus),
            " to ",
            _statusToString(newStatus),
            " by ",
            _addressToString(msg.sender),
            " at ",
            _uint256ToString(block.timestamp)
        )));
        
        emit AidStatusUpdated(tokenId, oldStatus, newStatus, msg.sender, notes);
    }
    
    function updatePaymentDocumentation(
        uint256 tokenId,
        string memory ipfsHash,
        string memory disbursementMethod
    ) external onlyAuthorized validTokenId(tokenId) whenNotPaused {
        AidRecord storage record = aidRecords[tokenId];
        
        record.ipfsHash = ipfsHash;
        record.disbursementMethod = disbursementMethod;
        record.updatedAt = block.timestamp;
        
        emit PaymentDocumented(tokenId, ipfsHash, record.amount, disbursementMethod);
    }
    
    // Query Functions
    function getAidRecord(uint256 tokenId) external view validTokenId(tokenId) returns (AidRecord memory) {
        return aidRecords[tokenId];
    }
    
    function getUserTokens(bytes32 userHash) external view returns (uint256[] memory) {
        return userTokens[userHash];
    }
    
    function getAidRecordsByProgram(string memory program) external view returns (uint256[] memory) {
        return programRecords[program];
    }
    
    function getAidRecordsByStatus(AidStatus status) external view returns (uint256[] memory) {
        return statusRecords[status];
    }
    
    function getAidRecordsByCategory(BeneficiaryCategory category) external view returns (uint256[] memory) {
        return categoryRecords[category];
    }
    
    function getAidRecordsByLocation(string memory province) external view returns (uint256[] memory) {
        return locationRecords[province];
    }
    
    function getRecordHistory(uint256 tokenId) external view validTokenId(tokenId) returns (string[] memory) {
        return recordHistory[tokenId];
    }
    
    function getProgram(string memory name) external view returns (Program memory) {
        require(approvedPrograms[name], "Program does not exist");
        return programs[name];
    }
    
    function getAllPrograms() external view returns (string[] memory) {
        return programNames;
    }
    
    function getStatistics() external view returns (Statistics memory) {
        return Statistics({
            totalRecords: _tokenIds,
            totalDisbursed: _calculateTotalDisbursed(),
            totalBeneficiaries: _calculateUniqueBeneficiaries(),
            activePrograms: _countActivePrograms(),
            pendingApplications: statusRecords[AidStatus.Pending].length,
            completedApplications: statusRecords[AidStatus.Completed].length
        });
    }
    
    // Utility Functions
    function generateUserHash(string memory ktp, string memory program) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(ktp, program));
    }
    
    function hasClaimedForProgram(bytes32 userHash, string memory program) external view returns (bool) {
        return hasClaimedProgram[userHash][program];
    }
    
    function getTotalAidIssued() external view returns (uint256) {
        return _tokenIds;
    }
    
    // Emergency Functions
    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        _pause();
        emit EmergencyAction("PAUSE", 0, msg.sender, "Emergency pause activated");
    }
    
    function emergencyUnpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit EmergencyAction("UNPAUSE", 0, msg.sender, "Emergency pause deactivated");
    }
    
    function emergencyCancel(uint256 tokenId, string memory reason) external onlyRole(ADMIN_ROLE) validTokenId(tokenId) {
        AidRecord storage record = aidRecords[tokenId];
        require(record.status != AidStatus.Completed, "Cannot cancel completed aid");
        
        AidStatus oldStatus = record.status;
        record.status = AidStatus.Cancelled;
        record.updatedAt = block.timestamp;
        record.notes = reason;
        
        // Update program budget
        programs[record.program].budgetUsed -= record.amount;
        
        // Update status tracking
        _removeFromStatusArray(oldStatus, tokenId);
        statusRecords[AidStatus.Cancelled].push(tokenId);
        
        emit EmergencyAction("CANCEL", tokenId, msg.sender, reason);
        emit AidStatusUpdated(tokenId, oldStatus, AidStatus.Cancelled, msg.sender, reason);
    }
    
    // Admin Functions
    function setMaxAidPerBeneficiary(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        maxAidPerBeneficiary = newMax;
    }
    
    function setMinWaitingPeriod(uint256 newPeriod) external onlyRole(ADMIN_ROLE) {
        minWaitingPeriod = newPeriod;
    }
    
    function setRequireSupervisorApproval(bool required) external onlyRole(ADMIN_ROLE) {
        requireSupervisorApproval = required;
    }
    
    // Internal Functions
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIds;
    }
    
    function _removeFromStatusArray(AidStatus status, uint256 tokenId) internal {
        uint256[] storage statusArray = statusRecords[status];
        for (uint256 i = 0; i < statusArray.length; i++) {
            if (statusArray[i] == tokenId) {
                statusArray[i] = statusArray[statusArray.length - 1];
                statusArray.pop();
                break;
            }
        }
    }
    
    function _calculateTotalDisbursed() internal view returns (uint256) {
        uint256 total = 0;
        uint256[] memory disbursedRecords = statusRecords[AidStatus.Disbursed];
        uint256[] memory completedRecords = statusRecords[AidStatus.Completed];
        
        for (uint256 i = 0; i < disbursedRecords.length; i++) {
            total += aidRecords[disbursedRecords[i]].amount;
        }
        
        for (uint256 i = 0; i < completedRecords.length; i++) {
            total += aidRecords[completedRecords[i]].amount;
        }
        
        return total;
    }
    
    function _calculateUniqueBeneficiaries() internal view returns (uint256) {
        // This is a simplified version - in production you'd want more sophisticated tracking
        return _tokenIds;
    }
    
    function _countActivePrograms() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < programNames.length; i++) {
            if (programs[programNames[i]].isActive) {
                count++;
            }
        }
        return count;
    }
    
    function _statusToString(AidStatus status) internal pure returns (string memory) {
        if (status == AidStatus.Pending) return "Pending";
        if (status == AidStatus.Approved) return "Approved";
        if (status == AidStatus.Disbursed) return "Disbursed";
        if (status == AidStatus.Completed) return "Completed";
        if (status == AidStatus.Rejected) return "Rejected";
        if (status == AidStatus.Cancelled) return "Cancelled";
        return "Unknown";
    }
    
    function _addressToString(address addr) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", _toHexString(uint160(addr), 20)));
    }
    
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    function _toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = 2 * length; i > 0; --i) {
            buffer[i - 1] = bytes1(uint8(value & 0xf) + (uint8(value & 0xf) < 10 ? 48 : 87));
            value >>= 4;
        }
        return string(buffer);
    }
    
    // Override tokenURI to return IPFS hash if available
    function tokenURI(uint256 tokenId) public view override validTokenId(tokenId) returns (string memory) {
        AidRecord memory record = aidRecords[tokenId];
        if (bytes(record.ipfsHash).length > 0) {
            return string(abi.encodePacked("ipfs://", record.ipfsHash));
        }
        return super.tokenURI(tokenId);
    }
    
    // Required overrides for AccessControl
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}