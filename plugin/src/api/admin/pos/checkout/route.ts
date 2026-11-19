import { posCheckoutWorkflow } from "../../../../workflows/pos-checkout.js";
import { RegisterModuleService } from "../../../../modules/register/service.js";
import { RepairPluginIntegration } from "../../../../integrations/repair.js";
import { DocumentsPluginIntegration } from "../../../../integrations/documents.js";
import { PaystackPluginIntegration } from "../../../../integrations/paystack.js";

const registerService = new RegisterModuleService();
const repairIntegration = new RepairPluginIntegration();
const documentsIntegration = new DocumentsPluginIntegration();
const paystackIntegration = new PaystackPluginIntegration();

export async function POST(req: any, res: any) {
  try {
    const result = await posCheckoutWorkflow(req.body, {
      registerService,
      repairIntegration,
      documentsIntegration,
      paystackIntegration,
    });
    res.status(200).json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
}
