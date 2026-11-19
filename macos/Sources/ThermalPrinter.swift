import Foundation

public struct ReceiptData {
    public let storeName: String
    public let orderNumber: String
    public let cashierName: String
    public let terminalId: String
    public let items: [CartItem]
    public let subtotal: Double
    public let tax: Double
    public let grandTotal: Double
    public let tenderType: String
    public let tendered: Double
    public let change: Double
    public let customerName: String?
    public let customerPhone: String?
    public let customerCompany: String?
    public let trackingUrl: String?
    
    public init(
        storeName: String = "Urban Device Care",
        orderNumber: String,
        cashierName: String,
        terminalId: String = "macos_desktop_01",
        items: [CartItem],
        subtotal: Double,
        tax: Double,
        grandTotal: Double,
        tenderType: String = "cash",
        tendered: Double,
        change: Double,
        customerName: String? = nil,
        customerPhone: String? = nil,
        customerCompany: String? = nil,
        trackingUrl: String? = nil
    ) {
        self.storeName = storeName
        self.orderNumber = orderNumber
        self.cashierName = cashierName
        self.terminalId = terminalId
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.grandTotal = grandTotal
        self.tenderType = tenderType
        self.tendered = tendered
        self.change = change
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerCompany = customerCompany
        self.trackingUrl = trackingUrl
    }
}

public class NativeThermalPrinter {
    public static func generateEscPos58mm(data: ReceiptData) -> Data {
        var bytes = [UInt8]()
        
        // ESC @ - Initialize printer
        bytes.append(contentsOf: [0x1B, 0x40])
        
        // Center alignment
        bytes.append(contentsOf: [0x1B, 0x61, 0x01])
        
        // Bold ON, Double Height
        bytes.append(contentsOf: [0x1B, 0x45, 0x01, 0x1D, 0x21, 0x11])
        appendString(&bytes, "\(data.storeName)\n")
        
        // Normal text
        bytes.append(contentsOf: [0x1D, 0x21, 0x00, 0x1B, 0x45, 0x00])
        appendString(&bytes, "Minimalist Native Desktop POS\n")
        appendString(&bytes, "--------------------------------\n")
        
        // Barcode Code 128 (Order Number)
        let cleanOrder = data.orderNumber.replacingOccurrences(of: " ", with: "")
        bytes.append(contentsOf: [0x1D, 0x77, 0x02]) // width 2
        bytes.append(contentsOf: [0x1D, 0x68, 0x32]) // height 50
        bytes.append(contentsOf: [0x1D, 0x48, 0x02]) // HRI below
        bytes.append(contentsOf: [0x1D, 0x6B, 0x49]) // Code 128
        let orderBytes = Array(cleanOrder.utf8)
        bytes.append(UInt8(orderBytes.count + 2))
        bytes.append(contentsOf: [0x7B, 0x42]) // Code Set B
        bytes.append(contentsOf: orderBytes)
        bytes.append(0x0A)
        
        // Left alignment for item list
        bytes.append(contentsOf: [0x1B, 0x61, 0x00])
        appendString(&bytes, "--------------------------------\n")
        appendString(&bytes, formatTwoColumns(left: "ITEM / QTY", right: "TOTAL", width: 32) + "\n")
        appendString(&bytes, "--------------------------------\n")
        
        for item in data.items {
            let title = String(item.part.displayTitle.prefix(20))
            let right = String(format: "%.2f", item.lineTotal)
            appendString(&bytes, formatTwoColumns(left: "\(item.quantity)x \(title)", right: right, width: 32) + "\n")
            if let sku = item.part.sku {
                appendString(&bytes, "   SKU: \(sku)\n")
            }
        }
        
        appendString(&bytes, "--------------------------------\n")
        appendString(&bytes, formatTwoColumns(left: "SUBTOTAL:", right: String(format: "KES %.2f", data.subtotal), width: 32) + "\n")
        appendString(&bytes, formatTwoColumns(left: "VAT (16%):", right: String(format: "KES %.2f", data.tax), width: 32) + "\n")
        
        // Bold Grand Total
        bytes.append(contentsOf: [0x1B, 0x45, 0x01])
        appendString(&bytes, formatTwoColumns(left: "TOTAL:", right: String(format: "KES %.2f", data.grandTotal), width: 32) + "\n")
        bytes.append(contentsOf: [0x1B, 0x45, 0x00])
        
        appendString(&bytes, "--------------------------------\n")
        appendString(&bytes, formatTwoColumns(left: "Tender:", right: data.tenderType.uppercased(), width: 32) + "\n")
        appendString(&bytes, formatTwoColumns(left: "Tendered:", right: String(format: "KES %.2f", data.tendered), width: 32) + "\n")
        appendString(&bytes, formatTwoColumns(left: "Change Due:", right: String(format: "KES %.2f", data.change), width: 32) + "\n")
        appendString(&bytes, "--------------------------------\n")
        
        // Cashier Audit attribution
        appendString(&bytes, "Cashier: \(data.cashierName)\n")
        appendString(&bytes, "Terminal: \(data.terminalId)\n")
        if let cust = data.customerName, !cust.isEmpty {
            let comp = data.customerCompany != nil ? " (\(data.customerCompany!))" : ""
            appendString(&bytes, "Client: \(cust)\(comp)\n")
            if let phone = data.customerPhone, !phone.isEmpty {
                appendString(&bytes, "Phone: \(phone)\n")
            }
        }
        
        // Center alignment for QR code
        if let url = data.trackingUrl, !url.isEmpty {
            bytes.append(contentsOf: [0x1B, 0x61, 0x01])
            appendString(&bytes, "\nScan to track / pay:\n")
            
            // GS ( k ESC/POS QR code
            let urlBytes = Array(url.utf8)
            let len = urlBytes.count + 3
            let pL = UInt8(len & 0xFF)
            let pH = UInt8((len >> 8) & 0xFF)
            
            // Model 2
            bytes.append(contentsOf: [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00])
            // Module size 4
            bytes.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04])
            // Error correction level M
            bytes.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31])
            // Store data
            bytes.append(contentsOf: [0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30])
            bytes.append(contentsOf: urlBytes)
            // Print QR
            bytes.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30])
        }
        
        // Feed 4 lines & paper cut
        bytes.append(contentsOf: [0x1B, 0x64, 0x04, 0x1D, 0x56, 0x42, 0x00])
        
        return Data(bytes)
    }
    
    private static func appendString(_ bytes: inout [UInt8], _ str: String) {
        bytes.append(contentsOf: Array(str.utf8))
    }
    
    private static func formatTwoColumns(left: String, right: String, width: Int) -> String {
        let maxLeft = width - right.count - 1
        let safeLeft = maxLeft > 0 ? String(left.prefix(maxLeft)) : ""
        let spaces = String(repeating: " ", count: max(1, width - safeLeft.count - right.count))
        return "\(safeLeft)\(spaces)\(right)"
    }
}
