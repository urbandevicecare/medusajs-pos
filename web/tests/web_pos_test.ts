import { assertEquals, assertExists } from "jsr:@std/assert";
import { MedusaPOSService } from "../services/medusa.ts";
import { ThermalPrinterService, ThermalReceiptData } from "../services/thermal.ts";
import { medusa, medusaUrl } from "../lib/sdk.ts";
import { handler as posMiddlewareHandler } from "../routes/pos/_middleware.ts";
import { handler as posScanHandler } from "../routes/api/pos/scan.ts";
import { handler as posCheckoutHandler } from "../routes/api/pos/checkout.ts";
import { handler as posReceiptHandler } from "../routes/api/pos/receipt.ts";
import { handler as posAuthHandler } from "../routes/api/pos/auth.ts";
import { handler as posCustomersHandler } from "../routes/api/pos/customers.ts";
import { handler as legacyScanHandler } from "../routes/api/scan.ts";
import { handler as legacyCheckoutHandler } from "../routes/api/checkout.ts";
import { handler as legacyReceiptHandler } from "../routes/api/receipt.ts";
import { handler as legacyAuthHandler } from "../routes/api/auth.ts";
import { handler as legacyCustomersHandler } from "../routes/api/customers.ts";

const service = new MedusaPOSService();

Deno.test("Medusa Storefront SDK initialization and configuration", () => {
  assertExists(medusa);
  assertExists(medusa.store);
  assertExists(medusa.store.product);
  assertExists(medusaUrl);
  assertEquals(typeof medusaUrl, "string");
});

Deno.test("Admin accounts & cashier PIN handover", async () => {
  // Test login
  const session = await service.loginAdmin("nelly@urbandevicecare.co.uk", "password");
  assertExists(session.admin);
  assertEquals(session.admin.first_name, "Nelly");

  // Test PIN login
  const pinSession = await service.loginWithPin("1234");
  assertExists(pinSession);
  assertEquals(pinSession.admin.id, "usr_01KRV9NELLY");

  // Test custom staff PIN
  service.registerPin("9999", {
    id: "usr_bench_tech_09",
    email: "james@urbandevicecare.co.uk",
    first_name: "James",
    role: "technician",
  });
  const customSession = await service.loginWithPin("9999");
  assertExists(customSession);
  assertEquals(customSession.admin.first_name, "James");

  // Invalid PIN
  const invalidSession = await service.loginWithPin("0000");
  assertEquals(invalidSession, null);
});

Deno.test("1D Linear Barcode SKU resolution", async () => {
  const res = await service.resolveScan("NP04011448");
  assertEquals(res.type, "part");
  assertExists(res.part);
  assertEquals(res.part.sku, "NP04011448");
  assertEquals(res.part.price, 6500);
});

Deno.test("Manufacturer EAN and UPC Barcode resolution", async () => {
  // EAN-13
  const eanRes = await service.resolveScan("0793573199210");
  assertEquals(eanRes.type, "part");
  assertExists(eanRes.part);
  assertEquals(eanRes.part.price, 28500);

  // UPC-A
  const upcRes = await service.resolveScan("194252432822");
  assertEquals(upcRes.type, "part");
  assertExists(upcRes.part);
  assertEquals(upcRes.part.sku, "ACC-CHG-67W");
});

Deno.test("Repair Ticket QR resolution (REP-10023)", async () => {
  const ticketRes = await service.resolveScan("REP-10023");
  assertEquals(ticketRes.type, "ticket");
  assertExists(ticketRes.ticket);
  assertEquals(ticketRes.ticket.ticket_number, "REP-10023");
  assertEquals(ticketRes.ticket.customer_name, "John Doe");
});

Deno.test("Apple Device 12-char serial number resolution", async () => {
  const serialRes = await service.resolveScan("C02G4120MD6R");
  assertEquals(serialRes.type, "device");
  assertExists(serialRes.device_history);
  assertEquals(serialRes.device_history[0].serial_number, "C02G4120MD6R");
});

Deno.test("Unknown or empty scan handling", async () => {
  const emptyRes = await service.resolveScan("");
  assertEquals(emptyRes.type, "unknown");

  const nonExistentRes = await service.resolveScan("XYZ_999999");
  assertEquals(nonExistentRes.type, "unknown");
  assertEquals(nonExistentRes.part, undefined);
});

