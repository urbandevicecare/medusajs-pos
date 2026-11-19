import { scanBarcodeWorkflow } from "../../../../workflows/scan-barcode.js";
import { RepairPluginIntegration } from "../../../../integrations/repair.js";

const repairIntegration = new RepairPluginIntegration();

export async function POST(req: any, res: any) {
  try {
    const code = req.body?.code || req.query?.code || "";
    const result = await scanBarcodeWorkflow(code, repairIntegration);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
}
