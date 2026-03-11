# Merkle Tree Generation

This reference covers the full process: collecting recipient data, generating the Merkle tree locally, pinning the campaign JSON to IPFS through Pinata, and extracting the values needed for campaign deployment. The agent handles every step — the only user-provided inputs are the recipient CSV and a single Pinata JWT.

## 1) Collect Recipient Data

The agent must obtain a CSV with `address` and `amount` columns.

**Primary — file path:** Ask the user for a path to a CSV on their filesystem. Read the file and verify it exists and is non-empty before proceeding.

**Fallback — inline data:** For small recipient lists (roughly 20 or fewer), the user may paste CSV rows directly in chat. Write the data to a temporary file:

```bash
cat > /tmp/recipients.csv << 'EOF'
address,amount
0x1111111111111111111111111111111111111111,1000
0x2222222222222222222222222222222222222222,500
EOF
```

Set `CSV_FILE` to the file path and proceed.

### CSV Format

- Header row must be exactly `address,amount`
- Amounts in **human-readable units** (not base units) — the local generator handles decimal conversion
- Addresses must be valid EVM addresses; the generator normalizes them to checksummed form
- No duplicate addresses allowed
- All amounts must be positive and non-zero
- Decimal places in amounts must not exceed the token's `decimals` value
- The CSV must contain at least **2 recipients**

Example:

```csv
address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,50.5
```

### Pre-submission Validation

Before running the generator, verify:

1. The file exists and is readable.
2. The header row is exactly `address,amount`.
3. There are at least two data rows after the header.
4. All addresses match the `0x[0-9a-fA-F]{40}` pattern.
5. All amounts are numeric and positive.

If any check fails, show the user the specific error and ask them to fix the CSV.

## 2) Resolve Token Decimals

Query the token's `decimals` from the chain — this is required by the API:

```bash
DECIMALS=$(cast call "$TOKEN" "decimals()(uint8)" --rpc-url "$RPC_URL")
```

## 3) Install the Local Generator

The airdrop skill ships with a local Node helper that reproduces the Merkle API create path without cloning or running the Rust server.

Install the package once:

```bash
npm install --prefix "skills/sablier-create-airdrop/scripts"
```

This requires Node.js. No Rust toolchain or local `merkle-api` process is needed.

### Obtain a Pinata JWT

The local generator pins the campaign JSON to IPFS through Pinata's JSON upload endpoint.

Ask the user to open the Pinata API keys page at [https://app.pinata.cloud/developers/api-keys](https://app.pinata.cloud/developers/api-keys), create an API key, and copy the JWT as:

- `PINATA_JWT`

Inform the user they only need `Write` permission for the `Files` resource.

## 4) Run the Local Generator and Parse Its Output

```bash
GENERATOR_OUTPUT=$(PINATA_JWT="$PINATA_JWT" \
  node "skills/sablier-create-airdrop/scripts/generate-merkle-campaign.mjs" \
    --csv-file "$CSV_FILE" \
    --decimals "$DECIMALS")
```

**On success:**

The CLI prints JSON to stdout:

```json
{
  "root": "0x1234abcd...",
  "cid": "bafy...",
  "total": "10000000000",
  "recipients": "50",
  "artifactPath": "/var/folders/.../recipients.campaign.json"
}
```

Parse the response:

```bash
MERKLE_ROOT=$(echo "$GENERATOR_OUTPUT" | jq -r '.root')
IPFS_CID=$(echo "$GENERATOR_OUTPUT" | jq -r '.cid')
AGGREGATE_AMOUNT=$(echo "$GENERATOR_OUTPUT" | jq -r '.total')
RECIPIENT_COUNT=$(echo "$GENERATOR_OUTPUT" | jq -r '.recipients')
ARTIFACT_PATH=$(echo "$GENERATOR_OUTPUT" | jq -r '.artifactPath')
```

- `root` — the Merkle root (`bytes32`) for the campaign's `merkleRoot` parameter.
- `cid` — the IPFS CID for the campaign's `ipfsCID` parameter.
- `total` — the aggregate amount already converted to the token's base units. Use directly as `aggregateAmount`.
- `recipients` — the recipient count. Use directly as `recipientCount`.
- `artifactPath` — the JSON file that was pinned to IPFS. Keep it for debugging or audits.

**On validation error:**

The CLI exits non-zero and prints JSON to stderr:

```json
{
  "status": "Invalid csv file.",
  "errors": [
    "Row 3: Invalid Ethereum address",
    "Row 5: Amounts should be positive, in normal notation, with an optional decimal point and a maximum number of decimals as provided by the query parameter."
  ]
}
```

Show the errors to the user and ask them to fix the CSV before retrying.

**On Pinata upload error:**

Diagnose before stopping:

- Is `PINATA_JWT` set?
- Is the JWT valid in Pinata?
- Is the CSV valid per the [format above](#csv-format)?

Do not proceed with campaign deployment until the generator returns all four deployment values successfully.

## Leaf Encoding (Reference)

Each leaf encodes three values — `(index, recipient, amount)` — and is **double-hashed** with keccak256 for second preimage resistance. The local generator uses OpenZeppelin's standard Merkle tree implementation with the same leaf schema as the Merkle API create path.
