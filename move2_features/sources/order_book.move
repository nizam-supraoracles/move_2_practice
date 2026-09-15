module move2_addr::order_book {

    // A small order-book contract used as a showcase of Move 2.x language
    // features (beyond function values, which live in ../function_value).
    // Each feature used below is called out in a comment next to its first use.

    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;

    /// Only the module owner may call admin/entry functions.
    const E_NOT_OWNER: u64 = 1;
    /// Referenced order id does not exist.
    const E_ORDER_NOT_FOUND: u64 = 2;
    /// `skus` / `quantities` / `prices` vectors must be the same length.
    const E_LENGTH_MISMATCH: u64 = 3;

    // Positional struct (Move 2.0): a lightweight newtype wrapping a raw SKU id.
    struct Sku(u64) has copy, drop, store;

    // Struct/enum visibility modifiers + variant data layouts (Move 2.0 / 2.4):
    // each variant can carry its own, differently shaped, data.
    public enum OrderStatus has copy, drop, store {
        Pending,
        Shipped { tracking_id: u64 },
        Cancelled { reason: vector<u8> },
    }

    struct LineItem has copy, drop, store {
        sku: Sku,
        quantity: u64,
        unit_price: u64,
    }

    struct Order has store, drop {
        id: u64,
        items: vector<LineItem>,
        status: OrderStatus,
        // Signed integer (Move 2.3): a discount (negative) or surcharge (positive)
        // applied on top of the line-item total.
        adjustment: i64,
    }

    struct Ledger has key {
        orders: Table<u64, Order>,
        next_id: u64,
    }

    #[event]
    struct OrderPlaced has drop, store { id: u64, total: u64 }

    #[event]
    struct OrderStatusChanged has drop, store { id: u64 }

    #[event]
    struct OrderClosed has drop, store { id: u64, net_total: i64 }

    fun init_module(owner: &signer) {
        move_to(owner, Ledger { orders: table::new(), next_id: 0 });
    }

    // Receiver-style function (Move 2.0): lets callers write `sku.code()`
    // instead of `order_book::code(&sku)`. Field access on a positional
    // struct uses `.0`.
    public fun code(self: &Sku): u64 { self.0 }

    // Receiver-style function computing a total from an order's line items.
    public fun total(self: &Order): u64 {
        let sum = 0u64;
        let i = 0u64;
        let len = self.items.length();
        // Loop labels (Move 2.1): gives `break`/`continue` an explicit target,
        // which matters once loops are nested (see `shipping_fee` callers/tests).
        'scan: loop {
            if (i >= len) break 'scan;
            let item = self.items.borrow(i);
            sum += item.unit_price * item.quantity; // compound assignment (Move 2.1)
            i += 1;
        };
        sum
    }

    // Match expression extensions (Move 2.4): range patterns over a primitive.
    public fun shipping_fee(quantity: u64): u64 {
        match (quantity) {
            0 => 0,
            1..=5 => 10,
            6..=20 => 20,
            _ => 50,
        }
    }

    // Package visibility (Move 2.0): callable from any module in this
    // package, but not exported outside it.
    public(package) fun allocate_id(self: &mut Ledger): u64 {
        let id = self.next_id;
        self.next_id += 1;
        id
    }

    // Underscore wildcards (Move 2.1): two independent `_` parameters no
    // longer collide as duplicate bindings, so a stub/no-op signature like
    // this is legal.
    public(package) fun waive_fee(_quantity: u64, _distance: u64): u64 { 0 }

    // Comparison operations extended to all types (Move 2.2): `<` here
    // compares two `Sku` values directly, not just primitives.
    public fun cheaper(a: Sku, b: Sku): bool { a < b }

    // This function keeps an explicit `acquires Ledger` for contrast with the
    // functions below, which omit it and let the compiler infer it
    // (Optional Acquires, Move 2.2).
    public entry fun place_order(
        owner: &signer,
        skus: vector<u64>,
        quantities: vector<u64>,
        prices: vector<u64>,
    ) acquires Ledger {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        assert!(
            skus.length() == quantities.length() && quantities.length() == prices.length(),
            E_LENGTH_MISMATCH,
        );
        // Optional assert codes (Move 2.0): omitting the code gives a default abort code.
        assert!(!skus.is_empty());

        let items = vector[];
        let i = 0u64;
        let len = skus.length();
        'build: loop {
            if (i >= len) break 'build;
            items.push_back(LineItem {
                sku: Sku(*skus.borrow(i)),
                quantity: *quantities.borrow(i),
                unit_price: *prices.borrow(i),
            });
            i += 1;
        };

        let ledger = borrow_global_mut<Ledger>(@move2_addr);
        let id = ledger.allocate_id();
        let order = Order { id, items, status: OrderStatus::Pending, adjustment: 0 };
        let order_total = order.total();
        ledger.orders.add(id, order);

        event::emit(OrderPlaced { id, total: order_total });
    }

    // `acquires Ledger` omitted here on purpose: the compiler infers it
    // from the `borrow_global_mut<Ledger>` call below (Move 2.2).
    public entry fun ship_order(owner: &signer, id: u64, tracking_id: u64) {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        let ledger = borrow_global_mut<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let order = ledger.orders.borrow_mut(id);
        order.status = OrderStatus::Shipped { tracking_id };
        event::emit(OrderStatusChanged { id });
    }

    public entry fun cancel_order(owner: &signer, id: u64, reason: vector<u8>) {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        let ledger = borrow_global_mut<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let order = ledger.orders.borrow_mut(id);
        order.status = OrderStatus::Cancelled { reason };
        event::emit(OrderStatusChanged { id });
    }

    public entry fun apply_adjustment(owner: &signer, id: u64, delta: i64) {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        let ledger = borrow_global_mut<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let order = ledger.orders.borrow_mut(id);
        order.adjustment += delta; // compound assignment on a signed integer
    }

    // Removes an order from storage and destructures it with a dot-dot
    // pattern (Move 2.0): only `id` is needed, every other field is dropped
    // via `..` instead of being named individually.
    public entry fun close_order(owner: &signer, id: u64) {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        let ledger = borrow_global_mut<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let removed = ledger.orders.remove(id);
        let net = (removed.total() as i64) + removed.adjustment; // cast syntax (Move 2.0)
        let Order { id: closed_id, .. } = removed;
        event::emit(OrderClosed { id: closed_id, net_total: net });
    }

    #[view]
    public fun get_total(id: u64): u64 acquires Ledger {
        let ledger = borrow_global<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        ledger.orders.borrow(id).total()
    }

    #[view]
    public fun net_total(id: u64): i64 acquires Ledger {
        let ledger = borrow_global<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let order = ledger.orders.borrow(id);
        (order.total() as i64) + order.adjustment
    }

    // Match expression extensions (Move 2.4): matching on a reference to an
    // enum, binding out the payload of the active variant.
    #[view]
    public fun status_label(id: u64): vector<u8> acquires Ledger {
        let ledger = borrow_global<Ledger>(@move2_addr);
        assert!(ledger.orders.contains(id), E_ORDER_NOT_FOUND);
        let order = ledger.orders.borrow(id);
        match (&order.status) {
            OrderStatus::Pending => b"pending",
            OrderStatus::Shipped { tracking_id: _ } => b"shipped",
            OrderStatus::Cancelled { reason } => *reason,
        }
    }

    #[test_only]
    public fun init_module_test(owner: &signer) {
        assert!(signer::address_of(owner) == @move2_addr, E_NOT_OWNER);
        init_module(owner);
    }

    #[test_only]
    public fun sku_for_test(code: u64): Sku { Sku(code) }
}
