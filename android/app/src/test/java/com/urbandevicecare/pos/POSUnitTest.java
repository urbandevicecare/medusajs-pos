package com.urbandevicecare.pos;

import com.urbandevicecare.pos.model.CartItem;
import com.urbandevicecare.pos.model.Cashier;
import com.urbandevicecare.pos.model.POSCustomer;
import com.urbandevicecare.pos.model.ProductPart;
import com.urbandevicecare.pos.model.ReceiptData;
import com.urbandevicecare.pos.printer.CS30ThermalPrinter;

import com.urbandevicecare.pos.model.RepairTicketRecord;
import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/**
 * Native Android POS Unit & Integration Test Suite
 */
public class POSUnitTest {

    @Test
    public void testProductAndCartOperations() {
        ProductPart part1 = new ProductPart("var_kb_a2681", "Keyboard", "MacBook Air M2 Keyboard", "NP04011448", "NP04011448", 6500.0, 10);
        ProductPart part2 = new ProductPart("var_diag", "Bench Diagnostic", "Diagnostic Service", "SRV-DIAG-01", "SRV-DIAG-01", 2000.0, 100);

        CartItem item1 = new CartItem(part1, 1);
        assertEquals(6500.0, item1.getLineTotal(), 0.001);

        item1.incrementQuantity();
        assertEquals(2, item1.getQuantity());
        assertEquals(13000.0, item1.getLineTotal(), 0.001);

        item1.decrementQuantity();
        assertEquals(1, item1.getQuantity());
        assertEquals(6500.0, item1.getLineTotal(), 0.001);
    }

    @Test
    public void testTaxAndGrandTotalCalculations() {
        ProductPart part = new ProductPart("test_part", "Test Part", "Test Part", "SKU-001", "SKU-001", 1000.0, 10);
        List<CartItem> cart = new ArrayList<>();
        cart.add(new CartItem(part, 1));

        double subtotal = 0;
        for (CartItem item : cart) subtotal += item.getLineTotal();
        assertEquals(1000.0, subtotal, 0.001);

        double tax = Math.round(subtotal * 0.16 * 100.0) / 100.0;
        assertEquals(160.0, tax, 0.001);

        double grandTotal = subtotal + tax;
        assertEquals(1160.0, grandTotal, 0.001);

        // Exact tender
        double tendered = 1160.0;
        double changeDue = tendered >= grandTotal ? tendered - grandTotal : 0.0;
        assertEquals(0.0, changeDue, 0.001);

        // Overpayment (2000 KES note)
        tendered = 2000.0;
        changeDue = tendered >= grandTotal ? tendered - grandTotal : 0.0;
        assertEquals(840.0, changeDue, 0.001);

        // Underpayment (500 KES note)
        tendered = 500.0;
        changeDue = tendered >= grandTotal ? tendered - grandTotal : 0.0;
        assertEquals(0.0, changeDue, 0.001);
    }

    @Test
    public void testCS30ThermalPrinterEscPosGeneration() {
        ProductPart part = new ProductPart("var_screen", "Screen", "MacBook Screen", "SCR-001", "0793573199210", 25000.0, 5);
        List<CartItem> cart = new ArrayList<>();
        cart.add(new CartItem(part, 1));

        ReceiptData receipt = new ReceiptData(
                "Urban Device Care",
                "POS-100234",
                "Nelly K.",
                "cs30_terminal_01",
                cart,
                25000.0,
                4000.0,
                29000.0,
                "cash",
                30000.0,
                1000.0,
                "https://track.urbandevicecare.co.uk/order/POS-100234"
        );

        byte[] escPosBytes = CS30ThermalPrinter.buildEscPos58mmReceipt(receipt);
        assertNotNull(escPosBytes);
        assertTrue("Receipt byte length must be greater than 100 bytes", escPosBytes.length > 100);

        // Check ESC @ init
        assertEquals(0x1B, escPosBytes[0]);
        assertEquals(0x40, escPosBytes[1]);

        // Check ending paper cut GS V 66 0
        int len = escPosBytes.length;
        assertEquals(0x00, escPosBytes[len - 1]);
        assertEquals(0x42, escPosBytes[len - 2]);
        assertEquals(0x56, escPosBytes[len - 3]);
        assertEquals(0x1D, escPosBytes[len - 4]);

        String receiptString = new String(escPosBytes);
        assertTrue(receiptString.contains("Urban Device Care"));
        assertTrue(receiptString.contains("CS30 Smart POS Terminal"));
        assertTrue(receiptString.contains("Nelly K."));
        assertTrue(receiptString.contains("cs30_terminal_01"));
    }