Deno.test("ESC/POS 58mm binary thermal receipt generator", () => {
  const receiptData: ThermalReceiptData = {
    storeName: "Urban Device Care",
    storeAddress: "Shop 12, Tech Centre, Nairobi",
    orderNumber: "POS-981240",
    cashierName: "Nelly K.",
    cashierId: "usr_01KRV9NELLY",
    terminalChannel: "web_counter_01",
    items: [
      {
        title: "MacBook Air M2 Keyboard",
        sku: "NP04011448",
        quantity: 1,
        unitPrice: 6500,
        total: 6500,
      },
    ],
    subtotal: 6500,
    tax: 1040,
    grandTotal: 7540,
    tenderType: "cash",
    tendered: 8000,
    change: 460,
    trackingUrl: "https://track.urbandevicecare.co.uk/order/POS-981240",
  };

  const bytes = ThermalPrinterService.generateEscPos58mm(receiptData);
  assertExists(bytes);
  assertEquals(bytes.length > 100, true);

  // Check ESC @ init
  assertEquals(bytes[0], 0x1b);
  assertEquals(bytes[1], 0x40);

  // Check ending paper cut GS V 66 0
  const len = bytes.length;
  assertEquals(bytes[len - 1], 0x00);
  assertEquals(bytes[len - 2], 0x42);
  assertEquals(bytes[len - 3], 0x56);
  assertEquals(bytes[len - 4], 0x1d);

  // Check string contents
  const text = new TextDecoder().decode(bytes);
  assertEquals(text.includes("Urban Device Care"), true);
  assertEquals(text.includes("Nelly K."), true);
  assertEquals(text.includes("web_counter_01"), true);
  assertEquals(text.includes("KES 7540.00"), true);
});

Deno.test("Storefront POS route middleware sets hideLayout and page title", async () => {
  const fakeCtx: any = {
    state: {},
    next: () => Promise.resolve(new Response("next-ok")),
  };
  const resp = await posMiddlewareHandler(fakeCtx);
  assertEquals(resp.status, 200);
  assertEquals(fakeCtx.state.hideLayout, true);
  assertEquals(fakeCtx.state.title, "Urban Device Care • Web POS");
});

Deno.test("POS API Routes: /api/pos/scan and legacy /api/scan", async () => {
  // /api/pos/scan
  const req1 = new Request("http://localhost:8000/api/pos/scan?code=NP04011448");
  const res1 = await posScanHandler(req1);
  assertEquals(res1.status, 200);
  const data1 = await res1.json();
  assertEquals(data1.type, "part");
  assertEquals(data1.part.sku, "NP04011448");

  // legacy /api/scan
  const req2 = new Request("http://localhost:8000/api/scan?code=NP04011448");
  const res2 = await legacyScanHandler(req2);
  assertEquals(res2.status, 200);
  const data2 = await res2.json();
  assertEquals(data2.type, "part");
  assertEquals(data2.part.sku, "NP04011448");
});

