import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const [generatedPath, fragmentPath, outputPath] = process.argv.slice(2);
if (!generatedPath || !fragmentPath || !outputPath) {
  throw new Error(
    "usage: node scripts/assemble-abi.mjs GENERATED_ABI FUNCTION_FRAGMENT OUTPUT",
  );
}

const readArray = (file) => {
  const value = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!Array.isArray(value)) throw new Error(`${file}: ABI root must be an array`);
  return value;
};

const generated = readArray(generatedPath);
const fragment = readArray(fragmentPath);
const constructor = {
  type: "constructor",
  inputs: [
    { name: "configured_caller", type: "address" },
    { name: "configured_target", type: "address" },
    { name: "configured_count", type: "uint8" },
    { name: "configured_selector0", type: "uint32" },
    { name: "configured_selector1", type: "uint32" },
    { name: "configured_selector2", type: "uint32" },
  ],
  stateMutability: "nonpayable",
};
const expectedErrors = [
  { type: "error", name: "InvalidPolicy", inputs: [] },
  { type: "error", name: "ReentrantExecution", inputs: [] },
  { type: "error", name: "UnauthorizedCaller", inputs: [] },
  { type: "error", name: "InvalidEnvelope", inputs: [] },
  { type: "error", name: "InvalidTarget", inputs: [] },
  { type: "error", name: "PolicyTargetMismatch", inputs: [] },
  {
    type: "error",
    name: "InvalidGasLimit",
    inputs: [{ name: "supplied", type: "uint256" }],
  },
  {
    type: "error",
    name: "InvalidCallCount",
    inputs: [{ name: "supplied", type: "uint256" }],
  },
  {
    type: "error",
    name: "NonCanonicalOffset",
    inputs: [{ name: "index", type: "uint32" }],
  },
  {
    type: "error",
    name: "OversizedCall",
    inputs: [
      { name: "index", type: "uint32" },
      { name: "supplied", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "OversizedBatch",
    inputs: [{ name: "supplied", type: "uint256" }],
  },
  { type: "error", name: "NonCanonicalEnd", inputs: [] },
  {
    type: "error",
    name: "ShortCall",
    inputs: [
      { name: "index", type: "uint32" },
      { name: "supplied", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "DisallowedSelector",
    inputs: [
      { name: "index", type: "uint32" },
      { name: "supplied", type: "uint32" },
    ],
  },
  {
    type: "error",
    name: "NonZeroPadding",
    inputs: [{ name: "index", type: "uint32" }],
  },
  {
    type: "error",
    name: "InsufficientForwardGas",
    inputs: [{ name: "index", type: "uint32" }],
  },
];
const execute = {
  type: "function",
  name: "execute",
  inputs: [
    { name: "target", type: "address" },
    { name: "gas_limit", type: "uint256" },
    { name: "calls", type: "bytes[]" },
  ],
  outputs: [
    {
      name: "",
      type: "tuple",
      components: [
        { name: "attempted", type: "uint64" },
        { name: "succeeded", type: "uint64" },
        { name: "failed", type: "uint64" },
        { name: "success_bitmap", type: "uint256" },
        { name: "last_returndata_len", type: "uint256" },
        { name: "last_prefix_len", type: "uint64" },
        { name: "last_prefix_word", type: "uint256" },
        { name: "last_prefix_hash", type: "bytes32" },
      ],
    },
  ],
  stateMutability: "nonpayable",
};

assert.equal(
  generated.filter((entry) => entry.type === "constructor").length,
  1,
  "generated ABI must contain exactly one constructor",
);
assert.deepStrictEqual(
  generated.find((entry) => entry.type === "constructor"),
  constructor,
  "generated constructor schema drifted",
);
assert.ok(
  generated.every((entry) => entry.type === "constructor" || entry.type === "error"),
  "generated ABI contains an unexpected entry type",
);
const byName = (left, right) => left.name.localeCompare(right.name);
assert.deepStrictEqual(
  generated.filter((entry) => entry.type === "error").sort(byName),
  expectedErrors.sort(byName),
  "generated custom-error schema drifted",
);
assert.deepStrictEqual(
  fragment,
  [execute],
  "raw execute fragment must match the complete expected ABI schema",
);

const repository = process.cwd();
const buildRoot = path.resolve(repository, "build");
const resolvedOutput = path.resolve(repository, outputPath);
if (
  resolvedOutput !== buildRoot &&
  !resolvedOutput.startsWith(`${buildRoot}${path.sep}`)
) {
  throw new Error(`combined ABI output must stay under build/: ${resolvedOutput}`);
}
fs.mkdirSync(path.dirname(resolvedOutput), { recursive: true });
fs.writeFileSync(
  resolvedOutput,
  `${JSON.stringify([...generated, ...fragment], null, 2)}\n`,
);
