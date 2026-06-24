// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // Viction tooling/verification tracks solc <= 0.8.19

import "./vrc25/VRC25Permit.sol";

/**
 * @title MyContract — example VRC25 sponsor-gas token
 * @notice Rename `MyContract` throughout the repo (src, script, test) for your token.
 *         For a non-token / free-gas DApp, replace the body per references/dapp.md:
 *         inherit `VRC25` instead of `VRC25Permit`, keep `minFee` at 0, and return 0 below.
 *
 * VRC25Permit is inherited FIRST so storage slots 0/1/2 (_balances, _minFee, _owner)
 * stay where the Viction node expects them. Never declare child state above the base.
 */
contract MyContract is VRC25Permit {
    constructor() VRC25("My Token", "MTK", 18) VRC25Permit() {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    /// @dev Fee model. Flat fee equal to the owner-configured `minFee` (0 by default).
    ///      Free transfers: `return 0;`. Proportional: e.g. `return value / 1000 + minFee();`.
    function _estimateFee(uint256 /* value */) internal view override returns (uint256) {
        return minFee();
    }
}
