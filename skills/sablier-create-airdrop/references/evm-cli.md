# EVM CLI Campaign Execution

## Overview

This guide is runbook-first: plan the campaign, generate the Merkle tree, run preflight checks, preview the deployment, require explicit confirmation, deploy the campaign, then use `AskUserQuestion` to decide whether to fund immediately or later.

**Prerequisites:** This runbook requires `cast`, `jq`, and `node` (checked in [CLI Prerequisites](#cli-prerequisites-check)). Merkle tree generation uses the local helper in `skills/sablier-create-airdrop/scripts` plus a single Pinata JWT for IPFS publication (see [merkle-tree.md](merkle-tree.md)).

## Execution Sequence

Use this sequence for every campaign creation:

1. Complete [Intake & Planning Inputs](#intake--planning-inputs): campaign type, chain, inputs, and Merkle tree generation.
2. Run the deployment-focused [Preflight Checks](#preflight-checks).
3. Build and show a human-readable deployment preview (no broadcast).
4. Require explicit user confirmation for deployment.
5. Deploy the campaign via the factory with `cast send`, then wait/poll up to 5 minutes for the confirmed receipt.
6. Use `AskUserQuestion` to ask whether the user wants to fund the campaign now or later.
7. If the user chooses `Fund now`, run the funding checks, preview the funding transfer, require explicit confirmation, then transfer tokens to the campaign and wait/poll up to 5 minutes for the confirmed receipt.
8. Exit successfully by sharing the campaign page URL plus campaign metadata. If funding is deferred, clearly warn that claims will fail until the campaign is funded.

## Mandatory Guardrails

### CLI Prerequisites Check

Before running any commands, verify the required tools are installed:

```bash
for cmd in cast jq node; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not found."
    exit 1
  fi
done

if ! cast send --help 2>&1 | grep -q -- '--browser'; then
  echo "Your cast version does not support --browser."
  echo "Upgrade Foundry: https://getfoundry.sh/"
  exit 1
fi
```

- `cast` — required for all onchain interactions. Install Foundry at [https://getfoundry.sh/](https://getfoundry.sh/).
- `jq` — required for parsing JSON responses from the local generator and transaction receipts.
- `node` — required for the local Merkle generator.

### Signing Method (Mandatory)

For any signing command (`cast send`), use this hierarchy:

1. **`--browser` (preferred)** - delegates signing to the user's browser wallet extension (MetaMask, Rabby, etc.). A local server starts on port 9545 and opens a browser tab where the user approves the transaction. Private keys never touch the terminal or chat. Inform the user: *"A browser tab will open - approve the transaction in your wallet extension (e.g. MetaMask)."*
2. **`--private-key` (fallback)** - only if `--browser` fails at runtime (e.g. no browser available, extension error). In that case, ask the user to provide a private key or set the `ETH_PRIVATE_KEY` environment variable. Never proactively ask the user to paste a private key in the chat.

Do not continue without a signing method.

### Confirmation Rule (Mandatory)

Always use this sequence for state-changing transactions:

1. Build a human-readable preview of all transaction parameters.
2. Show the transaction details to the user.
3. Ask for explicit confirmation.
4. Only after confirmation, run `cast send`.

Never broadcast before explicit user confirmation.

### Receipt Wait Timeout (Mandatory)

For every broadcasted transaction (factory deploy and optional token funding), wait/poll for a confirmed receipt for up to **5 minutes** before treating the transaction as failed or unconfirmed.

Use this polling pattern for receipt verification:

```bash
RECEIPT=""
START_TIME=$(date +%s)

while true; do
  RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null) && break

  if [ "$(($(date +%s) - START_TIME))" -ge 300 ]; then
    echo "Timed out waiting for a confirmed receipt after 5 minutes: $TX_HASH"
    exit 1
  fi

  sleep 5
done

# Check transaction status (1 = success, 0 = reverted)
TX_STATUS=$(echo "$RECEIPT" | jq -r '.status')
if [ "$TX_STATUS" != "0x1" ]; then
  echo "Transaction reverted: $TX_HASH"
  exit 1
fi
```

After polling:

- If the receipt is still unavailable after 5 minutes, stop, tell the user the transaction may still be pending, and share the transaction hash for manual follow-up.
- If `status` is not `0x1`, the transaction reverted — stop, show the transaction hash, and ask the user to investigate on a block explorer.

## Intake & Planning Inputs

Complete these steps in order before building calldata.

### 1) Choose Campaign Type

Use the [decision tree in SKILL.md](../SKILL.md#choosing-a-campaign-type) to select the campaign type:

| Signal                                                              | Campaign Type |
| ------------------------------------------------------------------- | ------------- |
| "airdrop tokens immediately", "instant distribution"                | **Instant**   |
| "airdrop with vesting", "linear vesting airdrop", "cliff + vesting" | **MerkleLL**  |
| "airdrop with monthly unlocks", "quarterly vesting", "step unlocks" | **MerkleLT**  |

- If ambiguous, ask the user to clarify using the decision tree.

### 2) Resolve Chain and Factory

Look up the factory contract address for the chosen campaign type and target chain at the [Airdrop Deployments page](https://docs.sablier.com/guides/airdrops/deployments.md).

Each campaign type has a dedicated factory:

| Campaign Type | Factory Contract              |
| ------------- | ----------------------------- |
| Instant       | `SablierFactoryMerkleInstant` |
| Linear (LL)   | `SablierFactoryMerkleLL`      |
| Tranched (LT) | `SablierFactoryMerkleLT`      |

Also look up:

- **SablierLockup address** — required by MerkleLL and MerkleLT campaigns (look up at [Lockup Deployments](https://docs.sablier.com/guides/lockup/deployments.md))

If the requested chain is not listed, ask the user to provide both the RPC URL and the factory address.

### 3) Collect Required Inputs

Collect these from the user before generating the Merkle tree or building any transaction:

- `chain` (ID and name — from step 2; store the numeric chain ID as `CHAIN_ID` for the final campaign URL)
- `token` address
- sender wallet address (resolved via `cast wallet address --browser` or provided by the user)
- signing method (`--browser` preferred, `--private-key` fallback)
- factory contract address (from step 2)
- `campaignName`
- `campaignStartTime` (Unix timestamp when claims open; `0` for immediate)
- `expiration` (Unix timestamp; `0` for never)
- `initialAdmin` (address authorized to clawback; defaults to sender if not specified)

**Type-specific inputs:**

| Campaign Type | Additional Inputs                                                                                                                                                                       |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Instant       | None                                                                                                                                                                                    |
| MerkleLL      | `lockup` address, `cancelable`, `transferable`, `shape`, `totalDuration`, `cliffDuration`, `cliffUnlockPercentage` (`uint256`), `startUnlockPercentage` (`uint256`), `vestingStartTime` |
| MerkleLT      | `lockup` address, `cancelable`, `transferable`, `shape`, `tranchesWithPercentages` array (each: `unlockPercentage` as `uint64`, `duration`), `vestingStartTime`                         |

### 4) Collect Recipient Data and Generate Merkle Tree

Follow the full process in [merkle-tree.md](merkle-tree.md): collect the CSV, validate it, run the local generator, and parse the response. This step requires `TOKEN` and `RPC_URL` from steps 2–3.

This step produces four values used throughout the rest of the runbook:

- `MERKLE_ROOT` — for the factory's `merkleRoot` parameter
- `IPFS_CID` — for the factory's `ipfsCID` parameter
- `AGGREGATE_AMOUNT` — total tokens in base units, for `aggregateAmount` and funding
- `RECIPIENT_COUNT` — for `recipientCount`

Do not proceed to preflight checks without all four values.

## Important Notes

**`aggregateAmount` is not enforced onchain.** The Merkle tree leaf amounts are what enforce correctness. If the campaign is funded with less than the true aggregate, later claims will fail. Always fund the campaign with at least the full aggregate amount.

**Token amounts must be in the token's smallest unit.** For example, for an 18-decimal token, 1.0 token = `1000000000000000000`. For a 6-decimal token like USDC, 1.0 USDC = `1000000`.

**`initialAdmin` can differ from the campaign creator.** The `initialAdmin` is the address authorized to clawback unclaimed tokens — it does not have to be the same address that deploys the campaign. If the user does not specify an admin, default to the sender address.

**Creation and funding are decoupled** — the campaign contract can exist before tokens are deposited. However, claims will fail if the campaign has insufficient token balance. If the user chooses to defer funding, complete the task after deployment and tell them to fund the campaign before `campaignStartTime`.

## Campaign Lifecycle

```
1. CREATE    → Deploy campaign via factory
2. FUND      → Transfer tokens to the campaign contract
3. CLAIMS    → Recipients claim with Merkle proofs (after campaignStartTime)
4. CLAWBACK  → (optional) Admin recovers unclaimed tokens after expiration
```

**Clawback** is allowed up until 7 days have passed since the first claim, and after the campaign has expired. It is blocked in between.

## Preflight Checks

Run the deployment-side checks before previewing or broadcasting the factory transaction. Run the funding-side checks only if the user chooses `Fund now` after deployment.

### Native Gas Balance for the Deployment Transaction

Before broadcasting the factory call, estimate the gas cost and verify the sender can cover it:

```bash
# Estimate gas for the factory call
GAS_ESTIMATE=$(cast estimate "$FACTORY" "$FUNCTION_SIG" $FUNCTION_ARGS \
  --rpc-url "$RPC_URL" \
  --from "$OWNER")

# Get current gas price (in wei)
GAS_PRICE=$(cast gas-price --rpc-url "$RPC_URL")

# Total native token needed ≈ gas estimate × gas price
TOTAL_NEEDED=$(echo "$GAS_ESTIMATE * $GAS_PRICE" | bc)
```

Compare `TOTAL_NEEDED` against the sender's native balance. If balance is insufficient, stop and tell the user to fund their wallet first. Recommend buying via [Transak](https://transak.com/buy).

### Funding Checks

Run these only if the user chooses `Fund now` after the deployment receipt is confirmed.

#### Token Balance

Check `balanceOf(owner)` is at least the `aggregateAmount`. If balance is insufficient, stop execution and inform the user they need more tokens (for example, purchase via Uniswap) before continuing with funding.

#### Native Gas Balance for the Funding Transaction

Before broadcasting the ERC-20 transfer, estimate the gas cost and verify the sender can cover it:

```bash
GAS_ESTIMATE=$(cast estimate "$TOKEN" "transfer(address,uint256)" "$CAMPAIGN" "$AGGREGATE_AMOUNT" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER")

GAS_PRICE=$(cast gas-price --rpc-url "$RPC_URL")
TOTAL_NEEDED=$(echo "$GAS_ESTIMATE * $GAS_PRICE" | bc)
```

Compare `TOTAL_NEEDED` against the sender's native balance. If balance is insufficient, stop and tell the user to fund their wallet first. Recommend buying via [Transak](https://transak.com/buy).

### Read-Only Validation Commands

```bash
# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)

# Check native gas token balance (ETH/POL/BNB/etc.)
cast balance "$OWNER" --rpc-url "$RPC_URL"

# Check token balance
cast call "$TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC_URL"
```

## Execution Runbook

### 1) Resolve RPC URL, signing method, and sender address

```bash
RPC_URL="<resolved-or-user-provided-rpc>"

# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)
```

### 2) Run deployment preflight checks

Run the deployment-side checks from [Preflight Checks](#preflight-checks).

### 3) Preview the Deployment Transaction (No Broadcast)

Present a human-readable summary of the deployment transaction:

**Transaction — Deploy Campaign:**

- **Contract:** `$FACTORY`
- **Function:** `createMerkle*` (type-specific)
- **Campaign name, type, token, start time, expiration**
- **Merkle root, IPFS CID, recipient count, aggregate amount**
- **Vesting parameters** (for LL/LT)

Also tell the user that funding is a separate post-deployment step and they will be asked again after deployment whether they want to fund now or later.

### 4) Require Explicit Confirmation for Deployment

Use a clear confirmation flow:

⚠️ Final confirmation required

```text
+------------------------------+
| Confirm broadcast?           |
| Reply exactly: YES           |
+------------------------------+
```

If the user does not explicitly confirm with `YES`, stop.

### 5) Deploy Campaign

First, predict the campaign address using the factory's `compute*` function:

```bash
CAMPAIGN=$(cast call "$FACTORY" "$COMPUTE_SIG" $COMPUTE_ARGS --rpc-url "$RPC_URL")
```

Then deploy. A browser tab will open for the user to approve the transaction in their wallet extension.

```bash
TX_HASH=$(cast send "$FACTORY" "$FUNCTION_SIG" $FUNCTION_ARGS \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
```

Wait/poll up to 5 minutes for the confirmed receipt per [Receipt Wait Timeout (Mandatory)](#receipt-wait-timeout-mandatory) before proceeding.

If `--browser` fails at runtime, ask the user to provide a private key and retry with `--private-key`. The same fallback applies to the funding transaction below.

### 6) Ask Whether to Fund Now or Later

After the deployment receipt is confirmed, use the `AskUserQuestion` tool to ask whether the user wants to fund the campaign now or later.

Use a question equivalent to:

- **Question:** `The campaign has been deployed. Do you want to fund it now or later?`
- **Choices:** `Fund now`, `Fund later`

If the user chooses `Fund later`, stop here successfully and share:

- campaign URL: `https://app.sablier.com/airdrops/campaign/${CAMPAIGN}-${CHAIN_ID}`
- chain name and chain ID
- campaign type
- token address
- aggregate amount
- recipient count
- claiming start time (`campaignStartTime`, or `immediate` when `0`)
- expiration (`expiration`, or `never` when `0`)
- funding status: `Awaiting funding`

Also warn explicitly that claims will fail until the campaign contract is funded with at least the aggregate amount.

If the user chooses `Fund now`, continue to the next step.

### 7) Fund the Campaign

Before broadcasting, rerun the [Funding Checks](#funding-checks). Then show a short human-readable preview of the funding transfer. The amount line in the preview must show the human-readable token amount for `AGGREGATE_AMOUNT`, not only the raw base-unit integer:

- **Contract:** `$TOKEN`
- **Function:** `transfer(address,uint256)`
- **To:** `$CAMPAIGN`
- **Amount:** human-readable token amount for `AGGREGATE_AMOUNT`

Then require explicit confirmation for the funding transfer using the same boxed `Reply exactly: YES` prompt before broadcasting. If the user does not explicitly confirm with `YES`, stop.

Then transfer the aggregate token amount to the deployed campaign address:

```bash
TX_HASH=$(cast send "$TOKEN" "transfer(address,uint256)" "$CAMPAIGN" "$AGGREGATE_AMOUNT" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
```

Wait/poll up to 5 minutes for the confirmed receipt per [Receipt Wait Timeout (Mandatory)](#receipt-wait-timeout-mandatory) before proceeding.

### 8) Direct User to the Campaign

After the successful exit path, present the direct link to the campaign:

```
https://app.sablier.com/airdrops/campaign/${CAMPAIGN}-${CHAIN_ID}
```

Include this metadata in the final response:

- funding status: `Funded` or `Awaiting funding`
- campaign type
- chain name and chain ID
- token address
- aggregate amount
- recipient count
- claiming start time (`campaignStartTime`, or `immediate` when `0`)
- expiration (`expiration`, or `never` when `0`)
- `initialAdmin`

If funding is still pending, add a short warning that recipients cannot claim until the campaign receives enough tokens.

## Entrypoint Catalog

Maps each campaign type to the correct factory function and calldata encoding. Refer to the per-factory ABI definitions for exact tuple encoding:

- [factory-merkle-instant-v2.0-abi.json](../assets/factory-merkle-instant-v2.0-abi.json)
- [factory-merkle-LL-v2.0-abi.json](../assets/factory-merkle-LL-v2.0-abi.json)
- [factory-merkle-LT-v2.0-abi.json](../assets/factory-merkle-LT-v2.0-abi.json)

### `createMerkleInstant`

Deploys a campaign where tokens transfer immediately to recipients on claim.

```
createMerkleInstant(
  (string campaignName, uint40 campaignStartTime, uint40 expiration, address initialAdmin, string ipfsCID, bytes32 merkleRoot, address token),
  uint256 aggregateAmount,
  uint256 recipientCount
)
```

**Arguments:**

1. **params** tuple — campaign configuration
2. **aggregateAmount** — total tokens to distribute (informational, not enforced onchain)
3. **recipientCount** — number of recipients (informational)

### `createMerkleLL`

Deploys a campaign where each claim creates a Lockup Linear stream with the specified vesting schedule.

```
createMerkleLL(
  (string campaignName, uint40 campaignStartTime, bool cancelable, uint40 cliffDuration, uint256 cliffUnlockPercentage, uint40 expiration, address initialAdmin, string ipfsCID, address lockup, bytes32 merkleRoot, string shape, uint256 startUnlockPercentage, address token, uint40 totalDuration, bool transferable, uint40 vestingStartTime),
  uint256 aggregateAmount,
  uint256 recipientCount
)
```

**Key parameters:**

- **cliffDuration** — seconds; `0` for no cliff
- **cliffUnlockPercentage** — `uint256`; fraction unlocked after cliff
- **startUnlockPercentage** — `uint256`; fraction unlocked immediately at stream start
- **lockup** — `SablierLockup` contract address (look up at [Lockup Deployments](https://docs.sablier.com/guides/lockup/deployments.md))
- **vestingStartTime** — `0` means vesting starts at each individual claim's `block.timestamp`; non-zero means all recipients vest from the same absolute timestamp

**Validation rules:**

- `totalDuration > 0`
- If `cliffDuration > 0`: `cliffDuration < totalDuration`
- If `cliffDuration == 0`: `cliffUnlockPercentage` must be `0`
- `startUnlockPercentage + cliffUnlockPercentage <= 1e18`

### `createMerkleLT`

Deploys a campaign where each claim creates a Lockup Tranched stream with percentage-based unlock steps.

```
createMerkleLT(
  (string campaignName, uint40 campaignStartTime, bool cancelable, uint40 expiration, address initialAdmin, string ipfsCID, address lockup, bytes32 merkleRoot, string shape, address token, (uint64 unlockPercentage, uint40 duration)[] tranchesWithPercentages, bool transferable, uint40 vestingStartTime),
  uint256 aggregateAmount,
  uint256 recipientCount
)
```

**Key parameters:**

- **tranchesWithPercentages** — array of `(unlockPercentage, duration)` tuples. `unlockPercentage` is a `uint64`. `duration` is seconds.
- **lockup** — `SablierLockup` contract address
- **vestingStartTime** — same behavior as MerkleLL

**Note on percentage encoding:** MerkleLT uses `uint64`, while MerkleLL uses `uint256`. In both cases, `1e18 = 100%`.

**Validation rules:**

- At least one tranche
- All tranche percentages must sum to exactly 100% (`1e18`)
- All tranche durations must be > 0

Use the factory's helper to verify percentages sum to 100%:

```bash
cast call "$FACTORY" "isPercentagesSum100((uint64,uint40)[])" "$TRANCHES" --rpc-url "$RPC_URL"
```

### Deterministic Addresses (`compute*`)

Each factory exposes a `compute*` function to predict the campaign address before deployment. Use this to know the campaign address for funding without parsing event logs.

**`computeMerkleInstant`:**

```
computeMerkleInstant(
  address campaignCreator,
  (string campaignName, uint40 campaignStartTime, uint40 expiration, address initialAdmin, string ipfsCID, bytes32 merkleRoot, address token)
) → address
```

**`computeMerkleLL`:**

```
computeMerkleLL(
  address campaignCreator,
  (string campaignName, uint40 campaignStartTime, bool cancelable, uint40 cliffDuration, uint256 cliffUnlockPercentage, uint40 expiration, address initialAdmin, string ipfsCID, address lockup, bytes32 merkleRoot, string shape, uint256 startUnlockPercentage, address token, uint40 totalDuration, bool transferable, uint40 vestingStartTime)
) → address
```

**`computeMerkleLT`:**

```
computeMerkleLT(
  address campaignCreator,
  (string campaignName, uint40 campaignStartTime, bool cancelable, uint40 expiration, address initialAdmin, string ipfsCID, address lockup, bytes32 merkleRoot, string shape, address token, (uint64 unlockPercentage, uint40 duration)[] tranchesWithPercentages, bool transferable, uint40 vestingStartTime)
) → address
```

The `campaignCreator` is the `msg.sender` of the `createMerkle*` call — use the sender's wallet address. The params tuple is identical to the one passed to the corresponding `createMerkle*` function.

## Worked Examples

These examples intentionally use raw integers and ABI-ready arguments because they are for command construction. Do not copy these machine values into the default transaction preview; show human-readable token amounts first, and provide exact machine values separately only if the user explicitly asks.

### Instant Campaign: `createMerkleInstant`

Deploy an instant airdrop of 10,000 USDC (6 decimals) to 50 recipients on Ethereum mainnet:

```bash
FACTORY="<factory-merkle-instant-address>"   # From Airdrop Deployments page
RPC_URL="<resolved-or-user-provided-rpc>"
TOKEN="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
OWNER=$(cast wallet address --browser)

# Install the local generator once
npm install --prefix "skills/sablier-create-airdrop/scripts"

# Generate the Merkle tree locally (see merkle-tree.md for full setup)
CSV_FILE="/path/to/recipients.csv"   # User-provided file path
DECIMALS=$(cast call "$TOKEN" "decimals()(uint8)" --rpc-url "$RPC_URL")
GENERATOR_OUTPUT=$(PINATA_JWT="$PINATA_JWT" \
  node "skills/sablier-create-airdrop/scripts/generate-merkle-campaign.mjs" \
    --csv-file "$CSV_FILE" \
    --decimals "$DECIMALS")
MERKLE_ROOT=$(echo "$GENERATOR_OUTPUT" | jq -r '.root')
IPFS_CID=$(echo "$GENERATOR_OUTPUT" | jq -r '.cid')
AGGREGATE_AMOUNT=$(echo "$GENERATOR_OUTPUT" | jq -r '.total')
RECIPIENT_COUNT=$(echo "$GENERATOR_OUTPUT" | jq -r '.recipients')

# Campaign starts in 24 hours, no expiration
START_TIME=$(echo "$(date +%s) + 86400" | bc)

# Predict campaign address via compute function
COMPUTE_SIG="computeMerkleInstant(address,(string,uint40,uint40,address,string,bytes32,address))"
CAMPAIGN=$(cast call "$FACTORY" "$COMPUTE_SIG" \
  "$OWNER" \
  "(\"My Airdrop\",$START_TIME,0,$OWNER,\"$IPFS_CID\",$MERKLE_ROOT,$TOKEN)" \
  --rpc-url "$RPC_URL")

# 1. Deploy campaign
FUNCTION_SIG="createMerkleInstant((string,uint40,uint40,address,string,bytes32,address),uint256,uint256)"
TX_HASH=$(cast send "$FACTORY" "$FUNCTION_SIG" \
  "(\"My Airdrop\",$START_TIME,0,$OWNER,\"$IPFS_CID\",$MERKLE_ROOT,$TOKEN)" \
  "$AGGREGATE_AMOUNT" "$RECIPIENT_COUNT" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
# Wait/poll up to 5 minutes for confirmed receipt

# 2. Fund campaign
TX_HASH=$(cast send "$TOKEN" "transfer(address,uint256)" "$CAMPAIGN" "$AGGREGATE_AMOUNT" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
# Wait/poll up to 5 minutes for confirmed receipt
```

Notes:

- `aggregateAmount` is informational — the Merkle tree leaf amounts enforce correctness
- Fund the campaign before `campaignStartTime` so claims don't fail

## Supported Chains

Use this registry to resolve chain metadata and RPC endpoints. Look up factory addresses at the [Airdrop Deployments page](https://docs.sablier.com/guides/airdrops/deployments.md). Look up `SablierLockup` addresses (needed by MerkleLL and MerkleLT) at the [Lockup Deployments page](https://docs.sablier.com/guides/lockup/deployments.md).

| Chain         | Chain ID   | Native Asset | RPC URL                                          |
| ------------- | ---------- | ------------ | ------------------------------------------------ |
| Ethereum      | `1`        | ETH          | `https://ethereum-rpc.publicnode.com`            |
| Abstract      | `2741`     | ETH          | `https://api.mainnet.abs.xyz`                    |
| Arbitrum      | `42161`    | ETH          | `https://arb1.arbitrum.io/rpc`                   |
| Avalanche     | `43114`    | AVAX         | `https://api.avax.network/ext/bc/C/rpc`          |
| Base          | `8453`     | ETH          | `https://mainnet.base.org`                       |
| Berachain     | `80094`    | BERA         | `https://rpc.berachain.com`                      |
| Blast         | `81457`    | ETH          | `https://rpc.blast.io`                           |
| BNB Chain     | `56`       | BNB          | `https://bsc-dataseed1.bnbchain.org`             |
| Chiliz        | `88888`    | CHZ          | `https://rpc.chiliz.com`                         |
| Core Dao      | `1116`     | CORE         | `https://rpc.coredao.org`                        |
| Denergy       | `369369`   | WATT         | `https://rpc.d.energy`                           |
| Gnosis        | `100`      | xDAI         | `https://rpc.gnosischain.com`                    |
| HyperEVM      | `999`      | HYPE         | `https://rpc.hyperliquid.xyz/evm`                |
| Lightlink     | `1890`     | ETH          | `https://replicator.phoenix.lightlink.io/rpc/v1` |
| Linea Mainnet | `59144`    | ETH          | `https://rpc.linea.build`                        |
| Mode          | `34443`    | ETH          | `https://mainnet.mode.network`                   |
| Monad         | `143`      | MON          | `https://rpc.monad.xyz`                          |
| Morph         | `2818`     | ETH          | `https://rpc.morphl2.io`                         |
| OP Mainnet    | `10`       | ETH          | `https://mainnet.optimism.io`                    |
| Polygon       | `137`      | POL          | `https://polygon-bor-rpc.publicnode.com`         |
| Scroll        | `534352`   | ETH          | `https://rpc.scroll.io`                          |
| Sei Network   | `1329`     | SEI          | `https://evm-rpc.sei-apis.com`                   |
| Sonic         | `146`      | S            | `https://rpc.soniclabs.com`                      |
| Superseed     | `5330`     | ETH          | `https://mainnet.superseed.xyz`                  |
| Unichain      | `130`      | ETH          | `https://mainnet.unichain.org`                   |
| XDC           | `50`       | XDC          | `https://rpc.xinfin.network`                     |
| ZKsync Era    | `324`      | ETH          | `https://mainnet.era.zksync.io`                  |
| Sepolia       | `11155111` | ETH          | `https://ethereum-sepolia-rpc.publicnode.com`    |

Ethereum can also be referred to as "Mainnet".
