package com.urbandevicecare.pos.model;

import java.util.List;

public class ReceiptData {
    private final String storeName;
    private final String orderNumber;
    private final String cashierName;
    private final String terminalId;
    private final List<CartItem> items;
    private final double subtotal;
    private final double tax;
    private final double grandTotal;
    private final String tenderType;
    private final double tendered;
    private final double change;
    private final String trackingUrl;
    private final String customerName;
    private final String customerPhone;
    private final String customerCompany;

    public ReceiptData(String storeName, String orderNumber, String cashierName, String terminalId,
                       List<CartItem> items, double subtotal, double tax, double grandTotal,
                       String tenderType, double tendered, double change, String trackingUrl) {
        this(storeName, orderNumber, cashierName, terminalId, items, subtotal, tax, grandTotal,
             tenderType, tendered, change, trackingUrl, null, null, null);
    }

    public ReceiptData(String storeName, String orderNumber, String cashierName, String terminalId,
                       List<CartItem> items, double subtotal, double tax, double grandTotal,
                       String tenderType, double tendered, double change, String trackingUrl,
                       String customerName, String customerPhone, String customerCompany) {
        this.storeName = storeName;
        this.orderNumber = orderNumber;
        this.cashierName = cashierName;
        this.terminalId = terminalId;
        this.items = items;
        this.subtotal = subtotal;
        this.tax = tax;
        this.grandTotal = grandTotal;
        this.tenderType = tenderType;
        this.tendered = tendered;
        this.change = change;
        this.trackingUrl = trackingUrl;
        this.customerName = customerName;
        this.customerPhone = customerPhone;
        this.customerCompany = customerCompany;
    }

    public String getStoreName() { return storeName; }
    public String getOrderNumber() { return orderNumber; }
    public String getCashierName() { return cashierName; }
    public String getTerminalId() { return terminalId; }
    public List<CartItem> getItems() { return items; }
    public double getSubtotal() { return subtotal; }
    public double getTax() { return tax; }
    public double getGrandTotal() { return grandTotal; }
    public String getTenderType() { return tenderType; }
    public double getTendered() { return tendered; }
    public double getChange() { return change; }
    public String getTrackingUrl() { return trackingUrl; }
    public String getCustomerName() { return customerName; }
    public String getCustomerPhone() { return customerPhone; }
    public String getCustomerCompany() { return customerCompany; }
}