Deno.test("POS API Routes: /api/pos/checkout and legacy /api/checkout", async () => {
  const body = {
    terminal_channel: "web_counter_01",
    cashier: { id: "usr_01KRV9NELLY", name: "Nelly K." },
    items: [
      { variant_id: "var_kb_a2681", title: "MacBook Air Keyboard", price: 6500, quantity: 1, total: 6500 },
    ],
    subtotal: 6500,
    tax: 1040,
    grand_total: 7540,
    tender: { type: "cash", tendered: 8000, change: 460 },
  };

  // /api/pos/checkout
  const req1 = new Request("http://localhost:8000/api/pos/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const res1 = await posCheckoutHandler(req1);
  assertEquals(res1.status, 200);
  const data1 = await res1.json();
  assertEquals(data1.success, true);
  assertEquals(data1.order.metadata.pos_channel, "web_counter_01");
  assertEquals(data1.order.grand_total, 7540);

  // legacy /api/checkout
  const req2 = new Request("http://localhost:8000/api/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const res2 = await legacyCheckoutHandler(req2);
  assertEquals(res2.status, 200);
  const data2 = await res2.json();
  assertEquals(data2.success, true);
  assertEquals(data2.order.metadata.cashier_name, "Nelly K.");
});

Deno.test("POS API Routes: /api/pos/receipt and legacy /api/receipt", async () => {
  // ESC/POS binary format
  const binReq = new Request("http://localhost:8000/api/pos/receipt?order_number=POS-123456&format=escpos");
  const binRes = await posReceiptHandler(binReq);
  assertEquals(binRes.status, 200);
  assertEquals(binRes.headers.get("Content-Type"), "application/octet-stream");
  const binBuffer = await binRes.arrayBuffer();
  assertEquals(binBuffer.byteLength > 50, true);

  // HTML format
  const htmlReq = new Request("http://localhost:8000/api/pos/receipt?order_number=POS-123456&format=html");
  const htmlRes = await posReceiptHandler(htmlReq);
  assertEquals(htmlRes.status, 200);
  assertEquals(htmlRes.headers.get("Content-Type"), "text/html; charset=utf-8");
  const html = await htmlRes.text();
  assertEquals(html.includes("POS-123456"), true);
  assertEquals(html.includes("Urban Device Care"), true);

  // legacy receipt check
  const legReq = new Request("http://localhost:8000/api/receipt?order_number=POS-123456&format=html");
  const legRes = await legacyReceiptHandler(legReq);
  assertEquals(legRes.status, 200);
});

Deno.test("POS API Routes: /api/pos/auth and legacy /api/auth", async () => {
  // GET session with PIN
  const getReq = new Request("http://localhost:8000/api/pos/auth?pin=1234");
  const getRes = await posAuthHandler(getReq);
  assertEquals(getRes.status, 200);
  const getData = await getRes.json();
  assertEquals(getData.admin.id, "usr_01KRV9NELLY");

  // POST login with PIN
  const postReq = new Request("http://localhost:8000/api/pos/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ pin: "5555" }),
  });
  const postRes = await posAuthHandler(postReq);
  assertEquals(postRes.status, 200);
  const postData = await postRes.json();
  assertEquals(postData.admin.first_name, "Dan");

  // Legacy route check
  const legReq = new Request("http://localhost:8000/api/auth?pin=1234");
  const legRes = await legacyAuthHandler(legReq);
  assertEquals(legRes.status, 200);
  const legData = await legRes.json();
  assertEquals(legData.admin.id, "usr_01KRV9NELLY");
});

Deno.test("POS Route: root redirect handler redirects to /pos", async () => {
  const { handler } = await import("../routes/index.tsx");
  const ctx: any = { req: new Request("http://localhost:8000/") };
  const res = await handler.GET(ctx);
  assertEquals(res.status, 307);
  assertEquals(res.headers.get("Location"), "http://localhost:8000/pos");
});

Deno.test("POS Route: /pos page module exports valid Fresh page component", async () => {
  const { default: PosPage } = await import("../routes/pos/index.tsx");
  assertExists(PosPage);
  assertEquals(typeof PosPage, "function");
});

Deno.test("Quick customer creation with fallback unique walk-in email", async () => {
  // Test creation without email (auto-generates walkin_{phone}@pos.urbandevicecare.co.uk)
  const cust1 = await service.createCustomer({
    first_name: "Alice",
    last_name: "Wambui",
    phone: "+254 700 999 888",
    company_name: "Safari Tech",
  });

  assertExists(cust1);
  assertExists(cust1.id);
  assertEquals(cust1.first_name, "Alice");
  assertEquals(cust1.last_name, "Wambui");
  assertEquals(cust1.phone, "+254 700 999 888");
  assertEquals(cust1.company_name, "Safari Tech");
  assertEquals(cust1.email, "walkin_254700999888@pos.urbandevicecare.co.uk");
  assertEquals(cust1.has_account, true);
  assertEquals(cust1.metadata?.is_pos_registered, true);

  // Test creation with explicit email
  const cust2 = await service.createCustomer({
    first_name: "Bob",
    last_name: "Kariuki",
    phone: "0711223344",
    email: "bob.k@example.com",
  });
  assertEquals(cust2.email, "bob.k@example.com");
  assertEquals(cust2.has_account, true);

  // Fallback email collision protection when different person shares phone
  const sharedCust = await service.createCustomer({
    first_name: "David",
    last_name: "Wambui",
    phone: "+254 700 999 888",
  });
  assertEquals(sharedCust.first_name, "David");
  assertEquals(sharedCust.email, "walkin_254700999888_2@pos.urbandevicecare.co.uk");
  assertEquals(sharedCust.has_account, true);

  // Validation errors for missing required fields
  let errorCaught = false;
  try {
    await service.createCustomer({ first_name: "", last_name: "Doe", phone: "123" });
  } catch (err: any) {
    errorCaught = true;
    assertEquals(err.message.includes("First name is required"), true);
  }
  assertEquals(errorCaught, true);

  // Validation errors for invalid email format
  errorCaught = false;
  try {
    await service.createCustomer({ first_name: "Jane", last_name: "Doe", phone: "0711000111", email: "bademail" });
  } catch (err: any) {
    errorCaught = true;
    assertEquals(err.message.includes("Invalid email format"), true);
  }
  assertEquals(errorCaught, true);
});

Deno.test("Customer search pipeline across live sync and mock store", async () => {
  // Search by name
  const nameRes = await service.searchCustomers("Alice");
  assertEquals(nameRes.length >= 1, true);
  assertEquals(nameRes[0].first_name, "Alice");

  // Search by phone
  const phoneRes = await service.searchCustomers("700999888");
  assertEquals(phoneRes.length >= 1, true);
  assertEquals(phoneRes[0].last_name, "Wambui");

  // Search by company
  const companyRes = await service.searchCustomers("Safari Tech");
  assertEquals(companyRes.length >= 1, true);
  assertEquals(companyRes[0].company_name, "Safari Tech");

  // Non-matching query
  const emptyRes = await service.searchCustomers("UNKNOWN_PERSON_XYZ");
  assertEquals(emptyRes.length, 0);
});

Deno.test("POS API Routes: /api/pos/customers and legacy /api/customers", async () => {
  // GET customer search
  const getReq = new Request("http://localhost:8000/api/pos/customers?q=John");
  const getRes = await posCustomersHandler(getReq);
  assertEquals(getRes.status, 200);
  const getData = await getRes.json();
  assertEquals(getData.customers.length >= 1, true);
  assertEquals(getData.customers[0].first_name, "John");

  // POST quick customer creation
  const postReq = new Request("http://localhost:8000/api/pos/customers", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      first_name: "Grace",
      last_name: "Mutua",
      phone: "+254 733 111 222",
      company_name: "Apex Logistics",
    }),
  });
  const postRes = await posCustomersHandler(postReq);
  assertEquals(postRes.status, 201);
  const postData = await postRes.json();
  assertEquals(postData.success, true);
  assertEquals(postData.customer.first_name, "Grace");
  assertEquals(postData.customer.email, "walkin_254733111222@pos.urbandevicecare.co.uk");

  // Legacy route check
  const legReq = new Request("http://localhost:8000/api/customers?q=Grace");
  const legRes = await legacyCustomersHandler(legReq);
  assertEquals(legRes.status, 200);
  const legData = await legRes.json();
  assertEquals(legData.customers.length >= 1, true);
});

Deno.test("POS Order Checkout with registered customer session", async () => {
  const order = await service.createPosOrder({
    order_number: "POS-TEST-CUST",
    cashier: { id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk" },
    customer: {
      id: "cus_alice_wambui",
      first_name: "Alice",
      last_name: "Wambui",
      email: "walkin_254700999888@pos.urbandevicecare.co.uk",
      phone: "+254 700 999 888",
      company_name: "Safari Tech",
    },
    items: [{ variant_id: "var_diag", title: "Diagnostic Service", quantity: 1, unit_price: 2000, total: 2000 }],
    subtotal: 2000,
    tax: 320,
    grand_total: 2320,
    tender: { type: "cash", tendered: 2500, change: 180 },
  });

  assertExists(order);
  assertExists(order.customer);
  assertEquals(order.customer_id, "cus_alice_wambui");
  assertEquals(order.customer.first_name, "Alice");
  assertEquals(order.metadata.customer_id, "cus_alice_wambui");
  assertEquals(order.metadata.customer_name, "Alice Wambui");
  assertEquals(order.metadata.customer_email, "walkin_254700999888@pos.urbandevicecare.co.uk");
  assertEquals(order.metadata.customer_company, "Safari Tech");
});


