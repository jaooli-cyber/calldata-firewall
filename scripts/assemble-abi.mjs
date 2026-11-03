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
if (!generated.some((entry) => entry.type === "constructor")) {
  throw new Error("generated ABI has no constructor");
}
if (generated.some((entry) => entry.type === "function" && entry.name === "execute")) {
  throw new Error("generated ABI unexpectedly contains execute; raw ABI assumptions changed");
}
if (
  fragment.length !== 1 ||
  fragment[0].type !== "function" ||
  fragment[0].name !== "execute"
) {
  throw new Error("function fragment must contain exactly execute");
}

const components = fragment[0].outputs?.[0]?.components ?? [];
const names = components.map((component) => component.name);
const expected = [
  "attempted",
  "succeeded",
  "failed",
  "success_bitmap",
  "last_returndata_len",
  "last_prefix_len",
  "last_prefix_word",
  "last_prefix_hash",
];
if (JSON.stringify(names) !== JSON.stringify(expected)) {
  throw new Error(`unexpected ForwardSummary components: ${names.join(",")}`);
}

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify([...generated, ...fragment], null, 2)}\n`);
