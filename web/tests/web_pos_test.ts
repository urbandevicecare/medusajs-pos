import { assertEquals, assertExists } from "jsr:@std/assert@1";
import { MedusaPOSService } from "../services/medusa.ts";
import {
  ThermalPrinterService,
  type ThermalReceiptData,
} from "../services/thermal.ts";
import { medusa, medusaUrl } from "../lib/sdk.ts";
import { handler as posMiddlewareHandler } from "../routes/pos/_middleware.ts";
import { handler as posScanHandler } from "../routes/api/pos/scan.ts";
import { handler as posCheckoutHandler } from "../routes/api/pos/checkout.ts";
import { handler as posReceiptHandler } from "../routes/api/pos/receipt.ts";
import { handler as posAuthHandler } from "../routes/api/pos/auth.ts";
import { handler as posCustomersHandler } from "../routes/api/pos/customers.ts";
import { handler as posRepairsHandler } from "../routes/api/pos/repairs.ts";
import { handler as posProductsHandler } from "../routes/api/pos/products.ts";
import { handler as legacyScanHandler } from "../routes/api/scan.ts";
import { handler as legacyCheckoutHandler } from "../routes/api/checkout.ts";
import { handler as legacyReceiptHandler } from "../routes/api/receipt.ts";
import { handler as legacyAuthHandler } from "../routes/api/auth.ts";
import { handler as legacyCustomersHandler } from "../routes/api/customers.ts";
import { handler as legacyRepairsHandler } from "../routes/api/repairs.ts";

const service = new MedusaPOSService();

Deno.test("Medusa Storefront SDK initialization and configuration", () => {
  assertExists(medusa);
  assertExists(medusa.store);
  assertExists(medusa.store.product);
  assertExists(medusaUrl);
  assertEquals(typeof medusaUrl, "string");
});

Deno.test("Medusa Admin accounts authentication & session token verification", async () => {
  // 1. Staff Admin login
  const session = await service.loginAdmin(
    "nelly@urbandevicecare.co.uk",
    "password",
  );
  assertExists(session.admin);
  assertExists(session.token);
  assertEquals(session.admin.first_name, "Nelly");
  assertEquals(session.admin.id, "usr_01KRV9NELLY");

  // 2. Token verification
  const verified = service.verifyAdminToken(session.token);
  assertExists(verified);
  assertEquals(verified?.id, "usr_01KRV9NELLY");

  // 3. Invalid token
  const invalidVerified = service.verifyAdminToken("token_invalid_123");
  assertEquals(invalidVerified, null);

  // 4. Invalid credentials check
  let errorCaught = false;
  try {
    await service.loginAdmin("unknown@example.com", "wrong");
  } catch (_e) {
    errorCaught = true;
  }
  assertEquals(errorCaught, true);
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
  const mockReceiptData: ThermalReceiptData = {
    storeName: "Urban Device Care",
    orderNumber: "POS-100293",
    cashierName: "Nelly K.",
    cashierId: "usr_01KRV9NELLY",
    terminalChannel: "web_pos_counter",
    items: [
      {
        title: "MacBook Air M2 Keyboard",
        quantity: 1,
        unitPrice: 6500,
        total: 6500,
      },
      {
        title: "Standard Diagnostic Service",
        quantity: 1,
        unitPrice: 2000,
        total: 2000,
      },
    ],
    subtotal: 8500,
    tax: 1360,
    grandTotal: 9860,
    tenderType: "cash",
    tendered: 10000,
    change: 140,
  };

  const bytes = ThermalPrinterService.generateEscPos58mm(mockReceiptData);
  assertExists(bytes);
  assertEquals(bytes instanceof Uint8Array, true);
  assertEquals(bytes.length > 50, true);

  // Assert ESC/POS initialization byte (0x1B, 0x40 -> '@')
  assertEquals(bytes[0], 0x1B);
  assertEquals(bytes[1], 0x40);

  // Assert Cut command at end (0x1D, 0x56, 0x42, 0x00)
  const len = bytes.length;
  assertEquals(bytes[len - 4], 0x1D);
  assertEquals(bytes[len - 3], 0x56);
  assertEquals(bytes[len - 2], 0x42);
  assertEquals(bytes[len - 1], 0x00);
});

