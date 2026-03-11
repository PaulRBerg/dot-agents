# EVM OnChain Integration

Onchain integration means creating Merkle airdrop campaigns directly from a Solidity smart contract by calling factory functions. Each campaign type has a dedicated factory contract: `SablierFactoryMerkleInstant`, `SablierFactoryMerkleLL`, and `SablierFactoryMerkleLT`. The factory deploys a campaign contract via CREATE2, returning a deterministic address.

MerkleLL percentage values are passed as `uint256`, and MerkleLT tranche percentages are passed as `uint64`. In both cases, `1e18 = 100%`.

Each factory also exposes a `compute*` function to predict the campaign address before deployment.

## References

- **Sablier documentation (LLM-optimized):** <https://docs.sablier.com/llms.txt>
- **Deployed factory addresses:** <https://docs.sablier.com/guides/airdrops/deployments.md>
- **Solidity examples:** <https://github.com/sablier-labs/evm-examples>
- **Merkle API:** <https://github.com/sablier-labs/merkle-api>
