import assert from "node:assert";
import { test } from "node:test";
import { RegisterModuleService } from "../src/modules/register/service.js";
import { RepairPluginIntegration } from "../src/integrations/repair.js";
import { DocumentsPluginIntegration } from "../src/integrations/documents.js";
import { PaystackPluginIntegration } from "../src/integrations/paystack.js";
import { posCheckoutWorkflow } from "../src/workflows/pos-checkout.js";
import { scanBarcodeWorkflow } from "../src/workflows/scan-barcode.js";

// ==========================================
// 1. RegisterModule Tests (Sessions & Cash Management)
// ==========================================

test("RegisterModule: Opens a new drawer session with opening float", async () => {
  const registerService = new RegisterModuleService();
  const session = await registerService.openSession({
    terminal_id: "cs30_terminal_01",
    cashier_id: "usr_01KRV9NELLY",
    cashier_name: "Nelly K.",
    opening_amount: 5000,
    notes: "Morning shift opening float",
  });

  assert.ok(session.id.startsWith("reg_sess_"));
  assert.strictEqual(session.status, "open");
  assert.strictEqual(session.opening_amount, 5000);
  assert.strictEqual(session.cash_sales, 0);

  // Attempting to open another session on the same terminal while active should fail
  await assert.rejects(
    async () => {
      await registerService.openSession({
        terminal_id: "cs30_terminal_01",
        cashier_id: "usr_02TECH_DAN",
        cashier_name: "Dan M.",
        opening_amount: 2000,
      });
    },
    /already has an active open session/
  );
});

test("RegisterModule: Records cash sales and closes session with reconciliation difference", async () => {
  const registerService = new RegisterModuleService();
  const session = await registerService.openSession({
    terminal_id: "macos_desktop_01",
    cashier_id: "usr_01KRV9NELLY",
    cashier_name: "Nelly K.",
    opening_amount: 10000,
  });

  // Record cash sale of 6500
  await registerService.recordCashMovement({
    session_id: session.id,
    type: "sale",
    amount: 6500,
    cashier_id: "usr_01KRV9NELLY",
    order_id: "ord_101",
  });

  // Record cash drop of 5000 to safe
  await registerService.recordCashMovement({
    session_id: session.id,
    type: "drop",
    amount: 5000,
    cashier_id: "usr_01KRV9NELLY",
    reason: "Midday safe drop",
  });

  const updatedSession = await registerService.getSessionById(session.id);
  assert.strictEqual(updatedSession?.cash_sales, 6500);
  assert.strictEqual(updatedSession?.cash_out, 5000);

  // Close session: Counted 11500 (expected: 10000 + 6500 - 5000 = 11500 -> diff 0)
  const closedSession = await registerService.closeSession({
    session_id: session.id,
    closing_amount: 11500,
    notes: "Balanced drawer",
  });

  assert.strictEqual(closedSession.status, "closed");
  assert.strictEqual(closedSession.expected_amount, 11500);
  assert.strictEqual(closedSession.difference, 0);

  // Cannot record movements on closed session
  await assert.rejects(
    async () => {
      await registerService.recordCashMovement({
        session_id: session.id,
        type: "sale",
        amount: 1000,
        cashier_id: "usr_01KRV9NELLY",
      });
    },
    /Cannot record movement on closed register session/
  );
});

// ==========================================
// 2. posCheckoutWorkflow & Integrations Tests
// ==========================================

test("posCheckoutWorkflow: Processes cash checkout, logs to register, links repair, and generates tax document", async () => {
  const registerService = new RegisterModuleService();
  const repairIntegration = new RepairPluginIntegration();
  const documentsIntegration = new DocumentsPluginIntegration();
  const paystackIntegration = new PaystackPluginIntegration();

  // Open drawer session
  await registerService.openSession({
    terminal_id: "cs30_terminal_01",
    cashier_id: "usr_01KRV9NELLY",
    cashier_name: "Nelly K.",
    opening_amount: 5000,
  });

  const checkoutInput = {
    terminal_id: "cs30_terminal_01",
    cashier: {
      id: "usr_01KRV9NELLY",
      name: "Nelly K.",
      email: "nelly@urbandevicecare.co.uk",
    },
    items: [
      {
        variant_id: "var_screen_a2338",
        title: "MacBook Pro M1 (A2338) Retina Display",
        sku: "NP04023381",
        quantity: 1,
        unit_price: 28500,
      },
    ],
    tender: {
      type: "cash" as const,
      tendered: 35000,
      change: 1940,
    },
    repair_ticket_number: "REP-10023",
  };

  const result = await posCheckoutWorkflow(checkoutInput, {
    registerService,
    repairIntegration,
    documentsIntegration,
    paystackIntegration,
  });

  // Verify financial totals
  assert.strictEqual(result.subtotal, 28500);
  assert.strictEqual(result.tax, 4560); // 16% of 28500
  assert.strictEqual(result.grand_total, 33060);

  // Verify cashier auditing metadata
  assert.strictEqual(result.metadata.cashier_id, "usr_01KRV9NELLY");
  assert.strictEqual(result.metadata.cashier_name, "Nelly K.");
  assert.strictEqual(result.metadata.pos_channel, "cs30_terminal_01");

  // Verify cash drawer movement
  assert.ok(result.cash_movement);
  assert.strictEqual(result.cash_movement.amount, 33060);

  // Verify Repair plugin integration
  assert.ok(result.repair);
  assert.strictEqual(result.repair.ticket_number, "REP-10023");
  assert.strictEqual(result.repair.status, "paid");

  // Verify Documents plugin integration
  assert.ok(result.document);
  assert.ok(result.document.fiscal_invoice_number.startsWith("INV-"));
  assert.ok(result.document.qr_code_payload.includes("invoice"));
});

