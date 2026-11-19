export interface RegisterSession {
  id: string;
  terminal_id: string;
  cashier_id: string;
  cashier_name: string;
  status: "open" | "closed";
  opening_amount: number;
  closing_amount?: number;
  cash_sales: number;
  cash_in: number;
  cash_out: number;
  expected_amount?: number;
  difference?: number;
  opened_at: Date;
  closed_at?: Date;
  notes?: string;
  metadata?: Record<string, unknown>;
}
