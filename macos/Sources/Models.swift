import Foundation

public struct Cashier: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let email: String
    
    public init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
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