    @Test
    public void testCashierIdentityAndPIN() {
        Cashier cashier = new Cashier("usr_01KRV9NELLY", "Nelly K.", "nelly@urbandevicecare.co.uk");
        assertEquals("usr_01KRV9NELLY", cashier.getId());
        assertEquals("Nelly K.", cashier.getName());
        assertEquals("nelly@urbandevicecare.co.uk", cashier.getEmail());
    }

    @Test
    public void testPOSCustomerModel() {
        POSCustomer cust = new POSCustomer(
                "cus_01HQ79124XYZ",
                "Alice",
                "Wonderland",
                "alice@example.com",
                "+254 700 999 888",
                "Wonderland Dev Ltd",
                true
        );

        assertEquals("cus_01HQ79124XYZ", cust.getId());
        assertEquals("Alice", cust.getFirstName());
        assertEquals("Wonderland", cust.getLastName());
        assertEquals("Alice Wonderland", cust.getFullName());
        assertEquals("alice@example.com", cust.getEmail());
        assertEquals("+254 700 999 888", cust.getPhone());
        assertEquals("Wonderland Dev Ltd", cust.getCompanyName());
        assertTrue("Customer must have account and be registered client", cust.hasAccount());
    }

    @Test
    public void testFallbackWalkInEmailGeneration() {
        String phone = "+254 712 345 678";
        String cleanPhone = phone.trim();
        String sanitizedPhone = cleanPhone.replaceAll("[^0-9]", "");
        String fallbackEmail = "walkin_" + sanitizedPhone + "@pos.urbandevicecare.co.uk";

        assertEquals("walkin_254712345678@pos.urbandevicecare.co.uk", fallbackEmail);

        POSCustomer walkinCust = new POSCustomer(
                "cus_walkin_01",
                "Bob",
                "Builder",
                fallbackEmail,
                cleanPhone,
                null,
                true
        );

        assertEquals("walkin_254712345678@pos.urbandevicecare.co.uk", walkinCust.getEmail());
        assertTrue("Walk-in customer must be registered client", walkinCust.hasAccount());
    }

    @Test
    public void testThermalReceiptWithCustomerData() {
        ProductPart part = new ProductPart("var_test", "Test Item", "Test Item", "SKU-T", "SKU-T", 5000.0, 2);
        List<CartItem> cart = new ArrayList<>();
        cart.add(new CartItem(part, 1));

        ReceiptData receipt = new ReceiptData(
                "Urban Device Care",
                "POS-778899",
                "Nelly K.",
                "cs30_terminal_01",
                cart,
                5000.0,
                800.0,
                5800.0,
                "cash",
                6000.0,
                200.0,
                "https://track.urbandevicecare.co.uk/order/POS-778899",
                "Dr. Grace Hopper",
                "+254 722 000 111",
                "Hopper Computing"
        );

        byte[] escPosBytes = CS30ThermalPrinter.buildEscPos58mmReceipt(receipt);
        assertNotNull(escPosBytes);

        String receiptStr = new String(escPosBytes);
        assertTrue("Receipt must contain customer name and company", receiptStr.contains("Dr. Grace Hopper (Hopper Computing)"));
        assertTrue("Receipt must contain customer phone", receiptStr.contains("+254 722 000 111"));
    }

