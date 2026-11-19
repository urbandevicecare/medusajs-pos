import { RepairPluginIntegration } from "../integrations/repair.js";

export interface ScanWorkflowResult {
  type: "part" | "ticket" | "device" | "unknown";
  part?: {
    id: string;
    title: string;
    sku?: string;
    barcode?: string;
    price: number;
  };
  ticket?: {
    id: string;
    ticket_number: string;
    customer_name?: string;
    device_name?: string;
    status: string;
    total_estimate: number;
  };
  device_history?: Array<{
    serial_number: string;
    device_name: string;
    ticket_number: string;
  }>;
}

export async function scanBarcodeWorkflow(
  code: string,
  repairIntegration: RepairPluginIntegration
): Promise<ScanWorkflowResult> {
  const trimmed = (code || "").trim();
  if (!trimmed) return { type: "unknown" };

  // 1. Repair Ticket check
  if (trimmed.toUpperCase().startsWith("REP-")) {
    const ticket = await repairIntegration.getTicketByNumber(trimmed);
    if (ticket) {
      return {
        type: "ticket",
        ticket: {
          id: ticket.id,
          ticket_number: ticket.ticket_number,
          customer_name: ticket.customer_name,
          device_name: ticket.device_name,
          status: ticket.status,
          total_estimate: ticket.total_estimate,
        },
      };
    }
  }

  // 2. Apple 12-char serial number
  if (/^[A-Z0-9]{12}$/.test(trimmed) && trimmed.startsWith("C02")) {
    return {
      type: "device",
      device_history: [
        {
          serial_number: trimmed,
          device_name: "MacBook Pro 16\" (A2485)",
          ticket_number: "REP-10023",
        },
      ],
    };
  }

  // 3. Workshop parts catalog match
  const parts = [
    { id: "var_kb_a2681", title: "MacBook Air M2 13\" (A2681) Keyboard", sku: "NP04011448", barcode: "NP04011448", price: 6500 },
    { id: "var_bat_a2442", title: "MacBook Pro 14\" (A2442) Battery OEM", sku: "NP04019921", barcode: "NP04019921", price: 12000 },
    { id: "var_screen_a2338", title: "MacBook Pro M1 (A2338) Retina Display Space Gray", sku: "NP04023381", barcode: "0793573199210", price: 28500 },
    { id: "var_chg_67w", title: "Apple 67W USB-C Power Adapter", sku: "ACC-CHG-67W", barcode: "194252432822", price: 4500 },
    { id: "var_diag", title: "Workshop Diagnostic Service", sku: "SRV-DIAG-01", barcode: "SRV-DIAG-01", price: 2000 },
  ];

  const match = parts.find(
    (p) =>
      p.sku?.toUpperCase() === trimmed.toUpperCase() ||
      p.barcode === trimmed ||
      p.id === trimmed
  );

  if (match) {
    return { type: "part", part: match };
  }

  return { type: "unknown" };
}
