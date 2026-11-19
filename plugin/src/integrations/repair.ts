export interface RepairTicketDetails {
  id: string;
  ticket_number: string;
  customer_id?: string;
  customer_name?: string;
  device_name?: string;
  serial_number?: string;
  labor_cost: number;
  parts_cost: number;
  total_estimate: number;
  status: "in_progress" | "ready_for_pickup" | "paid" | "completed";
}

export class RepairPluginIntegration {
  private mockTickets: Map<string, RepairTicketDetails> = new Map();

  constructor() {
    this.mockTickets.set("REP-10023", {
      id: "rep_10023",
      ticket_number: "REP-10023",
      customer_id: "cus_john_01",
      customer_name: "John Doe",
      device_name: "MacBook Pro 16\" M1 Max (A2485)",
      serial_number: "C02G4120MD6R",
      labor_cost: 4500,
      parts_cost: 28500,
      total_estimate: 33000,
      status: "ready_for_pickup",
    });
  }

  public async getTicketByNumber(ticketNumber: string): Promise<RepairTicketDetails | null> {
    const clean = ticketNumber.trim().toUpperCase();
    return this.mockTickets.get(clean) || null;
  }

  public async markTicketPaid(ticketNumber: string, orderId: string, cashierId: string): Promise<RepairTicketDetails> {
    const ticket = await this.getTicketByNumber(ticketNumber);
    if (!ticket) {
      throw new Error(`Repair ticket ${ticketNumber} not found`);
    }

    ticket.status = "paid";
    return ticket;
  }

  public async linkOrderToRepair(ticketNumber: string, orderId: string): Promise<{ success: boolean; ticket: RepairTicketDetails }> {
    const ticket = await this.getTicketByNumber(ticketNumber);
    if (!ticket) {
      throw new Error(`Repair ticket ${ticketNumber} not found`);
    }
    return { success: true, ticket };
  }
}
