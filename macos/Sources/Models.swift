import Foundation

public struct Cashier: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let email: String
    public let role: String
    public let pin: String?
    
    public init(id: String, name: String, email: String, role: String = "Cashier", pin: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.pin = pin
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
    
    public init(id: String, title: String, productTitle: String? = nil, sku: String? = nil, barcode: String? = nil, price: Double, inventoryQuantity: Int = 10) {
        self.id = id
        self.title = title
        self.productTitle = productTitle
        self.sku = sku
        self.barcode = barcode
        self.price = price
        self.inventoryQuantity = inventoryQuantity
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
