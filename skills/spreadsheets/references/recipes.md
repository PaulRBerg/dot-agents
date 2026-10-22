# Spreadsheet Recipes

Use these as starting points. Keep amounts as strings. Preserve source data. Validate the output with `peek.py`.

## Exact Decimal Transform

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
import csv
from decimal import Decimal

with open("in.tsv", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    rows = list(reader)
    fields = list(reader.fieldnames or [])

if "value_usd" not in fields:
    fields.append("value_usd")

for row in rows:
    amount = Decimal(row["amount"])
    price = Decimal(row["price_usd"])
    row["value_usd"] = str(amount * price)

with open("out.tsv", "w", encoding="utf-8", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
```

## Idempotent Append

Use multiset difference, not set difference: identical rows can be legitimate.

```python
from collections import Counter

existing_counts = Counter(tuple(row.items()) for row in existing_rows)
to_append = []
for row in candidate_rows:
    key = tuple(row.items())
    if existing_counts[key] > 0:
        existing_counts[key] -= 1
    else:
        to_append.append(row)
```

## Schema Validation

Generate a draft schema from representative data. Edit the schema, then validate future files. `qsv schema` creates
stats sidecars next to its input. When the source directory must stay clean, run it against a temporary copy.

```sh
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cp txs.tsv "$tmpdir/txs.tsv"
(cd "$tmpdir" && qsv schema --stdout txs.tsv > txs.schema.json)
cp "$tmpdir/txs.schema.json" txs.schema.json
qsv validate schema txs.schema.json
qsv validate txs.tsv txs.schema.json
```

For house TSV validation after edits:

```sh
uv run "<skill-dir>/scripts/peek.py" txs.tsv --strict --house
```

## Keyed Diff

When primary key values are unique, use qsv. Use daff for row/column-aware human review.

```sh
qsv extdedup --select tx_id txs.tsv --no-output
qsv diff --key tx_id --delimiter-output '\t' -o txs.diff.tsv before.tsv after.tsv
bunx daff before.tsv after.tsv
```

## External-Disclosure Profile

For a profile report that leaves the agent workspace, render Markdown with redacted samples:

```sh
uv run "<skill-dir>/scripts/profile.py" txs.tsv --markdown --redact-samples
```
