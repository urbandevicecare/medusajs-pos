package com.urbandevicecare.pos;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.urbandevicecare.pos.model.CartItem;
import com.urbandevicecare.pos.model.Cashier;
import com.urbandevicecare.pos.model.ProductPart;
import com.urbandevicecare.pos.model.ReceiptData;
import com.urbandevicecare.pos.printer.CS30ThermalPrinter;
import com.urbandevicecare.pos.scanner.CameraScannerActivity;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;

/**
 * 100% Native Android POS Activity for CS30 Smart POS and generic Android terminals.
 * Zero WebView or browser wrapper dependencies.
 */
public class MainActivity extends AppCompatActivity {
    private static MainActivity sInstance;

    public static MainActivity getInstance() {
        return sInstance;
    }

    private Cashier activeCashier;
    private final List<ProductPart> catalog = new ArrayList<>();
    private final List<CartItem> cart = new ArrayList<>();
    private final Map<String, Cashier> pinStore = new HashMap<>();

    private CS30ThermalPrinter cs30Printer;

    // UI elements
    private TextView tvCashierName;
    private TextView tvTerminalChannel;
    private EditText etScanInput;
    private LinearLayout layoutCatalog;
    private LinearLayout layoutCart;
    private TextView tvSubtotal;
    private TextView tvTax;
    private TextView tvGrandTotal;
    private EditText etTenderInput;
    private TextView tvChangeDue;
    private TextView tvStatusNotice;

    // Laser gun wedge interceptor
    private final StringBuilder wedgeBuffer = new StringBuilder();
    private long lastKeyTimestamp = 0;
    private static final long WEDGE_MAX_INTER_KEY_DELAY_MS = 45;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        sInstance = this;
        setContentView(R.layout.activity_main);

        cs30Printer = new CS30ThermalPrinter(this);

