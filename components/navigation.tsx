'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
const groups = [
  { title: 'Company staff', links: [{ href: '/company/dispatch', label: 'Dispatch confirmation', icon: '↗' }, { href: '/company/reconciliation', label: 'Reconciliation', icon: '≡' }] },
  { title: 'Distributor', links: [{ href: '/distributor/invoices/new', label: 'Create B2B invoice', icon: '+' }, { href: '/distributor/invoices', label: 'Invoice status', icon: '◷' }] },
];
export function Navigation() {
  const pathname = usePathname();
  function item(href: string, label: string, icon: string) { return <Link key={href} href={href} className={`nav-link ${pathname === href ? 'active' : ''}`} aria-current={pathname === href ? 'page' : undefined}><span aria-hidden="true">{icon}</span>{label}</Link>; }
  return <aside className="sidebar"><Link href="/" className="brand"><span className="brand-mark">E</span><span>EMAN<small>BAKERY OPERATIONS</small></span></Link><p className="nav-label">WORKSPACE</p><nav aria-label="Workspace">{item('/', 'Overview', '▦')}{groups.map(group => <section className="nav-group" key={group.title}><h2>{group.title}</h2>{group.links.map(link => item(link.href, link.label, link.icon))}</section>)}</nav><div className="sidebar-note">● Application shell<p>Role areas are for navigation preview. Authentication is not connected.</p></div></aside>;
}
