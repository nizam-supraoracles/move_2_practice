module client_addr::client_test {
    use aptos_std::signer;
    use aptos_framework::randomness;

    use client_addr::client;
    use supra_addr::supra_vrf;

    #[test(client = @client_addr, supra_admin = @supra_addr, aptos_framework = @aptos_framework)]
    fun test_supra_vrf_flow(client : &signer, supra_admin: &signer, aptos_framework: &signer) {
        
        // Initialise randomness
        randomness::initialize_for_testing(aptos_framework);

        client::init_module_test(client);
        supra_vrf::init_module_test(supra_admin);

        client::request_nonce(client);

        // initally we just requested random number so nonce is 1 and rng =0
        assert!(client::get_nonce(1) == 0, 0x101);

        let client_addr = signer::address_of(client);
        // now admin is calling is processing the rng and making callback transaction
        supra_vrf::generate_rng_and_callback(supra_admin, client_addr, 1);

        // now client is feching the random number which is supra is given
        let random_number = client::get_nonce(1);
        std::debug::print(&random_number);
        assert!(random_number > 0, 0x102);


    }
}