test("posCheckoutWorkflow: Processes Paystack electronic payment", async () => {
  const registerService = new RegisterModuleService();
  const repairIntegration = new RepairPluginIntegration();
  const documentsIntegration = new DocumentsPluginIntegration();
  const paystackIntegration = new PaystackPluginIntegration();

  const checkoutInput = {
    terminal_id: "cs30_terminal_01",
    cashier: {
      id: "usr_02TECH_DAN",
      name: "Dan M.",
      email: "dan@urbandevicecare.co.uk",
    },
    items: [
      {
        variant_id: "var_chg_67w",
        title: "Apple 67W USB-C Adapter",
        sku: "ACC-CHG-67W",
        quantity: 2,
        unit_price: 4500,
      },
    ],
    tender: {
      type: "paystack" as const,
      tendered: 10440,
      change: 0,
    },
  };

  const result = await posCheckoutWorkflow(checkoutInput, {
    registerService,
    repairIntegration,
    documentsIntegration,
    paystackIntegration,
  });

  assert.strictEqual(result.subtotal, 9000);
  assert.strictEqual(result.tax, 1440);
  assert.strictEqual(result.grand_total, 10440);

  // Paystack verification
  assert.ok(result.paystack);
  assert.ok(result.paystack.authorization_url.includes("paystack.com"));
  assert.ok(result.paystack.qr_code_url.includes("create-qr-code"));
});

test("posCheckoutWorkflow: Rejects empty cart checkout", async () => {
  const registerService = new RegisterModuleService();
  const repairIntegration = new RepairPluginIntegration();
  const documentsIntegration = new DocumentsPluginIntegration();
  const paystackIntegration = new PaystackPluginIntegration();

  await assert.rejects(
    async () => {
      await posCheckoutWorkflow(
        {
          terminal_id: "test",
          cashier: { id: "1", name: "T", email: "t@t.com" },
          items: [],
          tender: { type: "cash", tendered: 0, change: 0 },
        },
        { registerService, repairIntegration, documentsIntegration, paystackIntegration }
      );
    },
    /Cannot checkout empty cart/
  );
});

// ==========================================
// 3. scanBarcodeWorkflow Tests
// ==========================================

test("scanBarcodeWorkflow: Resolves SKU, barcodes, repair tickets, and device serials", async () => {
  const repairIntegration = new RepairPluginIntegration();

  // Part SKU
  const skuRes = await scanBarcodeWorkflow("NP04011448", repairIntegration);
  assert.strictEqual(skuRes.type, "part");
  assert.strictEqual(skuRes.part?.sku, "NP04011448");
  assert.strictEqual(skuRes.part?.price, 6500);

  // EAN-13
  const eanRes = await scanBarcodeWorkflow("0793573199210", repairIntegration);
  assert.strictEqual(eanRes.type, "part");
  assert.strictEqual(eanRes.part?.id, "var_screen_a2338");

  // Repair ticket
  const ticketRes = await scanBarcodeWorkflow("REP-10023", repairIntegration);
  assert.strictEqual(ticketRes.type, "ticket");
  assert.strictEqual(ticketRes.ticket?.ticket_number, "REP-10023");
  assert.strictEqual(ticketRes.ticket?.customer_name, "John Doe");

  // Serial number
  const serialRes = await scanBarcodeWorkflow("C02G4120MD6R", repairIntegration);
  assert.strictEqual(serialRes.type, "device");
  assert.strictEqual(serialRes.device_history?.[0].serial_number, "C02G4120MD6R");

  // Unknown
  const unknownRes = await scanBarcodeWorkflow("UNKNOWN_CODE", repairIntegration);
  assert.strictEqual(unknownRes.type, "unknown");
});
