---
name: create-vrc25-contract
description: Use when a user wants to create, scaffold, generate, or deploy a Viction VRC25 / TRC21 sponsor-gas contract — a token or a gasless DApp where an issuer-funded pool pays users' gas. Triggers include VRC25/TRC21 tokens, gasless or sponsored transactions on Viction, gasPrice=0 contracts, and TRC21Issuer registration.
---

# Create a VRC25 Sponsor-Gas Contract

## What this skill produces

A complete, buildable **Foundry repo** for a Viction sponsor-gas contract — not a loose `.sol` file. Users interact with the contract while the issuer's funded VIC pool pays their gas (VRC25, formerly TRC21).

```
<project>/
├── foundry.toml          # solc 0.8.19 pinned, evm_version paris, viction RPCs
├── remappings.txt
├── .env.example          # RPC, keys, TRC21Issuer address, fund amount
├── .gitignore
├── README.md             # GENERATED per project (see step 5) — not copied verbatim
├── src/
│   ├── vrc25/            # audited base, copied verbatim — inherited first for slot safety
│   └── MyContract.sol    # the generated child (token or DApp)
├── script/
│   ├── Deploy.s.sol
│   └── Register.s.sol    # apply()/charge() on TRC21Issuer to fund sponsorship
└── test/
    ├── Behavior.t.sol
    └── StorageLayout.t.sol  # asserts slots 0/1/2 via vm.load — the Viction-critical guard
```

> Target network is **Viction mainnet** (chain `88`, RPC alias `viction`). Testnet
> (chain `89`, alias `viction_testnet`) is available for an optional free dry-run.

## The process (follow in order)

### 1. Clarify intent
Ask whether the user wants a **token** (people hold/transfer it; fees paid in the token) or a **non-token DApp** (game, registry, NFT, utility — free gas for users). For a token, default to including EIP-2612 permit.
*Why:* this picks the base class and fee model. Token → `VRC25Permit`, fee model in `_estimateFee`. DApp → `VRC25`, `_estimateFee` returns 0, `minFee` stays 0. Read `references/token.md` or `references/dapp.md` for the chosen path.

### 2. Scaffold the Foundry project
Copy `assets/foundry-template/` to the project root, then copy `assets/vrc25/` to `<project>/src/vrc25/`. The template already pins solc `0.8.19` and wires scripts/tests. The template ships **no README** — you write one in step 5.
*Why:* the deliverable must build, test, deploy, and register as-is.

### 3. Generate the contract
Edit `src/MyContract.sol` (rename as the user wants — update `src/`, `script/`, `test/` references). The base **must** be inherited first; declare child state only after it. Override `_estimateFee`.
*Why:* the Viction node validates sponsorship by reading storage slots 0/1/2 (`_balances`, `_minFee`, `_owner`) directly off your contract. They line up only when the base is first. `_estimateFee` is abstract — the contract won't deploy until overridden.

### 4. Keep the scripts honest
`Deploy.s.sol` deploys; `Register.s.sol` funds capacity on `TRC21Issuer` (`apply` first, `charge` to top up).
*Why:* the contract sponsors nothing until the issuer funds a VIC pool. Sponsored calls are then sent with `gasPrice = 0` (or `250000000`) and `value = 0`; the node handles the rest — no special client tx-type handling is required.

### 5. Write the project README
Generate `<project>/README.md` from the actual project — its name, whether it is a token or a DApp, the specific functions users call, and the mainnet deploy/register commands. Do **not** paste a generic template. It must cover: what the contract is; `forge build` / `forge test`; deploy + register to mainnet (`--rpc-url viction`); how users send a sponsored call (`gasPrice = 0`, `value = 0`); and the constants (TRC21Issuer, `VRC25GasPrice`, solc `0.8.19`).
*Why:* a README copied verbatim describes a different project than the one you generated, so it misleads the installer. The README is the user-facing entry point — it has to match their contract and name.

### 6. Keep the tests
`StorageLayout.t.sol` asserts slots 0/1/2 with `vm.load`; `Behavior.t.sol` covers contract logic.
*Why:* `forge build` compiles a broken storage layout happily — a misordered base or a child variable above the base silently kills sponsorship. The slot test is the cheapest reliable guard.

### 7. Verify
Run `forge build` and `forge test`. For real confidence, deploy to **Viction mainnet** (`--rpc-url viction`), fund capacity, and confirm a zero-VIC wallet's `gasPrice = 0` call succeeds — see `references/testing.md`. Use the testnet alias first only if you want a free dry-run.
*Why:* compilation never proves the node will sponsor; only a funded, registered contract accepting a gas-less tx does.

## Hard constraints the generated code must satisfy

- VRC25 base inherited **first**; all child state declared after it (slots 0/1/2 intact).
- `_estimateFee(uint256)` overridden — `0` for non-token DApps, a fee model for tokens.
- `minFee = 0` for non-token contracts (the default; never raised).
- Compiled with **solc ≤ 0.8.19** (`pragma solidity 0.8.19;`, pinned in `foundry.toml`).
- Capacity funded post-deploy via `apply`/`charge` on `TRC21Issuer` `0x8c0faeb5C6bEd2129b8674F262Fd45c4e9468bee`.

## Common mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `missing field type` error *after* a tx mined | recent Foundry (alloy) can't parse Viction's legacy receipts | the tx already succeeded — confirm with `cast rpc eth_getTransactionReceipt <hash>`; for scripts use `cast send --async` |
| Zero-VIC `gasPrice = 0` call rejected before mining | base not inherited first (slots 0/1/2 wrong), or capacity is 0 | inherit the VRC25 base first; fund via `apply`/`charge` |
| Contract deploys but "sponsors nothing" | never registered/funded on TRC21Issuer | run `Register.s.sol` — `apply` once, then `charge` to top up |
| `apply` reverts | caller isn't `issuer()`, already registered, or `msg.value` too low | send from the deployer/issuer; use `charge` if already registered |

## Reference documentation (read before generating code)

- **`references/token.md`** — VRC25 fungible token (inherit `VRC25Permit`, fee model).
- **`references/dapp.md`** — non-token / free-gas contract (inherit `VRC25`, `_estimateFee` → 0).
- **`references/register.md`** — activating & funding sponsorship after deploy.
- **`references/testing.md`** — proving sponsorship works on Viction (catches broken layouts).
- **`assets/vrc25/`** — the audited base contracts. Copy them verbatim; never rewrite from scratch.
- **`assets/foundry-template/`** — the project scaffold to copy (no README — you generate that).
