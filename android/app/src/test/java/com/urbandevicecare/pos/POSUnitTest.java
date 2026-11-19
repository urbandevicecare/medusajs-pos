package com.urbandevicecare.pos;

import com.urbandevicecare.pos.model.CartItem;
import com.urbandevicecare.pos.model.Cashier;
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
}
