package com.urbandevicecare.pos.model;

import java.util.Objects;

public class ProductPart {
    private final String id;
    private final String title;
    private final String productTitle;
    private final String sku;
    private final String barcode;
    private double price;
    private final int inventoryQuantity;
    private final boolean isCustom;
    private Double originalPrice;
    private String appliedPriceList;

    public ProductPart(String id, String title, String productTitle, String sku, String barcode, double price, int inventoryQuantity) {
        this(id, title, productTitle, sku, barcode, price, inventoryQuantity, false, null, null);
    }

    public ProductPart(String id, String title, String productTitle, String sku, String barcode, double price, int inventoryQuantity, boolean isCustom) {
        this(id, title, productTitle, sku, barcode, price, inventoryQuantity, isCustom, null, null);
    }

    public ProductPart(String id, String title, String productTitle, String sku, String barcode, double price, int inventoryQuantity, boolean isCustom, Double originalPrice, String appliedPriceList) {
        this.id = id;
        this.title = title;
        this.productTitle = productTitle;
        this.sku = sku;
        this.barcode = barcode;
        this.price = price;
        this.inventoryQuantity = inventoryQuantity;
        this.isCustom = isCustom;
        this.originalPrice = originalPrice;
        this.appliedPriceList = appliedPriceList;
    }

    public String getId() { return id; }
    public String getTitle() { return title; }
    public String getProductTitle() { return productTitle; }
    public String getDisplayTitle() { return productTitle != null && !productTitle.isEmpty() ? productTitle : title; }
    public String getSku() { return sku; }
    public String getBarcode() { return barcode; }
    public double getPrice() { return price; }
    public void setPrice(double price) { this.price = price; }
    public Double getOriginalPrice() { return originalPrice; }
    public void setOriginalPrice(Double originalPrice) { this.originalPrice = originalPrice; }
    public String getAppliedPriceList() { return appliedPriceList; }
    public void setAppliedPriceList(String appliedPriceList) { this.appliedPriceList = appliedPriceList; }
    public int getInventoryQuantity() { return inventoryQuantity; }
    public boolean isCustom() { return isCustom; }
    public String getFormattedPrice() { return String.format("KES %.2f", price); }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        ProductPart that = (ProductPart) o;
        return Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}
