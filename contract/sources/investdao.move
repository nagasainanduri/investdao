module dao_addr::InvestmentDAO {
    use std::signer;
    use std::table;
    use std::string;
    use std::event;
    use std::timestamp;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;

    // Constants
    const MIN_VOTES: u64 = 10;
    const VOTING_PERIOD: u64 = 604800; // 7 days in seconds
    const EXECUTION_DELAY: u64 = 86400; // 1 day delay after voting ends
    const QUORUM_PERCENTAGE: u64 = 20; // 20% of total governance tokens
    const INITIAL_TOKEN_SUPPLY: u64 = 1000000; // 1M governance tokens
    
    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1001;
    const E_PROPOSAL_NOT_OPEN: u64 = 1002;
    const E_ALREADY_VOTED: u64 = 1003;
    const E_VOTING_ENDED: u64 = 1004;
    const E_INSUFFICIENT_BALANCE: u64 = 1005;
    const E_PROPOSAL_NOT_READY: u64 = 1006;
    const E_INSUFFICIENT_TOKENS: u64 = 1007;
    const E_QUORUM_NOT_MET: u64 = 1008;
    const E_PROPOSAL_ALREADY_EXECUTED: u64 = 1009;
    const E_INSUFFICIENT_FUNDS: u64 = 1010;

    // Events
    #[event]
    struct ProposalCreatedEvent has drop, store {
        proposal_id: u64,
        proposer: address,
        title: string::String,
        requested_amount: u64,
    }

    #[event]
    struct VoteCastEvent has drop, store {
        proposal_id: u64,
        voter: address,
        vote: bool,
        voting_power: u64,
    }

    #[event]
    struct ProposalExecutedEvent has drop, store {
        proposal_id: u64,
        result: u8, // 0=Funded, 1=Rejected, 2=QuorumNotMet
        amount_transferred: u64,
    }

    #[event]
    struct FundsDepositedEvent has drop, store {
        depositor: address,
        amount: u64,
    }

    #[event]
    struct TokensStakedEvent has drop, store {
        staker: address,
        amount: u64,
    }

    // Governance Token (simplified representation)
    struct GovernanceToken has key, store {
        balance: u64,
        staked_balance: u64,
        last_claim_time: u64,
    }

    // Investment Proposal with enhanced features
    struct InvestmentProposal has key, store {
        id: u64,
        title: string::String,
        description: string::String,
        recipient: address,
        requested_amount: u64,
        yes_votes: u64,
        no_votes: u64,
        proposer: address,
        creation_time: u64,
        voting_end_time: u64,
        execution_time: u64,
        status: u8, // 0: Open, 1: Funded, 2: Rejected, 3: Executed, 4: QuorumNotMet
        voters: table::Table<address, u64>, // voter -> voting power used
        executed: bool,
    }

    // DAO Treasury and Governance
    struct DAOTreasury has key {
        proposals: table::Table<u64, InvestmentProposal>,
        proposal_count: u64,
        total_funds: u64,
        total_governance_tokens: u64,
        staked_tokens: u64,
        admin: address,
        governance_threshold: u64, // minimum tokens needed to create proposal
    }

    // Member information
    struct DAOMember has key {
        governance_tokens: GovernanceToken,
        proposals_created: u64,
        votes_cast: u64,
        member_since: u64,
    }

    // Initialize the DAO (now anyone can initialize)
    public entry fun initialize_dao(account: &signer) {
        let sender_addr = signer::address_of(account);
        
        // Create treasury
        move_to(account, DAOTreasury {
            proposals: table::new<u64, InvestmentProposal>(),
            proposal_count: 0,
            total_funds: 0,
            total_governance_tokens: INITIAL_TOKEN_SUPPLY,
            staked_tokens: 0,
            admin: sender_addr,
            governance_threshold: 1000, // Need 1000 tokens to create proposal
        });

        // Give initial tokens to founder
        move_to(account, DAOMember {
            governance_tokens: GovernanceToken {
                balance: INITIAL_TOKEN_SUPPLY,
                staked_balance: 0,
                last_claim_time: timestamp::now_seconds(),
            },
            proposals_created: 0,
            votes_cast: 0,
            member_since: timestamp::now_seconds(),
        });
    }

    // Join DAO as a new member
    public entry fun join_dao(account: &signer, dao_address: address) {
        let sender_addr = signer::address_of(account);
        
        // Initialize member with 0 tokens (they need to earn or receive them)
        move_to(account, DAOMember {
            governance_tokens: GovernanceToken {
                balance: 0,
                staked_balance: 0,
                last_claim_time: timestamp::now_seconds(),
            },
            proposals_created: 0,
            votes_cast: 0,
            member_since: timestamp::now_seconds(),
        });
    }

    // Deposit funds into DAO treasury
    public entry fun deposit_funds(account: &signer, dao_address: address, amount: u64) 
    acquires DAOTreasury {
        let sender_addr = signer::address_of(account);
        
        // Transfer coins to DAO
        let coins = coin::withdraw<AptosCoin>(account, amount);
        coin::deposit<AptosCoin>(dao_address, coins);
        
        // Update treasury
        let treasury = borrow_global_mut<DAOTreasury>(dao_address);
        treasury.total_funds = treasury.total_funds + amount;
        
        event::emit<FundsDepositedEvent>(FundsDepositedEvent {
            depositor: sender_addr,
            amount,
        });
    }

    // Stake governance tokens for voting power
    public entry fun stake_tokens(account: &signer, dao_address: address, amount: u64) 
    acquires DAOMember, DAOTreasury {
        let sender_addr = signer::address_of(account);
        let member = borrow_global_mut<DAOMember>(sender_addr);
        
        assert!(member.governance_tokens.balance >= amount, E_INSUFFICIENT_TOKENS);
        
        // Move tokens from balance to staked
        member.governance_tokens.balance = member.governance_tokens.balance - amount;
        member.governance_tokens.staked_balance = member.governance_tokens.staked_balance + amount;
        
        // Update global staked count
        let treasury = borrow_global_mut<DAOTreasury>(dao_address);
        treasury.staked_tokens = treasury.staked_tokens + amount;
        
        event::emit<TokensStakedEvent>(TokensStakedEvent {
            staker: sender_addr,
            amount,
        });
    }

    // Transfer governance tokens between members
    public entry fun transfer_tokens(
        account: &signer, 
        recipient: address, 
        amount: u64
    ) acquires DAOMember {
        let sender_addr = signer::address_of(account);
        let sender_member = borrow_global_mut<DAOMember>(sender_addr);
        
        assert!(sender_member.governance_tokens.balance >= amount, E_INSUFFICIENT_TOKENS);
        
        // Deduct from sender
        sender_member.governance_tokens.balance = sender_member.governance_tokens.balance - amount;
        
        // Add to recipient
        let recipient_member = borrow_global_mut<DAOMember>(recipient);
        recipient_member.governance_tokens.balance = recipient_member.governance_tokens.balance + amount;
    }

    // Create investment proposal (requires minimum tokens)
    public entry fun create_investment_proposal(
        account: &signer,
        dao_address: address,
        title: string::String,
        description: string::String,
        recipient: address,
        requested_amount: u64
    ) acquires DAOTreasury, DAOMember {
        let sender_addr = signer::address_of(account);
        let treasury = borrow_global_mut<DAOTreasury>(dao_address);
        let member = borrow_global_mut<DAOMember>(sender_addr);
        
        // Check if member has enough governance tokens
        let total_tokens = member.governance_tokens.balance + member.governance_tokens.staked_balance;
        assert!(total_tokens >= treasury.governance_threshold, E_INSUFFICIENT_TOKENS);
        
        // Check if DAO has enough funds
        assert!(treasury.total_funds >= requested_amount, E_INSUFFICIENT_FUNDS);
        
        let proposal_id = treasury.proposal_count;
        let current_time = timestamp::now_seconds();
        let voting_end = current_time + VOTING_PERIOD;
        let execution_time = voting_end + EXECUTION_DELAY;
        
        let proposal = InvestmentProposal {
            id: proposal_id,
            title,
            description,
            recipient,
            requested_amount,
            yes_votes: 0,
            no_votes: 0,
            proposer: sender_addr,
            creation_time: current_time,
            voting_end_time: voting_end,
            execution_time,
            status: 0, // Open
            voters: table::new<address, u64>(),
            executed: false,
        };
        
        table::add(&mut treasury.proposals, proposal_id, proposal);
        treasury.proposal_count = proposal_id + 1;
        member.proposals_created = member.proposals_created + 1;
        
        event::emit<ProposalCreatedEvent>(ProposalCreatedEvent {
            proposal_id,
            proposer: sender_addr,
            title,
            requested_amount,
        });
    }

    // Vote on proposal with staked token weight
    public entry fun vote_on_proposal(
        account: &signer,
        dao_address: address,
        proposal_id: u64,
        vote: bool
    ) acquires DAOTreasury, DAOMember {
        let voter_addr = signer::address_of(account);
        let treasury = borrow_global_mut<DAOTreasury>(dao_address);
        let member = borrow_global_mut<DAOMember>(voter_addr);
        
        let proposal = table::borrow_mut(&mut treasury.proposals, proposal_id);
        
        // Check if proposal is still open and voting period hasn't ended
        assert!(proposal.status == 0, E_PROPOSAL_NOT_OPEN);
        assert!(timestamp::now_seconds() <= proposal.voting_end_time, E_VOTING_ENDED);
        assert!(!table::contains(&proposal.voters, voter_addr), E_ALREADY_VOTED);
        
        // Voting power = staked tokens
        let voting_power = member.governance_tokens.staked_balance;
        assert!(voting_power > 0, E_INSUFFICIENT_TOKENS);
        
        // Record vote
        table::add(&mut proposal.voters, voter_addr, voting_power);
        member.votes_cast = member.votes_cast + 1;
        
        // Add weighted vote
        if (vote) {
            proposal.yes_votes = proposal.yes_votes + voting_power;
        } else {
            proposal.no_votes = proposal.no_votes + voting_power;
        };
        
        event::emit<VoteCastEvent>(VoteCastEvent {
            proposal_id,
            voter: voter_addr,
            vote,
            voting_power,
        });
    }

    // Execute proposal (anyone can call after execution time)
    public entry fun execute_proposal(
        account: &signer,
        dao_address: address,
        proposal_id: u64
    ) acquires DAOTreasury {
        let treasury = borrow_global_mut<DAOTreasury>(dao_address);
        let proposal = table::borrow_mut(&mut treasury.proposals, proposal_id);
        
        // Check conditions
        assert!(proposal.status == 0, E_PROPOSAL_NOT_OPEN);
        assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);
        assert!(timestamp::now_seconds() >= proposal.execution_time, E_PROPOSAL_NOT_READY);
        
        let total_votes = proposal.yes_votes + proposal.no_votes;
        let quorum_required = (treasury.staked_tokens * QUORUM_PERCENTAGE) / 100;
        
        // Check quorum
        if (total_votes < quorum_required) {
            proposal.status = 4; // QuorumNotMet
            proposal.executed = true;
            event::emit<ProposalExecutedEvent>(ProposalExecutedEvent {
                proposal_id,
                result: 2,
                amount_transferred: 0,
            });
            return
        };
        
        // Execute based on vote result
        if (proposal.yes_votes > proposal.no_votes) {
            // Proposal passed - transfer funds
            let coins = coin::withdraw<AptosCoin>(account, proposal.requested_amount);
            coin::deposit<AptosCoin>(proposal.recipient, coins);
            
            treasury.total_funds = treasury.total_funds - proposal.requested_amount;
            proposal.status = 1; // Funded
            
            event::emit<ProposalExecutedEvent>(ProposalExecutedEvent {
                proposal_id,
                result: 0,
                amount_transferred: proposal.requested_amount,
            });
        } else {
            // Proposal rejected
            proposal.status = 2; // Rejected
            event::emit<ProposalExecutedEvent>(ProposalExecutedEvent {
                proposal_id,
                result: 1,
                amount_transferred: 0,
            });
        };
        
        proposal.executed = true;
    }

    // Admin function to distribute governance tokens
    public entry fun distribute_tokens(
        account: &signer,
        dao_address: address,
        recipient: address,
        amount: u64
    ) acquires DAOTreasury, DAOMember {
        let sender_addr = signer::address_of(account);
        let treasury = borrow_global<DAOTreasury>(dao_address);
        
        // Only admin can distribute tokens
        assert!(sender_addr == treasury.admin, E_NOT_AUTHORIZED);
        
        let recipient_member = borrow_global_mut<DAOMember>(recipient);
        recipient_member.governance_tokens.balance = recipient_member.governance_tokens.balance + amount;
    }

    // View functions
    #[view]
    public fun get_proposal_info(dao_address: address, proposal_id: u64): (
        string::String, // title
        u64, // requested_amount
        u64, // yes_votes
        u64, // no_votes
        u8,  // status
        u64, // voting_end_time
        bool // executed
    ) acquires DAOTreasury {
        let treasury = borrow_global<DAOTreasury>(dao_address);
        let proposal = table::borrow(&treasury.proposals, proposal_id);
        (
            proposal.title,
            proposal.requested_amount,
            proposal.yes_votes,
            proposal.no_votes,
            proposal.status,
            proposal.voting_end_time,
            proposal.executed
        )
    }

    #[view]
    public fun get_member_info(member_address: address): (u64, u64, u64, u64) acquires DAOMember {
        let member = borrow_global<DAOMember>(member_address);
        (
            member.governance_tokens.balance,
            member.governance_tokens.staked_balance,
            member.proposals_created,
            member.votes_cast
        )
    }

    #[view]
    public fun get_treasury_info(dao_address: address): (u64, u64, u64, u64) acquires DAOTreasury {
        let treasury = borrow_global<DAOTreasury>(dao_address);
        (
            treasury.total_funds,
            treasury.proposal_count,
            treasury.total_governance_tokens,
            treasury.staked_tokens
        )
    }
}