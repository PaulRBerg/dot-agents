# EVM CLI Stream Execution

## Overview

Use this reference when the user wants the agent to execute EVM transactions on their behalf, such as creating Sablier Lockup streams directly from the terminal.

This guide is runbook-first: plan the stream, run preflight checks, preview the transaction, require explicit confirmation, then broadcast and verify.

## Execution Sequence

Use this sequence for every state-changing operation:

1. Complete [Intake & Planning Inputs](#intake--planning-inputs): mode, shape, variant, chain, and arguments.
2. Run all [Preflight Checks](#preflight-checks), including allowance/balance checks and `MSG_VALUE` setup.
3. Build and show a human-readable transaction preview (no broadcast).
4. Require explicit user confirmation.
5. Broadcast with `cast send`.
6. Verify the receipt.
7. Direct the user to [app.sablier.com](https://app.sablier.com).

If ERC-20 allowance is insufficient, execute an `approve` transaction first, then resume at step 2.

## Mandatory Guardrails

### Cast CLI and Browser Wallet Capability Check

Before running any `cast` command, verify the CLI is installed and supports `--browser`:

```bash
if ! command -v cast >/dev/null 2>&1; then
  echo "cast CLI not found. Install Foundry: https://getfoundry.sh/"
  exit 1
fi

if ! cast send --help 2>&1 | grep -q -- '--browser'; then
  echo "Your cast version does not support --browser."
  echo "Upgrade Foundry: https://getfoundry.sh/"
  exit 1
fi
```

If the check fails, stop and ask the user to install or upgrade Foundry at <https://getfoundry.sh/>.

### Signing Method (Mandatory)

For any signing command (`cast send`), use this hierarchy:

1. **`--browser` (preferred)** - delegates signing to the user's browser wallet extension (MetaMask, Rabby, etc.). A local server starts on port 9545 and opens a browser tab where the user approves the transaction. Private keys never touch the terminal or chat. Inform the user: *"A browser tab will open - approve the transaction in your wallet extension (e.g. MetaMask)."*
2. **`--private-key` (fallback)** - only if `--browser` fails at runtime (e.g. no browser available, extension error). In that case, ask the user to provide a private key or set the `ETH_PRIVATE_KEY` environment variable. Never proactively ask the user to paste a private key in the chat.

Do not continue without a signing method.

### Confirmation Rule (Mandatory)

Always use this sequence for state-changing transactions:

1. Build a human-readable preview of the transaction parameters.
2. Show the transaction details to the user.
3. Ask for explicit confirmation.
4. Only after confirmation, run `cast send`.

Never broadcast before explicit user confirmation.

## Intake & Planning Inputs

Choose the transaction shape in this order before building calldata.

### 1) Choose Mode

Infer the creation mode from the user's request:

| Signal | Mode |
| --- | --- |
| One recipient, one stream | **Single Stream** |
| Multiple recipients or multiple streams | **Batch of Streams** |
| "create streams for 5 recipients" | **Batch of Streams** |
| "create a stream for Alice" | **Single Stream** |

- If ambiguous, ask the user to clarify.
- For batch requests exceeding **50 streams**, recommend [Sablier Airdrops](https://app.sablier.com/airdrops), which is purpose-built for large-scale token distributions.

### 2) Choose Shape

This reference supports five vesting shapes: **Linear**, **Cliff**, **Unlock in Steps**, **Monthly Unlocks**, and **Timelock**.

Use [Entrypoint Catalog](#entrypoint-catalog) to map the chosen shape to the correct function and calldata encoding.

- If the vesting shape cannot be inferred from the user's instructions, default to **Linear**.
- If the user mentions a **cliff** but no other shape, default to **Cliff**.
- If the inferred shape is not among the five listed above, inform the user that this skill does not currently support that shape and suggest they request it as a feature. In the meantime, direct them to the [vesting gallery](https://app.sablier.com/vesting/gallery) in the Sablier UI.

### 3) Choose Variant

- **`Durations` variants** (`createWithDurationsLL`, `createWithDurationsLT`): use when the user does not specify a specific start time. The stream starts immediately upon transaction confirmation.
- **`Timestamps` variants** (`createWithTimestampsLL`, `createWithTimestampsLT`): use when the user specifies a specific start time (for example, "starting March 15" or "beginning at Unix timestamp 1710460800").

### 4) Resolve Chain and `SablierLockup`

Use [Supported Chains](#supported-chains) to resolve chain metadata, RPC endpoints, and `SablierLockup` contract addresses.

If the requested chain is not listed:

1. Check [Sablier Lockup deployments](https://docs.sablier.com/guides/lockup/deployments) for the contract address.
2. If still unresolved, ask the user to provide both the RPC URL and `SablierLockup` contract address.

### 5) Collect Required Inputs

Collect these before building any transaction:

- `chain` (ID and name)
- sender wallet address (resolved via `cast wallet address --browser` or provided by the user)
- signing method (`--browser` preferred, `--private-key` fallback)
- native gas balance (`ETH` etc.)
- `SablierLockup` contract address
- recipient count and number of streams
- token, deposit amount, and approval requirements
- function signature and arguments (see [Entrypoint Catalog](#entrypoint-catalog))

## Preflight Checks

Run these checks before previewing or broadcasting any state-changing transaction.

### Stream Creation Fee (`MSG_VALUE`)

For stream creation transactions, hard-code `MSG_VALUE` to `500000000000000` wei (`0.0005 ETH`, approximately **$1 USD**).

- Use the same flat fee for both **Single Stream** and **Batch of Streams** transactions.
- Do not browse the web or look up ETH/native-token prices.
- Before sending, verify the wallet has enough native token for both `MSG_VALUE` and gas.

### Allowance and Token Balance

For stream creation:

1. **ERC-20 allowance.** Check `allowance(owner, lockup)`. The required allowance depends on mode:
   - **Single Stream:** `DEPOSIT_AMOUNT`
   - **Batch of Streams:** sum of `DEPOSIT_AMOUNT` across all streams
   If allowance is below the required total, send an `approve` transaction to raise allowance before attempting stream creation.
2. **ERC-20 token balance.** Check `balanceOf(owner)` is at least the total deposit amount (single-stream deposit or the sum of all batch deposits). If balance is insufficient, stop execution and inform the user they need more tokens (for example, obtain or purchase via Uniswap) before continuing.

### Native Gas Balance for Every Transaction

Before broadcasting each transaction, check that the sender has enough native gas token (ETH/POL/BNB/etc.) to pay transaction fees. Run this check again before each broadcast (`approve` and stream creation). If balance is insufficient, stop and tell the user to fund their wallet first. Recommend buying via [Transak](https://transak.com/buy).

### Read-Only Validation Commands

Resolve the sender address first via the browser wallet, then run read-only checks:

```bash
# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)

# Check native gas token balance (ETH/POL/BNB/etc.)
cast balance "$OWNER" --rpc-url "$RPC_URL"

# Check token balance
cast call "$TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC_URL"

# Check token allowance
cast call "$TOKEN" "allowance(address,address)(uint256)" "$OWNER" "$LOCKUP" --rpc-url "$RPC_URL"
```

## Execution Runbook

### Shared Setup

#### 1) Resolve RPC URL, signing method, and sender address

```bash
RPC_URL="<resolved-or-user-provided-rpc>"

# Resolve sender address from browser wallet (opens a browser tab for the user to connect)
OWNER=$(cast wallet address --browser)
```

#### 2) Run preflight checks and handle `approve` if needed

Run all checks from [Preflight Checks](#preflight-checks), set `MSG_VALUE="500000000000000"`, and re-run the native gas check before each broadcast (`approve` and stream creation). If an ERC-20 `approve` transaction is needed, execute it before continuing to step 3.

### Single Stream Flow

#### 3) Preview Transaction (No Broadcast)

Build and display calldata so the user can review before signing:

```bash
CALLDATA=$(cast calldata "$FUNCTION_SIG" $FUNCTION_ARGS)
echo "Calldata: $CALLDATA"
```

Present a human-readable summary:

- **Contract:** `$LOCKUP`
- **Function:** chosen `create*` entrypoint
- **Recipient, token, amount, shape, duration/timestamps**
- **Creation fee:** `0.0005 ETH` (`MSG_VALUE`)

#### 4) Require Explicit Confirmation

Use a clear confirmation prompt, for example:

- `Confirm broadcast? Reply exactly: YES`

If the user does not explicitly confirm, stop.

#### 5) Broadcast After Confirmation

A browser tab will open for the user to approve the transaction in their wallet extension.

```bash
cast send "$LOCKUP" "$FUNCTION_SIG" $FUNCTION_ARGS \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser
```

If `--browser` fails at runtime, ask the user to provide a private key and retry with `--private-key`.

#### 6) Verify Receipt

```bash
cast receipt "$TX_HASH" --rpc-url "$RPC_URL"
```

#### 7) Direct User to the Sablier App

After successful confirmation, inform the user they can view and manage streams at [app.sablier.com](https://app.sablier.com).

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

#### 4) Preview Batch Transaction (No Broadcast)

Present a human-readable summary:

- **Contract:** `$LOCKUP`
- **Function:** `batch(bytes[])`
- **Number of streams**, each with: recipient, amount, shape, duration
- **Creation fee:** `0.0005 ETH` (`MSG_VALUE`) for the entire batch

#### 5) Require Explicit Confirmation

Apply the same confirmation rule as Single Stream: show transaction details and require explicit user confirmation before broadcast.

#### 6) Broadcast After Confirmation

A browser tab will open for the user to approve the transaction in their wallet extension.

```bash
cast send "$LOCKUP" "batch(bytes[])" "[$CALL_1,$CALL_2,$CALL_3]" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$OWNER" \
  --browser
```

If `--browser` fails at runtime, ask the user to provide a private key and retry with `--private-key`.

#### 7) Verify Receipt

```bash
cast receipt "$TX_HASH" --rpc-url "$RPC_URL"
```

#### 8) Direct User to the Sablier App

After successful confirmation, inform the user they can view and manage streams at [app.sablier.com](https://app.sablier.com).

## Entrypoint Catalog

Use this section after intake to map the vesting schedule to the correct `SablierLockup` function and calldata shape. Refer to ABI definitions in [lockup-v3.0-abi.json](../assets/lockup-v3.0-abi.json) for exact tuple encoding.

### Shape-to-Function Mapping

| Shape | `Durations` Variant | `Timestamps` Variant | `shape` String |
| --- | --- | --- | --- |
| Linear | `createWithDurationsLL` | `createWithTimestampsLL` | `"linear"` |
| Cliff | `createWithDurationsLL` | `createWithTimestampsLL` | `"cliff"` |
| Unlock in Steps | `createWithDurationsLT` | `createWithTimestampsLT` | `"tranchedStepper"` |
| Monthly Unlocks | `createWithDurationsLT` | `createWithTimestampsLT` | `"tranchedMonthly"` |
| Timelock | `createWithDurationsLL` | `createWithTimestampsLL` | `"linearTimelock"` |

Use `Durations` variants when the stream should start immediately upon confirmation. Use `Timestamps` variants when the user provides specific start or unlock times.

### `createWithDurationsLL`

Used for **Linear**, **Cliff**, and **Timelock** when no specific start time is given.

```
createWithDurationsLL(
  (address sender, address recipient, uint128 depositAmount, address token, bool cancelable, bool transferable, string shape),
  (uint128 start, uint128 cliff),
  (uint40 cliff, uint40 total)
)
```

**Arguments:**

1. **params** tuple - `(sender, recipient, depositAmount, token, cancelable, transferable, shape)`
2. **unlockAmounts** tuple - `(start, cliff)` - amounts unlocked instantly at stream start and at cliff time
3. **durations** tuple - `(cliff, total)` - durations in seconds

**Shape-specific encoding:**

| Shape | `unlockAmounts` | `durations` |
| --- | --- | --- |
| Linear | `(0, 0)` | `(0, totalDuration)` - no cliff |
| Cliff | `(0, cliffUnlockAmount)` | `(cliffDuration, totalDuration)` |
| Timelock | `(0, 0)` | `(0, lockDuration)` - entire amount unlocks at end |

### `createWithTimestampsLL`

Used for **Linear**, **Cliff**, and **Timelock** when the user specifies a start time.

```
createWithTimestampsLL(
  (address sender, address recipient, uint128 depositAmount, address token, bool cancelable, bool transferable, (uint40 start, uint40 end) timestamps, string shape),
  (uint128 start, uint128 cliff),
  uint40 cliffTime
)
```

**Arguments:**

1. **params** tuple - `(sender, recipient, depositAmount, token, cancelable, transferable, (startTimestamp, endTimestamp), shape)`
2. **unlockAmounts** tuple - `(start, cliff)` - amounts unlocked instantly at stream start and at cliff time
3. **cliffTime** - Unix timestamp for the cliff; set to `0` if no cliff

**Shape-specific encoding:**

| Shape | `unlockAmounts` | `cliffTime` |
| --- | --- | --- |
| Linear | `(0, 0)` | `0` |
| Cliff | `(0, cliffUnlockAmount)` | cliff Unix timestamp |
| Timelock | `(0, 0)` | `0` |

### `createWithDurationsLT`

Used for **Unlock in Steps** and **Monthly Unlocks** when no specific start time is given.

```
createWithDurationsLT(
  (address sender, address recipient, uint128 depositAmount, address token, bool cancelable, bool transferable, string shape),
  (uint128 amount, uint40 duration)[]
)
```

**Arguments:**

1. **params** tuple - `(sender, recipient, depositAmount, token, cancelable, transferable, shape)`
2. **tranchesWithDuration** array - each element is `(amount, duration)` where `amount` is the token amount unlocked in that tranche and `duration` is the tranche length in seconds

**Shape-specific encoding:**

| Shape | Tranche Construction |
| --- | --- |
| Unlock in Steps | Equal amounts, equal durations (for example, 4 tranches of 250 tokens every 90 days) |
| Monthly Unlocks | Equal amounts, 30-day durations (use 2592000 seconds per tranche) |

### `createWithTimestampsLT`

Used for **Unlock in Steps** and **Monthly Unlocks** when the user specifies a start time.

```
createWithTimestampsLT(
  (address sender, address recipient, uint128 depositAmount, address token, bool cancelable, bool transferable, (uint40 start, uint40 end) timestamps, string shape),
  (uint128 amount, uint40 timestamp)[]
)
```

**Arguments:**

1. **params** tuple - `(sender, recipient, depositAmount, token, cancelable, transferable, (startTimestamp, endTimestamp), shape)`
2. **tranches** array - each element is `(amount, timestamp)` where `amount` is the token amount unlocked and `timestamp` is the Unix timestamp at which it unlocks

**Shape-specific encoding:**

| Shape | Tranche Construction |
| --- | --- |
| Unlock in Steps | Equal amounts at equally spaced timestamps |
| Monthly Unlocks | Equal amounts at monthly timestamps (add 30 days per tranche to start) |

### `batch`

Used to create **multiple streams in a single transaction**. Each element in the `calls` array is a fully ABI-encoded `create*` calldata.

```
batch(bytes[] calls)
```

**Arguments:**

1. **calls** - `bytes[]` array where each element is the output of `cast calldata` for a `create*` function

## Worked Examples

### Single Stream: `createWithDurationsLL`

A single cliff stream of 1000 USDC (6 decimals) with a 90-day cliff and 365-day total duration on Ethereum mainnet:

```bash
LOCKUP="<lockup-address>"    # From Supported Chains table
TOKEN="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
MSG_VALUE="500000000000000"  # 0.0005 ETH flat fee
SENDER=$(cast wallet address --browser)
RECIPIENT="0x..."

cast send "$LOCKUP" \
  "createWithDurationsLL((address,address,uint128,address,bool,bool,string),(uint128,uint128),(uint40,uint40))" \
  "($SENDER,$RECIPIENT,1000000000,$TOKEN,true,true,cliff)" \
  "(0,0)" \
  "(7776000,31536000)" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$SENDER" \
  --browser
```

Notes:

- `1000000000` = 1000 USDC in 6-decimal base units
- `cliff` selects the Cliff shape
- `(0,0)` = no start unlock and no lump-sum cliff unlock amount
- `(7776000,31536000)` = 90-day cliff and 365-day total duration, both in seconds
- `MSG_VALUE` = `500000000000000` wei (`0.0005 ETH`)

### Batch of Streams: 3x `createWithDurationsLL`

A batch of three linear streams of 1000 USDC each to different recipients, with a 365-day duration and no cliff, on Ethereum mainnet:

```bash
LOCKUP="<lockup-address>"    # From Supported Chains table
TOKEN="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
MSG_VALUE="500000000000000"  # 0.0005 ETH flat fee for the entire batch
SENDER=$(cast wallet address --browser)
FUNCTION_SIG="createWithDurationsLL((address,address,uint128,address,bool,bool,string),(uint128,uint128),(uint40,uint40))"

# Encode each create call
CALL_1=$(cast calldata "$FUNCTION_SIG" \
  "($SENDER,0xRecipient1,1000000000,$TOKEN,true,true,linear)" "(0,0)" "(0,31536000)")
CALL_2=$(cast calldata "$FUNCTION_SIG" \
  "($SENDER,0xRecipient2,1000000000,$TOKEN,true,true,linear)" "(0,0)" "(0,31536000)")
CALL_3=$(cast calldata "$FUNCTION_SIG" \
  "($SENDER,0xRecipient3,1000000000,$TOKEN,true,true,linear)" "(0,0)" "(0,31536000)")

# MSG_VALUE = 500000000000000 (0.0005 ETH flat fee for the entire batch)
cast send "$LOCKUP" "batch(bytes[])" "[$CALL_1,$CALL_2,$CALL_3]" \
  --value "$MSG_VALUE" \
  --rpc-url "$RPC_URL" \
  --from "$SENDER" \
  --browser
```

Notes:

- ERC-20 approval must cover the total deposit: 3 × 1000000000 = 3000000000 (3000 USDC)
- `linear` selects the Linear shape
- `MSG_VALUE` = `500000000000000` wei (`0.0005 ETH`) for the entire batch
- All three streams use the same `SablierLockup` contract and the same `batch()` entrypoint
- For more than 50 streams, use [Sablier Airdrops](https://app.sablier.com/airdrops) instead

## Supported Chains

Use this registry to resolve chain metadata, RPC endpoints, and `SablierLockup` contract addresses:

| Chain | Chain ID | SablierLockup | RPC URL |
| --- | --- | --- | --- |
| Ethereum | `1` | `0xcF8ce57fa442ba50aCbC57147a62aD03873FfA73` | `https://ethereum-rpc.publicnode.com` |
| Abstract | `2741` | `0x293d8d192C0C93225FF6bBE7415a56B57379bbA3` | `https://api.mainnet.abs.xyz` |
| Arbitrum | `42161` | `0xF12AbfB041b5064b839Ca56638cDB62fEA712Db5` | `https://arb1.arbitrum.io/rpc` |
| Avalanche | `43114` | `0x7e146250Ed5CCCC6Ada924D456947556902acaFD` | `https://api.avax.network/ext/bc/C/rpc` |
| Base | `8453` | `0xe261b366f231b12fcb58d6bbd71e57faee82431d` | `https://mainnet.base.org` |
| Berachain | `80094` | `0xC37B51a3c3Be55f0B34Fbd8Bd1F30cFF6d251408` | `https://rpc.berachain.com` |
| Blast | `81457` | `0xcD16d89cc79Ab0b52717A46b8A3F73E61014c7dc` | `https://rpc.blast.io` |
| BNB Chain | `56` | `0x06bd1Ec1d80acc45ba332f79B08d2d9e24240C74` | `https://bsc-dataseed1.bnbchain.org` |
| Chiliz | `88888` | `0x957a54aC691893B20c705e0b2EecbDDF5220d019` | `https://rpc.chiliz.com` |
| Core Dao | `1116` | `0x01Fed2aB51A830a3AF3AE1AB817dF1bA4F152bB0` | `https://rpc.coredao.org` |
| Denergy | `369369` | `0x9f5d28C8ed7F09e65519C1f6f394e523524cA38F` | `https://rpc.d.energy` |
| Gnosis | `100` | `0x87f87Eb0b59421D1b2Df7301037e923932176681` | `https://rpc.gnosischain.com` |
| HyperEVM | `999` | `0x50ff828e66612A4D1F7141936F2B4078C7356329` | `https://rpc.hyperliquid.xyz/evm` |
| Lightlink | `1890` | `0xA4f1f4a5C55b5d9372CBB29112b14e1912A23d9D` | `https://replicator.phoenix.lightlink.io/rpc/v1` |
| Linea Mainnet | `59144` | `0xc853DB30a908dC1b655bbd4A8B9d5DB8588C13c8` | `https://rpc.linea.build` |
| Mode | `34443` | `0x9513CE572D4f4AAc1Dd493bcd50866235D1c698d` | `https://mainnet.mode.network` |
| Monad | `143` | `0x003F5393F4836f710d492AD98D89F5BFCCF1C962` | `https://rpc.monad.xyz` |
| Morph | `2818` | `0xE646D9A037c6B62e4d417592A10f57e77f007a27` | `https://rpc.morphl2.io` |
| OP Mainnet | `10` | `0xe2620fB20fC9De61CD207d921691F4eE9d0fffd0` | `https://mainnet.optimism.io` |
| Polygon | `137` | `0x1E901b0E05A78C011D6D4cfFdBdb28a42A1c32EF` | `https://polygon-bor-rpc.publicnode.com` |
| Scroll | `534352` | `0xcb60a39942CD5D1c2a1C8aBBEd99C43A73dF3f8d` | `https://rpc.scroll.io` |
| Sei Network | `1329` | `0x1d96e9d05f6910d22876177299261290537cfBBc` | `https://evm-rpc.sei-apis.com` |
| Sonic | `146` | `0x763Cfb7DF1D1BFe50e35E295688b3Df789D2feBB` | `https://rpc.soniclabs.com` |
| Superseed | `5330` | `0x2F1c6AD6306Bd0200D55b59AD54d4b44067D00E6` | `https://mainnet.superseed.xyz` |
| Unichain | `130` | `0xfFb540fC132dCefb0Fdef96ef63FE2f2F1BD7CFd` | `https://mainnet.unichain.org` |
| XDC | `50` | `0x2266901B1EcF499b4c91B6cBeA8e06700cFbde1e` | `https://rpc.xinfin.network` |
| ZKsync Era | `324` | `0xC07E338Ce1aEd183A8b3c55f980548f5E463b5c5` | `https://mainnet.era.zksync.io` |
| Sepolia | `11155111` | `0x6b0307b4338f2963A62106028E3B074C2c0510DA` | `https://ethereum-sepolia-rpc.publicnode.com` |

Ethereum can also be referred to as "Mainnet".
