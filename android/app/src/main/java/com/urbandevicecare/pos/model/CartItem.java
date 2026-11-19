package com.urbandevicecare.pos.model;

import java.util.Objects;

public class CartItem {
    private final ProductPart part;
    private int quantity;

    public CartItem(ProductPart part, int quantity) {
        this.part = part;
        this.quantity = quantity;
    }

    public ProductPart getPart() { return part; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
    public void incrementQuantity() { this.quantity++; }
    public void decrementQuantity() { this.quantity--; }
    public double getLineTotal() { return part.getPrice() * quantity; }
    public String getFormattedLineTotal() { return String.format("KES %.2f", getLineTotal()); }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        CartItem cartItem = (CartItem) o;
        return Objects.equals(part.getId(), cartItem.part.getId());
    }

    @Override
    public int hashCode() {
        return Objects.hash(part.getId());
    }
}
