module client_addr::client {

    // Example client module showing how to request randomness from supra_vrf
    // and receive the result via a callback function stored on-chain.

    use aptos_std::smart_table;
    use aptos_std::signer;
    use supra_addr::supra_vrf;

    /// Unauthorized caller error: only the module owner/address may call certain functions.
    const E_UNAUTHORISED_CALLER: u64 = 1;

    /// Invalid nonce error: callback provided a nonce that was not requested/stored.
    const E_INVALID_NONCE: u64 = 2;

    // Stores mapping of request nonce -> random value for this client.
    struct RandomNumber has key {
        /// Request nonce <-> Random Number
        list: smart_table::SmartTable<u64, u256>
    }

    // Initialize the client's storage (to be called during contract deployment).
    fun init_module(client: &signer) {
        move_to(client, RandomNumber { list: smart_table::new() })
    }

    // Entry function to request a nonce / random number from supra_vrf.
    // - Ensures only the client account itself can call this (simple access control).
    // - Registers a local callback function pointer that supra_vrf will call later.
    // - Stores a default value (0) for the request nonce so the callback can verify validity.
    public entry fun request_nonce(client: &signer) acquires RandomNumber {
        assert!(signer::address_of(client) == @client_addr, E_UNAUTHORISED_CALLER);

        // Construct a function pointer to the local callback implementation.
        let callback_function: |u64, u256| bool has store + copy + drop = |nonce, random_number| callback_function(nonce, random_number);

        // Make RNG request to supra_vrf; this will emit an event and persist the callback on the client's address.
        let request_nonce = supra_vrf::rng_request(client, callback_function);

        let fetch_list = borrow_global_mut<RandomNumber>(@client_addr);

        // Default random number stored as 0 until the callback updates it.
        fetch_list.list.add(request_nonce, 0);
    }

    // Persistent callback that supra_vrf will call with (nonce, random_number).
    // - Validates the nonce exists and then upserts the random value into storage.
    #[persistent] public fun callback_function(nonce: u64, random_number: u256): bool acquires RandomNumber {
        let fetch_list = borrow_global_mut<RandomNumber>(@client_addr);
        assert!(fetch_list.list.contains(nonce), E_INVALID_NONCE);
        fetch_list.list.upsert(nonce, random_number);

        // TODO : needs to remove reponse argument later
        true
    }

    #[view]
    public fun get_nonce(nonce: u64): u256 {
        let fetch_list = borrow_global<RandomNumber>(@client_addr);
        assert!(fetch_list.list.contains(nonce), E_INVALID_NONCE);
        *fetch_list.list.borrow(nonce)
    }

    #[test_only]
    public fun init_module_test(client: &signer) {
        assert!(signer::address_of(client) == @client_addr, E_UNAUTHORISED_CALLER);
        init_module(client);
    }
}