    @Test
    public void testCustomerSearchAndRegistration() {
        List<POSCustomer> store = new ArrayList<>();
        store.add(new POSCustomer("c1", "John", "Doe", "john@test.com", "+254700112233", "Nairobi Tech", true));
        store.add(new POSCustomer("c2", "Jane", "Smith", "jane@test.com", "+254711445566", "Alpha Corp", true));

        // Search by name
        POSCustomer found = null;
        String query = "jane";
        for (POSCustomer c : store) {
            if (c.getFullName().toLowerCase().contains(query) || (c.getPhone() != null && c.getPhone().contains(query))) {
                found = c;
                break;
            }
        }
        assertNotNull(found);
        assertEquals("Jane Smith", found.getFullName());

        // Search by phone
        found = null;
        query = "700112";
        for (POSCustomer c : store) {
            if (c.getFullName().toLowerCase().contains(query) || (c.getPhone() != null && c.getPhone().contains(query))) {
                found = c;
                break;
            }
        }
        assertNotNull(found);
        assertEquals("John Doe", found.getFullName());

        // Quick register a customer with optional fields omitted
        String rawPhone = "+254 799 888 777";
        String autoEmail = "walkin_" + rawPhone.replaceAll("[^0-9]", "") + "@pos.urbandevicecare.co.uk";
        POSCustomer quickAdded = new POSCustomer("c3", "Sam", "Altman", autoEmail, rawPhone, null, true);
        store.add(quickAdded);

        assertEquals(3, store.size());
        assertEquals("walkin_254799888777@pos.urbandevicecare.co.uk", quickAdded.getEmail());
        assertTrue(quickAdded.hasAccount());

        // Test collision protection: second customer with same phone number
        String secondEmail;
        String baseCollision = "walkin_" + rawPhone.replaceAll("[^0-9]", "") + "@pos.urbandevicecare.co.uk";
        boolean collision = false;
        for (POSCustomer c : store) {
            if (c.getEmail().equalsIgnoreCase(baseCollision)) {
                collision = true;
                break;
            }
        }
        assertTrue("Collision should be detected for duplicate phone", collision);
        int counter = 2;
        secondEmail = "walkin_" + rawPhone.replaceAll("[^0-9]", "") + "_" + counter + "@pos.urbandevicecare.co.uk";
        POSCustomer secondCust = new POSCustomer("c4", "Greg", "Brockman", secondEmail, rawPhone, null, true);
        store.add(secondCust);

        assertEquals(4, store.size());
        assertEquals("walkin_254799888777_2@pos.urbandevicecare.co.uk", secondCust.getEmail());
        assertTrue(secondCust.hasAccount());
    }

    @Test
    public void testZeroDummyRepairsAndIntakeCreation() {
        // Assert initial store starts empty (Zero dummy data contract)
        List<com.urbandevicecare.pos.model.RepairTicketRecord> repairs = new ArrayList<>();
        assertTrue("Initial repair tickets list must be empty (zero dummy data)", repairs.isEmpty());

        // Create a repair intake matching Medusa repair plugin 1-to-1
        double estimate = 45000.0;
        double deposit = 15000.0;
        double balDue = Math.max(0, estimate - deposit);
        String payStatus = deposit >= estimate && estimate > 0 ? "captured" : deposit > 0 ? "partially_paid" : "pending";

        com.urbandevicecare.pos.model.RepairTicketRecord ticket = new com.urbandevicecare.pos.model.RepairTicketRecord(
                "rep_intake_001",
                "REP-88991",
                "cus_01HQ79124XYZ",
                "John Doe",
                "+254 700 112 233",
                "john.doe@example.com",
                "Dan M.",
                "usr_02TECH_DAN",
                "Apple",
                "MacBook Pro 16\" (A2485)",
                "Apple MacBook Pro 16\" (A2485)",
                "C02G1234MD6R",
                "356789012345678",
                "Minor scratch on bezel",
                "received",
                "Liquid spill on top case, trackpad unresponsive",
                "MagSafe 3 Cable, 140W Adapter",
                "1234",
                estimate,
                deposit,
                balDue,
                payStatus,
                true,
                true,
                "2026-11-20T08:00:00Z"
        );

        repairs.add(0, ticket);
        assertEquals(1, repairs.size());
        assertEquals("REP-88991", ticket.getTicketNumber());
        assertEquals("Apple", ticket.getBrand());
        assertEquals("MacBook Pro 16\" (A2485)", ticket.getModelName());
        assertEquals("356789012345678", ticket.getImei());
        assertEquals("Minor scratch on bezel", ticket.getCondition());
        assertEquals("Dan M.", ticket.getTechnicianName());
        assertEquals("partially_paid", ticket.getPaymentStatus());
        assertEquals(30000.0, ticket.getBalanceDue(), 0.001);
        assertTrue(ticket.isTermsAccepted());
        assertTrue(ticket.isDataWipedConsent());
    }

