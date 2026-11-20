package com.urbandevicecare.pos.model;

import java.util.ArrayList;
import java.util.List;

/**
 * Registered POS Client model conforming to Medusa v2 customer constraints.
 */
public class POSCustomer {
    private final String id;
    private final String firstName;
    private final String lastName;
    private final String email;
    private final String phone;
    private final String companyName;
    private final boolean hasAccount;
    private final List<String> groups;
    private final Double discountRate;
    private final String pricingTier;

    public POSCustomer(String id, String firstName, String lastName, String email, String phone, String companyName, boolean hasAccount) {
        this(id, firstName, lastName, email, phone, companyName, hasAccount, new ArrayList<>(), null, null);
    }

    public POSCustomer(String id, String firstName, String lastName, String email, String phone, String companyName, boolean hasAccount, List<String> groups, Double discountRate, String pricingTier) {
        this.id = id;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.phone = phone;
        this.companyName = companyName;
        this.hasAccount = hasAccount;
        this.groups = groups != null ? groups : new ArrayList<>();
        this.discountRate = discountRate;
        this.pricingTier = pricingTier;
    }

    public String getId() {
        return id;
    }

    public String getFirstName() {
        return firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public String getFullName() {
        if (lastName != null && !lastName.trim().isEmpty()) {
            return firstName + " " + lastName.trim();
        }
        return firstName;
    }

    public String getEmail() {
        return email;
    }

    public String getPhone() {
        return phone;
    }

    public String getCompanyName() {
        return companyName;
    }

    public boolean hasAccount() {
        return hasAccount;
    }

    public List<String> getGroups() {
        return groups;
    }

    public Double getDiscountRate() {
        return discountRate;
    }

    public String getPricingTier() {
        return pricingTier;
    }
}
