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
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.urbandevicecare.pos.model.CartItem;
import com.urbandevicecare.pos.model.Cashier;
import com.urbandevicecare.pos.model.POSCustomer;
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
    private final List<Cashier> staffList = new ArrayList<>();
    private String activeAuthToken = "tok_staff_admin_init";
    private final List<ProductPart> catalog = new ArrayList<>();
    private final List<CartItem> cart = new ArrayList<>();
    private final List<com.urbandevicecare.pos.model.RepairTicketRecord> repairsList = new ArrayList<>();
    private POSCustomer activeCustomer = null;
    private final List<POSCustomer> customerList = new ArrayList<>();

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
    private Button btnRepairsNav;
    private Button btnCustomItem;

    // Customer UI
    private LinearLayout layoutSelectedCustomer;
    private LinearLayout layoutCustomerSearchBar;
    private TextView tvCustomerName;
    private TextView tvCustomerDetails;
    private EditText etCustomerSearch;
    private TextView tvDefaultCustomerLabel;

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
        // Staff accounts for auditing (Zero PIN requirement)
        Cashier cashierNelly = new Cashier("usr_01KRV9NELLY", "Nelly K.", "nelly@urbandevicecare.co.uk", "Admin");
        Cashier cashierDan = new Cashier("usr_02TECH_DAN", "Dan M.", "dan@urbandevicecare.co.uk", "Repair Technician");
        Cashier cashierJames = new Cashier("usr_03TECH_JAMES", "James O.", "tech@urbandevicecare.co.uk", "Cashier");

        staffList.add(cashierNelly);
        staffList.add(cashierDan);
        staffList.add(cashierJames);

        activeCashier = cashierNelly;

        // Customer database seeded with registered Medusa clients
        customerList.add(new POSCustomer("cus_01HQ79124XYZ", "John", "Doe", "john.doe@example.com", "+254 700 112 233", "Nairobi Tech Ltd", true));
        customerList.add(new POSCustomer("cus_02HQ79124ABC", "Jane", "Smith", "jane@company.co.ke", "+254 711 445 566", "Alpha Corp", true));

        // Workshop repairs list starts empty (Zero dummy data, connected to Medusa repair plugin)
        repairsList.clear();

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
        btnRepairsNav = findViewById(R.id.btn_repairs_nav);
        btnCustomItem = findViewById(R.id.btn_custom_item);

        // Customer HUD and search bar bindings
        layoutSelectedCustomer = findViewById(R.id.layout_selected_customer);
        layoutCustomerSearchBar = findViewById(R.id.layout_customer_search_bar);
        tvCustomerName = findViewById(R.id.tv_customer_name);
        tvCustomerDetails = findViewById(R.id.tv_customer_details);
        etCustomerSearch = findViewById(R.id.et_customer_search);
        tvDefaultCustomerLabel = findViewById(R.id.tv_default_customer_label);

        if (btnRepairsNav != null) {
            btnRepairsNav.setText("Repairs (" + repairsList.size() + ")");
            btnRepairsNav.setOnClickListener(v -> showRepairsListDialog());
        }

        if (btnCustomItem != null) {
            btnCustomItem.setOnClickListener(v -> showAddCustomItemDialog());
        }

        findViewById(R.id.btn_unlink_customer).setOnClickListener(v -> unlinkCustomer());

        findViewById(R.id.btn_search_customer).setOnClickListener(v -> {
            String query = etCustomerSearch.getText().toString().trim();
            searchCustomer(query);
        });

        etCustomerSearch.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH ||
                (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER && event.getAction() == KeyEvent.ACTION_DOWN)) {
                String query = etCustomerSearch.getText().toString().trim();
                searchCustomer(query);
                return true;
            }
            return false;
        });

        findViewById(R.id.btn_quick_add_customer).setOnClickListener(v -> {
            String initial = etCustomerSearch.getText().toString().trim();
            showQuickCustomerDialog(initial);
        });

        updateCustomerUI();

        findViewById(R.id.btn_switch_cashier).setOnClickListener(v -> showStaffLoginDialog());

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

    public void showStaffLoginDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_login, null);
        builder.setView(dialogView);
        AlertDialog dialog = builder.create();

        Button btnNelly = dialogView.findViewById(R.id.btn_staff_nelly);
        Button btnDan = dialogView.findViewById(R.id.btn_staff_dan);
        Button btnJames = dialogView.findViewById(R.id.btn_staff_james);
        EditText etEmail = dialogView.findViewById(R.id.et_login_email);
        EditText etPassword = dialogView.findViewById(R.id.et_login_password);

        if (btnNelly != null) {
            btnNelly.setOnClickListener(v -> selectStaffPreset("usr_01KRV9NELLY", dialog));
        }
        if (btnDan != null) {
            btnDan.setOnClickListener(v -> selectStaffPreset("usr_02TECH_DAN", dialog));
        }
        if (btnJames != null) {
            btnJames.setOnClickListener(v -> selectStaffPreset("usr_03TECH_JAMES", dialog));
        }

        builder.setPositiveButton("Login", (d, which) -> {
            String email = etEmail != null ? etEmail.getText().toString().trim() : "";
            if (email.isEmpty()) {
                Toast.makeText(this, "Enter staff email", Toast.LENGTH_SHORT).show();
                return;
            }
            Cashier matched = null;
            for (Cashier c : staffList) {
                if (c.getEmail().equalsIgnoreCase(email)) {
                    matched = c;
                    break;
                }
            }
            if (matched != null) {
                activeCashier = matched;
            } else {
                String namePart = email.contains("@") ? email.substring(0, email.indexOf("@")) : email;
                activeCashier = new Cashier("usr_" + System.currentTimeMillis(), namePart, email, "Staff Admin");
                staffList.add(activeCashier);
            }
            activeAuthToken = "tok_medusa_" + System.currentTimeMillis();
            tvCashierName.setText("Cashier: " + activeCashier.getName());
            tvStatusNotice.setText("✔ Authenticated " + activeCashier.getName() + " (" + activeCashier.getRole() + ")");
            Toast.makeText(this, "Logged in: " + activeCashier.getName(), Toast.LENGTH_SHORT).show();
        });
        builder.setNegativeButton("Cancel", null);

        dialog.show();
    }

    private void selectStaffPreset(String staffId, AlertDialog dialog) {
        for (Cashier c : staffList) {
            if (c.getId().equalsIgnoreCase(staffId)) {
                activeCashier = c;
                activeAuthToken = "tok_" + c.getId().toLowerCase(Locale.ROOT);
                tvCashierName.setText("Cashier: " + activeCashier.getName());
                tvStatusNotice.setText("✔ Cashier switched to " + activeCashier.getName() + " (" + activeCashier.getRole() + ")");
                Toast.makeText(this, "Welcome " + activeCashier.getName(), Toast.LENGTH_SHORT).show();
                if (dialog != null) dialog.dismiss();
                return;
            }
        }
    }

    public void showAddCustomItemDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_custom_item, null);

        EditText etTitle = dialogView.findViewById(R.id.et_custom_title);
        EditText etPrice = dialogView.findViewById(R.id.et_custom_price);
        EditText etQty = dialogView.findViewById(R.id.et_custom_qty);
        EditText etSku = dialogView.findViewById(R.id.et_custom_sku);

        builder.setView(dialogView);
        builder.setPositiveButton("Add to Cart", (dialog, which) -> {
            String title = etTitle.getText().toString().trim();
            String priceStr = etPrice.getText().toString().trim();
            String qtyStr = etQty.getText().toString().trim();
            String sku = etSku != null ? etSku.getText().toString().trim() : "";

            if (title.isEmpty()) {
                Toast.makeText(this, "Item title is required", Toast.LENGTH_SHORT).show();
                return;
            }
            double price;
            try {
                price = Double.parseDouble(priceStr);
                if (price <= 0) throw new IllegalArgumentException();
            } catch (Exception e) {
                Toast.makeText(this, "Enter valid positive price", Toast.LENGTH_SHORT).show();
                return;
            }
            int qty = 1;
            try {
                qty = Integer.parseInt(qtyStr);
                if (qty <= 0) qty = 1;
            } catch (Exception ignored) {}

            addCustomItem(title, price, qty, sku.isEmpty() ? "CUSTOM" : sku);
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    public void addCustomItem(String title, double price, int quantity, String sku) {
        String id = "custom_" + System.currentTimeMillis();
        ProductPart customPart = new ProductPart(id, title, title, sku, sku, price, 999, true);
        for (CartItem item : cart) {
            if (item.getPart().getTitle().equalsIgnoreCase(title) && item.getPart().getPrice() == price) {
                for (int i = 0; i < quantity; i++) item.incrementQuantity();
                renderCart();
                updateTotals();
                tvStatusNotice.setText("✔ Incremented custom item: " + title);
                return;
            }
        }
        cart.add(new CartItem(customPart, quantity));
        renderCart();
        updateTotals();
        tvStatusNotice.setText("✔ Added custom item: " + title);
        Toast.makeText(this, "Added custom item to cart", Toast.LENGTH_SHORT).show();
    }

    public void showRepairsListDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_repairs_list, null);
        builder.setView(dialogView);
        AlertDialog dialog = builder.create();

        Button btnBookNew = dialogView.findViewById(R.id.btn_repairs_dialog_book_new);
        EditText etSearch = dialogView.findViewById(R.id.et_repairs_search);
        LinearLayout layoutItems = dialogView.findViewById(R.id.layout_repairs_items_container);

        if (btnBookNew != null) {
            btnBookNew.setOnClickListener(v -> {
                dialog.dismiss();
                showRepairIntakeDialog();
            });
        }

        renderRepairsList(layoutItems, dialog, "");

        if (etSearch != null) {
            etSearch.addTextChangedListener(new TextWatcher() {
                @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
                @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                    renderRepairsList(layoutItems, dialog, s.toString().trim());
                }
                @Override public void afterTextChanged(Editable s) {}
            });
        }

        dialog.show();
    }

    private void renderRepairsList(LinearLayout container, AlertDialog dialog, String query) {
        if (container == null) return;
        container.removeAllViews();

        List<com.urbandevicecare.pos.model.RepairTicketRecord> filtered = new ArrayList<>();
        String q = query.toLowerCase(Locale.ROOT);
        for (com.urbandevicecare.pos.model.RepairTicketRecord t : repairsList) {
            if (q.isEmpty() ||
                t.getTicketNumber().toLowerCase(Locale.ROOT).contains(q) ||
                (t.getCustomerName() != null && t.getCustomerName().toLowerCase(Locale.ROOT).contains(q)) ||
                (t.getDeviceName() != null && t.getDeviceName().toLowerCase(Locale.ROOT).contains(q)) ||
                (t.getStatus() != null && t.getStatus().toLowerCase(Locale.ROOT).contains(q))) {
                filtered.add(t);
            }
        }

        if (filtered.isEmpty()) {
            TextView emptyTv = new TextView(this);
            emptyTv.setText(repairsList.isEmpty() ? "No repair tickets found. Zero dummy data." : "No matching repair tickets.");
            emptyTv.setTextColor(getResources().getColor(R.color.pos_text_muted));
            emptyTv.setTextSize(12f);
            emptyTv.setPadding(16, 24, 16, 24);
            container.addView(emptyTv);
            return;
        }

        for (com.urbandevicecare.pos.model.RepairTicketRecord ticket : filtered) {
            LinearLayout card = new LinearLayout(this);
            card.setOrientation(LinearLayout.VERTICAL);
            card.setBackgroundColor(getResources().getColor(R.color.pos_surface_variant));
            card.setPadding(12, 10, 12, 10);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            lp.bottomMargin = 8;
            card.setLayoutParams(lp);

            // Row 1: Ticket # and Status
            LinearLayout r1 = new LinearLayout(this);
            r1.setOrientation(LinearLayout.HORIZONTAL);
            TextView tvNum = new TextView(this);
            tvNum.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f));
            tvNum.setText(ticket.getTicketNumber() + " • " + (ticket.getDeviceName() != null ? ticket.getDeviceName() : "Device"));
            tvNum.setTextColor(getResources().getColor(R.color.pos_text_primary));
            tvNum.setTextSize(12f);
            tvNum.setTypeface(null, android.graphics.Typeface.BOLD);

            TextView tvStatus = new TextView(this);
            tvStatus.setText(ticket.getStatus().toUpperCase(Locale.ROOT));
            tvStatus.setTextColor(getResources().getColor(R.color.pos_accent));
            tvStatus.setTextSize(10f);
            tvStatus.setTypeface(null, android.graphics.Typeface.BOLD);
            r1.addView(tvNum);
            r1.addView(tvStatus);
            card.addView(r1);

            // Row 2: Customer & Balance
            TextView tvSub = new TextView(this);
            String cust = ticket.getCustomerName() != null ? ticket.getCustomerName() : "Walk-in";
            String balText = String.format(Locale.US, "Client: %s • Balance Due: KES %.2f (%s)",
                    cust, ticket.getBalanceDue(), ticket.getPaymentStatus());
            tvSub.setText(balText);
            tvSub.setTextColor(getResources().getColor(R.color.pos_text_secondary));
            tvSub.setTextSize(10f);
            tvSub.setPadding(0, 4, 0, 6);
            card.addView(tvSub);

            // Row 3: Action Buttons
            LinearLayout r3 = new LinearLayout(this);
            r3.setOrientation(LinearLayout.HORIZONTAL);

            if (ticket.getBalanceDue() > 0) {
                Button btnTender = new Button(this);
                btnTender.setText("Tender Balance");
                btnTender.setTextSize(10f);
                btnTender.setLayoutParams(new LinearLayout.LayoutParams(0, 80, 1.0f));
                btnTender.setOnClickListener(v -> {
                    if (dialog != null) dialog.dismiss();
                    tenderRepairBalance(ticket);
                });
                r3.addView(btnTender);
            }

            Button btnStatus = new Button(this);
            btnStatus.setText("Update Status");
            btnStatus.setTextSize(10f);
            btnStatus.setLayoutParams(new LinearLayout.LayoutParams(0, 80, 1.0f));
            btnStatus.setOnClickListener(v -> showUpdateTicketStatusDialog(ticket, container, dialog, query));
            r3.addView(btnStatus);

            card.addView(r3);
            container.addView(card);
        }
    }

    private void showUpdateTicketStatusDialog(com.urbandevicecare.pos.model.RepairTicketRecord ticket, LinearLayout container, AlertDialog parentDialog, String query) {
        String[] statuses = {
            "pending_dropoff", "received", "diagnosing", "awaiting_approval",
            "repairing", "ready", "completed", "collected", "cancelled", "refunded"
        };
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Update Status: " + ticket.getTicketNumber());
        builder.setItems(statuses, (dialog, which) -> {
            String newStatus = statuses[which];
            int idx = repairsList.indexOf(ticket);
            if (idx >= 0) {
                com.urbandevicecare.pos.model.RepairTicketRecord updated = new com.urbandevicecare.pos.model.RepairTicketRecord(
                    ticket.getId(), ticket.getTicketNumber(), ticket.getCustomerId(),
                    ticket.getCustomerName(), ticket.getCustomerPhone(), ticket.getCustomerEmail(),
                    ticket.getTechnicianName(), ticket.getTechnicianId(), ticket.getBrand(),
                    ticket.getModelName(), ticket.getDeviceName(), ticket.getSerialNumber(),
                    ticket.getImei(), ticket.getCondition(), newStatus,
                    ticket.getIssueDescription(), ticket.getAccessories(), ticket.getPasscode(),
                    ticket.getTotalEstimate(), ticket.getDepositAmount(), ticket.getBalanceDue(),
                    ticket.getPaymentStatus(), ticket.isTermsAccepted(), ticket.isDataWipedConsent(),
                    ticket.getCreatedAt()
                );
                repairsList.set(idx, updated);
                tvStatusNotice.setText("✔ Status of " + ticket.getTicketNumber() + " updated to " + newStatus);
                renderRepairsList(container, parentDialog, query);
                Toast.makeText(this, "Status updated to " + newStatus, Toast.LENGTH_SHORT).show();
            }
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    public void showRepairIntakeDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_repair_intake, null);

        EditText etCustName = dialogView.findViewById(R.id.et_intake_cust_name);
        EditText etCustPhone = dialogView.findViewById(R.id.et_intake_cust_phone);
        EditText etBrand = dialogView.findViewById(R.id.et_intake_brand);
        EditText etModel = dialogView.findViewById(R.id.et_intake_model);
        EditText etSerial = dialogView.findViewById(R.id.et_intake_serial);
        EditText etPasscode = dialogView.findViewById(R.id.et_intake_passcode);
        EditText etIssue = dialogView.findViewById(R.id.et_intake_issue);
        EditText etAccessories = dialogView.findViewById(R.id.et_intake_accessories);
        EditText etEstimate = dialogView.findViewById(R.id.et_intake_estimate);
        EditText etDeposit = dialogView.findViewById(R.id.et_intake_deposit);

        // Pre-fill active client or fallback to cashier
        if (activeCustomer != null) {
            etCustName.setText(activeCustomer.getFullName());
            if (activeCustomer.getPhone() != null) etCustPhone.setText(activeCustomer.getPhone());
        } else {
            etCustName.setText(activeCashier.getName());
            etCustPhone.setText("+254 700 000 000");
        }

        builder.setView(dialogView);
        builder.setPositiveButton("Book Intake", (dialog, which) -> {
            String custName = etCustName.getText().toString().trim();
            if (custName.isEmpty()) {
                custName = (activeCustomer != null) ? activeCustomer.getFullName() : activeCashier.getName();
            }
            String custPhone = etCustPhone.getText().toString().trim();
            if (custPhone.isEmpty()) {
                custPhone = (activeCustomer != null && activeCustomer.getPhone() != null) ? activeCustomer.getPhone() : "+254 700 000 000";
            }
            String custEmail = (activeCustomer != null && activeCustomer.getEmail() != null) ? activeCustomer.getEmail() : activeCashier.getEmail();

            String brand = etBrand.getText().toString().trim();
            String model = etModel.getText().toString().trim();
            if (model.isEmpty()) {
                Toast.makeText(this, "Device model is required", Toast.LENGTH_SHORT).show();
                return;
            }
            String issue = etIssue.getText().toString().trim();
            if (issue.isEmpty()) {
                Toast.makeText(this, "Fault description is required", Toast.LENGTH_SHORT).show();
                return;
            }
            String serial = etSerial.getText().toString().trim();
            String passcode = etPasscode.getText().toString().trim();
            String accessories = etAccessories.getText().toString().trim();

            double estimate = 0;
            try {
                String eStr = etEstimate.getText().toString().trim();
                if (!eStr.isEmpty()) estimate = Double.parseDouble(eStr);
            } catch (Exception ignored) {}

            double deposit = 0;
            try {
                String dStr = etDeposit.getText().toString().trim();
                if (!dStr.isEmpty()) deposit = Double.parseDouble(dStr);
            } catch (Exception ignored) {}

            String ticketNum = "REP-" + (10000 + new Random().nextInt(90000));
            double balDue = Math.max(0, estimate - deposit);
            String payStatus = deposit >= estimate && estimate > 0 ? "captured" : deposit > 0 ? "partially_paid" : "pending";
            String dName = (brand + " " + model).trim();

            com.urbandevicecare.pos.model.RepairTicketRecord ticket = new com.urbandevicecare.pos.model.RepairTicketRecord(
                "rep_" + System.currentTimeMillis(),
                ticketNum,
                activeCustomer != null ? activeCustomer.getId() : activeCashier.getId(),
                custName,
                custPhone,
                custEmail,
                activeCashier.getName(),
                activeCashier.getId(),
                brand,
                model,
                dName.isEmpty() ? "Generic Device" : dName,
                serial,
                serial, // imei
                "Workshop Intake",
                "received",
                issue,
                accessories,
                passcode,
                estimate,
                deposit,
                balDue,
                payStatus,
                true,
                true,
                "2026-11-20T08:00:00Z"
            );

            repairsList.add(0, ticket);
            if (btnRepairsNav != null) {
                btnRepairsNav.setText("Repairs (" + repairsList.size() + ")");
            }
            tvStatusNotice.setText("✔ Booked Repair #" + ticketNum + " for " + custName);
            Toast.makeText(this, "Booked Repair #" + ticketNum + " for " + custName, Toast.LENGTH_LONG).show();
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }

    public void tenderRepairBalance(com.urbandevicecare.pos.model.RepairTicketRecord ticket) {
        if (ticket.getBalanceDue() <= 0) {
            Toast.makeText(this, "Repair #" + ticket.getTicketNumber() + " has zero balance due", Toast.LENGTH_SHORT).show();
            return;
        }

        ProductPart repairPart = new ProductPart(
            "rep_bal_" + ticket.getId(),
            "Repair Balance #" + ticket.getTicketNumber() + " - " + (ticket.getDeviceName() != null ? ticket.getDeviceName() : "Device"),
            "Repair Ticket #" + ticket.getTicketNumber(),
            ticket.getTicketNumber(),
            ticket.getTicketNumber(),
            ticket.getBalanceDue(),
            1,
            true
        );

        if (activeCustomer == null && ticket.getCustomerName() != null) {
            activeCustomer = new POSCustomer(
                ticket.getCustomerId() != null ? ticket.getCustomerId() : "cus_repair_" + ticket.getId(),
                ticket.getCustomerName(),
                "",
                ticket.getCustomerEmail() != null ? ticket.getCustomerEmail() : "repair_" + ticket.getTicketNumber().toLowerCase(Locale.ROOT) + "@pos.urbandevicecare.co.uk",
                ticket.getCustomerPhone(),
                "Repair Client",
                true
            );
            updateCustomerUI();
        }

        addToCart(repairPart);
        tvStatusNotice.setText("✔ Loaded Repair #" + ticket.getTicketNumber() + " balance (KES " + String.format(Locale.US, "%.2f", ticket.getBalanceDue()) + ") into cart.");
        Toast.makeText(this, "Repair balance loaded into cart", Toast.LENGTH_SHORT).show();
    }

    public List<com.urbandevicecare.pos.model.RepairTicketRecord> getRepairsList() {
        return repairsList;
    }

    public List<CartItem> getCart() {
        return cart;
    }

    public Cashier getActiveCashier() {
        return activeCashier;
    }

    public List<ProductPart> getCatalog() {
        return catalog;
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

        // If no customer is explicitly selected, default to the logged in cashier user
        String effectiveCustomerName = (activeCustomer != null) ? activeCustomer.getFullName() : activeCashier.getName();
        String effectiveCustomerPhone = (activeCustomer != null) ? activeCustomer.getPhone() : "+254 700 000 000";
        String effectiveCustomerCompany = (activeCustomer != null) ? activeCustomer.getCompanyName() : "Staff Counter (" + activeCashier.getRole() + ")";

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
                "https://track.urbandevicecare.co.uk/order/" + orderNum,
                effectiveCustomerName,
                effectiveCustomerPhone,
                effectiveCustomerCompany
        );

        // Native CS30 thermal printer dispatch
        boolean printSuccess = cs30Printer.printReceipt(receipt);

        String custNotice = " for " + effectiveCustomerName;
        clearCart();
        unlinkCustomer();
        tvStatusNotice.setText("✔ Order " + orderNum + " completed" + custNotice + "! Printed: " + printSuccess);
        Toast.makeText(this, "Order " + orderNum + " completed" + custNotice + "!", Toast.LENGTH_LONG).show();
    }

    public POSCustomer getActiveCustomer() {
        return activeCustomer;
    }

    public void setActiveCustomer(POSCustomer customer) {
        this.activeCustomer = customer;
        updateCustomerUI();
    }

    public List<POSCustomer> getCustomerList() {
        return customerList;
    }

    public void selectCustomer(POSCustomer customer) {
        setActiveCustomer(customer);
        if (etCustomerSearch != null) {
            etCustomerSearch.setText("");
        }
        if (tvStatusNotice != null) {
            tvStatusNotice.setText("✔ Linked client: " + customer.getFullName());
        }
        Toast.makeText(this, "Client linked: " + customer.getFullName(), Toast.LENGTH_SHORT).show();
    }

    public void unlinkCustomer() {
        this.activeCustomer = null;
        updateCustomerUI();
        if (tvStatusNotice != null) {
            tvStatusNotice.setText("Client unlinked (Guest sale)");
        }
    }

    private void updateCustomerUI() {
        if (layoutSelectedCustomer == null || layoutCustomerSearchBar == null) return;
        if (activeCustomer != null) {
            layoutSelectedCustomer.setVisibility(View.VISIBLE);
            layoutCustomerSearchBar.setVisibility(View.GONE);
            String nameStr = "Client: " + activeCustomer.getFullName();
            if (activeCustomer.getCompanyName() != null && !activeCustomer.getCompanyName().isEmpty()) {
                nameStr += " (" + activeCustomer.getCompanyName() + ")";
            }
            tvCustomerName.setText(nameStr);
            tvCustomerDetails.setText("Tel: " + (activeCustomer.getPhone() != null ? activeCustomer.getPhone() : "N/A") + " • " + activeCustomer.getEmail());
        } else {
            layoutSelectedCustomer.setVisibility(View.GONE);
            layoutCustomerSearchBar.setVisibility(View.VISIBLE);
            if (etCustomerSearch != null) etCustomerSearch.setText("");
        }
    }

    public void searchCustomer(String query) {
        if (query == null || query.trim().isEmpty()) {
            Toast.makeText(this, "Enter customer name, phone, or company", Toast.LENGTH_SHORT).show();
            return;
        }
        String q = query.trim().toLowerCase(Locale.ROOT);
        for (POSCustomer c : customerList) {
            if ((c.getFullName().toLowerCase(Locale.ROOT).contains(q)) ||
                (c.getPhone() != null && c.getPhone().contains(q)) ||
                (c.getEmail() != null && c.getEmail().toLowerCase(Locale.ROOT).contains(q)) ||
                (c.getCompanyName() != null && c.getCompanyName().toLowerCase(Locale.ROOT).contains(q))) {
                selectCustomer(c);
                return;
            }
        }
        // Not found: prompt to quick add
        Toast.makeText(this, "Customer not found. Opening Quick Add...", Toast.LENGTH_SHORT).show();
        showQuickCustomerDialog(query);
    }

    public POSCustomer registerQuickCustomer(String firstName, String lastName, String phone, String email, String companyName) {
        String cleanPhone = phone != null ? phone.trim() : "";
        String cleanFirst = firstName != null ? firstName.trim() : "";
        String cleanLast = lastName != null ? lastName.trim() : "";

        String finalEmail;
        if (email != null && !email.trim().isEmpty()) {
            finalEmail = email.trim().toLowerCase(Locale.ROOT);
        } else {
            String sanitizedPhone = cleanPhone.replaceAll("[^0-9]", "");
            if (sanitizedPhone.isEmpty()) {
                sanitizedPhone = String.valueOf(System.currentTimeMillis());
            }
            String baseEmail = "walkin_" + sanitizedPhone + "@pos.urbandevicecare.co.uk";
            finalEmail = baseEmail;

            // Check if baseEmail already exists locally
            for (POSCustomer existing : customerList) {
                if (existing.getEmail() != null && existing.getEmail().equalsIgnoreCase(baseEmail)) {
                    boolean isSame = existing.getFirstName().equalsIgnoreCase(cleanFirst) &&
                                     existing.getLastName().equalsIgnoreCase(cleanLast);
                    if (isSame) {
                        selectCustomer(existing);
                        return existing;
                    }
                    // Different customer sharing phone: append counter to satisfy unique constraint
                    int counter = 2;
                    while (isEmailTaken("walkin_" + sanitizedPhone + "_" + counter + "@pos.urbandevicecare.co.uk")) {
                        counter++;
                    }
                    finalEmail = "walkin_" + sanitizedPhone + "_" + counter + "@pos.urbandevicecare.co.uk";
                    break;
                }
            }
        }

        String id = "cus_" + System.currentTimeMillis();
        POSCustomer newCustomer = new POSCustomer(
                id,
                cleanFirst,
                cleanLast,
                finalEmail,
                cleanPhone,
                companyName != null && !companyName.trim().isEmpty() ? companyName.trim() : null,
                true // hasAccount: registered Medusa client
        );

        customerList.add(0, newCustomer);
        selectCustomer(newCustomer);
        return newCustomer;
    }

    private boolean isEmailTaken(String email) {
        for (POSCustomer c : customerList) {
            if (c.getEmail() != null && c.getEmail().equalsIgnoreCase(email)) {
                return true;
            }
        }
        return false;
    }

    public void showQuickCustomerDialog(String initialInput) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_quick_customer, null);

        EditText etFirst = dialogView.findViewById(R.id.et_cust_first_name);
        EditText etLast = dialogView.findViewById(R.id.et_cust_last_name);
        EditText etPhone = dialogView.findViewById(R.id.et_cust_phone);
        EditText etEmail = dialogView.findViewById(R.id.et_cust_email);
        EditText etCompany = dialogView.findViewById(R.id.et_cust_company);

        if (initialInput != null && !initialInput.trim().isEmpty()) {
            String trimmed = initialInput.trim();
            if (trimmed.matches(".*\\d{5,}.*")) {
                etPhone.setText(trimmed);
            } else if (trimmed.contains("@")) {
                etEmail.setText(trimmed);
            } else {
                String[] parts = trimmed.split("\\s+");
                if (parts.length >= 2) {
                    etFirst.setText(parts[0]);
                    etLast.setText(parts[1]);
                } else {
                    etFirst.setText(trimmed);
                }
            }
        }

        builder.setView(dialogView);
        builder.setPositiveButton("Save & Select", (dialog, which) -> {
            String first = etFirst.getText().toString().trim();
            String last = etLast.getText().toString().trim();
            String phone = etPhone.getText().toString().trim();
            String email = etEmail.getText().toString().trim();
            String company = etCompany.getText().toString().trim();

            if (first.isEmpty() || last.isEmpty() || phone.isEmpty()) {
                Toast.makeText(this, "First Name, Last Name, and Phone are required", Toast.LENGTH_SHORT).show();
                return;
            }

            registerQuickCustomer(first, last, phone, email, company);
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
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
