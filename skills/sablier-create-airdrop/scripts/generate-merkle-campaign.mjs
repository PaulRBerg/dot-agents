#!/usr/bin/env node

import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { parse as parseCsv } from "csv-parse/sync";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, extname, join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { pathToFileURL } from "node:url";
import { getAddress, parseUnits } from "viem";

export const INVALID_AMOUNT_MESSAGE =
  "Amounts should be positive, in normal notation, with an optional decimal point and a maximum number of decimals as provided by the query parameter.";
export const INVALID_ADDRESS_MESSAGE = "Invalid Ethereum address";
export const ZERO_AMOUNT_MESSAGE = "The amount cannot be 0";
export const DUPLICATE_ADDRESS_MESSAGE =
  "Each recipient should have an unique address. This address was already specified in file";
export const MIN_RECIPIENTS_MESSAGE = "An airdrop campaign must have at least 2 recipients";
export const INVALID_HEADER_ADDRESS_MESSAGE =
  "CSV header invalid. The csv header should be `address` column. The address column is missing";
export const INVALID_HEADER_AMOUNT_MESSAGE =
  "CSV header invalid. The csv header should contain `amount` column. The amount column id missing";
export const INSUFFICIENT_COLUMNS_MESSAGE = "Insufficient columns";
export const DEFAULT_PINATA_API_URL = "https://api.pinata.cloud/pinning/pinJSONToIPFS";

export class CliError extends Error {
  constructor(payload, exitCode = 1) {
    super(payload.message ?? payload.status ?? "Command failed");
    this.exitCode = exitCode;
    this.payload = payload;
  }
}

function formatRowError(row, message) {
  return `Row ${row}: ${message}`;
}

function invalidCsv(errors) {
  return new CliError({ status: "Invalid csv file.", errors });
}

function normalizeAmountString(value) {
  let normalized = value.trim();
  if (normalized.startsWith("+")) {
    normalized = normalized.slice(1);
  }
  if (normalized.startsWith(".")) {
    normalized = `0${normalized}`;
  }
  if (normalized.endsWith(".")) {
    normalized = `${normalized}0`;
  }
  return normalized;
}

function buildAmountRegex(decimals) {
  return new RegExp(`^[+]?\\d*\\.?\\d{0,${decimals}}$`);
}

function sanitizeArtifactBaseName(filePath) {
  const baseName = basename(filePath, extname(filePath));
  const sanitized = baseName.replace(/[^a-zA-Z0-9._-]/g, "-");
  return sanitized.length > 0 ? sanitized : "campaign";
}

function parseCsvInput(content) {
  try {
    return parseCsv(content, {
      bom: true,
      relax_column_count: true,
      skip_empty_lines: false,
      trim: false,
    });
  } catch (error) {
    throw invalidCsv([String(error.message ?? error)]);
  }
}

export function parseCliArguments(argv = process.argv.slice(2), env = process.env) {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: false,
    options: {
      "csv-file": { type: "string" },
      decimals: { type: "string" },
      "output-dir": { type: "string" },
      "pinata-jwt": { type: "string" },
      help: { type: "boolean", short: "h" },
    },
  });

  if (positionals.length > 0) {
    throw new CliError({
      message: `Unexpected positional arguments: ${positionals.join(" ")}`,
    });
  }

  if (values.help) {
    return { help: true };
  }

  if (!values["csv-file"]) {
    throw new CliError({ message: "Missing required option `--csv-file`." });
  }

  if (values.decimals === undefined) {
    throw new CliError({ message: "Missing required option `--decimals`." });
  }

  const decimals = Number.parseInt(values.decimals, 10);
  if (!Number.isInteger(decimals) || decimals < 0) {
    throw new CliError({ message: "`--decimals` must be a non-negative integer." });
  }

  const pinataJwt = values["pinata-jwt"] ?? env.PINATA_JWT;
  if (!pinataJwt) {
    throw new CliError({
      message:
        "Missing Pinata credentials. Set `PINATA_JWT` or pass `--pinata-jwt`. Create or view a JWT at https://app.pinata.cloud/developers/api-keys",
    });
  }

  return {
    help: false,
    csvFile: resolve(values["csv-file"]),
    decimals,
    outputDir: values["output-dir"] ? resolve(values["output-dir"]) : undefined,
    pinataJwt,
  };
}

