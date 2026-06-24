# Activating & Funding Sponsorship (TRC21Issuer)

A VRC25 contract does not sponsor anything until its issuer funds a VIC gas pool in the `TRC21Issuer` system contract. This file covers the post-deployment on-chain steps and how end users then send sponsored transactions.

## The system contract

`TRC21Issuer` is pre-deployed on Viction mainnet at:

```
0x8c0faeb5C6bEd2129b8674F262Fd45c4e9468bee
```

Relevant methods:

| Method | Who can call | Requirement | Purpose |
|--------|--------------|-------------|---------|
| `apply(address token)` | the contract's `issuer()` only | `msg.value >= minCap` (typically `1 wei`) | Register the contract for sponsorship and seed its gas pool |
| `charge(address token)` | anyone | `msg.value >= minCap` (`1 wei`) | Top up an already-registered contract's pool |
| `getTokenCapacity(address token) view returns (uint256)` | anyone | — | Read remaining sponsor capacity (in wei of VIC) |

`token` here is **your deployed contract's address**, whether it is a token or a non-token DApp.

## Step 1 — Register and seed (issuer only)

The call must come from the address that `yourContract.issuer()` returns (which the base sets to the deployer / `_owner`). Send some VIC as `msg.value` — `1 wei` satisfies the minimum, but send enough to actually pay for the gas you expect to sponsor.

Minimal ABI you need:

```json
[
  {"name":"apply","type":"function","stateMutability":"payable","inputs":[{"name":"token","type":"address"}],"outputs":[]},
  {"name":"charge","type":"function","stateMutability":"payable","inputs":[{"name":"token","type":"address"}],"outputs":[]},
  {"name":"getTokenCapacity","type":"function","stateMutability":"view","inputs":[{"name":"token","type":"address"}],"outputs":[{"name":"","type":"uint256"}]}
]
```

ethers v6 example:

```js
import { ethers } from "ethers";

const ISSUER = "0x8c0faeb5C6bEd2129b8674F262Fd45c4e9468bee";
const provider = new ethers.JsonRpcProvider("https://rpc.viction.xyz");
const wallet = new ethers.Wallet(ISSUER_PRIVATE_KEY, provider); // must be yourContract.issuer()

const trc21 = new ethers.Contract(ISSUER, ABI, wallet);

// Register + seed with 1 VIC of capacity:
await (await trc21.apply(MY_CONTRACT, { value: ethers.parseEther("1") })).wait();

// Later, anyone can top up:
await (await trc21.charge(MY_CONTRACT, { value: ethers.parseEther("0.5") })).wait();

// Check what's left:
console.log(await trc21.getTokenCapacity(MY_CONTRACT));
```

`apply` will revert if the caller is not the issuer, if the contract is already registered, or if `msg.value` is below the minimum.

## Step 2 — Top up over time

As sponsored transactions execute, the network converts gas used into a VIC cost and deducts it from the pool. When `getTokenCapacity` runs low, anyone (not just the issuer) can call `charge(token)` to refill. Monitoring capacity and auto-charging is a good operational habit — if the pool hits zero, the node stops accepting sponsored transactions for that contract.

## Step 3 — How end users send sponsored transactions

Once capacity is funded, users invoke the contract with a transaction shaped so the node applies the sponsorship path:

- `gasPrice = 0` — the required signal. (The node also accepts the network default `VRC25GasPrice` = `250000000` wei.) Set it explicitly: `--gas-price 0` in cast, `gasPrice: 0n` in ethers. The node handles the rest, so no other special tx handling is required.
- `value = 0`
- The node admits the tx to the pool only if **both** hold: the contract has capacity > 0 in TRC21Issuer, **and** `balances[sender] >= minFee + value`. For a free-gas DApp with `minFee = 0`, any sender qualifies; for a token, the sender needs token balance to cover the fee.

ethers v6 example of a user calling a sponsored method:

```js
const c = new ethers.Contract(MY_CONTRACT, MY_ABI, userWallet);
await (await c.submitScore(42, { gasPrice: 0n, value: 0n })).wait();
```

During execution the node swaps the fee "payer" from the user to the TRC21Issuer pool (`buyGas`), so the user spends no VIC.

## Troubleshooting

- **Sponsored tx rejected immediately:** capacity is 0 (call `getTokenCapacity`), or the sender fails `balances[sender] >= minFee` (set `minFee = 0` for non-token DApps, or give the user token balance).
- **`apply` reverts:** caller is not `issuer()`, contract already registered (use `charge` instead), or `msg.value` too low.
- **Fees still charged from a contract caller:** expected — the base skips sponsorship/fees when `msg.sender.isContract()`, because contract-to-contract calls are not sponsored.
