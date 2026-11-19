import {
  createQuickCustomerWorkflow,
  searchCustomersWorkflow,
} from "../../../workflows/quick-customer.js";

/**
 * Medusa v2 Standard Admin Customer API:
 * GET /admin/customers - Search and list registered customers
 * POST /admin/customers - Create a registered customer record (not guest)
 */
export async function GET(req: any, res: any) {
  try {
    const query = req.query?.q || req.query?.query || "";
    const customers = await searchCustomersWorkflow(query);
    res.status(200).json({
      customers,
      count: customers.length,
      limit: 50,
      offset: 0,
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
}

export async function POST(req: any, res: any) {
  try {
    const body = req.body || {};
    const customer = await createQuickCustomerWorkflow(body);
    res.status(201).json({ customer });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
}
