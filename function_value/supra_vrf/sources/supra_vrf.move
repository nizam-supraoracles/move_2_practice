module supra_addr::supra_vrf {
    // Module that demonstrates a simple VRF-like request/response flow with callbacks.
    // - Clients emit a request (RngRequest) and register a callback function.
    // - An admin (VRF FREE-node) later calls generate_rng_and_callback to provide randomness and
    //   invoke the stored client callback with the generated value.

    use aptos_std::signer;
    use aptos_framework::event;
    use aptos_framework::randomness;

    /// Unauthorized caller error: only the module owner/address may call certain functions.
    const E_UNAUTHORISED_CALLER: u64 = 1;

    // Event emitted when a client requests randomness. Off-chain vrf-node can listen for this.
    #[event]
    struct RngRequest has drop, store {
        nonce: u64,        // Unique request id (per VRFConfig)
        client_addr: address // Address of the requester (used to find the stored callback)
    }

    // Simple on-chain config to keep a monotonically increasing request nonce.
    struct VRFConfig has key {
        request_nonce: u64,
    }

    // Stores the client's callback function so the admin can call it later.
    // The function signature accepts (nonce, random_number).
    struct StoreClientFun has key, drop {
        callback_function: |&signer, u64, u256| has store + copy + drop
    }

    // Initialize module state. Should be called by module deployer/admin to create VRFConfig.
    fun init_module(admin: &signer) {
        move_to(admin, VRFConfig { request_nonce: 0})
    }

    // Client-facing API to request randomness.
    // - caller: signer making the request (client)
    // - callback_function: function pointer on the client module to invoke when result is ready
    // Returns the request nonce assigned to this request.
    // Acquires VRFConfig to increment and persist the nonce.
    public fun rng_request(caller: &signer, callback_function: |&signer, u64, u256| has store + copy + drop ): u64 acquires VRFConfig {
        let vrf_config = borrow_global_mut<VRFConfig>(@supra_addr);
        vrf_config.request_nonce += 1;

        let nonce = vrf_config.request_nonce;
        let client_addr = signer::address_of(caller);

        // Persist the callback function under the client's address so the admin can call it later.
        if (!exists<StoreClientFun>(client_addr)) {
            move_to(caller, StoreClientFun { callback_function });
        };

        // Emit an event so off-chain vrf-node can detect new requests.
        event::emit(RngRequest { nonce, client_addr });

        nonce
    }

    #[lint::allow_unsafe_randomness]
    // Admin function to generate (or supply) randomness and invoke the stored client callback.
    // - admin: signer authorized to call this
    // - client_addr: address where the callback was stored (from the event)
    // - nonce: request id to correlate the response
    // Acquires StoreClientFun so it can read the stored callback function.
    public entry fun generate_rng_and_callback(admin: &signer, client_addr: address, nonce: u64) acquires StoreClientFun {

        assert!(signer::address_of(admin) == @supra_addr, E_UNAUTHORISED_CALLER);

        let data = borrow_global<StoreClientFun>(client_addr);

        // Generate Random number
        // Replace the following with a real randomness source when available:
        let random_number = randomness::u256_integer();
        
        // Using it as the static number for the test
        // let random_number = 10;

        // Call the client's callback function with (nonce, random_number).
        (data.callback_function)(admin, nonce, random_number);
    }

    #[test_only]
    public fun init_module_test(admin: &signer) {
        assert!(signer::address_of(admin) == @supra_addr, E_UNAUTHORISED_CALLER);
        init_module(admin);
    }
    
}
