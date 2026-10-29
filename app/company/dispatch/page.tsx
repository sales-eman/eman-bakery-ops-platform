import { Placeholder } from '@/components/placeholder';
export const metadata = { title: 'Dispatch confirmation' };
export default function Page() { return <Placeholder area="Company staff" title="Dispatch confirmation" description="A dedicated place for company staff to confirm distributor pickups." icon="↗" action="Confirm dispatch" steps={['Select a distributor and daily cycle', 'Review the pickup details', 'Confirm the physical dispatch']} />; }
