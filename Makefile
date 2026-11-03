SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

FE ?= build/tools/fe
OUT_DIR ?= build
TRACE_DIR ?= $(OUT_DIR)/traces
NODE ?= node
NPM ?= npm

.PHONY: help fmt check build test traces abi abi-check metadata-repro demo-deps demo verify

help:
	@echo "Targets: fmt check build test traces abi-check metadata-repro demo verify"
	@echo "Default Fe binary: $(FE) (downloaded and SHA-256 verified when absent)"

$(FE):
	./scripts/install-fe.sh "$@"

fmt: $(FE)
	"$(FE)" fmt gate --check --color never

check: $(FE)
	"$(FE)" check gate --color never

build: $(FE)
	mkdir -p "$(OUT_DIR)"
	"$(FE)" build gate --contract CalldataFirewall --profile release -O 2 \
		--emit bytecode,runtime-bytecode,abi,metadata \
		--out-dir "$(OUT_DIR)" --color never
	"$(FE)" build gate --contract Probe --profile release -O 2 \
		--emit bytecode,runtime-bytecode,abi \
		--out-dir "$(OUT_DIR)" --color never

test: $(FE)
	env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 \
		"$(FE)" test gate --jobs 1 --grouped --color never

traces: $(FE)
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
	rm -rf -- "$(OUT_DIR)/reproduced"
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
	"$(NPM)" --prefix demo ci --ignore-scripts --no-audit --no-fund

demo: abi-check demo-deps
	"$(NODE)" demo/run.mjs --artifacts "$(OUT_DIR)"

verify: fmt check build test abi-check metadata-repro traces demo
