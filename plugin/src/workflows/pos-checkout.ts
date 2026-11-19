import { RegisterModuleService } from "../modules/register/service.js";
import { RepairPluginIntegration } from "../integrations/repair.js";
import { DocumentsPluginIntegration } from "../integrations/documents.js";
import { PaystackPluginIntegration } from "../integrations/paystack.js";

export interface POSCheckoutInput {
  terminal_id: string;
  cashier: {
    id: string;
    name: string;
    email: string;
  };
  items: Array<{
    variant_id: string;
    title: string;
    sku?: string;
    quantity: number;
    unit_price: number;
  }>;
  tender: {
    type: "cash" | "paystack" | "split";
    tendered: number;
    change: number;
  };
  customer?: {
    id?: string;
    first_name?: string;
    last_name?: string;
    email?: string;
    phone?: string;
    company_name?: string;
  };
  repair_ticket_number?: string;
  tax_rate?: number;
}

export interface POSCheckoutResult {
  order_id: string;
  order_number: string;
  status: "completed";
  customer_id?: string;
  customer?: {
    id?: string;
    first_name?: string;
    last_name?: string;
    email?: string;
    phone?: string;
    company_name?: string;
  };
  subtotal: number;
  tax: number;
  grand_total: number;
  metadata: Record<string, unknown>;
  document?: {
    document_id: string;
    document_url: string;
    fiscal_invoice_number: string;
  };
  paystack?: {
    reference: string;
    authorization_url: string;
    qr_code_url: string;
  };
  repair?: {
    ticket_number: string;
    status: string;
  };
  cash_movement?: {
    id: string;
    session_id: string;
    amount: number;
  };
}

export async function posCheckoutWorkflow(
  input: POSCheckoutInput,
  services: {
    registerService: RegisterModuleService;
    repairIntegration: RepairPluginIntegration;
    documentsIntegration: DocumentsPluginIntegration;
    paystackIntegration: PaystackPluginIntegration;
  }
): Promise<POSCheckoutResult> {
  const { registerService, repairIntegration, documentsIntegration, paystackIntegration } = services;

  if (!input.items || input.items.length === 0) {
    throw new Error("Cannot checkout empty cart");
  }

  // 1. Calculate financial totals
  const subtotal = input.items.reduce((sum, item) => sum + item.unit_price * item.quantity, 0);
  const taxRate = input.tax_rate ?? 0.16;
  const tax = Math.round(subtotal * taxRate * 100) / 100;
  const grandTotal = subtotal + tax;

  const orderNum = `POS-${Math.floor(100000 + Math.random() * 900000)}`;
  const orderId = `ord_${Date.now()}`;

  // 2. Base metadata
  const metadata: Record<string, unknown> = {
    pos_channel: input.terminal_id,
    cashier_id: input.cashier.id,
    cashier_name: input.cashier.name,
    cashier_email: input.cashier.email,
    terminal_type: "native_pos",
    tender_type: input.tender.type,
    tendered_amount: input.tender.tendered,
    change_given: input.tender.change,
    printed_at: new Date().toISOString(),
  };

  if (input.customer) {
    const custFullName = `${input.customer.first_name || ""} ${input.customer.last_name || ""}`.trim();
    metadata.customer_id = input.customer.id;
    metadata.customer_name = custFullName;
    metadata.customer_email = input.customer.email;
    metadata.customer_phone = input.customer.phone;
    metadata.customer_company = input.customer.company_name;
  }

  let cashMovementResult;
  let paystackResult;
  let repairResult;

  // 3. Register cash transaction
  if (input.tender.type === "cash" || input.tender.type === "split") {
    const activeSession = await registerService.getActiveSession(input.terminal_id);
    if (activeSession) {
      const tx = await registerService.recordCashMovement({
        session_id: activeSession.id,
        type: "sale",
        amount: grandTotal,
        order_id: orderId,
        cashier_id: input.cashier.id,
        reason: `POS Sale ${orderNum}`,
      });
      cashMovementResult = {
        id: tx.id,
        session_id: activeSession.id,
        amount: grandTotal,
      };
      metadata.register_session_id = activeSession.id;
    }
  }

  // 4. Paystack transaction if applicable
  if (input.tender.type === "paystack") {
    const pst = await paystackIntegration.initializePOSTransaction({
      amount: Math.round(grandTotal * 100),
      email: input.cashier.email,
      reference: `pst_${orderNum}`,
      metadata: { order_id: orderId },
    });
    paystackResult = {
      reference: pst.reference,
      authorization_url: pst.authorization_url,
      qr_code_url: pst.qr_code_url,
    };
    metadata.paystack_reference = pst.reference;
  }

  // 5. Repair ticket link if applicable
  if (input.repair_ticket_number) {
    const updatedTicket = await repairIntegration.markTicketPaid(
      input.repair_ticket_number,
      orderId,
      input.cashier.id
    );
    repairResult = {
      ticket_number: updatedTicket.ticket_number,
      status: updatedTicket.status,
    };
    metadata.repair_ticket_id = updatedTicket.id;
    metadata.repair_ticket_number = updatedTicket.ticket_number;
  }

  // 6. Documents plugin fiscal document generation
  const docResult = await documentsIntegration.generateFiscalReceiptDocument({
    order_id: orderId,
    order_number: orderNum,
    store_name: "Urban Device Care",
    cashier_name: input.cashier.name,
    terminal_id: input.terminal_id,
    items: input.items.map((i) => ({
      title: i.title,
      quantity: i.quantity,
      unit_price: i.unit_price,
      total: i.unit_price * i.quantity,
      tax: (i.unit_price * i.quantity) * taxRate,
    })),
    subtotal,
    tax,
    grand_total: grandTotal,
    currency: "KES",
  });

  metadata.fiscal_invoice_number = docResult.fiscal_invoice_number;
  metadata.document_id = docResult.document_id;

  return {
    order_id: orderId,
    order_number: orderNum,
    status: "completed",
    customer_id: input.customer?.id,
    customer: input.customer,
    subtotal,
    tax,
    grand_total: grandTotal,
    metadata,
    document: docResult,
    paystack: paystackResult,
    repair: repairResult,
    cash_movement: cashMovementResult,
  };
}
