# EVM OnChain Integration

Onchain integration means creating Flow payment streams directly from a Solidity smart contract by calling functions on the deployed `SablierFlow` contract. The caller's contract must first approve the ERC-20 token transfer to the Flow contract (for `createAndDeposit`), then invoke the appropriate create function.

Two creation functions are available: `create` (zero-balance stream) and `createAndDeposit` (stream with immediate funding).

Each create function accepts a `ratePerSecond` parameter in `UD21x18` format — a fixed-point type from the PRBMath library, encoded as `uint128` with 18 decimals, where `1e18` = 1 whole token per second. The stream has no predefined end date — debt accrues continuously until paused or voided.

Multiple streams can be created in a single transaction using the built-in `batch()` function.

## What Happens on Create

1. A stream struct is written with the provided parameters.
2. An ERC-721 NFT is minted to `recipient`.
3. `streamId` is returned (auto-incrementing, starts at 1).
4. If `createAndDeposit`: tokens are transferred from `msg.sender` to the Flow contract.
5. The stream starts accruing debt from `startTime` (or `block.timestamp` if `startTime` is 0). If `startTime` is in the past, debt accrues retroactively from that past timestamp.

## References

- **Sablier documentation (LLM-optimized):** <https://docs.sablier.com/llms.txt>
- **Deployed contract addresses:** <https://docs.sablier.com/guides/flow/deployments.md>
- **Solidity examples:** <https://github.com/sablier-labs/evm-examples/tree/main/flow>
