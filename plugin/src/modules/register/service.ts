import { RegisterSession } from "./models/register-session.js";
import { CashTransaction, CashTransactionType } from "./models/cash-transaction.js";
import { POSTerminal } from "./models/pos-terminal.js";

export class RegisterModuleService {
  private sessions: Map<string, RegisterSession> = new Map();
  private transactions: Map<string, CashTransaction[]> = new Map();
  private terminals: Map<string, POSTerminal> = new Map();

  constructor() {
    // Seed standard terminals
    this.terminals.set("cs30_terminal_01", {
      id: "cs30_terminal_01",
      name: "Handheld CS30 Smart POS",
      location: "Workshop Floor / Counter 1",
      default_channel: "retail_counter_1",
      currency_code: "KES",
      default_tax_rate: 0.16,
      is_active: true,
    });
    this.terminals.set("macos_desktop_01", {
      id: "macos_desktop_01",
      name: "MacBook Bench POS",
      location: "Technician Bench 1",
      default_channel: "bench_terminal_01",
      currency_code: "KES",
      default_tax_rate: 0.16,
      is_active: true,
    });
  }

  public getTerminal(terminalId: string): POSTerminal | undefined {
    return this.terminals.get(terminalId);
  }

  public async openSession(data: {
    terminal_id: string;
    cashier_id: string;
    cashier_name: string;
    opening_amount: number;
    notes?: string;
  }): Promise<RegisterSession> {
    // Verify no existing open session
    const existing = await this.getActiveSession(data.terminal_id);
    if (existing) {
      throw new Error(`Terminal ${data.terminal_id} already has an active open session: ${existing.id}`);
    }

    const sessionId = `reg_sess_${Date.now()}`;
    const session: RegisterSession = {
      id: sessionId,
      terminal_id: data.terminal_id,
      cashier_id: data.cashier_id,
      cashier_name: data.cashier_name,
      status: "open",
      opening_amount: data.opening_amount,
      cash_sales: 0,
      cash_in: 0,
      cash_out: 0,
      opened_at: new Date(),
      notes: data.notes,
    };

    this.sessions.set(sessionId, session);
    this.transactions.set(sessionId, []);
    return session;
  }

  public async getActiveSession(terminalId: string): Promise<RegisterSession | null> {
    for (const session of this.sessions.values()) {
      if (session.terminal_id === terminalId && session.status === "open") {
        return session;
      }
    }
    return null;
  }

  public async getSessionById(sessionId: string): Promise<RegisterSession | null> {
    return this.sessions.get(sessionId) || null;
  }

  public async recordCashMovement(data: {
    session_id: string;
    type: CashTransactionType;
    amount: number;
    cashier_id: string;
    order_id?: string;
    reason?: string;
  }): Promise<CashTransaction> {
    const session = await this.getSessionById(data.session_id);
    if (!session) {
      throw new Error(`Register session not found: ${data.session_id}`);
    }
    if (session.status !== "open") {
      throw new Error(`Cannot record movement on closed register session: ${data.session_id}`);
    }

    const txId = `ctx_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const tx: CashTransaction = {
      id: txId,
      register_session_id: data.session_id,
      type: data.type,
      amount: data.amount,
      order_id: data.order_id,
      reason: data.reason,
      cashier_id: data.cashier_id,
      created_at: new Date(),
    };

    const txs = this.transactions.get(data.session_id) || [];
    txs.push(tx);
    this.transactions.set(data.session_id, txs);

    // Update running totals
    if (data.type === "sale") {
      session.cash_sales += data.amount;
    } else if (data.type === "cash_in") {
      session.cash_in += data.amount;
    } else if (data.type === "cash_out" || data.type === "drop") {
      session.cash_out += data.amount;
    } else if (data.type === "refund") {
      session.cash_sales -= data.amount;
    }

    return tx;
  }

  public async closeSession(data: {
    session_id: string;
    closing_amount: number;
    notes?: string;
  }): Promise<RegisterSession> {
    const session = await this.getSessionById(data.session_id);
    if (!session) {
      throw new Error(`Register session not found: ${data.session_id}`);
    }
    if (session.status !== "open") {
      throw new Error(`Session ${data.session_id} is already closed`);
    }

    const expected = session.opening_amount + session.cash_sales + session.cash_in - session.cash_out;
    const difference = data.closing_amount - expected;

    session.status = "closed";
    session.closing_amount = data.closing_amount;
    session.expected_amount = expected;
    session.difference = difference;
    session.closed_at = new Date();
    if (data.notes) {
      session.notes = session.notes ? `${session.notes}\n${data.notes}` : data.notes;
    }

    return session;
  }

  public async getSessionTransactions(sessionId: string): Promise<CashTransaction[]> {
    return this.transactions.get(sessionId) || [];
  }
}
