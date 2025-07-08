
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/BansosAid.sol";

contract DeployBansosAid is Script {
    function run() external {
        // Get the private key from environment variable or use default anvil key
        // uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the contract with the deployer as initial owner
        address initialOwner = vm.addr(deployerPrivateKey);
        BansosAid bansosAid = new BansosAid(initialOwner);
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log the deployment info
        console.log("BansosAid deployed at:", address(bansosAid));
        console.log("Initial owner:", initialOwner);
        console.log("Contract owner:", bansosAid.owner());
        console.log("Total supply:", bansosAid.getTotalAidIssued());
    }
}