#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { createRequire } from "node:module"
import path from "node:path"
import { fileURLToPath } from "node:url"

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const repositoryRoot = path.resolve(scriptDirectory, "../..")
const voyantRoot = path.join(repositoryRoot, "upstream/voyant")
const vitest = path.join(voyantRoot, "node_modules/.bin/vitest")
const databaseUrl = process.env.TEST_DATABASE_URL
const operatorRequire = createRequire(path.join(voyantRoot, "templates/operator/package.json"))
const { Client } = operatorRequire("pg")

if (!databaseUrl?.startsWith("postgresql://")) {
  throw new Error("TEST_DATABASE_URL must be a PostgreSQL URL scoped to module_voyant")
}
if (!existsSync(vitest)) {
  throw new Error(`Vendored Vitest executable is missing: ${vitest}`)
}

const scenarios = [
  {
    file: "packages/products/tests/integration/routes.test.ts",
    names: [
      "creates a product",
      "creates a new default itinerary without violating the unique default constraint",
    ],
  },
  {
    file: "packages/availability/tests/integration/routes.test.ts",
    names: ["creates a slot", "returns per-option-unit availability for a slot"],
  },
  {
    file: "packages/bookings/tests/integration/routes.test.ts",
    names: [
      "reserves a slot and creates on-hold allocations",
      "allows scoped non-staff booking status mutations through the capability guard",
    ],
  },
]

async function resetBusinessData() {
  const client = new Client({ connectionString: databaseUrl })
  await client.connect()
  try {
    const { rows } = await client.query(`
      SELECT quote_ident(table_schema) || '.' || quote_ident(table_name) AS qualified_name
      FROM information_schema.tables
      WHERE table_schema = current_schema()
        AND table_type = 'BASE TABLE'
        AND table_name <> '__drizzle_migrations'
      ORDER BY table_name
    `)
    if (rows.length > 0) {
      await client.query(
        `TRUNCATE TABLE ${rows.map((row) => row.qualified_name).join(", ")} RESTART IDENTITY CASCADE`,
      )
    }
  } finally {
    await client.end()
  }
}

let scenarioCount = 0
for (const scenario of scenarios) {
  for (const name of scenario.names) {
    await resetBusinessData()
    const result = spawnSync(
      vitest,
      ["run", scenario.file, "--testNamePattern", name, "--maxWorkers", "1"],
      {
        cwd: voyantRoot,
        env: { ...process.env, DB_ADAPTER: "node", KMS_PROVIDER: "env" },
        encoding: "utf8",
        timeout: 300_000,
      },
    )
    process.stdout.write(result.stdout ?? "")
    process.stderr.write(result.stderr ?? "")
    if (result.error) throw result.error
    if (result.status !== 0) {
      throw new Error(`Voyant business scenario failed: ${scenario.file} :: ${name}`)
    }
    if (!/Tests\s+1 passed/.test(`${result.stdout ?? ""}\n${result.stderr ?? ""}`)) {
      throw new Error(`Voyant business scenario did not execute exactly one test: ${scenario.file} :: ${name}`)
    }
    scenarioCount += 1
  }
}

console.log(JSON.stringify({ module: "tour", scenarios: scenarioCount, status: "passed" }))