Deno.test("HTML 58mm preview thermal receipt generator", () => {
  const mockReceiptData: ThermalReceiptData = {
    storeName: "Urban Device Care",
    orderNumber: "POS-998877",
    cashierName: "Dan M.",
    cashierId: "usr_02TECH_DAN",
    terminalChannel: "web_pos_counter",
    items: [
      {
        title: "Diagnostic Service",
        quantity: 1,
        unitPrice: 2000,
        total: 2000,
      },
    ],
    subtotal: 2000,
    tax: 320,
    grandTotal: 2320,
    tenderType: "card",
    tendered: 2320,
    change: 0,
  };

  const html = ThermalPrinterService.generateHtml58mm(mockReceiptData);
  assertExists(html);
  assertEquals(html.includes("URBAN DEVICE CARE"), true);
  assertEquals(html.includes("POS-998877"), true);
  assertEquals(html.includes("Dan M."), true);
  assertEquals(html.includes("58mm"), true);
});

Deno.test("POS Terminal Security Middleware", async () => {
  let nextCalled = false;
  const ctx: any = {
    req: new Request("http://localhost:8000/pos"),
    state: {},
    next: () => {
      nextCalled = true;
      return new Response("OK", { status: 200 });
    },
  };
  const res = await (posMiddlewareHandler as any)(ctx);
  assertEquals(nextCalled, true);
  assertEquals(res.status, 200);
  assertEquals(ctx.state.hideLayout, true);
  assertEquals(ctx.state.title.includes("Web POS"), true);
});

Deno.test("POS API Routes: /api/pos/scan and legacy /api/scan", async () => {
  // Test new /api/pos/scan
  const req1 = new Request(
    "http://localhost:8000/api/pos/scan?code=NP04011448",
  );
  const res1 = await posScanHandler(req1);
  assertEquals(res1.status, 200);
  const data1 = await res1.json();
  assertEquals(data1.type, "part");
  assertEquals(data1.part.sku, "NP04011448");

  // Test backward compatible /api/scan
  const req2 = new Request("http://localhost:8000/api/scan?code=REP-10023");
  const res2 = await legacyScanHandler(req2);
  assertEquals(res2.status, 200);
  const data2 = await res2.json();
  assertEquals(data2.type, "ticket");
  assertEquals(data2.ticket.ticket_number, "REP-10023");
});

Deno.test("POS API Routes: /api/pos/checkout and legacy /api/checkout", async () => {
  const checkoutPayload = {
    order_number: "POS-TEST-8888",
    cashier: {
      id: "usr_01KRV9NELLY",
      name: "Nelly K.",
      email: "nelly@urbandevicecare.co.uk",
    },
    items: [
      {
        variant_id: "var_diag",
        title: "Diagnostic",
        quantity: 1,
        unit_price: 2000,
        total: 2000,
      },
    ],
    subtotal: 2000,
    tax: 320,
    grand_total: 2320,
    tender: { type: "cash", tendered: 3000, change: 680 },
  };

  // Test new /api/pos/checkout
  const req1 = new Request("http://localhost:8000/api/pos/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(checkoutPayload),
  });
  const res1 = await posCheckoutHandler(req1);
  assertEquals(res1.status, 200);
  const data1 = await res1.json();
  assertEquals(data1.status, "completed");
  assertEquals(data1.order_number, "POS-TEST-8888");

  // Test backward compatible /api/checkout
  const req2 = new Request("http://localhost:8000/api/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...checkoutPayload, order_number: "POS-TEST-9999" }),
  });
  const res2 = await legacyCheckoutHandler(req2);
  assertEquals(res2.status, 200);
  const data2 = await res2.json();
  assertEquals(data2.order_number, "POS-TEST-9999");
});

Deno.test("POS API Routes: /api/pos/receipt (ESC/POS binary & HTML format)", async () => {
  // ESC/POS binary format
  const binReq = new Request(
    "http://localhost:8000/api/pos/receipt?order_number=POS-123456&format=escpos",
  );
  const binRes = await posReceiptHandler(binReq);
  assertEquals(binRes.status, 200);
  assertEquals(binRes.headers.get("Content-Type"), "application/octet-stream");
  const binBuf = await binRes.arrayBuffer();
  assertEquals(binBuf.byteLength > 50, true);

  // HTML format
  const htmlReq = new Request(
    "http://localhost:8000/api/pos/receipt?order_number=POS-123456&format=html",
  );
  const htmlRes = await posReceiptHandler(htmlReq);
  assertEquals(htmlRes.status, 200);
  assertEquals(htmlRes.headers.get("Content-Type"), "text/html; charset=utf-8");
  const htmlText = await htmlRes.text();
  assertEquals(htmlText.includes("POS-123456"), true);

  // legacy receipt check
  const legReq = new Request(
    "http://localhost:8000/api/receipt?order_number=POS-123456&format=html",
  );
  const legRes = await legacyReceiptHandler(legReq);
  assertEquals(legRes.status, 200);
});

