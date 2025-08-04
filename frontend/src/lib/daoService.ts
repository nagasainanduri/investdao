import { Aptos, AptosConfig, Network, Account, AccountAddress, InputEntryFunctionData } from "@aptos-labs/ts-sdk";

// Configuration constants
const DAO_ADDRESS = "0x1";
const MODULE_NAME = "InvestmentDAO";
const CONTRACT_ADDRESS = `0x1::${MODULE_NAME}`;

// Aptos client configuration (using testnet for this example, adjust for mainnet or devnet)
const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

// Interface for proposal data (returned from blockchain)
interface ProposalData {
  id: string;
  title: string;
  description: string;
  yes: string;
  no: string;
  proposer: string;
  status: string;
  voters: { handle: string };
}

// Interface for proposal (frontend-friendly format)
interface Proposal {
  id: number;
  title: string;
  description: string;
  yes: number;
  no: number;
  proposer: string;
  status: number; // 0: Open, 1: Funded, 2: Closed, 3: NotMin
}

// InvestmentDAO API class
export class InvestmentDaoApi {
  private account: Account;

  constructor(account: Account) {
    this.account = account;
  }

  // Initialize the contract (only callable by DAO address)
  async init(): Promise<string> {
    try {
      const payload: InputEntryFunctionData = {
        function: `${CONTRACT_ADDRESS}::init`,
        typeArguments: [],
        functionArguments: [],
      };
      const transaction = await this.submitTransaction(payload);
      return transaction.hash;
    } catch (error) {
      throw new Error(`Failed to initialize contract: ${error}`);
    }
  }

  // Create a new proposal
  async createProposal(title: string, description: string): Promise<string> {
    try {
      const payload: InputEntryFunctionData = {
        function: `${CONTRACT_ADDRESS}::create_proposal`,
        typeArguments: [],
        functionArguments: [title, description],
      };
      const transaction = await this.submitTransaction(payload);
      return transaction.hash;
    } catch (error) {
      throw new Error(`Failed to create proposal: ${error}`);
    }
  }

  // Vote on a proposal
  async voteOnProposal(proposalId: number, vote: boolean): Promise<string> {
    try {
      const payload: InputEntryFunctionData = {
        function: `${CONTRACT_ADDRESS}::vote_on_props`,
        typeArguments: [],
        functionArguments: [proposalId.toString(), vote], // Convert proposalId to string for u64
      };
      const transaction = await this.submitTransaction(payload);
      return transaction.hash;
    } catch (error) {
      throw new Error(`Failed to vote on proposal: ${error}`);
    }
  }

  // Finalize a proposal
  async finalizeProposal(proposalId: number): Promise<string> {
    try {
      const payload: InputEntryFunctionData = {
        function: `${CONTRACT_ADDRESS}::finalize_props`,
        typeArguments: [],
        functionArguments: [proposalId.toString()], // Convert proposalId to string for u64
      };
      const transaction = await this.submitTransaction(payload);
      return transaction.hash;
    } catch (error) {
      throw new Error(`Failed to finalize proposal: ${error}`);
    }
  }

  // Helper to submit transaction
  private async submitTransaction(payload: InputEntryFunctionData): Promise<any> {
    const transaction = await aptos.transaction.build.simple({
      sender: this.account.accountAddress,
      data: payload,
    });

    const pendingTxn = await aptos.signAndSubmitTransaction({
      signer: this.account,
      transaction,
    });

    const confirmedTxn = await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
    return confirmedTxn;
  }

  // Query proposal data
  async getProposal(proposalId: number): Promise<Proposal> {
    try {
      const resource = await aptos.getAccountResource({
        accountAddress: DAO_ADDRESS,
        resourceType: `${CONTRACT_ADDRESS}::ProposalStore`,
      });

      const proposalsTableHandle = (resource.data as any).proposals.handle;
      const proposalData = await aptos.getTableItem<ProposalData>({
        handle: proposalsTableHandle,
        data: {
          key: proposalId.toString(),
          key_type: "u64",
          value_type: `${CONTRACT_ADDRESS}::Proposal`,
        },
      });

      return {
        id: Number(proposalData.id),
        title: proposalData.title,
        description: proposalData.description,
        yes: Number(proposalData.yes),
        no: Number(proposalData.no),
        proposer: proposalData.proposer,
        status: Number(proposalData.status),
      };
    } catch (error) {
      throw new Error(`Failed to fetch proposal: ${error}`);
    }
  }
}