import { RegisterModuleService } from "../modules/register/service.js";
import { RegisterSession } from "../modules/register/models/register-session.js";

export async function closeRegisterSessionWorkflow(
  input: {
    session_id: string;
    closing_amount: number;
    notes?: string;
  },
  registerService: RegisterModuleService
): Promise<RegisterSession> {
  return await registerService.closeSession(input);
}
