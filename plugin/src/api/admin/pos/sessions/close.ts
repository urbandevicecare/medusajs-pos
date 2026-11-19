import { RegisterModuleService } from "../../../../modules/register/service.js";

export async function POST(req: any, res: any, registerService: RegisterModuleService) {
  try {
    const { session_id, closing_amount, notes } = req.body;
    const session = await registerService.closeSession({
      session_id,
      closing_amount: Number(closing_amount),
      notes,
    });
    res.json({ session });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
}