Deno.test("POS API Routes: /api/pos/auth and legacy /api/auth with Medusa Admin credentials", async () => {
  // POST login with Medusa Admin email & password
  const postReq = new Request("http://localhost:8000/api/pos/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: "nelly@urbandevicecare.co.uk",
      password: "password",
    }),
  });
  const postRes = await posAuthHandler(postReq);
  assertEquals(postRes.status, 200);
  const postData = await postRes.json();
  assertEquals(postData.admin.first_name, "Nelly");
  assertExists(postData.token);

  // GET session with Bearer token
  const getReq = new Request("http://localhost:8000/api/pos/auth", {
    headers: { Authorization: `Bearer ${postData.token}` },
  });
  const getRes = await posAuthHandler(getReq);
  assertEquals(getRes.status, 200);
  const getData = await getRes.json();
  assertEquals(getData.authenticated, true);
  assertEquals(getData.admin.id, "usr_01KRV9NELLY");

  // GET without token returns 401
  const unauthReq = new Request("http://localhost:8000/api/pos/auth");
  const unauthRes = await posAuthHandler(unauthReq);
  assertEquals(unauthRes.status, 401);

  // Legacy route check
  const legReq = new Request("http://localhost:8000/api/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: "dan@urbandevicecare.co.uk",
      password: "password",
    }),
  });
  const legRes = await legacyAuthHandler(legReq);
  assertEquals(legRes.status, 200);
  const legData = await legRes.json();
  assertEquals(legData.admin.first_name, "Dan");
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
  assertEquals(
    sharedCust.email,
    "walkin_254700999888_2@pos.urbandevicecare.co.uk",
  );
  assertEquals(sharedCust.has_account, true);

  // Validation errors for missing required fields
  let errorCaught = false;
  try {
    await service.createCustomer({
      first_name: "",
      last_name: "Doe",
      phone: "123",
    });
  } catch (err: any) {
    errorCaught = true;
    assertEquals(err.message.includes("First name is required"), true);
  }
  assertEquals(errorCaught, true);

  // Validation errors for invalid email format
  errorCaught = false;
  try {
    await service.createCustomer({
      first_name: "Jane",
      last_name: "Doe",
      phone: "0711000111",
      email: "bademail",
    });
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

Deno.test("POS API Routes: /api/pos/customers and legacy /api/customers with Bearer token", async () => {
  // GET customer search with Authorization header
  const getReq = new Request("http://localhost:8000/api/pos/customers?q=John", {
    headers: { Authorization: "Bearer token_staff_usr_01KRV9NELLY" },
  });
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
  assertEquals(
    postData.customer.email,
    "walkin_254733111222@pos.urbandevicecare.co.uk",
  );

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
    cashier: {
      id: "usr_01KRV9NELLY",
      name: "Nelly K.",
      email: "nelly@urbandevicecare.co.uk",
    },
    customer: {
      id: "cus_alice_wambui",
      first_name: "Alice",
      last_name: "Wambui",
      email: "walkin_254700999888@pos.urbandevicecare.co.uk",
      phone: "+254 700 999 888",
      company_name: "Safari Tech",
    },
    items: [{
      variant_id: "var_diag",
      title: "Diagnostic Service",
      quantity: 1,
      unit_price: 2000,
      total: 2000,
    }],
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
  assertEquals(
    order.metadata.customer_email,
    "walkin_254700999888@pos.urbandevicecare.co.uk",
  );
  assertEquals(order.metadata.customer_company, "Safari Tech");
});

Deno.test("Workshop Intake & Repairs Module (getRepairs & createRepairIntake)", async () => {
  // 1. Initial list with zero dummy data
  const initialRepairs = await service.getRepairs();
  assertEquals(Array.isArray(initialRepairs), true);

  // 2. Create a new repair intake
  const newIntake = await service.createRepairIntake(undefined, {
    customer_id: "cus_01JOHN_DOE",
    customer_name: "John Doe",
    brand: "Apple",
    model_name: "iPhone 15 Pro",
    device_type: "smartphone",
    serial_number: "DX398102KL",
    issue_description: "Cracked OLED screen after drop",
    total_estimate: 24000,
    deposit_amount: 5000,
  });

  assertExists(newIntake);
  assertExists(newIntake.ticket_number);
  assertEquals(newIntake.device_name, "Apple iPhone 15 Pro");
  assertEquals(newIntake.total_estimate, 24000);
  assertEquals(newIntake.deposit_amount, 5000);
  assertEquals(newIntake.balance_due, 19000);
  assertEquals(newIntake.status, "received");

  // 3. Update repair status & add note matching repair plugin
  const statusUpdated = await service.updateRepairStatus(
    undefined,
    newIntake.id,
    "repairing",
    "Started screen replacement",
  );
  assertEquals(statusUpdated, true);
  const noteAdded = await service.addRepairNote(
    undefined,
    newIntake.id,
    "Disassembled device",
    false,
  );
  assertEquals(noteAdded, true);

  // 4. Filter by status
  const repairingRepairs = await service.getRepairs(undefined, "repairing");
  assertEquals(repairingRepairs.some((r) => r.id === newIntake.id), true);

  // 5. API endpoints test: GET /api/pos/repairs
  const getReq1 = new Request(
    "http://localhost:8000/api/pos/repairs?status=all",
  );
  const getRes1 = await posRepairsHandler(getReq1);
  assertEquals(getRes1.status, 200);
  const getData1 = await getRes1.json();
  assertEquals(getData1.repairs.length >= 1, true);

  // 5. API endpoints test: POST /api/pos/repairs
  const postReq = new Request("http://localhost:8000/api/pos/repairs", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      customer_id: "cus_02JANE_SMITH",
      customer_name: "Jane Smith",
      brand: "Apple",
      model_name: "iPad Pro 12.9",
      issue_description: "Battery not charging",
      total_estimate: 15000,
      deposit_amount: 3000,
    }),
  });
  const postRes = await posRepairsHandler(postReq);
  assertEquals(postRes.status, 201);
  const postData = await postRes.json();
  assertEquals(postData.success, true);
  assertEquals(postData.repair.balance_due, 12000);

  // 6. Legacy /api/repairs test
  const legReq = new Request("http://localhost:8000/api/repairs?status=all");
  const legRes = await legacyRepairsHandler(legReq);
  assertEquals(legRes.status, 200);
});

