package com.urbandevicecare.pos.model;

public class RepairTicketRecord {
    private final String id;
    private final String ticketNumber;
    private final String customerId;
    private final String customerName;
    private final String customerPhone;
    private final String customerEmail;
    private final String technicianName;
    private final String technicianId;
    private final String brand;
    private final String modelName;
    private final String deviceName;
    private final String serialNumber;
    private final String imei;
    private final String condition;
    private final String status;
    private final String issueDescription;
    private final String accessories;
    private final String passcode;
    private final double totalEstimate;
    private final double depositAmount;
    private final double balanceDue;
    private final String paymentStatus;
    private final boolean termsAccepted;
    private final boolean dataWipedConsent;
    private final String createdAt;
    private final String companyName;

    public RepairTicketRecord(
            String id,
            String ticketNumber,
            String customerId,
            String customerName,
            String customerPhone,
            String customerEmail,
            String deviceName,
            String serialNumber,
            String status,
            String issueDescription,
            String accessories,
            String passcode,
            double totalEstimate,
            double depositAmount,
            double balanceDue,
            String createdAt
    ) {
        this(
                id, ticketNumber, customerId, customerName, customerPhone, customerEmail,
                null, null, null, null, deviceName, serialNumber, null, null,
                status, issueDescription, accessories, passcode,
                totalEstimate, depositAmount, balanceDue,
                depositAmount >= totalEstimate && totalEstimate > 0 ? "captured" : depositAmount > 0 ? "partially_paid" : "pending",
                true, true, createdAt, null
        );
    }

    public RepairTicketRecord(
            String id,
            String ticketNumber,
            String customerId,
            String customerName,
            String customerPhone,
            String customerEmail,
            String technicianName,
            String technicianId,
            String brand,
            String modelName,
            String deviceName,
            String serialNumber,
            String imei,
            String condition,
            String status,
            String issueDescription,
            String accessories,
            String passcode,
            double totalEstimate,
            double depositAmount,
            double balanceDue,
            String paymentStatus,
            boolean termsAccepted,
            boolean dataWipedConsent,
            String createdAt
    ) {
        this(
                id, ticketNumber, customerId, customerName, customerPhone, customerEmail,
                technicianName, technicianId, brand, modelName, deviceName, serialNumber, imei, condition,
                status, issueDescription, accessories, passcode,
                totalEstimate, depositAmount, balanceDue, paymentStatus, termsAccepted, dataWipedConsent, createdAt, null
        );
    }

    public RepairTicketRecord(
            String id,
            String ticketNumber,
            String customerId,
            String customerName,
            String customerPhone,
            String customerEmail,
            String technicianName,
            String technicianId,
            String brand,
            String modelName,
            String deviceName,
            String serialNumber,
            String imei,
            String condition,
            String status,
            String issueDescription,
            String accessories,
            String passcode,
            double totalEstimate,
            double depositAmount,
            double balanceDue,
            String paymentStatus,
            boolean termsAccepted,
            boolean dataWipedConsent,
            String createdAt,
            String companyName
    ) {
        this.id = id;
        this.ticketNumber = ticketNumber;
        this.customerId = customerId;
        this.customerName = customerName;
        this.customerPhone = customerPhone;
        this.customerEmail = customerEmail;
        this.technicianName = technicianName;
        this.technicianId = technicianId;
        this.brand = brand;
        this.modelName = modelName;
        this.deviceName = deviceName;
        this.serialNumber = serialNumber;
        this.imei = imei;
        this.condition = condition;
        this.status = status != null ? status : "received";
        this.issueDescription = issueDescription != null ? issueDescription : "";
        this.accessories = accessories;
        this.passcode = passcode;
        this.totalEstimate = totalEstimate;
        this.depositAmount = depositAmount;
        this.balanceDue = balanceDue;
        this.paymentStatus = paymentStatus != null ? paymentStatus : "pending";
        this.termsAccepted = termsAccepted;
        this.dataWipedConsent = dataWipedConsent;
        this.createdAt = createdAt != null ? createdAt : "";
        this.companyName = companyName;
    }

    public String getId() { return id; }
    public String getTicketNumber() { return ticketNumber; }
    public String getCustomerId() { return customerId; }
    public String getCustomerName() { return customerName; }
    public String getCustomerPhone() { return customerPhone; }
    public String getCustomerEmail() { return customerEmail; }
    public String getTechnicianName() { return technicianName; }
    public String getTechnicianId() { return technicianId; }
    public String getBrand() { return brand; }
    public String getModelName() { return modelName; }
    public String getDeviceName() { return deviceName; }
    public String getSerialNumber() { return serialNumber; }
    public String getImei() { return imei; }
    public String getCondition() { return condition; }
    public String getStatus() { return status; }
    public String getIssueDescription() { return issueDescription; }
    public String getAccessories() { return accessories; }
    public String getPasscode() { return passcode; }
    public double getTotalEstimate() { return totalEstimate; }
    public double getDepositAmount() { return depositAmount; }
    public double getAmountPaid() { return depositAmount; }
    public double getBalanceDue() { return balanceDue; }
    public String getPaymentStatus() { return paymentStatus; }
    public boolean isTermsAccepted() { return termsAccepted; }
    public boolean isDataWipedConsent() { return dataWipedConsent; }
    public String getCreatedAt() { return createdAt; }
    public String getCompanyName() { return companyName; }
    public String getClientDisplayName() {
        String name = (customerName != null && !customerName.trim().isEmpty()) ? customerName.trim() : "Walk-in Customer";
        if (companyName != null && !companyName.trim().isEmpty()) {
            return companyName.trim() + " (" + name + ")";
        }
        return name;
    }
}
