# Variant: VRC25 Fungible Token

Use this when the user wants a token that people hold and transfer, and whose transfer fees are paid in the token itself (then routed to the issuer). This is the original purpose of VRC25.

## Which base to inherit

Inherit **`VRC25Permit`** as the *first* parent. It extends `VRC25` and adds EIP-2612 `permit`, which the Viction docs recommend so gasless protocols can support your token even if it is not registered with TomoZ. Use plain `VRC25` only if you have a specific reason to drop permit.

The recommended EIP-712 domain is `name = "VRC25"`, `version = "1"` — the bundled `VRC25Permit` constructor already sets this, so you get it for free.

## What the base already gives you

Do not re-implement any of these in the child — they are part of the audited slot/event contract:

- Storage slots 0–2 (`_balances`, `_minFee`, `_owner`) in the required order.
- `transfer`, `transferFrom`, `approve`, `burn` with fee charging built in.
- `_chargeFeeFrom`, which transfers the fee to the issuer and emits `Fee(from, to, issuer, value)` plus the corresponding `Transfer`. It also **skips the fee when the caller is a contract** (`msg.sender.isContract()`), because contract callers are not gas-sponsored.
- `issuer()` (returns `_owner`), `balanceOf`, `allowance`, `totalSupply`, `decimals`, `name`, `symbol`.
- `setFee(uint256)` / `minFee()` for the owner to manage the fee, and two-step `transferOwnership` / `acceptOwnership`.
- `supportsInterface` (ERC-165) reporting `type(IVRC25).interfaceId`.

## What you MUST implement in the child

`_estimateFee(uint256 value)` is declared abstract in the base, so the contract will not compile/deploy until you override it. This is your fee model.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // Viction tooling/verification tracks solc <= 0.8.19

import "./vrc25/VRC25Permit.sol";

contract MyToken is VRC25Permit {
    constructor() VRC25("My Token", "MTK", 18) VRC25Permit() {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    /// Flat fee equal to the owner-configured minFee.
    function _estimateFee(uint256 /* value */) internal view override returns (uint256) {
        return minFee();
    }
}
```

Note the constructor passes args to the **`VRC25`** base (name/symbol/decimals) and invokes `VRC25Permit()`; this is how Solidity initializes the inherited bases. Mint your initial supply with the inherited `_mint`.

### Fee-model options for `_estimateFee`

- **Flat fee:** `return minFee();` — every transfer costs the same, owner-tunable via `setFee`.
- **Free transfers:** `return 0;` — no token fee is charged (gas still sponsored once capacity is funded).
- **Proportional fee:** e.g. `return value * 1 / 1000 + minFee();` — careful with overflow on old compilers; the base uses `SafeMath`, and Solidity ≥0.8 checks arithmetic by default.

Keep `estimateFee` cheap and side-effect-free; it is a `view` the network and wallets call to quote fees.

## After writing

The token is inert until the issuer funds gas capacity. Hand the user the activation steps from `references/register.md` (`apply` then optional `charge` on TRC21Issuer `0x8c0faeb5C6bEd2129b8674F262Fd45c4e9468bee`).

## Review checklist for token contracts

- `VRC25Permit` (or `VRC25`) is the **first** base; no child state variable precedes it.
- `_estimateFee` is overridden.
- Initial supply minted via `_mint`, not by writing `_balances` directly (which you can't — it's private — another reason to use the base).
- Child does **not** redefine `transfer`, `balanceOf`, `issuer`, or the events.
- User has been told to `apply`/`charge` capacity.