Deno.test("Custom Cart Line Item & Default customer fallback", async () => {
  // Test order checkout with custom uncataloged line item and cashier default customer
  const cashierAdmin = {
    id: "usr_01KRV9NELLY",
    name: "Nelly K.",
    first_name: "Nelly",
    last_name: "K.",
    email: "nelly@urbandevicecare.co.uk",
  };

  const customLineItem = {
    variant_id: "custom_item_12345",
    title: "Special Anti-Glare Screen Protector (Custom)",
    quantity: 2,
    unit_price: 1500,
    total: 3000,
    is_custom: true,
  };

  // If no customer is selected, system defaults to cashier admin user
  const order = await service.createPosOrder({
    order_number: "POS-CUSTOM-ITEM",
    cashier: cashierAdmin,
    customer: {
      id: cashierAdmin.id,
      first_name: cashierAdmin.first_name,
      last_name: cashierAdmin.last_name,
      email: cashierAdmin.email,
      has_account: true,
      company_name: "Urban Device Care Staff",
    },
    items: [customLineItem],
    subtotal: 3000,
    tax: 480,
    grand_total: 3480,
    tender: { type: "cash", tendered: 3500, change: 20 },
  });

  assertExists(order);
  assertEquals(order.items.length, 1);
  assertEquals(order.items[0].is_custom, true);
  assertEquals(order.customer_id, "usr_01KRV9NELLY");
  assertEquals(order.metadata.cashier_id, "usr_01KRV9NELLY");
});

Deno.test("POS Products & Catalog: live search suggestions and infinite scroll pagination", async () => {
  // 1. getCatalog pagination
  const catalogPage1 = await service.getCatalog({
    limit: 2,
    offset: 0,
    includeFallback: true,
  });
  assertExists(catalogPage1.products);
  assertEquals(catalogPage1.limit, 2);
  assertEquals(catalogPage1.offset, 0);

  // 2. getCatalog keyword search (searching by item title / name)
  const searchResult = await service.getCatalog({
    q: "Keyboard",
    limit: 10,
    includeFallback: true,
  });
  assertExists(searchResult.products);
  const found = searchResult.products.some((p) =>
    p.title.toLowerCase().includes("keyboard")
  );
  assertEquals(found, true);

  // 3. /api/pos/products API route invocation
  const req = new Request(
    "http://localhost:8000/api/pos/products?q=MacBook&limit=5&fallback=true",
  );
  const res = await posProductsHandler(req);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("content-type"), "application/json");
  const data = await res.json();
  assertExists(data.products);
  assertEquals(typeof data.count, "number");
  assertEquals(typeof data.has_more, "boolean");
});
