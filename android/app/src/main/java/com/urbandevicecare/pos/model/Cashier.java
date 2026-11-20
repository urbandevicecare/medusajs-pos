package com.urbandevicecare.pos.model;

public class Cashier {
    private final String id;
    private final String name;
    private final String email;
    private final String role;

    public Cashier(String id, String name, String email) {
        this(id, name, email, "Admin");
    }

    public Cashier(String id, String name, String email, String role) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.role = role != null ? role : "Admin";
    }

    public String getId() { return id; }
    public String getName() { return name; }
    public String getEmail() { return email; }
    public String getRole() { return role; }
}
