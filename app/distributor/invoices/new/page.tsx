import { Placeholder } from '@/components/placeholder';
export const metadata = { title: 'Create B2B invoice' };
export default function Page() { return <Placeholder area="Distributor" title="Create B2B invoice" description="A future workspace for requests for B2B invoices issued in Eman Bakery’s name." icon="+" action="Submit invoice request" steps={['Choose an assigned customer', 'Prepare the invoice request', 'Submit for server-side validation']} />; }
