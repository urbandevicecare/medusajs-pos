package com.urbandevicecare.pos.model;

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

    public POSCustomer(String id, String firstName, String lastName, String email, String phone, String companyName, boolean hasAccount) {
        this.id = id;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.phone = phone;
        this.companyName = companyName;
        this.hasAccount = hasAccount;
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
}
