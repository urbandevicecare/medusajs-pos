import { RegisterModuleService } from "../modules/register/service.js";
import { RegisterSession } from "../modules/register/models/register-session.js";

export async function openRegisterSessionWorkflow(
  input: {
    terminal_id: string;
    cashier_id: string;
    cashier_name: string;
    opening_amount: number;
    notes?: string;
  },
  registerService: RegisterModuleService
): Promise<RegisterSession> {
  return await registerService.openSession(input);
}
