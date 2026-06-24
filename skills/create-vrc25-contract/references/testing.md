# Testing a Sponsor-Gas Contract on Viction

A contract can compile perfectly and still fail to sponsor gas, because the Viction node validates sponsorship by reading storage slots 0/1/2 directly — something `solc`/`forge build` never checks. The only way to be sure is to deploy, fund capacity, and watch a **zero-VIC wallet** send a `gasPrice = 0` transaction that the network accepts. Target **mainnet** (chain `88`, RPC alias `viction`); run the same flow against testnet first (chain `89`, `viction_testnet`) only if you want a free dry-run. Always run this before telling a user their contract is ready.

## Compiler and transaction shape (Viction specifics)

- **Compile with solc ≤ 0.8.19.** Viction's tooling and source verification track up to 0.8.19; newer pragmas can verify or behave inconsistently. Pin child contracts to `pragma solidity 0.8.19;` and set `solc = "0.8.19"` in `foundry.toml`. The bundled base contracts use `pragma solidity >=0.7.6;`, which resolves cleanly at 0.8.19.
- **Send sponsored calls with `gasPrice = 0`.** That is the signal the node keys on; the network handles the transaction from there. In cast pass `--gas-price 0`, in ethers set `gasPrice: 0n`.

## Foundry on Viction — receipt gotcha

Viction is a legacy go-ethereum fork whose receipts omit the `type` field. Recent Foundry (alloy-based — all 2024+ nightlies and 1.x stable) fails to deserialize them with `missing field type`, *after* the tx is already mined. The send still succeeds on-chain. Confirm it with raw RPC, which skips the typed parser: `cast rpc eth_getTransactionReceipt <hash> --rpc-url viction` (a `"status":"0x1"` means success). For scripted sends, prefer `cast send ... --async` so Foundry never parses the receipt.

## The flow (cast)

`$RPC` = `https://rpc.viction.xyz` (mainnet), `$CHAIN_ID` = `88`. `$ISSUER`, `$TOKEN`, `$DEPLOYER_KEY`, `$TESTER_KEY` are your values.

```bash
# 1. Deploy
forge create src/MyToken.sol:MyToken --rpc-url $RPC --private-key $DEPLOYER_KEY --broadcast
export TOKEN=0x...   # the "Deployed to" address

# 2. Register + fund capacity — MUST be sent from issuer() (the deployer). 0.001 VIC:
cast send $ISSUER "apply(address)" $TOKEN --value 1000000000000000 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY --chain-id $CHAIN_ID
cast call $ISSUER "getTokenCapacity(address)(uint256)" $TOKEN --rpc-url $RPC   # expect > 0

# 3. Prove the tester is gas-less
TESTER=$(cast wallet address --private-key $TESTER_KEY)
cast balance $TESTER --rpc-url $RPC                                            # expect 0

# 4. Sponsored tx from the zero-VIC tester (gasPrice 0)
cast send $TOKEN "transfer(address,uint256)" 0x0000000000000000000000000000000000000001 500000000000000000 \
  --rpc-url $RPC --private-key $TESTER_KEY --gas-price 0 --chain-id $CHAIN_ID

# 5. Confirm the issuer pool paid for it (capacity decreased)
cast call $ISSUER "getTokenCapacity(address)(uint256)" $TOKEN --rpc-url $RPC
```

## Interpreting failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `apply` reverts | caller isn't `issuer()`, already registered, or `msg.value` below min | send from the deployer/issuer; use `charge` if already registered |
| Sponsored tx rejected before mining | capacity is 0, **wrong storage slots 0/1/2**, or `balances[sender] < minFee` | fund capacity; re-check the contract inherits the base first; seed tester tokens or set `minFee = 0` |
| Tx mines but reverts (status 0) | sponsorship worked; your contract logic failed | debug the contract function, not the sponsorship |
| Capacity didn't drop | tx wasn't sent with `gasPrice = 0` | resend with `gasPrice = 0` (cast: `--gas-price 0`) |

A rejected `gasPrice = 0` transaction from a zero-VIC wallet — despite funded capacity — is the classic signature of a broken storage layout. That is precisely the bug inheriting the bundled base prevents.