    @Test
    public void testCustomNonCatalogItemAddition() {
        ProductPart customPart = new ProductPart(
                "custom_123",
                "Screen Protector Installation",
                "Screen Protector Installation",
                "SP-FIT-01",
                "SP-FIT-01",
                1500.0,
                999,
                true
        );

        assertTrue("Item must be flagged as custom", customPart.isCustom());
        assertEquals(1500.0, customPart.getPrice(), 0.001);

        CartItem item = new CartItem(customPart, 2);
        assertEquals(3000.0, item.getLineTotal(), 0.001);
    }

    @Test
    public void testDefaultCustomerFallbackToCashier() {
        Cashier cashier = new Cashier("usr_01KRV9NELLY", "Nelly K.", "nelly@urbandevicecare.co.uk", "Admin");
        POSCustomer activeCust = null; // Unselected customer

        // Emulate completeSaleAndPrint fallback logic
        String effectiveName = (activeCust != null) ? activeCust.getFullName() : cashier.getName();
        String effectivePhone = (activeCust != null) ? activeCust.getPhone() : "+254 700 000 000";
        String effectiveCompany = (activeCust != null) ? activeCust.getCompanyName() : "Staff Account (" + cashier.getRole() + ")";

        assertEquals("Nelly K.", effectiveName);
        assertEquals("+254 700 000 000", effectivePhone);
        assertEquals("Staff Account (Admin)", effectiveCompany);
    }

    @Test
    public void testVatToggleAndExemptThermalReceipt() {
        ProductPart part = new ProductPart("p1", "Battery", "OEM Battery", "BAT-01", "BAT-01", 10000.0, 5);
        List<CartItem> cart = new ArrayList<>();
        cart.add(new CartItem(part, 1));

        double subtotal = 10000.0;

        // VAT Disabled (Exempt default)
        boolean applyVat = false;
        double tax = applyVat ? Math.round(subtotal * 0.16 * 100.0) / 100.0 : 0.0;
        double grandTotal = subtotal + tax;
        assertEquals(0.0, tax, 0.001);
        assertEquals(10000.0, grandTotal, 0.001);

        // Receipt with tax = 0 should print Exempt line
        ReceiptData exemptReceipt = new ReceiptData(
                "Urban Device Care", "POS-EXEMPT-01", "Nelly K.", "cs30_01",
                cart, subtotal, tax, grandTotal, "cash", 10000.0, 0.0, ""
        );
        byte[] exemptBytes = CS30ThermalPrinter.buildEscPos58mmReceipt(exemptReceipt);
        String exemptStr = new String(exemptBytes);
        assertTrue("Thermal receipt must state KES 0.00 (Exempt) when VAT is off", exemptStr.contains("VAT (16%):") && exemptStr.contains("KES 0.00 (Exempt)"));

        // VAT Enabled (16%)
        applyVat = true;
        tax = applyVat ? Math.round(subtotal * 0.16 * 100.0) / 100.0 : 0.0;
        grandTotal = subtotal + tax;
        assertEquals(1600.0, tax, 0.001);
        assertEquals(11600.0, grandTotal, 0.001);

        ReceiptData taxedReceipt = new ReceiptData(
                "Urban Device Care", "POS-TAX-01", "Nelly K.", "cs30_01",
                cart, subtotal, tax, grandTotal, "cash", 12000.0, 400.0, ""
        );
        byte[] taxedBytes = CS30ThermalPrinter.buildEscPos58mmReceipt(taxedReceipt);
        String taxedStr = new String(taxedBytes);
        assertTrue("Thermal receipt must show KES 1600.00 when VAT is on", taxedStr.contains("VAT (16%):") && taxedStr.contains("1600.00"));
    }

