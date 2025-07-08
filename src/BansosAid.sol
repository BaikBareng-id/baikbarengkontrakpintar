// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BansosAid is ERC721, Ownable {
    uint256 private _tokenIds;

    struct AidRecord {
        string program;
        uint256 timestamp;
        string ipfsHash; // IPFS hash for payment receipt/documentation
        uint256 amount; // Amount in rupiah (stored as uint for precision)
        string recipientId; // KTP or other ID
    }

    // Mapping from user hash to claim status
    mapping(bytes32 => bool) public hasClaimed;
    
    // Mapping from user hash to program to prevent duplicate claims per program
    mapping(bytes32 => mapping(string => bool)) public hasClaimedProgram;
    
    // Mapping from token ID to aid record
    mapping(uint256 => AidRecord) public aidRecords;
    
    // Mapping from user hash to their token IDs
    mapping(bytes32 => uint256[]) public userTokens;

    // Events
    event AidIssued(
        bytes32 indexed userHash,
        uint256 indexed tokenId,
        string program,
        uint256 amount,
        string ipfsHash
    );
    
    event PaymentDocumented(
        uint256 indexed tokenId,
        string ipfsHash,
        uint256 amount
    );

    constructor(address initialOwner) ERC721("BansosAid", "BANSOS") Ownable(initialOwner) {}

    /**
     * @dev Check if a token exists
     * @param tokenId Token ID to check
     * @return bool whether token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIds;
    }

    /**
     * @dev Issue aid to a beneficiary and mint NFT as proof
     * @param userHash Hash of user ID + program (keccak256(abi.encodePacked(ktp, program)))
     * @param program Name of the aid program
     */
    function issueAid(bytes32 userHash, string memory program) external onlyOwner {
        require(!hasClaimedProgram[userHash][program], "Already claimed");
        
        _tokenIds++;
        uint256 tokenId = _tokenIds;
        
        // Create aid record
        aidRecords[tokenId] = AidRecord({
            program: program,
            timestamp: block.timestamp,
            ipfsHash: "",
            amount: 0,
            recipientId: ""
        });
        
        // Update claim status
        hasClaimed[userHash] = true;
        hasClaimedProgram[userHash][program] = true;
        userTokens[userHash].push(tokenId);
        
        // Mint NFT to contract owner (government) as proof of distribution
        _mint(owner(), tokenId);
        
        emit AidIssued(userHash, tokenId, program, 0, "");
    }

    /**
     * @dev Issue aid with full details including payment documentation
     * @param userHash Hash of user ID + program
     * @param program Name of the aid program
     * @param amount Amount in rupiah
     * @param ipfsHash IPFS hash of payment receipt/documentation
     * @param recipientId KTP or other ID of recipient
     */
    function issueAidWithDetails(
        bytes32 userHash,
        string memory program,
        uint256 amount,
        string memory ipfsHash,
        string memory recipientId
    ) external onlyOwner {
        require(!hasClaimedProgram[userHash][program], "Already claimed");
        
        _tokenIds++;
        uint256 tokenId = _tokenIds;
        
        // Create aid record with full details
        aidRecords[tokenId] = AidRecord({
            program: program,
            timestamp: block.timestamp,
            ipfsHash: ipfsHash,
            amount: amount,
            recipientId: recipientId
        });
        
        // Update claim status
        hasClaimed[userHash] = true;
        hasClaimedProgram[userHash][program] = true;
        userTokens[userHash].push(tokenId);
        
        // Mint NFT to contract owner (government) as proof of distribution
        _mint(owner(), tokenId);
        
        emit AidIssued(userHash, tokenId, program, amount, ipfsHash);
    }

    /**
     * @dev Update payment documentation for existing aid record
     * @param tokenId Token ID of the aid record
     * @param ipfsHash IPFS hash of payment receipt/documentation
     * @param amount Amount in rupiah
     */
    function updatePaymentDocumentation(
        uint256 tokenId,
        string memory ipfsHash,
        uint256 amount
    ) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        
        aidRecords[tokenId].ipfsHash = ipfsHash;
        aidRecords[tokenId].amount = amount;
        
        emit PaymentDocumented(tokenId, ipfsHash, amount);
    }

    /**
     * @dev Get aid record details
     * @param tokenId Token ID of the aid record
     * @return AidRecord struct with all details
     */
    function getAidRecord(uint256 tokenId) external view returns (AidRecord memory) {
        require(_exists(tokenId), "Token does not exist");
        return aidRecords[tokenId];
    }

    /**
     * @dev Get all token IDs for a user
     * @param userHash Hash of user ID + program
     * @return Array of token IDs
     */
    function getUserTokens(bytes32 userHash) external view returns (uint256[] memory) {
        return userTokens[userHash];
    }

    /**
     * @dev Generate user hash for checking claims
     * @param ktp KTP number or other ID
     * @param program Program name
     * @return bytes32 hash
     */
    function generateUserHash(string memory ktp, string memory program) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(ktp, program));
    }

    /**
     * @dev Check if user has claimed for specific program
     * @param userHash Hash of user ID + program
     * @param program Program name
     * @return bool claim status
     */
    function hasClaimedForProgram(bytes32 userHash, string memory program) external view returns (bool) {
        return hasClaimedProgram[userHash][program];
    }

    /**
     * @dev Get total number of aid records issued
     * @return uint256 total count
     */
    function getTotalAidIssued() external view returns (uint256) {
        return _tokenIds;
    }

    /**
     * @dev Override tokenURI to return IPFS hash if available
     * @param tokenId Token ID
     * @return string URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        AidRecord memory record = aidRecords[tokenId];
        if (bytes(record.ipfsHash).length > 0) {
            return string(abi.encodePacked("ipfs://", record.ipfsHash));
        }
        
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Get aid records by program
     * @param program Program name
     * @return Array of token IDs for the program
     */
    function getAidRecordsByProgram(string memory program) external view returns (uint256[] memory) {
        uint256 totalTokens = _tokenIds;
        uint256[] memory tempResults = new uint256[](totalTokens);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= totalTokens; i++) {
            if (keccak256(abi.encodePacked(aidRecords[i].program)) == keccak256(abi.encodePacked(program))) {
                tempResults[count] = i;
                count++;
            }
        }
        
        // Create array with exact size
        uint256[] memory results = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            results[i] = tempResults[i];
        }
        
        return results;
    }
}