export function validateAndTransformRows(rows, decimals) {
  if (rows.length === 0) {
    throw invalidCsv([formatRowError(1, INSUFFICIENT_COLUMNS_MESSAGE)]);
  }

  const header = rows[0] ?? [];
  if (header.length < 2) {
    throw invalidCsv([formatRowError(1, INSUFFICIENT_COLUMNS_MESSAGE)]);
  }

  const headerAddress = String(header[0] ?? "").trim().toLowerCase();
  const headerAmount = String(header[1] ?? "").trim().toLowerCase();
  if (headerAddress !== "address") {
    throw invalidCsv([formatRowError(1, INVALID_HEADER_ADDRESS_MESSAGE)]);
  }
  if (headerAmount !== "amount") {
    throw invalidCsv([formatRowError(1, INVALID_HEADER_AMOUNT_MESSAGE)]);
  }

  const amountRegex = buildAmountRegex(decimals);
  const recipients = [];
  const errors = [];
  const seenAddresses = new Set();
  let totalAmount = 0n;

  for (let index = 1; index < rows.length; index += 1) {
    if (errors.length >= 100) {
      break;
    }

    const row = rows[index] ?? [];
    const rowNumber = index + 1;

    if (row.length < 2) {
      errors.push(formatRowError(rowNumber, INSUFFICIENT_COLUMNS_MESSAGE));
      continue;
    }

    const addressField = String(row[0] ?? "").trim();
    const amountField = String(row[1] ?? "").trim();

    let checksummedAddress;
    try {
      checksummedAddress = getAddress(addressField);
    } catch {
      errors.push(formatRowError(rowNumber, INVALID_ADDRESS_MESSAGE));
      continue;
    }

    const normalizedAmount = normalizeAmountString(amountField);
    if (!amountRegex.test(amountField) || normalizedAmount.length === 0 || normalizedAmount === ".") {
      errors.push(formatRowError(rowNumber, INVALID_AMOUNT_MESSAGE));
      continue;
    }

    let baseAmount;
    try {
      baseAmount = parseUnits(normalizedAmount, decimals);
    } catch {
      errors.push(formatRowError(rowNumber, INVALID_AMOUNT_MESSAGE));
      continue;
    }

    if (baseAmount <= 0n) {
      errors.push(formatRowError(rowNumber, ZERO_AMOUNT_MESSAGE));
      continue;
    }

    const duplicateKey = checksummedAddress.toLowerCase();
    if (seenAddresses.has(duplicateKey)) {
      errors.push(formatRowError(rowNumber, DUPLICATE_ADDRESS_MESSAGE));
      continue;
    }

    seenAddresses.add(duplicateKey);
    totalAmount += baseAmount;
    recipients.push({ address: checksummedAddress, amount: baseAmount.toString() });
  }

  if (recipients.length <= 1) {
    errors.push(formatRowError(1, MIN_RECIPIENTS_MESSAGE));
  }

  if (errors.length > 0) {
    throw invalidCsv(errors.slice(0, 100));
  }

  return {
    recipients,
    totalAmount: totalAmount.toString(),
    recipientCount: recipients.length,
  };
}

export async function buildCampaignArtifact({ csvFile, decimals, outputDir }) {
  let csvContent;
  try {
    csvContent = await readFile(csvFile, "utf8");
  } catch (error) {
    if (error && error.code === "ENOENT") {
      throw new CliError({ message: `CSV file not found: ${csvFile}` });
    }
    throw new CliError({ message: `Could not read CSV file: ${csvFile}` });
  }

  const rows = parseCsvInput(csvContent);
  const { recipients, totalAmount, recipientCount } = validateAndTransformRows(rows, decimals);

  const merkleValues = recipients.map((recipient, index) => [
    index.toString(),
    recipient.address,
    recipient.amount,
  ]);
  const tree = StandardMerkleTree.of(merkleValues, ["uint", "address", "uint256"]);

  const payload = {
    total_amount: totalAmount,
    number_of_recipients: recipientCount,
    root: tree.root,
    merkle_tree: JSON.stringify(tree.dump()),
    recipients,
  };

  const artifactDirectory =
    outputDir !== undefined ? outputDir : await mkdtemp(join(tmpdir(), "sablier-merkle-campaign-"));
  await mkdir(artifactDirectory, { recursive: true });

  const artifactPath = join(artifactDirectory, `${sanitizeArtifactBaseName(csvFile)}.campaign.json`);
  await writeFile(artifactPath, `${JSON.stringify(payload, null, 2)}\n`);

  return { artifactPath, payload };
}

