import { RegisterModuleService } from "../../../../modules/register/service.js";

const registerService = new RegisterModuleService();

export async function GET(req: any, res: any) {
  const terminalId = req.query?.terminal_id || "cs30_terminal_01";
  const activeSession = await registerService.getActiveSession(terminalId);
  res.json({ session: activeSession });
}

export async function POST(req: any, res: any) {
  try {
    const { terminal_id, cashier_id, cashier_name, opening_amount, notes } = req.body;
    const session = await registerService.openSession({
      terminal_id,
      cashier_id,
      cashier_name,
      opening_amount: Number(opening_amount),
      notes,
    });
    res.status(201).json({ session });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
}
