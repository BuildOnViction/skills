// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/MyContract.sol";

/**
 * The Viction node validates sponsorship by reading raw storage slots 0/1/2 of the
 * contract — it never calls your functions. `forge build` happily compiles a broken
 * layout, so this is the cheapest guard against a misordered base or a child state
 * variable declared above the base. If any of these fail, sponsorship will be rejected
 * on-chain even though the contract compiles and unit tests pass.
 *
 * Slot 0: mapping(address => uint256) _balances
 * Slot 1: uint256 _minFee
 * Slot 2: address _owner   (== issuer())
 */
contract StorageLayoutTest is Test {
    MyContract c;

    function setUp() public {
        c = new MyContract();
    }

    function test_Slot0_IsBalancesMapping() public {
        address holder = address(this); // received minted supply
        bytes32 slot = keccak256(abi.encode(holder, uint256(0)));
        assertEq(uint256(vm.load(address(c), slot)), c.balanceOf(holder));
        assertGt(c.balanceOf(holder), 0); // non-trivial: proves we read the real mapping
    }

    function test_Slot1_IsMinFee() public {
        c.setFee(0x1234);
        assertEq(uint256(vm.load(address(c), bytes32(uint256(1)))), 0x1234);
        assertEq(uint256(vm.load(address(c), bytes32(uint256(1)))), c.minFee());
    }

    function test_Slot2_IsOwner() public {
        address slot2 = address(uint160(uint256(vm.load(address(c), bytes32(uint256(2))))));
        assertEq(slot2, c.issuer());
    }
}
