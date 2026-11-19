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

// ==========================================
// 4. quickCustomerWorkflow & Checkout with Customer Tests
// ==========================================

import {
  createQuickCustomerWorkflow,
  searchCustomersWorkflow,
} from "../src/workflows/quick-customer.js";

test("quickCustomerWorkflow: Creates a registered customer with unique auto-generated fallback email", async () => {
  const customer = await createQuickCustomerWorkflow({
    first_name: "Alice",
    last_name: "Wambui",
    phone: "+254 700 112 233",
    company_name: "Safari Tech",
  });

  assert.ok(customer.id.startsWith("cus_"));
  assert.strictEqual(customer.first_name, "Alice");
  assert.strictEqual(customer.last_name, "Wambui");
  assert.strictEqual(customer.phone, "+254 700 112 233");
  assert.strictEqual(customer.company_name, "Safari Tech");
  assert.strictEqual(customer.has_account, true); // Must be a registered client, not guest
  assert.strictEqual(customer.email, "walkin_254700112233@pos.urbandevicecare.co.uk");
  assert.strictEqual(customer.metadata.company_name, "Safari Tech");
  assert.strictEqual(customer.metadata.is_pos_registered, true);
});

test("quickCustomerWorkflow: Preserves explicit email and enforces required fields", async () => {
  const customerWithEmail = await createQuickCustomerWorkflow({
    first_name: "Bob",
    last_name: "Otieno",
    phone: "0711223344",
    email: "bob.otieno@company.com",
  });
  assert.strictEqual(customerWithEmail.email, "bob.otieno@company.com");
  assert.strictEqual(customerWithEmail.has_account, true);

  // Validation: Missing first_name
  await assert.rejects(
    async () => {
      await createQuickCustomerWorkflow({
        first_name: "",
        last_name: "Otieno",
        phone: "0711223344",
      });
    },
    /First name is required/
  );

  // Validation: Missing phone
  await assert.rejects(
    async () => {
      await createQuickCustomerWorkflow({
        first_name: "Bob",
        last_name: "Otieno",
        phone: "",
      });
    },
    /Phone number is required/
  );
});

test("searchCustomersWorkflow: Resolves existing registered customers by name, phone, or company", async () => {
  // Search by name
  const nameResults = await searchCustomersWorkflow("Alice");
  assert.ok(nameResults.length >= 1);
  assert.strictEqual(nameResults[0].first_name, "Alice");

  // Search by phone
  const phoneResults = await searchCustomersWorkflow("700112233");
  assert.ok(phoneResults.length >= 1);
  assert.strictEqual(phoneResults[0].last_name, "Wambui");

  // Search by company
  const companyResults = await searchCustomersWorkflow("Safari Tech");
  assert.ok(companyResults.length >= 1);
  assert.strictEqual(companyResults[0].company_name, "Safari Tech");
});

test("posCheckoutWorkflow: Attaches registered customer into checkout metadata", async () => {
  const registerService = new RegisterModuleService();
  const repairIntegration = new RepairPluginIntegration();
  const documentsIntegration = new DocumentsPluginIntegration();
  const paystackIntegration = new PaystackPluginIntegration();

  const checkoutInput = {
    terminal_id: "bench_terminal_01",
    cashier: {
      id: "usr_01KRV9NELLY",
      name: "Nelly K.",
      email: "nelly@urbandevicecare.co.uk",
    },
    items: [
      {
        variant_id: "var_diag",
        title: "Standard Workshop Diagnostic Service",
        quantity: 1,
        unit_price: 2000,
      },
    ],
    tender: {
      type: "cash" as const,
      tendered: 2320,
      change: 0,
    },
    customer: {
      id: "cus_alice_wambui",
      first_name: "Alice",
      last_name: "Wambui",
      email: "walkin_254700112233@pos.urbandevicecare.co.uk",
      phone: "+254 700 112 233",
      company_name: "Safari Tech",
    },
  };

  const result = await posCheckoutWorkflow(checkoutInput, {
    registerService,
    repairIntegration,
    documentsIntegration,
    paystackIntegration,
  });

  assert.strictEqual(result.customer_id, "cus_alice_wambui");
  assert.strictEqual(result.customer?.first_name, "Alice");
  assert.strictEqual(result.metadata.customer_id, "cus_alice_wambui");
  assert.strictEqual(result.metadata.customer_name, "Alice Wambui");
  assert.strictEqual(result.metadata.customer_email, "walkin_254700112233@pos.urbandevicecare.co.uk");
  assert.strictEqual(result.metadata.customer_phone, "+254 700 112 233");
  assert.strictEqual(result.metadata.customer_company, "Safari Tech");
});