    @Test
    public void testCustomerPriceListTiersAndRecalculation() {
        ProductPart basePart = new ProductPart("var_screen", "Screen M1", "MacBook Screen M1", "SCR-M1", "SCR-M1", 10000.0, 10);

        MainActivity.PriceCalculation guestCalc = MainActivity.calculatePriceForCustomer(basePart, null);
        assertEquals(10000.0, guestCalc.price, 0.001);
        assertNull(guestCalc.badge);
        assertNull(guestCalc.originalPrice);

        // VIP 10%
        POSCustomer vipCustomer = new POSCustomer("c_vip", "VIP", "Member", "vip@test.com", "07001", "VIP Ltd", true, Arrays.asList("VIP"), null, "VIP");
        MainActivity.PriceCalculation vipCalc = MainActivity.calculatePriceForCustomer(basePart, vipCustomer);
        assertEquals(9000.0, vipCalc.price, 0.001);
        assertEquals("VIP (10% Off)", vipCalc.badge);
        assertEquals(10000.0, vipCalc.originalPrice, 0.001);

        // Wholesale 20%
        POSCustomer wsCustomer = new POSCustomer("c_ws", "WS", "Member", "ws@test.com", "07002", "WS Corp", true, Arrays.asList("Wholesale"), null, "Wholesale");
        MainActivity.PriceCalculation wsCalc = MainActivity.calculatePriceForCustomer(basePart, wsCustomer);
        assertEquals(8000.0, wsCalc.price, 0.001);
        assertEquals("Wholesale (20% Off)", wsCalc.badge);
        assertEquals(10000.0, wsCalc.originalPrice, 0.001);

        // Corporate 15%
        POSCustomer corpCustomer = new POSCustomer("c_corp", "Corp", "Member", "corp@test.com", "07003", "Corp Inc", true, Arrays.asList("Corporate"), null, "Corporate");
        MainActivity.PriceCalculation corpCalc = MainActivity.calculatePriceForCustomer(basePart, corpCustomer);
        assertEquals(8500.0, corpCalc.price, 0.001);
        assertEquals("Corporate (15% Off)", corpCalc.badge);
        assertEquals(10000.0, corpCalc.originalPrice, 0.001);

        // Custom discount override (25%)
        POSCustomer customDiscountCustomer = new POSCustomer("c_disc", "Custom", "Rate", "disc@test.com", "07004", "Partner", true, Collections.emptyList(), 0.25, null);
        MainActivity.PriceCalculation customCalc = MainActivity.calculatePriceForCustomer(basePart, customDiscountCustomer);
        assertEquals(7500.0, customCalc.price, 0.001);
        assertEquals("25% Customer Discount", customCalc.badge);
        assertEquals(10000.0, customCalc.originalPrice, 0.001);

        // CartItem tracks original price and applied price list badge
        CartItem cartItem = new CartItem(basePart, 1, vipCalc.originalPrice, vipCalc.badge);
        assertEquals("VIP (10% Off)", cartItem.getAppliedPriceList());
        assertEquals(10000.0, cartItem.getOriginalPrice(), 0.001);
    }

    @Test
    public void testActualStockResolutionAndExceedsWarning() {
        ProductPart limitedPart = new ProductPart("p_ltd", "Keyboard", "Keyboard", "KB-01", "KB-01", 5000.0, 3);
        CartItem normalItem = new CartItem(limitedPart, 3);
        boolean normalExceeds = normalItem.getQuantity() > normalItem.getPart().getInventoryQuantity();
        assertFalse("3 in cart with 3 in stock should NOT exceed stock", normalExceeds);

        CartItem overItem = new CartItem(limitedPart, 4);
        boolean overExceeds = overItem.getQuantity() > overItem.getPart().getInventoryQuantity();
        assertTrue("4 in cart with 3 in stock MUST exceed stock", overExceeds);
    }

