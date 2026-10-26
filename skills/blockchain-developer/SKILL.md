---
name: blockchain-developer
description: Builds and reviews backend integrations with blockchains - node clients, confirmations and finality per chain, reorg handling, deposit address derivation, nonce and fee management, idempotent withdrawals, memo/tag chains, and reconciliation of on-chain against internal balances. Use when writing deposit detection, withdrawal sending, wallet or node integration code for a service that holds or moves crypto assets. Not for smart contract code (solidity-developer), browser wallet flows (web3-integration) or key storage policy (crypto-custody-and-keys).
---

# Blockchain Developer

## Overview

A backend that moves crypto assets has to agree with the chain about what happened, even when the chain
changes its mind (reorgs), the node lies or lags, and the same request arrives twice. Credit late, send
once, and reconcile every day.

## Node Clients

- Do not make balance or finality decisions from a single RPC provider. Run your own nodes or compare at
  least two sources, and alert when their heads diverge.
- Timeouts and bounded retries on every call; handle rate limits; pin client versions.
- Monitor sync lag (local head against a reference). Validate responses: chain id, and the parent-hash
  linkage of the blocks you store.

## Confirmations and Finality

- Configure the threshold per chain and asset; one global number is wrong.
  - Probabilistic finality (proof-of-work style chains): N confirmations, scaled with the amount.
  - Chains with a finality gadget: wait for the node's `finalized` (or `safe`) block, not just inclusion.
  - BFT chains with deterministic finality: still wait for the node to report the block as final.
  - Rollups: separate sequencer confirmation from settlement on the parent chain; credit at the level the
    risk policy requires.
- Show deposits as pending until the threshold; credit only after it.

## Reorg Handling

- Store the block hash and height with every observed transaction.
- On each new head, check the parent-hash chain. On a mismatch, walk back to the common ancestor, mark the
  affected deposits as orphaned or pending again, and reverse any provisional credit.
- Test it with a forced reorg on a local chain (EVM devnets: snapshot and revert; regtest:
  `invalidateblock`).

## Deposit Detection

- Key each deposit by (chain, transaction hash, output index or log index), with a unique constraint, so
  crediting is idempotent.
- Read token transfers from logs and handle internal transfers; handle several outputs to one address.
- Credit only tokens on an allow-list of contract addresses. Tokens with a familiar symbol from an
  unknown contract are spoofs, not deposits. Apply dust thresholds.
- Read each token's decimals from its contract, keyed by (chain id, contract address), and store them with
  the allow-list entry. If the call fails, refuse the token (fail closed). Never default to 18 decimals,
  even though the evm-token-decimals skill shows that fallback; for money the rule here wins.

## Deposit Address Derivation

- Hierarchical deterministic derivation (BIP-32 with the BIP-44/84/86 path for the chain). Online systems
  hold only extended public keys; private keys never sit on application servers.
- Allocate the derivation index atomically and store the path with the address. Re-derive and compare
  before showing an address to a user.
- Validate address formats and checksums (EIP-55, bech32, and each chain's own); respect gap limits when
  scanning.

## Memo and Tag Chains

- Chains that share one address and route by a memo, tag or comment (destination tags, memos, comments)
  credit by the tag. Validate its type and length per chain.
- A deposit with a missing or unknown tag goes to a manual review queue, never to a guessed user.
- Withdrawals to such chains require the tag when the destination needs one; enforce it in the API, not
  only in the UI.

## Nonce and Fee Management

- Account-based chains: one nonce allocator per sending address (a row lock or a single-writer service).
  Reading the pending transaction count from a node is a race under concurrency.
- Replace a stuck transaction with the same nonce and a higher fee, by at least the node's minimum bump
  (commonly 10 percent on both the fee cap and the priority fee for EIP-1559 transactions).
- UTXO chains: deliberate coin selection, change outputs, RBF or CPFP for stuck transactions, a fee rate
  from an estimator with a floor and a cap.

## Idempotent Withdrawals

- Each withdrawal request carries an idempotency key and moves through persisted states: requested,
  approved, signed, broadcast, confirmed or failed. Persist the state before each external side effect.
- Retry a broadcast with the same signed transaction (same hash). Sign a new one only after the old one is
  proven dropped or replaced.
- After a timeout during broadcast, query by transaction hash before doing anything else.
- Limits and approvals come from the custody policy; this code enforces them, it does not define them.

## Reconciliation

- Daily and on demand: compare on-chain balances per address or wallet, at a finalized block height, with
  the internal ledger.
- Explain every difference: in-flight withdrawals, unconfirmed deposits, network fees, dust.
- An unexplained difference above the threshold raises an alert and pauses withdrawals of that asset.
  Store every reconciliation result immutably.

## Verify Before Done

```bash
<test-cmd> -k 'reorg or finality or confirmation or idempot'    # these tests exist and pass
anvil --block-time 1 &     # EVM devnet for reorg tests (evm_snapshot / evm_revert)
bitcoin-cli -regtest invalidateblock <block-hash>   # UTXO regtest: force a reorg
# Thresholds are set per chain, not as one global number
grep -rnE 'confirmations|finality|finalized' <config-dir>/
# Nonces read straight from a node race under concurrency
grep -rniE 'getTransactionCount.*pending' <src>/
<reconcile-cmd> --dry-run --at finalized    # on-chain vs ledger difference is zero or fully explained
```
