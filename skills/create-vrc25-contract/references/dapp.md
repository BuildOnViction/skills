# Variant: Non-Token Sponsored Contract (DApp, Game, NFT, utility)

Use this when the user wants an arbitrary contract — not a token — that gives its users **free gas** on Viction. The contract logic can be anything (a game, a registry, an NFT mint, a voting app); the VRC25 base is here purely to satisfy the node's gas-exemption check, not to be a token.

## Key idea

Any contract can be sponsored, but the node still reads the same hardcoded storage slots (slot 0 balances, slot 1 minFee, slot 2 issuer) to validate exemption. So you **must** inherit a VRC25 base to keep those slots aligned — even though you are not running a token. Skipping inheritance and "just adding three variables" is fragile and unnecessary; inherit `VRC25` (or `VRC25Upgradable` for proxies).

## The two things that make it free

1. **Keep `minFee = 0`.** The node accepts a sponsored tx when `balances[sender] >= minFee + value`. With `minFee = 0` and the user sending `value = 0`, every sender passes regardless of token balance. `_minFee` defaults to `0`, so a fresh contract is already correct — you do **not** need to set it. (`setFee` is an `external onlyOwner` function, so it cannot be called from your constructor anyway; if the fee was ever raised, the owner lowers it back with a `setFee(0)` transaction after deploy.)
2. **Charge no token fee.** Override `_estimateFee` to return `0` so no fee is ever deducted and no `Fee` event fires. Your users pay nothing; the issuer's funded VIC pool covers gas.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // Viction tooling/verification tracks solc <= 0.8.19

import "./vrc25/VRC25.sol";

contract MyGame is VRC25 {
    uint256 public highScore;

    // _minFee defaults to 0, so the node check is balances[sender] >= 0 -> always true.
    constructor() VRC25("MyGame", "GAME", 18) {}

    // No token fee for any action.
    function _estimateFee(uint256 /* value */) internal view override returns (uint256) {
        return 0;
    }

    // ---- your actual app logic below; users call these with gasPrice = 0 ----
    function submitScore(uint256 score) external {
        if (score > highScore) {
            highScore = score;
        }
    }
}
```

`name`/`symbol`/`decimals` are required by the base constructor but are cosmetic for a non-token contract — pass any sensible placeholder.

## Storage safety when you add your own state

You are adding app state (like `highScore` above). That is fine **as long as every variable you declare comes after the inherited base.** Because `VRC25` is the first (and here only) base and you declare `highScore` in the child, the inherited slots 0–2 stay at the front. Never insert your own state "above" the base, and if you use multiple inheritance put the VRC25 base first.

## The revert-path safety net (why inheriting the real base matters)

If a sponsored transaction reverts, the node's internal `PayFeeWithVRC25` forcibly deducts `minFee` from slot 0 (`balances[sender]`) and credits slot 2 (`issuer`). With `minFee = 0` this is a no-op, but it operates on your real storage either way — so the slots must be genuine VRC25 state, not look-alike variables. This is another reason to inherit the audited base rather than fake the layout.

## After writing

Fund capacity exactly like a token: from the `issuer()` address call `apply(yourContract)` on TRC21Issuer `0x8c0faeb5C6bEd2129b8674F262Fd45c4e9468bee` with ≥1 wei, then `charge` to top up. See `references/register.md`.

## Review checklist for non-token contracts

- Inherits `VRC25` (or `VRC25Upgradable`) **first**; app state declared only in the child.
- `_estimateFee` overridden to `return 0`.
- `minFee` is 0 (the default — never raised above 0), so balance-less users pass the node check.
- User told to `apply`/`charge` capacity, and that end users must send `gasPrice = 0`, `value = 0`.
