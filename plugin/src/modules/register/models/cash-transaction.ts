export type CashTransactionType = "sale" | "refund" | "cash_in" | "cash_out" | "drop";

export interface CashTransaction {
  id: string;
  register_session_id: string;
  type: CashTransactionType;
  amount: number;
  order_id?: string;
  reason?: string;
  cashier_id: string;
  created_at: Date;
}
