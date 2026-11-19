import Foundation
import Combine
import AppKit

@MainActor
public class POSViewModel: ObservableObject {
    @Published public var serverBaseUrl: String = "http://localhost:8000"
    @Published public var isConnected: Bool = true
    @Published public var connectionStatusText: String = "Terminal Connected"
    @Published public var selectedChannel: String = "bench_terminal_01"
    
    // Active Cashier (Auditing requirement)
    @Published public var cashier: Cashier = Cashier(
        id: "usr_01KRV9NELLY",
        name: "Nelly K.",
        email: "nelly@urbandevicecare.co.uk"
    )
    
    @Published public var catalog: [ProductPart] = []
    @Published public var cart: [CartItem] = []
    @Published public var scanInput: String = ""
    @Published public var statusNotice: String = "Ready for barcode scan or SKU lookup."
    @Published public var isProcessing: Bool = false
    
    // Tender state
    @Published public var tenderInputText: String = ""
    @Published public var selectedTenderType: String = "cash"
    @Published public var lastOrderNumber: String? = nil
    @Published public var linkedRepairTicket: RepairTicket? = nil
    @Published public var lastReceiptBytesCount: Int = 0
    
    public init() {
        loadMockCatalog()
        fetchServerSession()
    }
    
    public var subtotal: Double {
        cart.reduce(0) { $0 + $1.lineTotal }
    }
    
    public var tax: Double {
        (subtotal * 0.16 * 100).rounded() / 100
    }
    
    public var grandTotal: Double {
        subtotal + tax
    }
    
    public var changeDue: Double {
        guard let tendered = Double(tenderInputText), tendered >= grandTotal else {
            return 0.0
        }
        return tendered - grandTotal
    }
    
