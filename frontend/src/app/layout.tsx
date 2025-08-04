import './globals.css';
import Link from 'next/link';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <nav>
          <Link href="/">Home</Link>
          <Link href="/create">Create Proposal</Link>
        </nav>
        <main>{children}</main>
      </body>
    </html>
  );
}
