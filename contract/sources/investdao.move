module dao_addr::InvestmentDAO {
    use std::signer;
    use std::table;
    use std::string;
    use std::event;

    //minimum number of votes to finalize a prop
    const MIN_VOTES: u64 = 10;

    //proposal finalized event
    #[event]
    struct ProposalFinalizedEvent has drop, store {
        props_id: u64,
        result: u8, //0=Funded, 1=Closed, 2=NotMin
    }

    //individual proposal type
    struct Proposal has key, store {
        id: u64,
        title: string::String,
        description: string::String,
        yes: u64,
        no: u64,
        proposer: address,
        status: u8, // 0: Open, 1: Funded, 2: Closed
        voters: table::Table<address, bool>,
    }

    //proposal store and event handles
    struct ProposalStore has key {
        proposals: table::Table<u64, Proposal>,
        props_count: u64,
    }

    //initialize contract
    public entry fun init(account: &signer) {
        move_to(account, ProposalStore {
            proposals: table::new<u64, Proposal>(),
            props_count: 0,
        });
    }

    //create a new proposal
    public entry fun create_proposal(account: &signer, title: string::String, description: string::String) acquires ProposalStore {
        let sender_addr = signer::address_of(account);
        let store = borrow_global_mut<ProposalStore>(sender_addr);
        let proposal_id = store.props_count;
        let voters_tbl = table::new<address, bool>();
        let proposal = Proposal {
            id: proposal_id,
            title,
            description,
            yes: 0,
            no: 0,
            proposer: sender_addr,
            status: 0, // Open 1=>close
            voters: voters_tbl,
        };
        table::add(&mut store.proposals, proposal_id, proposal);
        store.props_count = proposal_id + 1;
    }

    // voting on open proposal
    public entry fun vote_on_props(account: &signer, prop_id: u64, vote: bool) acquires ProposalStore {
        let sender_addr = signer::address_of(account);
        let store = borrow_global_mut<ProposalStore>(sender_addr);

        //borrow proposal - mutable
        let proposal = table::borrow_mut(&mut store.proposals, prop_id);

        //check if still open
        assert!(proposal.status == 0, 1); //Error code 1 = proposal not open

        //prevent double voting
        let has_voted = table::contains(&proposal.voters, sender_addr);
        assert!(!has_voted, 2); // Error code 2 = Aleady voted

        //REcord vote
        table::add(&mut proposal.voters, sender_addr, true);

        //increment
        if (vote) {
            proposal.yes = proposal.yes + 1;
        } else {
            proposal.no = proposal.no + 1;
        }
    }

    //finalize proposals
    public entry fun finalize_props(account: &signer, props_id: u64) acquires ProposalStore {
        let sender_addr = signer::address_of(account);
        let store = borrow_global_mut<ProposalStore>(sender_addr);

        let proposal = table::borrow_mut(&mut store.proposals, props_id);

        //must still be open
        assert!(proposal.status == 0, 3); //Error code 3 = Cannot finalize non-open

        let total_votes = proposal.yes + proposal.no;

        if (total_votes < MIN_VOTES) {
            proposal.status = 3; //Not minimum
            event::emit<ProposalFinalizedEvent>(ProposalFinalizedEvent {props_id, result: 2});
            return;
        };

        if(proposal.yes > proposal.no){
            proposal.status = 1;
            event::emit<ProposalFinalizedEvent>(ProposalFinalizedEvent{props_id, result: 0});
        } else {
            proposal.status = 2;
            event::emit<ProposalFinalizedEvent>(ProposalFinalizedEvent{props_id, result: 1});
        }
    }
}
