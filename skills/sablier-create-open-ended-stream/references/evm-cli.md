# EVM CLI Stream Execution

## Overview

This guide is runbook-first: plan the stream, run preflight checks, preview the transaction, require explicit confirmation, then broadcast and verify.

## Execution Sequence

Use this sequence for every state-changing operation:

1. Complete [Intake & Planning Inputs](#intake--planning-inputs): mode, function, rate, chain, and arguments.
2. Run all [Preflight Checks](#preflight-checks), including allowance/balance checks and `MSG_VALUE` setup.
3. Build and show a human-readable transaction preview (no broadcast).
4. Require explicit user confirmation.
5. Broadcast with `cast send`.
6. Wait/poll up to 5 minutes for the confirmed receipt, then derive the created stream ID or IDs from `CreateFlowStream` logs.
7. Direct the user to the stream page on [app.sablier.com](https://app.sablier.com).

If ERC-20 allowance is insufficient (for `createAndDeposit`), execute an `approve` transaction first, wait/poll up to 5 minutes for its confirmed receipt, then resume at step 2.

## Mandatory Guardrails

### CLI Prerequisites Check

Before running any commands, verify the required tools are installed:

```bash
for cmd in cast jq; do
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
- `jq` — required for parsing transaction receipts.

### Signing Method (Mandatory)

For any signing command (`cast send`), use this hierarchy:

1. **`--browser` (preferred)** - delegates signing to the user's browser wallet extension (MetaMask, Rabby, etc.). A local server starts on port 9545 and opens a browser tab where the user approves the transaction. Private keys never touch the terminal or chat. Inform the user: *"A browser tab will open - approve the transaction in your wallet extension (e.g. MetaMask)."*
2. **`--private-key` (fallback)** - only if `--browser` fails at runtime (e.g. no browser available, extension error). In that case, ask the user to provide a private key or set the `ETH_PRIVATE_KEY` environment variable. Never proactively ask the user to paste a private key in the chat.

Do not continue without a signing method.

### Confirmation Rule (Mandatory)

Always use this sequence for state-changing transactions:

1. Build a human-readable preview of the transaction parameters.
2. Show the transaction details to the user.
3. If the user explicitly requested an amount `"per month"`, show the [Calendar-Month Caveat for Explicit `"per month"` Requests](#calendar-month-caveat-for-explicit-per-month-requests) immediately before the final confirmation prompt.
4. Ask for explicit confirmation.
5. Only after confirmation, run `cast send`.

Never broadcast before explicit user confirmation.

### Receipt Wait Timeout (Mandatory)

For every broadcasted transaction (`approve`, `create`, `createAndDeposit`, and `batch`), wait/poll for a confirmed receipt for up to **5 minutes** before treating the transaction as failed or unconfirmed.

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

#### Calendar-Month Caveat for Explicit `"per month"` Requests

If and only if the user explicitly requested an amount `"per month"`, show this caveat immediately before the final `YES` confirmation prompt:

> **Calendar-Month Caveat**
> Sablier Flow uses a fixed per-second streaming rate.
> Exact "same amount every calendar month" streaming is not possible because calendar months have different numbers of seconds.
> Your requested `"per month"` amount will be implemented using a **30-day month approximation** to calculate `ratePerSecond`.

- Do not show this caveat unless the user explicitly used `"per month"` in their request.
- Do not show it for monthly wording introduced by the agent.

## Intake & Planning Inputs

Choose the transaction parameters in this order before building calldata.

### 1) Choose Mode

Infer the creation mode from the user's request:

| Signal                                  | Mode                 |
| --------------------------------------- | -------------------- |
| One recipient, one stream               | **Single Stream**    |
| Multiple recipients or multiple streams | **Batch of Streams** |
| "create streams for 5 recipients"       | **Batch of Streams** |
| "create a stream for Alice"             | **Single Stream**    |

- If ambiguous, ask the user to clarify.

- For batch requests exceeding **50 streams**, route to `sablier-create-airdrop`. If this skill is unavailable, recommend installing it with:

  ```bash
  npx skills add sablier-labs/sablier-skills --skill sablier-create-airdrop
  ```

### 2) Choose Function

Infer whether to fund the stream upfront:

| Signal                                                                                   | Function                                              |
| ---------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| "create a stream", "start streaming", no mention of deposit                              | **`create`** — stream starts with zero balance        |
| "create and deposit", "fund the stream", "deposit tokens", mentions an amount to deposit | **`createAndDeposit`** — stream is funded immediately |

- If the user wants to deposit tokens upfront but hasn't specified an amount, ask them to provide the deposit amount.
- If ambiguous, ask the user whether they want to fund the stream at creation or deposit later.

### 3) Calculate Rate Per Second

Convert the user's desired streaming rate into the `UD21x18` format. `UD21x18` is a fixed-point type from the PRBMath library, encoded as `uint128` with 18 decimals of precision.

**Conversion formula:**

```
ratePerSecond = (tokensPerPeriod * 1e18) / secondsInPeriod
```

**Common period conversions:**

| Period           | Seconds    |
| ---------------- | ---------- |
| Per hour         | `3600`     |
| Per day          | `86400`    |
| Per week         | `604800`   |
| Per 30-day month | `2592000`  |
| Per 365-day year | `31536000` |

**Example:** Stream 1,000 USDC per 30-day month:

```
ratePerSecond = (1000 * 1e18) / 2_592_000
             = 1e21 / 2_592_000
             ≈ 385_802_469_135_802
```

- The `UD21x18` type represents `1e18` as 1 whole token per second, regardless of the token's actual decimals. The contract handles decimal scaling internally.
- If the user provides a rate like "1000 per month", convert it using a 30-day month approximation. Do not ask the user to calculate the rate themselves.
- If the user does not provide a rate, ask them to specify how many tokens per time period they want to stream.

### 4) Resolve Chain and `SablierFlow`

Use [Supported Chains](#supported-chains) to resolve chain metadata, RPC endpoints, and `SablierFlow` contract addresses.

If the requested chain is not listed:

1. Check [Sablier Flow deployments](https://docs.sablier.com/guides/flow/deployments.md) for the contract address.
2. If still unresolved, ask the user to provide both the RPC URL and `SablierFlow` contract address.

### 5) Collect Required Inputs

Collect these before building any transaction:

- `chain` (ID and name)
- sender wallet address (resolved via `cast wallet address --browser` or provided by the user)
- signing method (`--browser` preferred, `--private-key` fallback)
- native gas balance (`ETH` etc.)
- `SablierFlow` contract address
- recipient count and number of streams
- token address
- `ratePerSecond` (calculated in step 3)
- `startTime` (`0` for immediate, or a Unix timestamp — future timestamps delay accrual, past timestamps cause retroactive debt accrual)
- `transferable` (default `true` unless the user explicitly requests non-transferable)
- deposit `amount` (for `createAndDeposit` only, in token base units)

## Preflight Checks

Run these checks before previewing or broadcasting any state-changing transaction.

### Creation Fee (`MSG_VALUE`)

The creation fee is approximately **~$1 USD** worth of the chain's native asset. Calculate it dynamically before each transaction.

**Procedure:**

Look up the `MSG_VALUE` for the chain's native asset from this table:

| Native Asset | ~Amount    | MSG_VALUE (wei)        |
| ------------ | ---------- | ---------------------- |
| ETH          | 0.0005 ETH | `500000000000000`      |
| AVAX         | 0.11 AVAX  | `110000000000000000`   |
| BERA         | 1.9 BERA   | `1900000000000000000`  |
| BNB          | 0.0016 BNB | `1600000000000000`     |
| CHZ          | 25 CHZ     | `25000000000000000000` |
| CORE         | 12.5 CORE  | `12500000000000000000` |
| HYPE         | 0.032 HYPE | `32000000000000000`    |
| MON          | 50 MON     | `50000000000000000000` |
| POL          | 10 POL     | `10000000000000000000` |
| S            | 25 S       | `25000000000000000000` |
| SEI          | 14 SEI     | `14000000000000000000` |
| WATT         | 0 WATT     | `0`                    |
| xDAI         | 1 xDAI     | `1000000000000000000`  |
| XDC          | 29 XDC     | `29000000000000000000` |

> These values are approximate as of March 2026. If a value seems outdated, use web search to find the current price and recalculate as `cast to-wei $(echo "scale=18; 1 / $PRICE" | bc) ether`.

- Use the same fee for both **Single Stream** and **Batch of Streams** transactions.
- Before sending, verify the wallet has enough native token for both `MSG_VALUE` and gas.

### Allowance and Token Balance

For `createAndDeposit` only:

1. **ERC-20 allowance.** Check `allowance(owner, flow)`. The required allowance depends on mode:

- **Single Stream:** `DEPOSIT_AMOUNT`
- **Batch of Streams:** sum of `DEPOSIT_AMOUNT` across all streams
  If allowance is below the required total, send an `approve` transaction to raise allowance before attempting stream creation.

2. **ERC-20 token balance.** Check `balanceOf(owner)` is at least the total deposit amount. If balance is insufficient, stop execution and inform the user they need more tokens (for example, purchase via Uniswap) before continuing.

For `create` (no upfront deposit): skip allowance and token balance checks — no tokens are transferred at creation time.

### Native Gas Balance for Every Transaction

Before broadcasting each transaction, estimate the gas cost and verify the sender can cover both gas and the creation fee (`MSG_VALUE`):

```bash
# Estimate gas for the transaction (returns gas units)
GAS_ESTIMATE=$(cast estimate "$FLOW" "$FUNCTION_SIG" $FUNCTION_ARGS \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER")

# Get current gas price (in wei)
GAS_PRICE=$(cast gas-price --rpc-url "$RPC_URL")

# Total native token needed = (gas estimate × gas price) + MSG_VALUE
TOTAL_NEEDED=$(echo "$GAS_ESTIMATE * $GAS_PRICE + $MSG_VALUE" | bc)
```

Compare `TOTAL_NEEDED` against the sender's native balance. Run this check before each broadcast (`approve` and stream creation). If balance is insufficient, stop and tell the user to fund their wallet first. Recommend buying via [Transak](https://transak.com/buy).

### Read-Only Validation Commands

Resolve the sender address first via the browser wallet, then run read-only checks:

```bash
# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)

# Check native gas token balance (ETH/POL/BNB/etc.)
cast balance "$OWNER" --rpc-url "$RPC_URL"

# Check token balance (for createAndDeposit)
cast call "$TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC_URL"

# Check token allowance (for createAndDeposit)
cast call "$TOKEN" "allowance(address,address)(uint256)" "$OWNER" "$FLOW" --rpc-url "$RPC_URL"
```

## Execution Runbook

### Shared Setup

#### 1) Resolve RPC URL, signing method, and sender address

```bash
CHAIN_ID="<resolved-chain-id>"
RPC_URL="<resolved-or-user-provided-rpc>"

# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)
```

#### 2) Run preflight checks and handle `approve` if needed

Run all checks from [Preflight Checks](#preflight-checks), calculate `MSG_VALUE` per the [Creation Fee](#creation-fee-msg_value) section, and re-run the native gas check before each broadcast (`approve` and stream creation). If an ERC-20 `approve` transaction is needed (for `createAndDeposit`), execute it, wait/poll up to 5 minutes for the confirmed receipt per [Receipt Wait Timeout (Mandatory)](#receipt-wait-timeout-mandatory), then continue to step 3.

### Single Stream Flow

#### 3) Preview Transaction (No Broadcast)

Build calldata internally if needed to validate the exact transaction before signing, but do not show the raw calldata in the default preview:

```bash
CALLDATA=$(cast calldata "$FUNCTION_SIG" $FUNCTION_ARGS)
```

Present a human-readable summary.

Default preview rule: show only human-readable values in the user-facing preview. Do not show raw calldata, raw `ratePerSecond` integers, `UD21x18` labels, or token base-unit integers unless the user explicitly asks for the exact machine values in a separate follow-up.

- **Contract:** `$FLOW`
- **Function:** `create` or `createAndDeposit`
- **Recipient, token, rate per second, start time**. In the preview, the rate field must show only the human-readable equivalent, for example `~0.0001 USDC per 30-day month`.
- **Deposit amount** (for `createAndDeposit`). Show only the human-readable token amount, for example `(0.1 USDC)`.
- **Creation fee:** ~$1 USD in native token (`MSG_VALUE`)
- **Expected UI slug after confirmation:** `FL3-${CHAIN_ID}-<streamId>`

#### 4) Require Explicit Confirmation

Use a clear confirmation flow:

- If the Calendar-Month Caveat applies, show it immediately before the final confirmation prompt.
- Then show this final confirmation prompt:

⚠️ Final confirmation required

```text
+------------------------------+
| Confirm broadcast?           |
| Reply exactly: YES           |
+------------------------------+
```

If the user does not explicitly confirm with `YES`, stop.

#### 5) Broadcast After Confirmation

A browser tab will open for the user to approve the transaction in their wallet extension.

```bash
TX_HASH=$(cast send "$FLOW" "$FUNCTION_SIG" $FUNCTION_ARGS \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
```

If `--browser` fails at runtime, ask the user to provide a private key and retry with `--private-key`.

#### 6) Verify Receipt and Extract the Created Stream ID

```bash
CREATE_FLOW_STREAM_TOPIC0="0xedec8afa4eeca64243a519c152eab5c4f9da1bded6fbb72cba74cd128de68369"
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

STREAM_IDS=$(echo "$RECEIPT" | jq -r \
  --arg flow "$(echo "$FLOW" | tr '[:upper:]' '[:lower:]')" \
  --arg topic0 "$CREATE_FLOW_STREAM_TOPIC0" '
  .logs[]
  | select((.address | ascii_downcase) == $flow)
  | select(.topics[0] == $topic0)
  | .data
' | while read -r DATA; do
  STREAM_ID_HEX="0x$(echo "$DATA" | sed 's/^0x//' | cut -c1-64)"
  cast to-dec "$STREAM_ID_HEX"
done)

STREAM_ID=$(printf '%s\n' "$STREAM_IDS" | sed -n '1p')
```

#### 7) Direct User to the Stream

After successful receipt verification within the 5-minute timeout:

- If `STREAM_ID` is empty, stop and tell the user no `CreateFlowStream` event was found in the confirmed receipt.
- Present the direct link to the stream:

```
https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}
```

### Batch Flow

#### 3) Encode Individual Create Calls

For each stream, ABI-encode the full `create*` calldata using `cast calldata`:

```bash
CALL_1=$(cast calldata "$FUNCTION_SIG" $ARGS_STREAM_1)
CALL_2=$(cast calldata "$FUNCTION_SIG" $ARGS_STREAM_2)
CALL_3=$(cast calldata "$FUNCTION_SIG" $ARGS_STREAM_3)
# ... repeat for each stream
```

Each `CALL_N` is a complete calldata blob (4-byte selector + ABI-encoded arguments).

You can mix `create` and `createAndDeposit` calls in the same batch.

#### 4) Preview Batch Transaction (No Broadcast)

Present a human-readable summary.

Apply the same default preview rule: do not show `CALL_N` blobs, raw `ratePerSecond` integers, `UD21x18` labels, or token base-unit integers unless the user explicitly asks for the exact machine values in a separate follow-up.

- **Contract:** `$FLOW`
- **Function:** `batch(bytes[])`
- **Number of streams**, each with: recipient, token, human-readable rate only (for example `~0.0001 USDC per 30-day month`), start time, human-readable deposit amount (if any, for example `(0.1 USDC)`)
- **Creation fee:** ~$1 USD in native token (`MSG_VALUE`) for the entire batch
- **Expected UI slug after confirmation:** `FL3-${CHAIN_ID}-<streamId>`

#### 5) Require Explicit Confirmation

Apply the same confirmation rule as Single Stream: show transaction details, show the Calendar-Month Caveat immediately before the final confirmation prompt if it applies, then show the same boxed `Reply exactly: YES` confirmation prompt before broadcast.

#### 6) Broadcast After Confirmation

A browser tab will open for the user to approve the transaction in their wallet extension.

```bash
TX_HASH=$(cast send "$FLOW" "batch(bytes[])" "[$CALL_1,$CALL_2,$CALL_3]" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser \
  --async)
```

If `--browser` fails at runtime, ask the user to provide a private key and retry with `--private-key`.

#### 7) Verify Receipt and Extract Created Stream IDs

```bash
CREATE_FLOW_STREAM_TOPIC0="0xedec8afa4eeca64243a519c152eab5c4f9da1bded6fbb72cba74cd128de68369"
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

STREAM_IDS=$(echo "$RECEIPT" | jq -r \
  --arg flow "$(echo "$FLOW" | tr '[:upper:]' '[:lower:]')" \
  --arg topic0 "$CREATE_FLOW_STREAM_TOPIC0" '
  .logs[]
  | select((.address | ascii_downcase) == $flow)
  | select(.topics[0] == $topic0)
  | .data
' | while read -r DATA; do
  STREAM_ID_HEX="0x$(echo "$DATA" | sed 's/^0x//' | cut -c1-64)"
  cast to-dec "$STREAM_ID_HEX"
done)
```

#### 8) Direct User to the Sablier App

After successful receipt verification within the 5-minute timeout:

- If `STREAM_IDS` is empty, stop and tell the user no `CreateFlowStream` events were found in the confirmed receipt.
- Present one link per stream using the confirmed IDs:

```bash
printf '%s\n' "$STREAM_IDS" | while read -r STREAM_ID; do
  echo "https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}"
done
```

## Entrypoint Catalog

Maps each creation function to the correct `SablierFlow` calldata encoding. Refer to ABI definitions in [flow-v2.0-abi.json](../assets/flow-v2.0-abi.json) for exact type encoding.

### Function-to-Use-Case Mapping

| Function           | Use Case                                                  |
| ------------------ | --------------------------------------------------------- |
| `create`           | Stream without upfront deposit — anyone can deposit later |
| `createAndDeposit` | Stream with immediate funding in a single transaction     |
| `batch`            | Multiple streams in a single transaction                  |

### `create`

Creates a stream with zero balance. Debt accrues from `startTime` but no tokens are held by the contract until someone deposits.

```
create(
  address sender,
  address recipient,
  uint128 ratePerSecond,
  uint40 startTime,
  address token,
  bool transferable
)
```

**Arguments:**

1. **sender** - has pause/restart/adjust/void authority over the stream
2. **recipient** - receives the stream NFT and can withdraw accrued tokens
3. **ratePerSecond** - token amount per second in `UD21x18` format (`1e18` = 1 whole token/second)
4. **startTime** - Unix timestamp when debt starts accruing; `0` means `block.timestamp` (immediate). A past timestamp causes retroactive debt accrual from that point.
5. **token** - ERC-20 token contract address (decimals must be ≤ 18)
6. **transferable** - whether the stream NFT can be transferred

### `createAndDeposit`

Creates a stream and immediately deposits tokens. Requires prior ERC-20 `approve` for the deposit amount.

```
createAndDeposit(
  address sender,
  address recipient,
  uint128 ratePerSecond,
  uint40 startTime,
  address token,
  bool transferable,
  uint128 amount
)
```

**Arguments:**

- **1–6.** Same as `create` above.
- **7. amount** — initial deposit in the token's base units (e.g. `1000000000` for 1000 USDC with 6 decimals). Must be > 0.

### `batch`

Used to create **multiple streams in a single transaction**. Each element in the `calls` array is a fully ABI-encoded `create` or `createAndDeposit` calldata.

```
batch(bytes[] calls)
```

**Arguments:**

1. **calls** - `bytes[]` array where each element is the output of `cast calldata` for a `create` or `createAndDeposit` function

## Validation Rules

Check these before building calldata. Violating any of them will cause the transaction to revert.

1. `sender` must not be the zero address.
2. `token` must be an ERC-20 token contract — not the chain's native token (ETH, BNB, etc.).
3. `token` decimals must be ≤ 18.
4. If `startTime == 0`: treated as `block.timestamp` (stream starts immediately).
5. If `startTime` is in the future: `ratePerSecond` must be > 0 (contract-enforced).
6. For `createAndDeposit`: `amount` must be > 0.

## Rate Per Second Reference

The `ratePerSecond` parameter uses the `UD21x18` fixed-point type from PRBMath (encoded as `uint128`) where `1e18` = 1 whole token per second. The contract handles decimal scaling internally — the rate is always expressed in whole tokens regardless of the token's actual decimals.

**Conversion formula:**

```
ratePerSecond = (tokensPerPeriod * 1e18) / secondsInPeriod
```

**Common rate examples:**

| Desired Rate        | Calculation                  | `ratePerSecond` Value     |
| ------------------- | ---------------------------- | ------------------------- |
| 1 token/second      | `1 * 1e18`                   | `1000000000000000000`     |
| 100 tokens/day      | `100 * 1e18 / 86_400`        | `≈ 1_157_407_407_407_407` |
| 1,000 tokens/month  | `1000 * 1e18 / 2_592_000`    | `≈ 385_802_469_135_802`   |
| 5,000 tokens/month  | `5000 * 1e18 / 2_592_000`    | `≈ 1_929_012_345_679_012` |
| 10,000 tokens/year  | `10000 * 1e18 / 31_536_000`  | `≈ 317_097_919_837_645`   |
| 120,000 tokens/year | `120000 * 1e18 / 31_536_000` | `≈ 3_805_175_038_051_750` |

## Worked Examples

These examples intentionally use raw integers and ABI-ready arguments because they are for command construction. Do not copy these machine values into the default transaction preview; show human-readable token amounts and rates first, and provide exact machine values separately only if the user explicitly asks.

### Single Stream: `createAndDeposit`

A single payment stream of 1000 USDC per 30-day month (6 decimals) with 3000 USDC deposited upfront on Ethereum mainnet:

```bash
FLOW="<flow-address>"    # From Supported Chains table
CHAIN_ID="1"             # Ethereum mainnet
TOKEN="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
# Calculate MSG_VALUE per the "Creation Fee" section
SENDER=$(cast wallet address --browser)
RECIPIENT="0x..."

# ratePerSecond = 1000 * 1e18 / 2_592_000 ≈ 385_802_469_135_802
RATE="385802469135802"

# 3000 USDC = 3000 * 1e6 = 3_000_000_000 (6-decimal base units)
AMOUNT="3000000000"

TX_HASH=$(cast send "$FLOW" \
  "createAndDeposit(address,address,uint128,uint40,address,bool,uint128)" \
  "$SENDER" "$RECIPIENT" "$RATE" 0 "$TOKEN" true "$AMOUNT" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$SENDER" \
  --browser \
  --async)
```

Notes:

- `385802469135802` = 1000 tokens/month expressed as `UD21x18` rate per second
- `3000000000` = 3000 USDC in 6-decimal base units (3 months of runway)
- `0` for `startTime` = stream starts immediately at `block.timestamp`
- `true` for `transferable` = the stream NFT can be transferred
- ERC-20 approval for `AMOUNT` (`3000000000` base units = 3000 USDC) to the `SablierFlow` contract is required before this call
- `MSG_VALUE` = ~$1 USD worth of native token (see [Creation Fee](#creation-fee-msg_value))
- After confirmation, wait/poll up to 5 minutes for the confirmed receipt, then extract the real `streamId` from the `CreateFlowStream` log and build the final app link as `https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}`

### Single Stream: `create` (No Deposit)

A payment stream of 5000 DAI per month with no upfront deposit — the sender or anyone else can deposit later:

```bash
FLOW="<flow-address>"    # From Supported Chains table
CHAIN_ID="1"             # Ethereum mainnet
TOKEN="0x6B175474E89094C44Da98b954EedeAC495271d0F"  # DAI on Ethereum
SENDER=$(cast wallet address --browser)
RECIPIENT="0x..."

# ratePerSecond = 5000 * 1e18 / 2_592_000 ≈ 1_929_012_345_679_012
RATE="1929012345679012"

TX_HASH=$(cast send "$FLOW" \
  "create(address,address,uint128,uint40,address,bool)" \
  "$SENDER" "$RECIPIENT" "$RATE" 0 "$TOKEN" true \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$SENDER" \
  --browser \
  --async)
```

Notes:

- No ERC-20 approval needed — no tokens are transferred at creation time
- The stream starts accruing debt immediately but remains insolvent until someone deposits
- `MSG_VALUE` = ~$1 USD worth of native token (see [Creation Fee](#creation-fee-msg_value))
- After confirmation, wait/poll up to 5 minutes for the confirmed receipt, then extract the real `streamId` from the `CreateFlowStream` log and build the final app link as `https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}`

### Batch of Streams: 3x `create`

A batch of three payment streams of 1000 USDC per month each to different recipients, with no upfront deposit, on Ethereum mainnet:

```bash
FLOW="<flow-address>"    # From Supported Chains table
CHAIN_ID="1"             # Ethereum mainnet
TOKEN="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
# Calculate MSG_VALUE per the "Creation Fee" section
SENDER=$(cast wallet address --browser)
FUNCTION_SIG="create(address,address,uint128,uint40,address,bool)"

# ratePerSecond = 1000 * 1e18 / 2_592_000 ≈ 385_802_469_135_802
RATE="385802469135802"

# Encode each create call
CALL_1=$(cast calldata "$FUNCTION_SIG" \
  "$SENDER" "0xRecipient1" "$RATE" 0 "$TOKEN" true)
CALL_2=$(cast calldata "$FUNCTION_SIG" \
  "$SENDER" "0xRecipient2" "$RATE" 0 "$TOKEN" true)
CALL_3=$(cast calldata "$FUNCTION_SIG" \
  "$SENDER" "0xRecipient3" "$RATE" 0 "$TOKEN" true)

TX_HASH=$(cast send "$FLOW" "batch(bytes[])" "[$CALL_1,$CALL_2,$CALL_3]" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$SENDER" \
  --browser \
  --async)
```

Notes:

- No ERC-20 approval needed since all three use `create` (no upfront deposit)
- `MSG_VALUE` = ~$1 USD worth of native token for the entire batch
- All three streams use the same `SablierFlow` contract and the same `batch()` entrypoint
- You can mix `create` and `createAndDeposit` calls in the same batch
- After confirmation, wait/poll up to 5 minutes for the confirmed receipt, then extract all `streamId` values and build one final link per stream as `https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}`
- For more than 50 streams, route to `sablier-create-airdrop`

## Supported Chains

Use this registry to resolve chain metadata, RPC endpoints, and `SablierFlow` contract addresses:

UI support note:

- The Flow v2.0 UI alias is `FL3`, so supported payment links use `https://app.sablier.com/payments/stream/FL3-${CHAIN_ID}-${STREAM_ID}`.

| Chain         | Chain ID   | Native Asset | SablierFlow                                  | RPC URL                                          |
| ------------- | ---------- | ------------ | -------------------------------------------- | ------------------------------------------------ |
| Ethereum      | `1`        | ETH          | `0x7a86d3e6894f9c5b5f25ffbdaae658cfc7569623` | `https://ethereum-rpc.publicnode.com`            |
| Abstract      | `2741`     | ETH          | `0xc415425e56cc6c42b87bacffb276db2292cc1e50` | `https://api.mainnet.abs.xyz`                    |
| Arbitrum      | `42161`    | ETH          | `0xf0f6477422a346378458f73cf02f05a7492e0c25` | `https://arb1.arbitrum.io/rpc`                   |
| Avalanche     | `43114`    | AVAX         | `0x64dc318ba879eca8222e963d319728f211c600c7` | `https://api.avax.network/ext/bc/C/rpc`          |
| Base          | `8453`     | ETH          | `0x8551208f75375abfaee1fbe0a69e390a94000ec2` | `https://mainnet.base.org`                       |
| Berachain     | `80094`    | BERA         | `0xb89cc68b2ef376ca1b9645f109f7a490b180cf1b` | `https://rpc.berachain.com`                      |
| Blast         | `81457`    | ETH          | `0x13ce2ca4602d5d1dd323014cd5a4e8414d310a06` | `https://rpc.blast.io`                           |
| BNB Chain     | `56`       | BNB          | `0x5505c2397B0BeBEEE64919F21Df84F83C008C51b` | `https://bsc-dataseed1.bnbchain.org`             |
| Chiliz        | `88888`    | CHZ          | `0x21797da50e180d24d6a68e8be6f8daca1c06f0ee` | `https://rpc.chiliz.com`                         |
| Core Dao      | `1116`     | CORE         | `0x4cb7fb49e4b646b472a5609804004722b3b94f93` | `https://rpc.coredao.org`                        |
| Denergy       | `369369`   | WATT         | `0xB2Fc49d89B72cD8Aadd7f07D602CF005D5A017Ea` | `https://rpc.d.energy`                           |
| Gnosis        | `100`      | xDAI         | `0xcdd3eb5283e4a675f16ba83e9d8c28c871a550a2` | `https://rpc.gnosischain.com`                    |
| HyperEVM      | `999`      | HYPE         | `0x70ce7795896c1e226C71360F9d77B743d8302182` | `https://rpc.hyperliquid.xyz/evm`                |
| Lightlink     | `1890`     | ETH          | `0x5f742f6becc61e76ae67b0dc29d58f5c964e2c78` | `https://replicator.phoenix.lightlink.io/rpc/v1` |
| Linea Mainnet | `59144`    | ETH          | `0x977FDf70abeD6b60eECcee85322beA4575B0b6Ed` | `https://rpc.linea.build`                        |
| Mode          | `34443`    | ETH          | `0xbed2f163cc0aa3278261ef1c3fa51b98db270829` | `https://mainnet.mode.network`                   |
| Monad         | `143`      | MON          | `0x0340a829b6dC3aDF7710a5bAF1970914af4977f5` | `https://rpc.monad.xyz`                          |
| Morph         | `2818`     | ETH          | `0xbf407836021c993dfa27cb8232415d15faea709a` | `https://rpc.morphl2.io`                         |
| OP Mainnet    | `10`       | ETH          | `0xd18491649440d6338532f260761cee64e79d7bb2` | `https://mainnet.optimism.io`                    |
| Polygon       | `137`      | POL          | `0x62b6d5a3ac0cc91ecebd019d1c70fe955d8c7426` | `https://polygon-bor-rpc.publicnode.com`         |
| Scroll        | `534352`   | ETH          | `0xc3e92b9714ed01b51fdc29bb88b17af5cddd2c22` | `https://rpc.scroll.io`                          |
| Sei Network   | `1329`     | SEI          | `0x9eaf5a3f23964148a1321078f9cce4c2325c603e` | `https://evm-rpc.sei-apis.com`                   |
| Sonic         | `146`      | S            | `0x3954146884425accb86a6476dad69ec3591838cd` | `https://rpc.soniclabs.com`                      |
| Superseed     | `5330`     | ETH          | `0xe91bbae6c7d67b7c5055de1c9635c17af056211b` | `https://mainnet.superseed.xyz`                  |
| Unichain      | `130`      | ETH          | `0x170ecc032c96aa976fa702e94fbc9fa5bb64ee7c` | `https://mainnet.unichain.org`                   |
| XDC           | `50`       | XDC          | `0x3F00b8334EBE2A85875D1F8b50a43a12db67ACAD` | `https://rpc.xinfin.network`                     |
| ZKsync Era    | `324`      | ETH          | `0xa7f02e692973b6315eaca7fb4285ad2536a89cd0` | `https://mainnet.era.zksync.io`                  |
| Sepolia       | `11155111` | ETH          | `0xde489096eC9C718358c52a8BBe4ffD74857356e9` | `https://ethereum-sepolia-rpc.publicnode.com`    |

Ethereum can also be referred to as "Mainnet".
