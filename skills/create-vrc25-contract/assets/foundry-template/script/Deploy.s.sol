// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/MyContract.sol";

/// Deploys the contract. Run:
///   forge script script/Deploy.s.sol:Deploy --rpc-url viction --broadcast
contract Deploy is Script {
    function run() external returns (MyContract deployed) {
        uint256 pk = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(pk);
        deployed = new MyContract();
        vm.stopBroadcast();

        console2.log("Deployed at:", address(deployed));
        console2.log("issuer():   ", deployed.issuer());
        console2.log("Next: set CONTRACT_ADDRESS in .env, then run Register.s.sol");
    }
}
