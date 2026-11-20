import Foundation

public struct Cashier: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let email: String
    public let role: String
    
    public init(id: String, name: String, email: String, role: String = "Admin") {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
    }
}

public struct StaffSession: Identifiable, Codable, Hashable {
    public let id: String
    public let staffId: String
    public let staffName: String
    public let staffEmail: String
    public let staffRole: String
    public let startedAt: Date
    public let token: String?
    
    public init(id: String = "ses_\(Int(Date().timeIntervalSince1970))", staffId: String, staffName: String, staffEmail: String, staffRole: String, startedAt: Date = Date(), token: String? = nil) {
        self.id = id
        self.staffId = staffId
        self.staffName = staffName
        self.staffEmail = staffEmail
        self.staffRole = staffRole
        self.startedAt = startedAt
        self.token = token
    }
}

public struct ProductPart: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let productTitle: String?
    public let sku: String?
    public let barcode: String?
    public let price: Double
    public let inventoryQuantity: Int
    public let isCustom: Bool
    
    public init(
        id: String,
        title: String,
        productTitle: String? = nil,
        sku: String? = nil,
        barcode: String? = nil,
        price: Double,
        inventoryQuantity: Int = 10,
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.productTitle = productTitle
        self.sku = sku
        self.barcode = barcode
        self.price = price
        self.inventoryQuantity = inventoryQuantity
        self.isCustom = isCustom
    }
    
    public var displayTitle: String {
        return productTitle ?? title
    }
    
    public var formattedPrice: String {
        return String(format: "KES %.2f", price)
    }
}

public struct CartItem: Identifiable, Hashable {
    public var id: String { part.id }
    public let part: ProductPart
    public var quantity: Int
    
    public init(part: ProductPart, quantity: Int = 1) {
        self.part = part
        self.quantity = quantity
    }
    
    public var lineTotal: Double {
        return part.price * Double(quantity)
    }
    
    public var formattedLineTotal: String {
        return String(format: "KES %.2f", lineTotal)
    }
}

public struct RepairNote: Identifiable, Codable, Hashable {
    public let id: String
    public let content: String
    public let isInternal: Bool
    public let createdAt: String
    
    public init(id: String = "note_\(Int(Date().timeIntervalSince1970))", content: String, isInternal: Bool = false, createdAt: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.content = content
        self.isInternal = isInternal
        self.createdAt = createdAt
    }
}

public struct RepairUpdate: Identifiable, Codable, Hashable {
    public let id: String
    public let status: String
    public let note: String?
    public let createdAt: String
    
    public init(id: String = "upd_\(Int(Date().timeIntervalSince1970))", status: String, note: String? = nil, createdAt: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.status = status
        self.note = note
        self.createdAt = createdAt
    }
}

public struct RepairTicketRecord: Identifiable, Codable, Hashable {
    public let id: String
    public let ticketNumber: String
    public let customerId: String?
    public let customerName: String?
    public let customerPhone: String?
    public let customerEmail: String?
    public let technicianName: String?
    public let technicianId: String?
    public let brand: String?
    public let modelName: String?
    public let deviceName: String?
    public let serialNumber: String?
    public let imei: String?
    public let condition: String?
    public var status: String
    public let issueDescription: String
    public let accessories: String?
    public let passcode: String?
    public let partsEstimate: Double
    public let laborEstimate: Double
    public let totalEstimate: Double
    public let partsActual: Double
    public let laborActual: Double
    public let totalActual: Double
    public let amountPaid: Double
    public let depositAmount: Double
    public let balanceDue: Double
    public let paymentStatus: String
    public let warrantyMonths: Int
    public let termsAccepted: Bool
    public let dataWipedConsent: Bool
    public var notes: [RepairNote]
    public var updates: [RepairUpdate]
    public let createdAt: String
    
    public init(
        id: String,
        ticketNumber: String,
        customerId: String? = nil,
        customerName: String? = nil,
        customerPhone: String? = nil,
        customerEmail: String? = nil,
        technicianName: String? = nil,
        technicianId: String? = nil,
        brand: String? = nil,
        modelName: String? = nil,
        deviceName: String? = nil,
        serialNumber: String? = nil,
        imei: String? = nil,
        condition: String? = nil,
        status: String = "received",
        issueDescription: String,
        accessories: String? = nil,
        passcode: String? = nil,
        partsEstimate: Double = 0.0,
        laborEstimate: Double = 0.0,
        totalEstimate: Double = 0.0,
        partsActual: Double = 0.0,
        laborActual: Double = 0.0,
        totalActual: Double = 0.0,
        amountPaid: Double = 0.0,
        depositAmount: Double = 0.0,
        balanceDue: Double = 0.0,
        paymentStatus: String = "pending",
        warrantyMonths: Int = 3,
        termsAccepted: Bool = true,
        dataWipedConsent: Bool = true,
        notes: [RepairNote] = [],
        updates: [RepairUpdate] = [],
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.ticketNumber = ticketNumber
        self.customerId = customerId
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerEmail = customerEmail
        self.technicianName = technicianName
        self.technicianId = technicianId
        self.brand = brand
        self.modelName = modelName
        self.deviceName = deviceName
        self.serialNumber = serialNumber
        self.imei = imei
        self.condition = condition
        self.status = status
        self.issueDescription = issueDescription
        self.accessories = accessories
        self.passcode = passcode
        self.partsEstimate = partsEstimate
        self.laborEstimate = laborEstimate
        self.totalEstimate = totalEstimate
        self.partsActual = partsActual
        self.laborActual = laborActual
        self.totalActual = totalActual
        self.amountPaid = amountPaid
        self.depositAmount = depositAmount > 0 ? depositAmount : amountPaid
        self.balanceDue = balanceDue
        self.paymentStatus = paymentStatus
        self.warrantyMonths = warrantyMonths
        self.termsAccepted = termsAccepted
        self.dataWipedConsent = dataWipedConsent
        self.notes = notes
        self.updates = updates
        self.createdAt = createdAt
    }
}

public struct RepairTicket: Identifiable, Codable, Hashable {
    public let id: String
    public let ticketNumber: String
    public let customerName: String?
    public let deviceName: String?
    public let serialNumber: String?
    public let status: String
    public let laborEstimate: Double?
    
    public init(id: String, ticketNumber: String, customerName: String? = nil, deviceName: String? = nil, serialNumber: String? = nil, status: String = "in_progress", laborEstimate: Double? = 0.0) {
        self.id = id
        self.ticketNumber = ticketNumber
        self.customerName = customerName
        self.deviceName = deviceName
        self.serialNumber = serialNumber
        self.status = status
        self.laborEstimate = laborEstimate
    }
}

public struct POSCustomer: Identifiable, Codable, Hashable {
    public let id: String
    public let firstName: String
    public let lastName: String?
    public let email: String
    public let phone: String?
    public let companyName: String?
    public let hasAccount: Bool
    
    public init(
        id: String,
        firstName: String,
        lastName: String? = nil,
        email: String,
        phone: String? = nil,
        companyName: String? = nil,
        hasAccount: Bool = true
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.companyName = companyName
        self.hasAccount = hasAccount
    }
    
    public var fullName: String {
        if let last = lastName, !last.isEmpty {
            return "\(firstName) \(last)"
        }
        return firstName
    }
}
