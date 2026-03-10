# EVM Onchain Integration

Onchain integration means creating Lockup streams directly from a Solidity smart contract by calling functions on the deployed `SablierLockup` contract. The caller's contract must first approve the ERC-20 token transfer to the Lockup contract, then invoke the appropriate create function.

Three stream shapes are available:

- **Linear** (LL) for continuous vesting with optional cliff
- **Dynamic** (LD) for custom unlock curves via segments
- **Tranched** (LT) for discrete unlock events at fixed dates

Each create function comes in two variants:

- `WithTimestamps` (caller specifies exact start/end times)
- `WithDurations` (stream starts at `block.timestamp` and durations are relative)

Multiple streams can be created in a single transaction using the built-in `batch()` function.

## References

- **Sablier documentation (LLM-optimized):** <https://docs.sablier.com/llms.txt>
- **Deployed contract addresses:** <https://docs.sablier.com/guides/lockup/deployments.md>
- **Solidity examples:** <https://github.com/sablier-labs/evm-examples/tree/main/lockup>
