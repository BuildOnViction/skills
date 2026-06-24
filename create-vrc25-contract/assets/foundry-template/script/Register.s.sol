// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";

interface ITRC21Issuer {
    // NOTE: `apply(address)` is omitted on purpose — `apply` is a reserved word in
    // Solidity, so it cannot be declared here. Register.run() calls it via its selector.
    function charge(address token) external payable;
    function getTokenCapacity(address token) external view returns (uint256);
}

/// Funds sponsorship capacity for the deployed contract on TRC21Issuer.
/// `apply` registers + seeds (issuer only, once); `charge` tops up (anyone).
/// Run from the issuer/deployer key:
///   forge script script/Register.s.sol:Register --rpc-url viction --broadcast
contract Register is Script {
    function run() external {
        address issuerContract = vm.envAddress("TRC21_ISSUER");
        ITRC21Issuer trc21 = ITRC21Issuer(issuerContract);
        address token = vm.envAddress("CONTRACT_ADDRESS");
        uint256 fund = vm.envOr("FUND_AMOUNT_VIC", uint256(1)) * 1 ether;
        uint256 pk = vm.envUint("DEPLOYER_KEY");

        bool registered = trc21.getTokenCapacity(token) > 0;

        vm.startBroadcast(pk);
        if (registered) {
            trc21.charge{value: fund}(token); // top up existing pool
        } else {
            // First-time register + seed (issuer only). `apply` is reserved, so call by selector.
            (bool ok, ) = issuerContract.call{value: fund}(
                abi.encodeWithSignature("apply(address)", token)
            );
            require(ok, "TRC21Issuer.apply failed (not issuer, already registered, or value too low)");
        }
        vm.stopBroadcast();

        console2.log("Capacity (wei VIC):", trc21.getTokenCapacity(token));
    }
}
