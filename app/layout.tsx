import type { Metadata } from 'next';
import { Navigation } from '@/components/navigation';
import './globals.css';
export const metadata: Metadata = { title: { default: 'Eman Bakery · Operations', template: '%s · Eman Bakery' }, description: 'Eman Bakery operations — application shell preview.' };
export default function Layout({ children }: { children: React.ReactNode }) { return <html lang="en"><body><a className="skip" href="#main">Skip to content</a><Navigation /><div className="workspace"><header className="topbar"><span>EMAN BAKERY <span className="muted">/ Operational platform</span></span><span className="preview">Scaffold preview</span></header><main id="main">{children}</main><footer>Jeddah, Saudi Arabia <span>Business timezone · Asia/Riyadh</span></footer></div></body></html>; }
