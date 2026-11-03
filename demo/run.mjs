import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { Common, Hardfork, Mainnet } from "@ethereumjs/common";
import {
  bytesToHex,
  createAddressFromString,
  hexToBytes,
} from "@ethereumjs/util";
import { createVM } from "@ethereumjs/vm";
import { AbiCoder, Interface, keccak256 } from "ethers";

const argumentIndex = process.argv.indexOf("--artifacts");
const artifacts = path.resolve(
  process.cwd(),
  argumentIndex === -1 ? "build" : process.argv[argumentIndex + 1],
);

const readText = (name) =>
  fs.readFileSync(path.join(artifacts, name), "utf8").trim();
const readJson = (name) => JSON.parse(readText(name));
const readBytecode = (name) => `0x${readText(name)}`;

const firewallInterface = new Interface(
  readJson("CalldataFirewall.combined.abi.json"),
);
const probeInterface = new Interface(readJson("Probe.abi.json"));
assert.equal(
  firewallInterface.getFunction("execute").selector,
  "0x7bd5292b",
  "execute selector drifted",
);
const authorized = createAddressFromString(
  "0x1000000000000000000000000000000000000001",
);
const unauthorized = createAddressFromString(
  "0x2000000000000000000000000000000000000002",
);

const common = new Common({ chain: Mainnet, hardfork: Hardfork.Cancun });
const vm = await createVM({ common });
let activeMessages;
vm.evm.events.on("beforeMessage", (message) => {
  if (activeMessages !== undefined && message.depth > 0 && message.to) {
    activeMessages.push({
      depth: message.depth,
      to: message.to.toString().toLowerCase(),
    });
  }
});

const execute = async ({ to, caller, data, gasLimit = 8_000_000n }) => {
  activeMessages = [];
  const result = await vm.evm.runCall({
    to,
    caller,
    origin: caller,
    data: hexToBytes(data),
    gasLimit,
    value: 0n,
  });
  const messages = activeMessages;
  activeMessages = undefined;
  return { result, messages };
};

const deploy = async (initcode, caller = authorized) => {
  const { result } = await execute({
    caller,
    data: initcode,
    gasLimit: 30_000_000n,
  });
  assert.equal(
    result.execResult.exceptionError,
    undefined,
    `deployment failed: ${result.execResult.exceptionError?.error ?? "unknown"} ${bytesToHex(result.execResult.returnValue)}`,
  );
  assert.ok(result.createdAddress, "deployment returned no address");
  const code = await vm.stateManager.getCode(result.createdAddress);
  assert.ok(code.length > 0, "deployment stored no runtime code");
  return result.createdAddress;
};

const probe = await deploy(readBytecode("Probe.bin"));
const alternateProbe = await deploy(readBytecode("Probe.bin"));
const hitData = probeInterface.encodeFunctionData("hit");
const failData = probeInterface.encodeFunctionData("fail");
const hitSelector = BigInt(probeInterface.getFunction("hit").selector);
const failSelector = BigInt(probeInterface.getFunction("fail").selector);
const constructorArgs = AbiCoder.defaultAbiCoder().encode(
  ["address", "address", "uint8", "uint32", "uint32", "uint32"],
  [
    authorized.toString(),
    probe.toString(),
    2,
    hitSelector,
    failSelector,
    0,
  ],
);
const firewall = await deploy(
  `${readBytecode("CalldataFirewall.bin")}${constructorArgs.slice(2)}`,
);

const targetAddresses = new Set([
  probe.toString().toLowerCase(),
  alternateProbe.toString().toLowerCase(),
]);
const targetMessageCount = (messages) =>
  messages.filter((message) => targetAddresses.has(message.to)).length;

const acceptedData = firewallInterface.encodeFunctionData("execute", [
  probe.toString(),
  200_000n,
  [hitData, failData, hitData],
]);
const accepted = await execute({
  to: firewall,
  caller: authorized,
  data: acceptedData,
});
assert.equal(accepted.result.execResult.exceptionError, undefined);
assert.equal(targetMessageCount(accepted.messages), 3);
const [summary] = firewallInterface.decodeFunctionResult(
  "execute",
  bytesToHex(accepted.result.execResult.returnValue),
);
assert.deepEqual(
  Array.from(summary),
  [
    3n,
    2n,
    1n,
    0b101n,
    32n,
    32n,
    2n,
    keccak256(AbiCoder.defaultAbiCoder().encode(["uint256"], [2n])),
  ],
);

