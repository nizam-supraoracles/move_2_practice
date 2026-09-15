#[test_only]
module move2_addr::order_book_test {
    use std::signer;
    use aptos_framework::account;
    use move2_addr::order_book;

    fun setup(owner: &signer) {
        account::create_account_for_test(signer::address_of(owner));
        order_book::init_module_test(owner);
    }

    #[test(owner = @move2_addr)]
    fun test_place_ship_close(owner: &signer) {
        setup(owner);

        order_book::place_order(owner, vector[1, 2], vector[3, 1], vector[10, 50]);
        // total = 3*10 + 1*50 = 80
        assert_eq!(order_book::get_total(0), 80);
        assert_eq!(order_book::status_label(0), b"pending");

        order_book::ship_order(owner, 0, 555);
        assert_eq!(order_book::status_label(0), b"shipped");

        order_book::apply_adjustment(owner, 0, -30i64);
        assert_eq!(order_book::net_total(0), 50i64);

        order_book::close_order(owner, 0);
    }

    #[test(owner = @move2_addr)]
    fun test_cancel(owner: &signer) {
        setup(owner);

        order_book::place_order(owner, vector[7], vector[2], vector[25]);
        order_book::cancel_order(owner, 0, b"out of stock");
        assert_eq!(order_book::status_label(0), b"out of stock");
    }

    #[test]
    fun test_shipping_fee_tiers() {
        assert_eq!(order_book::shipping_fee(0), 0);
        assert_eq!(order_book::shipping_fee(3), 10);
        assert_eq!(order_book::shipping_fee(15), 20);
        assert_eq!(order_book::shipping_fee(100), 50);
    }

    #[test]
    fun test_sku_ordering() {
        assert!(order_book::cheaper(order_book::sku_for_test(1), order_book::sku_for_test(2)));
        assert!(!order_book::cheaper(order_book::sku_for_test(9), order_book::sku_for_test(2)));
    }

    #[test(owner = @0xBAD)]
    #[expected_failure(abort_code = 1, location = move2_addr::order_book)]
    fun test_unauthorized_caller(owner: &signer) {
        setup(owner);
        account::create_account_for_test(signer::address_of(owner));
        order_book::place_order(owner, vector[1], vector[1], vector[1]);
    }

    #[test(owner = @move2_addr)]
    #[expected_failure(abort_code = 2, location = move2_addr::order_book)]
    fun test_missing_order(owner: &signer) {
        setup(owner);
        order_book::ship_order(owner, 42, 1);
    }
}
