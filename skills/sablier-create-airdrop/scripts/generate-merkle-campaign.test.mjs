import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import {
  CliError,
  buildCampaignArtifact,
  generateMerkleCampaign,
  pinJsonToPinata,
} from "./generate-merkle-campaign.mjs";

const execFileAsync = promisify(execFile);
const thisDirectory = dirname(fileURLToPath(import.meta.url));

async function writeTempCsv(contents) {
  const directory = await mkdtemp(join(tmpdir(), "sablier-airdrop-test-"));
  const csvFile = join(directory, "recipients.csv");
  await writeFile(csvFile, contents);
  return { directory, csvFile };
}

function mockFetch(responseInit) {
  return async (url, options) => {
    assert.equal(url, "https://api.pinata.cloud/pinning/pinJSONToIPFS");
    assert.equal(options.method, "POST");
    return {
      ok: responseInit.ok,
      status: responseInit.status,
      async text() {
        return responseInit.body;
      },
    };
  };
}

async function assertCliError(promiseFactory, expectedPayload) {
  await assert.rejects(promiseFactory, (error) => {
    assert.ok(error instanceof CliError);
    assert.deepEqual(error.payload, expectedPayload);
    return true;
  });
}

test("buildCampaignArtifact validates a valid CSV and produces a stable root", async () => {
  const { directory, csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  const { artifactPath, payload } = await buildCampaignArtifact({
    csvFile,
    decimals: 2,
    outputDir: directory,
  });

  assert.equal(payload.total_amount, "30000");
  assert.equal(payload.number_of_recipients, 2);
  assert.equal(payload.root, "0x9aa5d0eb7a1350d03d053f55c4e2f31d07a7bc80c5ab23e4036e81270facfd18");
  assert.equal(payload.recipients[0].address, "0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491");
  assert.equal(payload.recipients[1].amount, "20000");

  const artifact = JSON.parse(await readFile(artifactPath, "utf8"));
  assert.equal(artifact.root, payload.root);
  assert.equal(artifact.total_amount, "30000");

  const treeDump = JSON.parse(payload.merkle_tree);
  assert.equal(treeDump.format, "standard-v1");
  assert.deepEqual(treeDump.leafEncoding, ["uint", "address", "uint256"]);
});

test("buildCampaignArtifact rejects an invalid header", async () => {
  const { csvFile } = await writeTempCsv(`address,amount_invalid
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: [
        "Row 1: CSV header invalid. The csv header should contain `amount` column. The amount column id missing",
      ],
    },
  );
});

test("buildCampaignArtifact rejects missing columns", async () => {
  const { csvFile } = await writeTempCsv(`address
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: ["Row 1: Insufficient columns"],
    },
  );
});

test("buildCampaignArtifact rejects an invalid address", async () => {
  const { csvFile } = await writeTempCsv(`address,amount
0xThisIsNotAnAddress,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: [
        "Row 2: Invalid Ethereum address",
        "Row 1: An airdrop campaign must have at least 2 recipients",
      ],
    },
  );
});

test("buildCampaignArtifact rejects duplicate addresses case-insensitively", async () => {
  const { csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0x9AD7cad4f10d0C3F875b8A2fD292590490C9F491,200.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: [
        "Row 3: Each recipient should have an unique address. This address was already specified in file",
        "Row 1: An airdrop campaign must have at least 2 recipients",
      ],
    },
  );
});

test("buildCampaignArtifact rejects a zero amount", async () => {
  const { csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: [
        "Row 2: The amount cannot be 0",
        "Row 1: An airdrop campaign must have at least 2 recipients",
      ],
    },
  );
});

test("buildCampaignArtifact rejects too many decimal places", async () => {
  const { csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,1.1234
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: [
        "Row 2: Amounts should be positive, in normal notation, with an optional decimal point and a maximum number of decimals as provided by the query parameter.",
        "Row 1: An airdrop campaign must have at least 2 recipients",
      ],
    },
  );
});

test("buildCampaignArtifact requires at least two recipients", async () => {
  const { csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
`);

  await assertCliError(
    () => buildCampaignArtifact({ csvFile, decimals: 2 }),
    {
      status: "Invalid csv file.",
      errors: ["Row 1: An airdrop campaign must have at least 2 recipients"],
    },
  );
});

test("pinJsonToPinata returns the CID on success", async () => {
  const cid = await pinJsonToPinata(
    { foo: "bar" },
    {
      pinataJwt: "test-jwt",
      fetchImpl: mockFetch({
        ok: true,
        status: 200,
        body: JSON.stringify({ IpfsHash: "bafy-test" }),
      }),
    },
  );

  assert.equal(cid, "bafy-test");
});

test("pinJsonToPinata surfaces invalid JWT errors", async () => {
  await assertCliError(
    () =>
      pinJsonToPinata(
        { foo: "bar" },
        {
          pinataJwt: "bad-jwt",
          fetchImpl: mockFetch({
            ok: false,
            status: 401,
            body: JSON.stringify({ error: "Unauthorized" }),
          }),
        },
      ),
    {
      message:
        "Pinata rejected the upload with HTTP 401. The provided `PINATA_JWT` is invalid or expired. Check the JWT at https://app.pinata.cloud/developers/api-keys",
    },
  );
});

test("generateMerkleCampaign returns CLI-ready JSON", async () => {
  const { directory, csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  const result = await generateMerkleCampaign({
    csvFile,
    decimals: 2,
    outputDir: directory,
    pinataJwt: "test-jwt",
    fetchImpl: mockFetch({
      ok: true,
      status: 200,
      body: JSON.stringify({ IpfsHash: "bafy-test" }),
    }),
  });

  assert.equal(result.cid, "bafy-test");
  assert.equal(result.total, "30000");
  assert.equal(result.recipients, "2");
  assert.equal(result.root, "0x9aa5d0eb7a1350d03d053f55c4e2f31d07a7bc80c5ab23e4036e81270facfd18");
});

test("CLI runbook works end-to-end against a mocked Pinata endpoint", async () => {
  const { directory, csvFile } = await writeTempCsv(`address,amount
0x9ad7CAD4F10D0c3f875b8a2fd292590490c9f491,100.0
0xf976aF93B0A5A9F55A7f285a3B5355B8575Eb5bc,200.0
`);

  let requestBody = "";
  const server = createServer((request, response) => {
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      requestBody += chunk;
    });
    request.on("end", () => {
      assert.equal(request.method, "POST");
      assert.equal(request.headers.authorization, "Bearer test-jwt");
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ IpfsHash: "bafy-cli-test" }));
    });
  });

  await new Promise((resolvePromise) => {
    server.listen(0, "127.0.0.1", resolvePromise);
  });

  const address = server.address();
  const { stdout } = await execFileAsync(
    "node",
    [
      "generate-merkle-campaign.mjs",
      "--csv-file",
      csvFile,
      "--decimals",
      "2",
      "--output-dir",
      directory,
    ],
    {
      cwd: thisDirectory,
      env: {
        ...process.env,
        PINATA_JWT: "test-jwt",
        PINATA_API_URL: `http://${address.address}:${address.port}/pinning/pinJSONToIPFS`,
      },
    },
  );

  await new Promise((resolvePromise, rejectPromise) => {
    server.close((error) => {
      if (error) {
        rejectPromise(error);
        return;
      }
      resolvePromise();
    });
  });

  const parsed = JSON.parse(stdout);
  assert.equal(parsed.cid, "bafy-cli-test");
  assert.equal(parsed.recipients, "2");
  assert.match(requestBody, /"pinataContent"/);
});
