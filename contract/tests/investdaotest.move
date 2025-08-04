module dao_addr::InvestmentDAO_test {
    use std::string;
    use std::signer;
    use dao_addr::InvestmentDAO;

    #[test(account1 = @0x1, account2 = @0x2, account3 = @0x3)]
    public fun test_multiple_members_flow(account1: &signer, account2: &signer, account3: &signer) {
        // Initialize DAO once with DAO deployer account (account1)
        InvestmentDAO::init(account1);

        // Account1 creates a proposal
        let title1 = string::utf8(b"Proposal from account1");
        let desc1 = string::utf8(b"Description1");
        InvestmentDAO::create_proposal(account1, title1, desc1);

        // Account2 creates another proposal
        let title2 = string::utf8(b"Proposal from account2");
        let desc2 = string::utf8(b"Description2");
        InvestmentDAO::create_proposal(account2, title2, desc2);

        // Voting on first proposal by multiple accounts
        InvestmentDAO::vote_on_props(account1, 0, true);
        InvestmentDAO::vote_on_props(account2, 0, false);
        InvestmentDAO::vote_on_props(account3, 0, true);

        // Finalize first proposal by DAO account
        InvestmentDAO::finalize_props(account1, 0);

        // Voting on second proposal
        InvestmentDAO::vote_on_props(account1, 1, true);

        // Finalize second proposal - should fail due to quorum (less than MIN_VOTES)
        // Expecting test to fail due to abort, so handled outside Move tests normally
        // Here just call to demonstrate usage:
        InvestmentDAO::finalize_props(account1, 1);
    }

    #[test(account = @0x4)]
    public fun test_double_vote_aborts(account: &signer) {
        InvestmentDAO::init(account);
        let title = string::utf8(b"Double Vote Test");
        let desc = string::utf8(b"Description");
        InvestmentDAO::create_proposal(account, title, desc);
        InvestmentDAO::vote_on_props(account, 0, true);
        // This second vote will abort with code 2 (already voted)
        InvestmentDAO::vote_on_props(account, 0, true);
    }

    #[test(account = @0x5)]
    public fun test_finalize_without_quorum_aborts(account: &signer) {
        InvestmentDAO::init(account);
        let title = string::utf8(b"Finalize Quorum Test");
        let desc = string::utf8(b"Description");
        InvestmentDAO::create_proposal(account, title, desc);
        // Finalize called with votes less than quorum, will abort with code 3
        InvestmentDAO::finalize_props(account, 0);
    }
}