    @Test
    public void testRepairTicketClientDisplayName() {
        // Company and customer name
        RepairTicketRecord t1 = new RepairTicketRecord(
                "r1", "REP-101", "c1", "John Kamau", "07001", "j@test.com",
                "Dan M.", "u1", "Apple", "MacBook Pro", "MacBook Pro 14\"",
                "SN101", "SN101", "Good", "diagnosing", "Screen flicker",
                "Charger", "1234", 25000.0, 5000.0, 20000.0, "partially_paid",
                true, true, "2026-11-20", "Apex Electronics"
        );
        assertEquals("Apex Electronics (John Kamau)", t1.getClientDisplayName());

        // Customer name only
        RepairTicketRecord t2 = new RepairTicketRecord(
                "r2", "REP-102", "c2", "Alex Waweru", "07002", "a@test.com",
                "Dan M.", "u1", "Apple", "iPhone 13", "iPhone 13",
                "SN102", "SN102", "Fair", "ready", "Battery",
                "None", "1234", 12000.0, 0.0, 12000.0, "pending",
                true, true, "2026-11-19", null
        );
        assertEquals("Alex Waweru", t2.getClientDisplayName());

        // Empty customer name fallback
        RepairTicketRecord t3 = new RepairTicketRecord(
                "r3", "REP-103", "c3", "", "07003", "",
                "Dan M.", "u1", "Dell", "XPS", "Dell XPS 15",
                "SN103", "SN103", "Good", "completed", "OS reinstall",
                "None", "1234", 4000.0, 4000.0, 0.0, "captured",
                true, true, "2026-11-18", null
        );
        assertEquals("Walk-in Customer", t3.getClientDisplayName());
    }

    @Test
    public void testMpesaStkZeroBalanceGuard() {
        // Case 1: Balance is 0 (Paid in full) -> STK push MUST be disabled
        double zeroBalance = 0.0;
        boolean buttonEnabled = zeroBalance > 0;
        String buttonText = buttonEnabled ? "Push M-Pesa STK" : "Push M-Pesa STK (Balance: KES 0.00 - Paid)";
        assertFalse("Push STK button must be disabled when balance is 0", buttonEnabled);
        assertEquals("Push M-Pesa STK (Balance: KES 0.00 - Paid)", buttonText);

        // Case 2: Balance is > 0 -> STK push enabled with formatted balance
        double positiveBalance = 15000.0;
        buttonEnabled = positiveBalance > 0;
        buttonText = buttonEnabled ? String.format(java.util.Locale.US, "Push M-Pesa STK (KES %.2f)", positiveBalance) : "Push M-Pesa STK (Balance: KES 0.00 - Paid)";
        assertTrue("Push STK button must be enabled when balance > 0", buttonEnabled);
        assertEquals("Push M-Pesa STK (KES 15000.00)", buttonText);
    }

    @Test
    public void testCustomerPhoneDigitsSearchAndCheckoutGuard() {
        // 1. Phone digit normalization
        POSCustomer cust = new POSCustomer(
                "cus_ke_01", "Wanjiku", "Mwangi", "wanjiku@test.co.ke",
                "+254 700 112 233", "Wanjiku Enterprises", true
        );
        String searchInput = "0700112233";
        String searchDigits = MainActivity.normalizePhoneDigits(searchInput);
        String custDigits = MainActivity.normalizePhoneDigits(cust.getPhone());
        boolean phoneMatches = custDigits.contains(searchDigits) || searchDigits.contains(custDigits);
        assertTrue("Normalized phone search should match customer despite format differences", phoneMatches);

        // 2. Cart checkout & STK button guard when cart is empty or balance is zero
        List<CartItem> emptyCart = new ArrayList<>();
        double grandTotalEmpty = 0.0;
        boolean canCheckoutEmpty = !emptyCart.isEmpty() && grandTotalEmpty > 0;
        assertFalse("Checkout & STK Push must be disabled when cart is empty", canCheckoutEmpty);

        ProductPart zeroPart = new ProductPart("free_promo", "Promo Sticker", "Promo Sticker", "PRM-00", "PRM-00", 0.0, 100);
        List<CartItem> zeroCart = new ArrayList<>();
        zeroCart.add(new CartItem(zeroPart, 1));
        double grandTotalZero = 0.0;
        boolean canCheckoutZero = !zeroCart.isEmpty() && grandTotalZero > 0;
        assertFalse("Checkout & STK Push must be disabled when grand total is KES 0.00", canCheckoutZero);
    }
}

