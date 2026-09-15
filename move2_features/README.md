# Move 2.x Feature Showcase

A single-module "order book" contract used to exercise Move 2.x language
features that aren't covered by [`function_value`](../function_value/README.md)
(function values / persistent callbacks).

## Structure

- [`Move.toml`](Move.toml)
- [`sources/order_book.move`](sources/order_book.move) — the contract.
- [`tests/order_book_test.move`](tests/order_book_test.move) — unit tests exercising every entry/view function.

## What it demonstrates

Each feature is called out with an inline comment at its first use in [`order_book.move`](sources/order_book.move). Summary, by version:

**Move 2.0**
- Positional structs — `Sku(u64)`, with `.0` field access.
- Struct/enum variant data layouts — `OrderStatus` (`Pending` / `Shipped { .. }` / `Cancelled { .. }`).
- Receiver-style (dot) function calls — `sku.code()`, `order.total()`, `ledger.allocate_id()`.
- Package visibility — `public(package) fun allocate_id`.
- Optional assert codes — `assert!(!skus.is_empty())` in `place_order`.
- Dot-dot destructuring patterns — `let Order { id: closed_id, .. } = removed;` in `close_order`.
- Cast syntax — `(removed.total() as i64)`.

**Move 2.1**
- Compound assignments — `sum += ...`, `self.next_id += 1`, `order.adjustment += delta`.
- Loop labels — `'scan: loop { ... break 'scan; ... }` in `total`.
- Underscore wildcard parameters — `waive_fee(_quantity: u64, _distance: u64)`.

**Move 2.2**
- Optional `acquires` inference — omitted on `ship_order`, `cancel_order`, `apply_adjustment`, `close_order`, `net_total`, `status_label` (kept explicit on `place_order` and `get_total` for contrast).
- Comparison operators extended to non-primitive types — `cheaper(a: Sku, b: Sku): bool { a < b }`.

**Move 2.3**
- Signed integers — `Order.adjustment: i64`, used for discounts/surcharges.

**Move 2.4**
- `public enum` visibility modifier on `OrderStatus`.
- Match expression extensions — range patterns over `u64` in `shipping_fee`, and matching on a reference to an enum (binding out variant payloads) in `status_label`.

## Not implemented here

- **Index notation** (`v[i]`) — Move 2.0 lets stdlib/user types opt in via a `#[syntax(index)]` attribute on `borrow`/`borrow_mut`, but the `aptos` CLI/framework revision this package was built against (`aptos 9.5.1`, `AptosFramework` @ `mainnet`) does not recognize that attribute yet (`unknown attribute 'syntax'`). Code instead uses the always-available receiver-style `.borrow(i)` / `.push_back(..)`.
- **Builtin min/max constant accessors** (e.g. `u64::max_value()`) — no such function was found in the vendored `move-stdlib`/`aptos-std` for this toolchain, so it's left out rather than guessed at.

Both may already work on a newer `aptos` CLI / framework pairing — worth revisiting if you upgrade.

## Compile & test

```sh
aptos move compile --package-dir move2_features
aptos move test --package-dir move2_features
```
