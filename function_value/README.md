# Function Value

This repository demonstrates testing of Move 2 "function value" (function pointer) features with a simple VRF-like request/response flow.

## Structure

- `function_value/supra_vrf/`
  - [`Move.toml`](function_value/supra_vrf/Move.toml)
  - [`sources/supra_vrf.move`](function_value/supra_vrf/sources/supra_vrf.move) — VRF admin module (emits `RngRequest` events, stores client callback, and calls callback with randomness).
- `function_value/client/`
  - [`Move.toml`](function_value/client/Move.toml)
  - [`sources/client.move`](function_value/client/sources/client.move) — example client module that requests randomness and implements a persistent callback.
  - [`tests/client_test.move`](function_value/client/tests/client_test.move) — unit test exercising the full flow.

## What it demonstrates

- Using function values / function pointers to store a client callback on-chain: see [`supra_addr::supra_vrf::StoreClientFun`](function_value/supra_vrf/sources/supra_vrf.move) and [`client_addr::client::callback_function`](function_value/client/sources/client.move).
- Emitting events for off-chain relayers: [`supra_addr::supra_vrf::RngRequest`](function_value/supra_vrf/sources/supra_vrf.move).
- Simple on-chain request nonce management: [`supra_addr::supra_vrf::VRFConfig`](function_value/supra_vrf/sources/supra_vrf.move).
- Using `smart_table::SmartTable` in the client for nonce -> random value storage: [`client_addr::client::RandomNumber`](function_value/client/sources/client.move).

## Notes / Suggested improvements

- Decide whether callbacks should be updated/overwritten per-request or stored per-nonce to support multiple outstanding requests per client. See [`supra_addr::supra_vrf::rng_request`](function_value/supra_vrf/sources/supra_vrf.move) and [`supra_addr::supra_vrf::StoreClientFun`](function_value/supra_vrf/sources/supra_vrf.move).  

## Compile Code

- Run client tests:
```sh
aptos move compile --package-dir supra_vrf

aptos move compile --package-dir client
```

## Run tests

Use your Aptos/Move toolchain to run package unit tests. Example (tooling may vary):

- Run client tests:
```sh
aptos move test --package-dir client
```