        initData();
        initViews();
        renderCatalog();
        updateTotals();
    }

    private void initData() {
        // Staff accounts for auditing
        Cashier cashierNelly = new Cashier("usr_01KRV9NELLY", "Nelly K.", "nelly@urbandevicecare.co.uk");
        Cashier cashierDan = new Cashier("usr_02TECH_DAN", "Dan M.", "dan@urbandevicecare.co.uk");
        Cashier cashierJames = new Cashier("usr_03TECH_JAMES", "James O.", "tech@urbandevicecare.co.uk");

        pinStore.put("1234", cashierNelly);
        pinStore.put("5555", cashierDan);
        pinStore.put("9876", cashierJames);

        activeCashier = cashierNelly;

        // Workshop parts catalog
        catalog.add(new ProductPart("var_kb_a2681", "Keyboard UK Layout", "MacBook Air M2 13\" (A2681) Keyboard", "NP04011448", "NP04011448", 6500.0, 15));
        catalog.add(new ProductPart("var_bat_a2442", "OEM Battery 70Wh", "MacBook Pro 14\" (A2442) Battery", "NP04019921", "NP04019921", 12000.0, 8));
        catalog.add(new ProductPart("var_screen_a2338", "Retina Display Space Gray", "MacBook Pro M1 (A2338) Screen", "NP04023381", "0793573199210", 28500.0, 5));
        catalog.add(new ProductPart("var_chg_67w", "67W USB-C Fast Charger", "Apple 67W USB-C Adapter", "ACC-CHG-67W", "194252432822", 4500.0, 25));
        catalog.add(new ProductPart("var_diag", "Bench Diagnostic Service", "Workshop Diagnostic", "SRV-DIAG-01", "SRV-DIAG-01", 2000.0, 999));
    }

    private void initViews() {
        tvCashierName = findViewById(R.id.tv_cashier_name);
        tvTerminalChannel = findViewById(R.id.tv_terminal_channel);
        etScanInput = findViewById(R.id.et_scan_input);
        layoutCatalog = findViewById(R.id.layout_catalog_items);
        layoutCart = findViewById(R.id.layout_cart_items);
        tvSubtotal = findViewById(R.id.tv_subtotal);
        tvTax = findViewById(R.id.tv_tax);
        tvGrandTotal = findViewById(R.id.tv_grand_total);
        etTenderInput = findViewById(R.id.et_tender_input);
        tvChangeDue = findViewById(R.id.tv_change_due);
        tvStatusNotice = findViewById(R.id.tv_status_notice);

        findViewById(R.id.btn_switch_cashier).setOnClickListener(v -> showPinSwitchDialog());

        findViewById(R.id.btn_scan_camera).setOnClickListener(v -> {
            Intent intent = new Intent(this, CameraScannerActivity.class);
            startActivityForResult(intent, 201);
        });

        findViewById(R.id.btn_add_code).setOnClickListener(v -> {
            String code = etScanInput.getText().toString().trim();
            if (!code.isEmpty()) {
                onBarcodeScanned(code);
                etScanInput.setText("");
            }
        });

        findViewById(R.id.btn_tender_exact).setOnClickListener(v -> setTenderAmount(getGrandTotal()));
        findViewById(R.id.btn_tender_500).setOnClickListener(v -> setTenderAmount(500.0));
        findViewById(R.id.btn_tender_1000).setOnClickListener(v -> setTenderAmount(1000.0));
        findViewById(R.id.btn_tender_2000).setOnClickListener(v -> setTenderAmount(2000.0));
        findViewById(R.id.btn_tender_5000).setOnClickListener(v -> setTenderAmount(5000.0));

        etTenderInput.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) { updateChangeDue(); }
            @Override public void afterTextChanged(Editable s) {}
        });

        findViewById(R.id.btn_clear_cart).setOnClickListener(v -> clearCart());
        findViewById(R.id.btn_paystack).setOnClickListener(v -> initiatePaystackQR());
        findViewById(R.id.btn_charge_print).setOnClickListener(v -> completeSaleAndPrint());
    }

    private void renderCatalog() {
        layoutCatalog.removeAllViews();
        for (ProductPart part : catalog) {
            View itemView = LayoutInflater.from(this).inflate(android.R.layout.simple_list_item_2, layoutCatalog, false);
            TextView title = itemView.findViewById(android.R.id.text1);
            TextView sub = itemView.findViewById(android.R.id.text2);

            title.setText(part.getDisplayTitle());
            title.setTextColor(getResources().getColor(R.color.pos_text_primary));
            title.setTextSize(12f);

            sub.setText(String.format(Locale.US, "SKU: %s • %s", part.getSku() != null ? part.getSku() : "N/A", part.getFormattedPrice()));
            sub.setTextColor(getResources().getColor(R.color.pos_text_secondary));
            sub.setTextSize(10f);

            itemView.setPadding(8, 8, 8, 8);
            itemView.setBackgroundColor(getResources().getColor(R.color.pos_surface_variant));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            lp.bottomMargin = 6;
            itemView.setLayoutParams(lp);

            itemView.setOnClickListener(v -> addToCart(part));
            layoutCatalog.addView(itemView);
        }
    }

    private void renderCart() {
        layoutCart.removeAllViews();
        for (CartItem item : cart) {
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(8, 6, 8, 6);
            row.setBackgroundColor(getResources().getColor(R.color.pos_surface_variant));

            TextView desc = new TextView(this);
            desc.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f));
            desc.setText(String.format(Locale.US, "%dx %s\n%s", item.getQuantity(), item.getPart().getDisplayTitle(), item.getFormattedLineTotal()));
            desc.setTextColor(getResources().getColor(R.color.pos_text_primary));
            desc.setTextSize(11f);

            Button btnMinus = new Button(this);
            btnMinus.setText("-");
            btnMinus.setTextSize(11f);
            btnMinus.setLayoutParams(new LinearLayout.LayoutParams(90, 80));
            btnMinus.setOnClickListener(v -> updateQuantity(item.getPart().getId(), -1));

            Button btnPlus = new Button(this);
            btnPlus.setText("+");
            btnPlus.setTextSize(11f);
            btnPlus.setLayoutParams(new LinearLayout.LayoutParams(90, 80));
            btnPlus.setOnClickListener(v -> updateQuantity(item.getPart().getId(), 1));

            row.addView(desc);
            row.addView(btnMinus);
            row.addView(btnPlus);

            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            lp.bottomMargin = 6;
            row.setLayoutParams(lp);

            layoutCart.addView(row);
        }
    }

    public void onBarcodeScanned(String rawBarcode) {
        if (rawBarcode == null || rawBarcode.trim().isEmpty()) return;
        final String code = rawBarcode.trim();

        // 1. Check local catalog
        for (ProductPart part : catalog) {
            if ((part.getSku() != null && part.getSku().equalsIgnoreCase(code)) ||
                (part.getBarcode() != null && part.getBarcode().equalsIgnoreCase(code))) {
                addToCart(part);
                tvStatusNotice.setText("✔ Added " + part.getDisplayTitle());
                return;
            }
        }

        // 2. Repair ticket check
        if (code.toUpperCase().startsWith("REP-")) {
            tvStatusNotice.setText("✔ Linked Repair Ticket #" + code);
            Toast.makeText(this, "Linked Repair Ticket: " + code, Toast.LENGTH_SHORT).show();
            return;
        }

        tvStatusNotice.setText("✖ Unrecognized barcode: " + code);
        Toast.makeText(this, "Barcode not found: " + code, Toast.LENGTH_SHORT).show();
    }

    public void addToCart(ProductPart part) {
        for (CartItem item : cart) {
            if (item.getPart().getId().equals(part.getId())) {
                item.incrementQuantity();
                renderCart();
                updateTotals();
                tvStatusNotice.setText("Incremented " + part.getDisplayTitle());
                return;
            }
        }
        cart.add(new CartItem(part, 1));
        renderCart();
        updateTotals();
        tvStatusNotice.setText("Added " + part.getDisplayTitle() + " to cart.");
    }

    public void updateQuantity(String partId, int delta) {
        CartItem toRemove = null;
        for (CartItem item : cart) {
            if (item.getPart().getId().equals(partId)) {
                if (delta > 0) {
                    item.incrementQuantity();
                } else {
                    item.decrementQuantity();
                    if (item.getQuantity() <= 0) {
                        toRemove = item;
                    }
                }
                break;
            }
        }
        if (toRemove != null) {
            cart.remove(toRemove);
        }
        renderCart();
        updateTotals();
    }

    public void clearCart() {
        cart.clear();
        etTenderInput.setText("");
        renderCart();
        updateTotals();
        tvStatusNotice.setText("Cart cleared.");
    }

    public double getSubtotal() {
        double sub = 0;
        for (CartItem item : cart) sub += item.getLineTotal();
        return sub;
    }

    public double getTax() {
        return Math.round(getSubtotal() * 0.16 * 100.0) / 100.0;
    }

    public double getGrandTotal() {
        return getSubtotal() + getTax();
    }

    public double getChangeDue() {
        try {
            double tendered = Double.parseDouble(etTenderInput.getText().toString());
            if (tendered >= getGrandTotal()) {
                return tendered - getGrandTotal();
            }
        } catch (Exception ignored) {}
        return 0.0;
    }

    private void updateTotals() {
        tvSubtotal.setText(String.format(Locale.US, "KES %.2f", getSubtotal()));
        tvTax.setText(String.format(Locale.US, "KES %.2f", getTax()));
        tvGrandTotal.setText(String.format(Locale.US, "KES %.2f", getGrandTotal()));
        updateChangeDue();
    }

    private void updateChangeDue() {
        tvChangeDue.setText(String.format(Locale.US, "Change: KES %.2f", getChangeDue()));
    }

    private void setTenderAmount(double amount) {
        etTenderInput.setText(String.format(Locale.US, "%.2f", amount));
        updateChangeDue();
    }

    private void showPinSwitchDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_pin, null);
        EditText etPin = dialogView.findViewById(R.id.et_pin_code);

        builder.setView(dialogView);
        builder.setPositiveButton("Verify", (dialog, which) -> {
            String pin = etPin.getText().toString().trim();
            Cashier nextCashier = pinStore.get(pin);
            if (nextCashier != null) {
                activeCashier = nextCashier;
                tvCashierName.setText("Cashier: " + activeCashier.getName());
                tvStatusNotice.setText("✔ Cashier switched to " + activeCashier.getName());
                Toast.makeText(this, "Welcome " + activeCashier.getName(), Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Invalid PIN", Toast.LENGTH_SHORT).show();
            }
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    private void completeSaleAndPrint() {
        if (cart.isEmpty()) {
            Toast.makeText(this, "Cart is empty", Toast.LENGTH_SHORT).show();
            return;
        }

        String orderNum = "POS-" + (100000 + new Random().nextInt(900000));
        double tendered = 0;
        try {
            tendered = Double.parseDouble(etTenderInput.getText().toString());
        } catch (Exception e) {
            tendered = getGrandTotal();
        }

        ReceiptData receipt = new ReceiptData(
                "Urban Device Care",
                orderNum,
                activeCashier.getName(),
                "cs30_terminal_01",
                new ArrayList<>(cart),
                getSubtotal(),
                getTax(),
                getGrandTotal(),
                "cash",
                tendered,
                getChangeDue(),
                "https://track.urbandevicecare.co.uk/order/" + orderNum
        );

        // Native CS30 thermal printer dispatch
        boolean printSuccess = cs30Printer.printReceipt(receipt);

        clearCart();
        tvStatusNotice.setText("✔ Order " + orderNum + " completed! Printed: " + printSuccess);
        Toast.makeText(this, "Order " + orderNum + " completed!", Toast.LENGTH_LONG).show();
    }

    private void initiatePaystackQR() {
        if (cart.isEmpty()) {
            Toast.makeText(this, "Cart is empty", Toast.LENGTH_SHORT).show();
            return;
        }
        String ref = "PST-" + System.currentTimeMillis();
        String paystackUrl = "https://checkout.paystack.com/" + ref;
        tvStatusNotice.setText("Paystack QR generated: " + ref);
        Toast.makeText(this, "Paystack QR ready for " + String.format(Locale.US, "KES %.2f", getGrandTotal()), Toast.LENGTH_LONG).show();
    }

    /**
     * Hardware Laser Barcode Gun Wedge Interceptor
     */
    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            long now = System.currentTimeMillis();
            if (now - lastKeyTimestamp > WEDGE_MAX_INTER_KEY_DELAY_MS) {
                wedgeBuffer.setLength(0);
            }
            lastKeyTimestamp = now;

            char unicodeChar = (char) event.getUnicodeChar();
            if (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) {
                if (wedgeBuffer.length() > 2) {
                    final String scanned = wedgeBuffer.toString();
                    wedgeBuffer.setLength(0);
                    runOnUiThread(() -> onBarcodeScanned(scanned));
                    return true;
                }
            } else if (unicodeChar > 31 && unicodeChar < 127) {
                wedgeBuffer.append(unicodeChar);
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == 201 && resultCode == Activity.RESULT_OK && data != null) {
            String scannedCode = data.getStringExtra(CameraScannerActivity.EXTRA_SCANNED_CODE);
            if (scannedCode != null) {
                onBarcodeScanned(scannedCode);
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (sInstance == this) {
            sInstance = null;
        }
    }
}