const expectRevert = async ({
  label,
  caller,
  target,
  calls,
  expectedName,
  expectedArgs = [],
}) => {
  const data = firewallInterface.encodeFunctionData("execute", [
    target,
    200_000n,
    calls,
  ]);
  const execution = await execute({ to: firewall, caller, data });
  assert.ok(
    execution.result.execResult.exceptionError,
    `${label}: expected revert`,
  );
  assert.equal(
    targetMessageCount(execution.messages),
    0,
    `${label}: target CALL occurred before rejection`,
  );
  const parsed = firewallInterface.parseError(
    bytesToHex(execution.result.execResult.returnValue),
  );
  assert.equal(parsed?.name, expectedName, `${label}: wrong custom error`);
  assert.deepEqual(
    Array.from(parsed.args),
    expectedArgs,
    `${label}: wrong error arguments`,
  );
  return {
    label,
    error: parsed.name,
    targetCalls: 0,
  };
};

const rejected = [];
rejected.push(
  await expectRevert({
    label: "unauthorized caller",
    caller: unauthorized,
    target: probe.toString(),
    calls: [hitData],
    expectedName: "UnauthorizedCaller",
  }),
);
rejected.push(
  await expectRevert({
    label: "configured-target mismatch",
    caller: authorized,
    target: alternateProbe.toString(),
    calls: [hitData],
    expectedName: "PolicyTargetMismatch",
  }),
);
rejected.push(
  await expectRevert({
    label: "last selector denied after an allowed first item",
    caller: authorized,
    target: probe.toString(),
    calls: [hitData, "0xdeadbeef"],
    expectedName: "DisallowedSelector",
    expectedArgs: [1n, 0xdeadbeefn],
  }),
);

const hitsCall = await execute({
  to: probe,
  caller: authorized,
  data: probeInterface.encodeFunctionData("hits"),
});
assert.equal(hitsCall.result.execResult.exceptionError, undefined);
const [hits] = probeInterface.decodeFunctionResult(
  "hits",
  bytesToHex(hitsCall.result.execResult.returnValue),
);
assert.equal(hits, 2n, "rejected batches changed target state");
const shanghaiCommon = new Common({
  chain: Mainnet,
  hardfork: Hardfork.Shanghai,
});
const shanghaiVm = await createVM({ common: shanghaiCommon });
const deployOnShanghai = async (initcode) => {
  const result = await shanghaiVm.evm.runCall({
    caller: authorized,
    origin: authorized,
    data: hexToBytes(initcode),
    gasLimit: 30_000_000n,
    value: 0n,
  });
  assert.equal(result.execResult.exceptionError, undefined);
  assert.ok(result.createdAddress);
  return result.createdAddress;
};
const shanghaiProbe = await deployOnShanghai(readBytecode("Probe.bin"));
const shanghaiArgs = AbiCoder.defaultAbiCoder().encode(
  ["address", "address", "uint8", "uint32", "uint32", "uint32"],
  [
    authorized.toString(),
    shanghaiProbe.toString(),
    2,
    hitSelector,
    failSelector,
    0,
  ],
);
const shanghaiDeployment = await shanghaiVm.evm.runCall({
  caller: authorized,
  origin: authorized,
  data: hexToBytes(
    `${readBytecode("CalldataFirewall.bin")}${shanghaiArgs.slice(2)}`,
  ),
  gasLimit: 30_000_000n,
  value: 0n,
});
assert.equal(
  shanghaiDeployment.execResult.exceptionError?.error,
  "invalid opcode",
  "Shanghai unexpectedly deployed transient-storage bytecode",
);

console.log(
  JSON.stringify(
    {
      project: "FE-014 Calldata Firewall",
      fork: "Cancun",
      preCancunNegative: "Shanghai deployment rejected: EIP-1153 unavailable",
      deployedViaInitcode: true,
      policy: {
        authorizedCaller: authorized.toString(),
        allowedTarget: probe.toString(),
        selectors: [
          probeInterface.getFunction("hit").selector,
          probeInterface.getFunction("fail").selector,
        ],
      },
      accepted: {
        attempted: summary.attempted.toString(),
        succeeded: summary.succeeded.toString(),
        failed: summary.failed.toString(),
        successBitmap: `0b${summary.success_bitmap.toString(2).padStart(3, "0")}`,
        targetCalls: targetMessageCount(accepted.messages),
        targetHits: hits.toString(),
      },
      rejected,
      note: "A bitmap bit records EVM CALL success only, not business success.",
    },
    null,
    2,
  ),
);