test("quickCustomerWorkflow: Generates collision-free fallback email when multiple customers share phone", async () => {
  // Alice is already registered with +254 700 112 233 -> walkin_254700112233@pos.urbandevicecare.co.uk
  // Now register Bob with the same shared phone number
  const bob = await createQuickCustomerWorkflow({
    first_name: "Bob",
    last_name: "Wambui",
    phone: "+254 700 112 233",
  });

  assert.strictEqual(bob.first_name, "Bob");
  assert.strictEqual(bob.has_account, true);
  // Email must be distinct to satisfy Medusa's unique constraint
  assert.strictEqual(bob.email, "walkin_254700112233_2@pos.urbandevicecare.co.uk");

  // Re-submitting the exact same Alice should be idempotent and return Alice
  const aliceAgain = await createQuickCustomerWorkflow({
    first_name: "Alice",
    last_name: "Wambui",
    phone: "+254 700 112 233",
  });
  assert.strictEqual(aliceAgain.first_name, "Alice");
  assert.strictEqual(aliceAgain.email, "walkin_254700112233@pos.urbandevicecare.co.uk");
});

test("quickCustomerWorkflow: Rejects invalid email syntax and non-digit phone numbers", async () => {
  // Rejects invalid email syntax
  await assert.rejects(
    async () => {
      await createQuickCustomerWorkflow({
        first_name: "Invalid",
        last_name: "Email",
        phone: "+254700112233",
        email: "not-an-email",
      });
    },
    /Invalid email format/
  );

  // Rejects phone with no digits/characters
  await assert.rejects(
    async () => {
      await createQuickCustomerWorkflow({
        first_name: "Invalid",
        last_name: "Phone",
        phone: "---+---",
      });
    },
    /Phone number must contain at least one valid digit or character/
  );
});

import { GET as adminGetCustomers, POST as adminPostCustomers } from "../src/api/admin/customers/route.js";

test("adminCustomersRoute: Supports standard Medusa v2 GET and POST /admin/customers", async () => {
  let createdStatusCode = 0;
  let createdData: any = null;
  const postRes = {
    status(code: number) {
      createdStatusCode = code;
      return this;
    },
    json(data: any) {
      createdData = data;
      return this;
    },
  };

  await adminPostCustomers(
    {
      body: {
        first_name: "Catherine",
        last_name: "Nduta",
        phone: "+254 711 000 999",
        company_name: "Nduta Enterprises",
      },
    },
    postRes
  );

  assert.strictEqual(createdStatusCode, 201);
  assert.strictEqual(createdData.customer.first_name, "Catherine");
  assert.strictEqual(createdData.customer.has_account, true);
  assert.strictEqual(createdData.customer.email, "walkin_254711000999@pos.urbandevicecare.co.uk");

  let listStatusCode = 0;
  let listData: any = null;
  const getRes = {
    status(code: number) {
      listStatusCode = code;
      return this;
    },
    json(data: any) {
      listData = data;
      return this;
    },
  };

  await adminGetCustomers({ query: { q: "Catherine" } }, getRes);
  assert.strictEqual(listStatusCode, 200);
  assert.ok(listData.customers.length >= 1);
  assert.strictEqual(listData.customers[0].first_name, "Catherine");
});