export async function pinJsonToPinata(
  payload,
  {
    pinataJwt,
    fetchImpl = fetch,
    pinataApiUrl = process.env.PINATA_API_URL ?? DEFAULT_PINATA_API_URL,
    pinataMetadataName = "sablier-merkle-campaign",
  } = {},
) {
  if (!pinataJwt) {
    throw new CliError({
      message:
        "Missing Pinata credentials. Set `PINATA_JWT` or pass `--pinata-jwt`. Create or view a JWT at https://app.pinata.cloud/developers/api-keys",
    });
  }

  const response = await fetchImpl(pinataApiUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${pinataJwt}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      pinataContent: payload,
      pinataMetadata: {
        name: pinataMetadataName,
      },
    }),
  });

  const body = await response.text();
  let parsedBody = null;
  try {
    parsedBody = JSON.parse(body);
  } catch {
    parsedBody = null;
  }

  if (!response.ok) {
    if (response.status === 401) {
      throw new CliError({
        message:
          "Pinata rejected the upload with HTTP 401. The provided `PINATA_JWT` is invalid or expired. Check the JWT at https://app.pinata.cloud/developers/api-keys",
      });
    }

    throw new CliError({
      message: `Pinata upload failed with HTTP ${response.status}: ${body}`,
    });
  }

  const cid = parsedBody?.IpfsHash;
  if (!cid) {
    throw new CliError({
      message: "Pinata upload succeeded but the response did not contain `IpfsHash`.",
    });
  }

  return cid;
}

export async function generateMerkleCampaign({
  csvFile,
  decimals,
  outputDir,
  pinataJwt,
  fetchImpl = fetch,
  pinataApiUrl = process.env.PINATA_API_URL ?? DEFAULT_PINATA_API_URL,
}) {
  const { artifactPath, payload } = await buildCampaignArtifact({ csvFile, decimals, outputDir });
  const cid = await pinJsonToPinata(payload, {
    pinataJwt,
    fetchImpl,
    pinataApiUrl,
    pinataMetadataName: basename(artifactPath),
  });

  return {
    root: payload.root,
    cid,
    total: payload.total_amount,
    recipients: payload.number_of_recipients.toString(),
    artifactPath,
  };
}

export function usage() {
  return `Usage:
  node generate-merkle-campaign.mjs --csv-file <path> --decimals <n> [--output-dir <path>] [--pinata-jwt <jwt>]

Required:
  --csv-file      Path to a CSV file with address,amount columns
  --decimals      Token decimals used to convert human-readable amounts to base units

Authentication:
  --pinata-jwt    Optional override for the PINATA_JWT environment variable

Output:
  Prints JSON to stdout with root, cid, total, recipients, and artifactPath`;
}

export async function runCli(argv = process.argv.slice(2), env = process.env) {
  const args = parseCliArguments(argv, env);
  if (args.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  const result = await generateMerkleCampaign(args);
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

const isCliEntrypoint =
  process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isCliEntrypoint) {
  try {
    await runCli();
  } catch (error) {
    if (error instanceof CliError) {
      process.stderr.write(`${JSON.stringify(error.payload, null, 2)}\n`);
      process.exitCode = error.exitCode;
    } else {
      process.stderr.write(
        `${JSON.stringify({ message: String(error?.message ?? error) }, null, 2)}\n`,
      );
      process.exitCode = 1;
    }
  }
}
