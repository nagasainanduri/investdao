import Link from 'next/link';

export default function HomePage() {
  const proposals = [
    { id: 0, title: 'Proposal One' },
    { id: 1, title: 'Proposal Two' },
  ];

  return (
    <>
      <h1>DAO Proposals</h1>
      {proposals.map(({ id, title }) => (
        <Link href={`/proposal/${id}`} key={id} legacyBehavior>
          <a className="proposal-card">
            <h2>#{id} - {title}</h2>
            <p>Proposal description preview...</p>
          </a>
        </Link>
      ))}
    </>
  );
}
