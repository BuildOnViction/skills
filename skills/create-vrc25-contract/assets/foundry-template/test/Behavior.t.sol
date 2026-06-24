// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/MyContract.sol";

contract BehaviorTest is Test {
    MyContract token;
    address issuer; // = deployer = this test contract
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        issuer = address(this);
        token = new MyContract(); // mints initial supply to msg.sender (this)
    }

    function test_DeployerIsIssuer() public {
        assertEq(token.issuer(), issuer);
        assertEq(token.owner(), issuer);
    }

    function test_InitialSupplyMintedToIssuer() public {
        assertGt(token.totalSupply(), 0);
        assertEq(token.balanceOf(issuer), token.totalSupply());
    }

    function test_TransferMovesTokens() public {
        token.transfer(alice, 1_000);
        assertEq(token.balanceOf(alice), 1_000);
    }

    /// Fee is only charged when the caller is an EOA (the node only sponsors EOAs).
    /// We seed alice (contract caller pays no fee), then transfer AS alice (an EOA with
    /// no code) so `_estimateFee`/`_chargeFeeFrom` actually run and route the fee to issuer.
    function test_FeeRoutedToIssuerForEoaCaller() public {
        token.setFee(10); // onlyOwner; this == owner
        token.transfer(alice, 100); // caller is a contract -> no fee, alice gets 100

        uint256 issuerBefore = token.balanceOf(issuer);

        vm.prank(alice); // alice has no code -> treated as EOA -> fee applies
        token.transfer(bob, 50);

        assertEq(token.balanceOf(bob), 50);
        assertEq(token.balanceOf(alice), 100 - 50 - 10); // sent 50, paid 10 fee
        assertEq(token.balanceOf(issuer), issuerBefore + 10); // issuer received the fee
    }

    function test_ContractCallerPaysNoFee() public {
        token.setFee(10);
        // this (a contract) transfers -> estimateFee returns 0
        assertEq(token.estimateFee(123), 0);
    }
}
