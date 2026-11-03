SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
.NOTPARALLEL: verify release-evidence

FE ?= build/tools/fe
override OUT_DIR := build
override TRACE_DIR := build/traces
NODE ?= node
NPM ?= npm
EVIDENCE_TAG ?=
EVIDENCE_PRE_TAG ?= 0

.PHONY: help toolchain fmt check build test traces abi abi-check metadata-repro demo-deps demo verify release-evidence

help:
	@echo "Targets: fmt check build test traces abi-check metadata-repro demo verify release-evidence"
	@echo "Fe binary: $(FE) (official SHA-256 and version are always verified)"

$(FE):
	./scripts/install-fe.sh "$@"

toolchain: $(FE)
	./scripts/verify-fe.sh "$(FE)"

fmt: toolchain
	"$(FE)" fmt gate --check --color never

check: toolchain
	"$(FE)" check gate --color never

build: toolchain
	./scripts/safe-output-dir.sh "$(OUT_DIR)" >/dev/null
	rm -f -- \
		"$(OUT_DIR)/CalldataFirewall.bin" \
		"$(OUT_DIR)/CalldataFirewall.runtime.bin" \
		"$(OUT_DIR)/CalldataFirewall.abi.json" \
		"$(OUT_DIR)/CalldataFirewall.metadata.json" \
		"$(OUT_DIR)/CalldataFirewall.combined.abi.json" \
		"$(OUT_DIR)/Probe.bin" \
		"$(OUT_DIR)/Probe.runtime.bin" \
		"$(OUT_DIR)/Probe.abi.json"
	"$(FE)" build gate --contract CalldataFirewall --profile release -O 2 \
		--emit bytecode,runtime-bytecode,abi,metadata \
		--out-dir "$(OUT_DIR)" --color never
	"$(FE)" build gate --contract Probe --profile release -O 2 \
		--emit bytecode,runtime-bytecode,abi \
		--out-dir "$(OUT_DIR)" --color never

test: toolchain
	env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 \
		"$(FE)" test gate --jobs 1 --grouped --color never

traces: toolchain
	FE="$(FE)" OUT_DIR="$(TRACE_DIR)" ./scripts/verify-traces.sh

abi: build
	"$(NODE)" scripts/assemble-abi.mjs \
		"$(OUT_DIR)/CalldataFirewall.abi.json" \
		interfaces/CalldataFirewall.function.abi.json \
		"$(OUT_DIR)/CalldataFirewall.combined.abi.json"

abi-check: abi
	cmp "$(OUT_DIR)/CalldataFirewall.combined.abi.json" \
		interfaces/CalldataFirewall.abi.json

metadata-repro: build
	./scripts/safe-output-dir.sh --reset "$(OUT_DIR)/reproduced" >/dev/null
	"$(FE)" build \
		--from-metadata "$(OUT_DIR)/CalldataFirewall.metadata.json" \
		--emit bytecode,runtime-bytecode,abi \
		--out-dir "$(OUT_DIR)/reproduced" --color never
	cmp "$(OUT_DIR)/CalldataFirewall.bin" \
		"$(OUT_DIR)/reproduced/CalldataFirewall.bin"
	cmp "$(OUT_DIR)/CalldataFirewall.runtime.bin" \
		"$(OUT_DIR)/reproduced/CalldataFirewall.runtime.bin"
	cmp "$(OUT_DIR)/CalldataFirewall.abi.json" \
		"$(OUT_DIR)/reproduced/CalldataFirewall.abi.json"

demo-deps:
	@test ! -L demo/node_modules || { echo "refusing symlinked demo/node_modules" >&2; exit 1; }
	"$(NPM)" --prefix demo ci --ignore-scripts --no-audit --no-fund

demo: abi-check demo-deps
	"$(NODE)" demo/run.mjs --artifacts "$(OUT_DIR)"

verify: fmt check build test abi-check metadata-repro traces demo

release-evidence:
	@test -n "$(EVIDENCE_TAG)" || { \
		echo "usage: make release-evidence EVIDENCE_TAG=fe-014-submission-v2" >&2; exit 1; }
	EVIDENCE_PRE_TAG="$(EVIDENCE_PRE_TAG)" \
		./scripts/release-evidence.sh "$(EVIDENCE_TAG)"
