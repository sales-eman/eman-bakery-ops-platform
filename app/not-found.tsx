import Link from 'next/link';
export default function NotFound() { return <section className="empty-panel"><p className="eyebrow">404</p><h1>Page not found</h1><p>Choose an available page from the workspace.</p><Link href="/">Back to overview →</Link></section>; }
