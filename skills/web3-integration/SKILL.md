---
name: web3-integration
description: Builds and reviews app-side wallet integrations - wallet connection, EIP-712 typed-data signing, chain IDs, checksummed addresses, RPC failure handling, and server-side verification of every signature. Use when connecting wallets in a web or mobile front end, asking users to sign messages or send transactions, or verifying wallet signatures on a backend (sign-in, orders, permits). Not for contract code (solidity-developer) or custodial deposit and withdrawal backends (blockchain-developer).
---

# Web3 Integration

## Overview

The wallet is the user's; the chain is shared; the server trusts neither the client nor its claims. Bind
every request to a chain, make every signature human-readable and single-use, and verify it on the server.

## Wallet Connection

- Discover injected wallets with EIP-6963; use WalletConnect for mobile wallets. Pin the libraries (for
  example viem and wagmi, or ethers v6).
- Handle `accountsChanged`, `chainChanged` and `disconnect` by resetting app state.
- A connected account is not an authenticated user. Authenticate with a signed message (below).

## Chain IDs

- Every request and signature names its chain id explicitly. Check `eth_chainId` before sending, and use
  `wallet_switchEthereumChain` / `wallet_addEthereumChain` to move the user.
- Chain configuration per environment comes from one place. On an unexpected chain, stop.

## Addresses

- Normalise and validate with an EIP-55 checksum function (`getAddress`). Reject mixed-case input with a
  bad checksum.
- Compare normalised forms. Show resolved names with the address they resolve to.
- Warn about address poisoning: lookalike addresses in transaction history that share a prefix and suffix.

## Signing

- Use EIP-712 typed data (`eth_signTypedData_v4`) with a domain of name, version, chain id and verifying
  contract, and a message that includes a nonce and an expiry.
- Never use `eth_sign` (it signs an opaque hash). Avoid `personal_sign` for anything structured.
- Sign-in uses EIP-4361 (Sign-In with Ethereum): domain, URI, nonce, issued-at and expiration.

## Server-Side Verification

- Verify every signature on the server (for example `verifyTypedData` in viem or ethers). The recovered
  signer must equal the expected address.
- Check that the domain's chain id and verifying contract match the server's configuration.
- Nonces are single-use and stored server-side; expired messages are rejected.
- Smart-contract wallets: verify with ERC-1271 `isValidSignature`, and ERC-6492 for wallets not yet
  deployed. Use library support rather than hand-rolled calls.
- Never trust a client-side "verified" flag.

## Transactions

- Simulate before sending (`eth_call` or `simulateContract`) and show the user what they are approving.
- Estimate gas with a margin; treat user rejection (code 4001) as its own case, not an error.
- Track by transaction hash; wait for a number of confirmations that fits the value; handle replaced and
  dropped transactions (speed-up or cancel).
- Ask for exact token approvals by default; show the spender; support revoking. Permits carry deadlines.

## RPC Failure Handling

- Several RPC endpoints with fallback, timeouts, and retries with backoff for idempotent reads only.
- Handle rate limits (429) and inconsistent nodes (a block number that goes backwards). Show a degraded
  state rather than wrong data.
- Keep paid RPC keys out of the client bundle: proxy through the backend or use keys restricted by origin.

## Verify Before Done

```bash
npx tsc --noEmit
npm test     # include: wrong chain id rejected, expired or replayed signature rejected, ERC-1271 path
# Unsafe signing methods: each hit needs a reason, prefer EIP-712
grep -rnE 'eth_sign\b|personal_sign' src/
# Every client signing call has a server-side verification
grep -rnE 'signTypedData|verifyTypedData|recoverTypedDataAddress|isValidSignature' src/ server/
# Paid RPC keys must not ship in the client bundle (file names only)
grep -rlE '(alchemy|infura|quicknode)[^"'"'"' ]*/[A-Za-z0-9_-]{20,}' src/
```
