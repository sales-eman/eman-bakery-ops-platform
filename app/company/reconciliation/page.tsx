import { Placeholder } from '@/components/placeholder';
export const metadata = { title: 'Reconciliation' };
export default function Page() { return <Placeholder area="Company staff" title="Reconciliation" description="A future view of daily reconciliation and operational exceptions." icon="≡" action="Run reconciliation" steps={['Review the daily cycle', 'Inspect discrepancies and exceptions', 'Record the reconciliation outcome']} />; }
