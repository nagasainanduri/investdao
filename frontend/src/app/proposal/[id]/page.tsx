interface ProposalPageProps {
  params: { id: string };
}

export default function ProposalPage({ params }: ProposalPageProps) {
  const { id } = params;

  return (
    <div className="proposal-card" style={{ marginTop: '20px' }}>
      <h1>Proposal Details - #{id}</h1>
      {/* Implement details, voting, finalization */}
    </div>
  );
}
