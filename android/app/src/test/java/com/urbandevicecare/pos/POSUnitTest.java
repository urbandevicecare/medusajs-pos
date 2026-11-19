package com.urbandevicecare.pos;

import com.urbandevicecare.pos.model.CartItem;
import com.urbandevicecare.pos.model.Cashier;
import com.urbandevicecare.pos.model.POSCustomer;
import com.urbandevicecare.pos.model.ProductPart;
import com.urbandevicecare.pos.model.ReceiptData;
import com.urbandevicecare.pos.printer.CS30ThermalPrinter;

import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
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
}
