---
name: solidity-developer
description: Writes, tests and reviews Solidity smart contracts with Foundry - checks-effects-interactions, reentrancy guards, access control, upgradeability risks, OpenZeppelin libraries, fuzz and invariant tests, and slither, with forge test and forge coverage as the gates. Use when writing or changing Solidity contracts, their tests or their deployment scripts. Not for off-chain node or wallet backends (blockchain-developer) or dApp front ends (web3-integration); for audit-style reviews see secure-workflow-guide and token-integration-analyzer.
---

# Solidity Developer

## Overview

A deployed contract cannot be patched quietly, and its users are adversaries with unlimited retries. Write
for that: simple control flow, well-tested libraries, invariants that a fuzzer tries to break, and a
deployment that hands control to a multisig in the same script.

## Setup

- Foundry (`forge`, `cast`, `anvil`). Pin the compiler exactly in deployable contracts
  (`pragma solidity 0.8.x;`, not `^`) and set the optimizer runs in `foundry.toml`.
- Configure fuzzing and invariants in `foundry.toml` (`fuzz.runs`, `invariant.runs`, `invariant.depth`)
  and keep `fs_permissions` minimal.
- OpenZeppelin Contracts installed at a tagged release and recorded in the repository
  (`forge install OpenZeppelin/openzeppelin-contracts@vX.Y.Z`).

## Patterns

- **Checks-effects-interactions.** Validate (custom errors), update state, then make external calls.
  Add `nonReentrant` to functions whose external calls can re-enter shared state, and watch for read-only
  reentrancy through view functions other protocols call during your callbacks.
- **External calls.** Use `SafeERC20`; check the result of every low-level `call`; prefer pull payments; do
  not rely on `transfer` or `send` gas stipends. Measure the balance delta for fee-on-transfer or rebasing
  tokens instead of trusting the amount argument.
- **Access control.** `Ownable2Step` or `AccessControl`; review who can call every state-changing external
  function; route admin rights through a multisig and a timelock.
- **Upgradeability.** Avoid it unless needed. If used: OpenZeppelin UUPS or transparent proxies, storage
  appended only (namespaced storage per ERC-7201, or gaps), `_disableInitializers()` in the implementation
  constructor, `_authorizeUpgrade` restricted, and the storage layout diffed between versions.
- **Arithmetic.** Checked by default since 0.8. `unchecked` only with a comment proving the bounds. Round
  in the protocol's favour (`mulDiv` with an explicit rounding direction) and handle token decimals (6 vs
  18).
- **Oracles.** Check staleness (`updatedAt`), answer bounds and, on rollups, the sequencer uptime feed. Never
  price from an AMM spot price; use an oracle or a TWAP.
- **Signatures.** EIP-712 with a domain separator that includes the chain id and the verifying contract;
  nonces and deadlines; OpenZeppelin `ECDSA` (it rejects malleable signatures and the zero address).
- **Ordering and MEV.** Slippage limits and deadlines on value-moving calls; commit-reveal where secrecy
  before execution matters.
- **Events** for every state change, and custom errors instead of revert strings.

## Testing

- Unit tests per function, including every revert path (`vm.expectRevert(Error.selector)`).
- Fuzz tests (`testFuzz_*`, with `bound()` instead of `vm.assume` where possible).
- Invariant tests with handler contracts: conservation of supply, solvency, access control, monotonic
  counters, share/asset round trips that never return more than was put in.
- Fork tests for integrations, pinned to a block number.

## Deployment

- `forge script` without `--broadcast` first; verify the source; record the deployed addresses.
- Transfer ownership to the multisig or timelock in the same script.
- Never put deployer keys in committed files or plain environment files; use an encrypted keystore
  (`--account`) or a hardware wallet (`--ledger`).

## Verify Before Done

```bash
forge fmt --check
forge build --sizes              # every deployable contract below the 24,576-byte limit
forge test -vvv
forge test --match-test 'invariant_' -vvv
forge coverage --report summary
slither . --exclude-dependencies # triage every finding: fix it or document why it is a false positive
# Upgrades: existing storage slots are unchanged
forge inspect <Contract> storageLayout > layout.new.json && diff layout.old.json layout.new.json
```
