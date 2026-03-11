---
name: sablier-create-airdrop
disable-model-invocation: false
user-invocable: true
argument-hint: <chain_name> <token_address> <airdrop_details_with_csv>
description: This skill should be used when the user asks to create "token airdrops", "Merkle airdrops", "community airdrops", "Sablier airdrop", "vested airdrops", "claimable airdrops", "token claim campaigns", "ERC-20 airdrops", "BEP-20 airdrops", or "BEP20 airdrops" with Sablier Airdrops, wants to distribute tokens to many recipients on Ethereum or EVM-compatible chains using Merkle proofs, or needs an agent to run onchain airdrop-campaign-creation transactions on their behalf.
---

# Sablier Merkle Airdrop Creation

## Overview

Create token airdrops using the Sablier Merkle system. A campaign creator deploys a campaign contract via a factory, storing a Merkle root. Anyone can then fund the campaign by transferring tokens to it. Recipients claim individually using Merkle proofs, paying their own gas.

Funding does not have to happen in the same session as deployment. For CLI execution, deploy first, then ask whether the user wants to fund immediately or later. If they defer funding, finish successfully after deployment, share the campaign URL plus key metadata, and warn that claims will fail until the campaign holds at least the aggregate amount.

This skill is a coordinator for airdrop campaign creation and execution routing.

## Arguments

| Argument                   | Description                                                                                                                                    |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `chain_name`               | EVM chain where to create the airdrop campaign                                                                                                 |
| `token_address`            | ERC-20 token contract address to distribute. Token symbols cannot be resolved to addresses — the user must provide the exact contract address. |
| `airdrop_details_with_csv` | Campaign type, recipient list in CSV, vesting schedule (if applicable)                                                                         |

## Campaign Types

| Type     | Code          | Distribution Method                                                |
| -------- | ------------- | ------------------------------------------------------------------ |
| Instant  | MerkleInstant | Direct token transfer on claim                                     |
| Linear   | MerkleLL      | Creates a Lockup Linear stream per claim (vesting over time)       |
| Tranched | MerkleLT      | Creates a Lockup Tranched stream per claim (discrete unlock steps) |

### Choosing a Campaign Type

```
Q1: Do recipients need vesting after claiming?
├─ No → ✅ Instant
└─ Yes → Q2

Q2: Do tokens unlock continuously or in discrete steps?
├─ Continuously (with optional cliff) → ✅ MerkleLL
└─ At discrete intervals (monthly, quarterly, etc.) → ✅ MerkleLT
```

## Workflow

### 1. Confirm product fit before implementation details

1. Verify the user needs Merkle-based token distribution to many recipients.
2. If the user needs fixed-schedule vesting, route to `sablier-create-vesting`. If this skill is unavailable, recommend installing it with:

```bash
npx skills add sablier-labs/sablier-skills --skill sablier-create-vesting
```

### 2. Check requested features

Stop and call out unsupported requests before selecting an execution path.

Treat the following as unsupported by this skill and by Sablier Airdrops:

- Launching tokens for users. Require the user to explicitly provide an existing token address as input.
- Resolving token symbols (e.g. "USDC") to contract addresses. If the user provides a symbol instead of an address, ask them to provide the exact ERC-20 contract address.
- Distributing native tokens (ETH, POL, etc.). Only ERC-20 tokens can be airdropped. If the user wants to airdrop a native token, inform them they must wrap it first (e.g. WETH) and provide the wrapped token contract address.

### 3. Clarify airdrop details

If any of the following are missing or ambiguous from the user's input, use the `AskUserQuestion` tool to ask the user to clarify before proceeding:

- Chain name (e.g. "Ethereum", "Base", etc.)
- Campaign type (Instant, LL, LT — use the [decision tree](#choosing-a-campaign-type) if unclear)
- Recipient list (file path to a CSV, or pasted inline for small lists)
- Token address
- Campaign start time (when claims open)
- Expiration (when unclaimed tokens can be recovered; `0` for never)
- Vesting schedule (for LL: duration and cliff; for LT: tranche intervals)

If the missing detail is the token address, tell the user they can look it up on a blockchain explorer such as Etherscan.

Do not guess or silently apply defaults for the campaign type, recipient list, or vesting schedule. Only proceed once all required inputs are confirmed.

### 4. Infer intent before selecting references

1. **Execution intent:** user wants the agent to create an airdrop campaign on their behalf (run CLI transactions).
2. **Onchain integration intent:** user wants developer integration guidance.

### 5. Validate chain support before routing

1. Check whether the user's desired chain is listed on [Supported Chains](https://docs.sablier.com/concepts/chains).
2. If the chain is not supported, inform the user and stop execution of this skill.

### 6. Route in two steps

1. Classify the request as one of:
   - Airdrop campaign creation on the user's behalf
   - Onchain integration guidance
   - Any other integration type (frontend, backend, indexer, etc.)
2. If the request is any other integration type, inform the user that this skill does not support non-onchain integrations and stop.
3. Otherwise, follow the route below.

| Intent                                         | EVM                                             | Solana                                                                                                       |
| ---------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Airdrop campaign creation on the user's behalf | Use [evm-cli.md](references/evm-cli.md)         | Not yet supported. Direct the user to [solana.sablier.com](https://solana.sablier.com).                      |
| Onchain integration guidance                   | Use [evm-onchain.md](references/evm-onchain.md) | Not yet supported. Direct the user to [docs.sablier.com](https://docs.sablier.com/solana/sablier-on-solana). |

### 7. Handle funding after deployment

For the EVM CLI route:

1. Deploy the campaign first.
2. After the deployment receipt is confirmed, use the `AskUserQuestion` tool to ask whether the user wants to fund now or later.
3. If the user chooses later, treat the deployment as a successful completion, share the campaign URL and core campaign metadata, and warn that claims will fail until the campaign is funded.
4. If the user chooses now, continue with the token funding transaction.

## Resources

- [Sablier Documentation](https://docs.sablier.com/llms.txt)
- [EVM Airdrop Deployments](https://docs.sablier.com/guides/airdrops/deployments.md)
- [Sablier Airdrops Monorepo](https://github.com/sablier-labs/airdrops)
- [Merkle API (tree generation + eligibility)](https://github.com/sablier-labs/merkle-api)
- [EVM Integration Examples](https://github.com/sablier-labs/evm-examples)