    public func fetchServerSession() {
        guard let url = URL(string: "\(serverBaseUrl)/api/auth/session") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            Task { @MainActor in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let adminObj = json["admin"] as? [String: Any] {
                        let id = adminObj["id"] as? String ?? self.cashier.id
                        let first = adminObj["first_name"] as? String ?? ""
                        let last = adminObj["last_name"] as? String ?? ""
                        let email = adminObj["email"] as? String ?? self.cashier.email
                        self.cashier = Cashier(id: id, name: "\(first) \(last)".trimmingCharacters(in: .whitespaces), email: email)
                        self.isConnected = true
                        self.connectionStatusText = "Online (Medusa v2)"
                        return
                    }
                }
                self.isConnected = false
                self.connectionStatusText = "Offline (Local Catalog)"
            }
        }.resume()
    }
    
    public func searchCatalog(query: String = "") {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBaseUrl)/api/pos/catalog?q=\(encoded)") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                let parsed = items.compactMap { item -> ProductPart? in
                    guard let id = item["id"] as? String,
                          let title = item["title"] as? String else { return nil }
                    let price = (item["price"] as? NSNumber)?.doubleValue ?? 0.0
                    let sku = item["sku"] as? String
                    let barcode = item["barcode"] as? String
                    let pTitle = item["product_title"] as? String
                    return ProductPart(id: id, title: title, productTitle: pTitle, sku: sku, barcode: barcode, price: price)
                }
                Task { @MainActor in
                    if !parsed.isEmpty {
                        self.catalog = parsed
                    }
                }
            }
        }.resume()
    }
    
    public func processScanInput() {
        let code = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        scanInput = ""
        
        isProcessing = true
        statusNotice = "Resolving code: \(code)..."
        
        // 1. Check local catalog first for instant response
        if let match = catalog.first(where: {
            $0.sku?.caseInsensitiveCompare(code) == .orderedSame ||
            $0.barcode?.caseInsensitiveCompare(code) == .orderedSame ||
            $0.title.localizedCaseInsensitiveContains(code)
        }) {
            addToCart(part: match)
            isProcessing = false
            statusNotice = "✔ Added \(match.displayTitle) [SKU: \(match.sku ?? "N/A")]"
            return
        }
        
        // 2. Query server scan endpoint
        guard let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBaseUrl)/api/pos/scan?code=\(encoded)") else {
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            Task { @MainActor in
                self.isProcessing = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String else {
                    self.statusNotice = "✖ No match for \"\(code)\""
                    NSSound.beep()
                    return
                }
                
                if type == "part", let partObj = json["part"] as? [String: Any],
                   let id = partObj["id"] as? String,
                   let title = partObj["title"] as? String {
                    let price = (partObj["price"] as? NSNumber)?.doubleValue ?? 0.0
                    let part = ProductPart(id: id, title: title, productTitle: partObj["product_title"] as? String, sku: partObj["sku"] as? String, barcode: partObj["barcode"] as? String, price: price)
                    self.addToCart(part: part)
                    self.statusNotice = "✔ Added \(part.displayTitle)"
                } else if type == "ticket", let tObj = json["ticket"] as? [String: Any],
                          let id = tObj["id"] as? String,
                          let tNum = tObj["ticket_number"] as? String {
                    self.linkedRepairTicket = RepairTicket(id: id, ticketNumber: tNum, customerName: tObj["customer_name"] as? String, deviceName: tObj["device_name"] as? String)
                    self.statusNotice = "✔ Linked to Ticket #\(tNum)"
                    NSSound.beep()
                } else {
                    self.statusNotice = "✖ Unrecognized barcode: \(code)"
                    NSSound.beep()
                }
            }
        }.resume()
    }
    
    public func addToCart(part: ProductPart) {
        if let idx = cart.firstIndex(where: { $0.part.id == part.id }) {
            cart[idx].quantity += 1
        } else {
            cart.append(CartItem(part: part, quantity: 1))
        }
        statusNotice = "Added \(part.displayTitle) to cart."
        NSSound.beep()
    }
    
    public func updateQuantity(at index: Int, delta: Int) {
        guard index >= 0 && index < cart.count else { return }
        cart[index].quantity += delta
        if cart[index].quantity <= 0 {
            let removedName = cart[index].part.displayTitle
            cart.remove(at: index)
            statusNotice = "Removed \(removedName) from cart."
        }
    }
    
    public func updateQuantity(for partId: String, delta: Int) {
        guard let index = cart.firstIndex(where: { $0.part.id == partId }) else { return }
        cart[index].quantity += delta
        if cart[index].quantity <= 0 {
            let removedName = cart[index].part.displayTitle
            cart.remove(at: index)
            statusNotice = "Removed \(removedName) from cart."
        }
    }
    
    public func clearCart() {
        cart.removeAll()
        tenderInputText = ""
        statusNotice = "Cart cleared."
    }
    
    public func switchCashier() {
        let staffList: [Cashier] = [
            Cashier(id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk"),
            Cashier(id: "usr_02TECH_DAN", name: "Dan M.", email: "dan@urbandevicecare.co.uk"),
            Cashier(id: "usr_03CASH_ALEX", name: "Alex T.", email: "alex@urbandevicecare.co.uk")
        ]
        if let currentIdx = staffList.firstIndex(where: { $0.id == cashier.id }) {
            let nextIdx = (currentIdx + 1) % staffList.count
            cashier = staffList[nextIdx]
            statusNotice = "Switched active cashier to \(cashier.name)."
        } else {
            cashier = staffList[0]
            statusNotice = "Active cashier: \(cashier.name)."
        }
        fetchServerSession()
    }
    
    public func setTenderExact() {
        tenderInputText = String(format: "%.2f", grandTotal)
    }
    
    public func setTenderAmount(_ amount: Double) {
        tenderInputText = String(format: "%.2f", amount)
    }
    
    public func completeSale(completion: ((String) -> Void)? = nil) {
        guard !cart.isEmpty else {
            statusNotice = "Cart is empty. Add items before checking out."
            NSSound.beep()
            return
        }
        
        isProcessing = true
        statusNotice = "Completing sale & tagging cashier \(cashier.name)..."
        
        let orderNum = "POS-\(Int.random(in: 100000...999999))"
        lastOrderNumber = orderNum
        
        let receiptData = ReceiptData(
            orderNumber: orderNum,
            cashierName: cashier.name,
            terminalId: selectedChannel,
            items: cart,
            subtotal: subtotal,
            tax: tax,
            grandTotal: grandTotal,
            tenderType: selectedTenderType,
            tendered: Double(tenderInputText) ?? grandTotal,
            change: changeDue,
            trackingUrl: "https://track.urbandevicecare.co.uk/order/\(orderNum)"
        )
        let escPosBytes = NativeThermalPrinter.generateEscPos58mm(data: receiptData)
        lastReceiptBytesCount = escPosBytes.count
        
        // Post to /api/pos/checkout
        guard let url = URL(string: "\(serverBaseUrl)/api/pos/checkout") else {
            finishLocalSale(orderNum: orderNum)
            completion?(orderNum)
            return
        }
        
        let payload: [String: Any] = [
            "items": cart.map { [
                "variant_id": $0.part.id,
                "title": $0.part.displayTitle,
                "sku": $0.part.sku ?? "",
                "quantity": $0.quantity,
                "unit_price": $0.part.price,
                "total": $0.lineTotal
            ] as [String: Any] },
            "cashier": [
                "id": cashier.id,
                "first_name": cashier.name,
                "email": cashier.email
            ] as [String: Any],
            "tender": [
                "type": selectedTenderType,
                "amount": grandTotal,
                "tendered": Double(tenderInputText) ?? grandTotal,
                "change": changeDue
            ] as [String: Any],
            "terminal_type": "macos_swiftui",
            "repair_ticket_id": linkedRepairTicket?.id as Any
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3.0
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            Task { @MainActor in
                self.finishLocalSale(orderNum: orderNum)
                completion?(orderNum)
            }
        }.resume()
    }
    
    public func finishLocalSale(orderNum: String) {
        isProcessing = false
        cart.removeAll()
        tenderInputText = ""
        statusNotice = "✔ Order \(orderNum) completed! Tagged to \(cashier.name). Receipt: \(lastReceiptBytesCount) bytes"
        NSSound.beep()
    }
    
    public func printLastReceipt() -> Bool {
        guard let orderNum = lastOrderNumber else {
            statusNotice = "No completed order to print receipt for."
            return false
        }
        statusNotice = "Thermal 58mm receipt (\(lastReceiptBytesCount) bytes) sent for #\(orderNum)"
        return true
    }
    
    private func loadMockCatalog() {
        catalog = [
            ProductPart(id: "var_kb_a2681", title: "Keyboard UK Layout", productTitle: "MacBook Air M2 13\" (A2681) Keyboard", sku: "NP04011448", barcode: "NP04011448", price: 6500),
            ProductPart(id: "var_bat_a2442", title: "OEM Battery 70Wh", productTitle: "MacBook Pro 14\" (A2442) Battery", sku: "NP04019921", barcode: "NP04019921", price: 12000),
            ProductPart(id: "var_screen_a2338", title: "Retina Display Space Gray", productTitle: "MacBook Pro M1 (A2338) Screen", sku: "NP04023381", barcode: "0793573199210", price: 28500),
            ProductPart(id: "var_chg_67w", title: "67W USB-C Fast Charger", productTitle: "Apple 67W USB-C Adapter", sku: "ACC-CHG-67W", barcode: "194252432822", price: 4500),
            ProductPart(id: "var_diag", title: "Bench Diagnostic Service", productTitle: "Workshop Diagnostic", sku: "SRV-DIAG-01", barcode: "SRV-DIAG-01", price: 2000)
        ]
    }
}
