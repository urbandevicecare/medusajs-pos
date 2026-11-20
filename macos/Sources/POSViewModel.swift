import Foundation
import Combine
import AppKit

@MainActor
public class POSViewModel: ObservableObject {
    private let kServerUrlKey = "udc_pos_server_url"
    private let kPublishableKey = "udc_pos_publishable_key"
    private let kHasConfiguredKey = "udc_pos_has_configured_server"
    
    @Published public var serverBaseUrl: String
    @Published public var publishableApiKey: String
    @Published public var isConnected: Bool = false
    @Published public var connectionStatusText: String = "Connecting..."
    @Published public var selectedChannel: String = "bench_terminal_01"
    
    // First startup & Settings sheet controls
    @Published public var isFirstLaunchSetupOpen: Bool = false
    @Published public var showSettingsSheet: Bool = false
    @Published public var isTestingConnection: Bool = false
    @Published public var testConnectionResult: String? = nil
    
    // Active Cashier (Auditing requirement)
    @Published public var cashier: Cashier = Cashier(
        id: "usr_01KRV9NELLY",
        name: "Nelly K.",
        email: "nelly@urbandevicecare.co.uk",
        role: "Admin"
    )
    
    // Staff authentication & session state (zero PIN - Medusa admin credentials)
    @Published public var isLoggedIn: Bool = false
    @Published public var currentSession: StaffSession? = nil
    @Published public var availableStaff: [Cashier] = [
        Cashier(id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk", role: "Admin"),
        Cashier(id: "usr_02TECH_DAN", name: "Dan M.", email: "dan@urbandevicecare.co.uk", role: "Repair Technician"),
        Cashier(id: "usr_03CASH_ALEX", name: "Alex T.", email: "alex@urbandevicecare.co.uk", role: "Cashier")
    ]
    
    // UI Navigation Tab ("pos" vs "repairs")
    @Published public var activeTab: String = "pos"
    
    // Workshop & Repairs state
    @Published public var repairs: [RepairTicketRecord] = []
    @Published public var repairFilterStatus: String = "all"
    @Published public var repairSearchText: String = ""
    @Published public var selectedRepair: RepairTicketRecord? = nil
    @Published public var showIntakeSheet: Bool = false
    @Published public var showCustomItemSheet: Bool = false
    
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
    
    // Customer state & Quick Customer pipeline
    @Published public var selectedCustomer: POSCustomer? = nil
    @Published public var customerSearchText: String = ""
    @Published public var searchCustomerResults: [POSCustomer] = []
    @Published public var isCustomerSearchOpen: Bool = false
    @Published public var showQuickCustomerSheet: Bool = false
    @Published public var localCustomers: [POSCustomer] = []
    
    public init() {
        // Read securely from Apple Keychain (hardware AES-256 encrypted) with legacy fallback
        let savedUrl = KeychainSecurity.load(key: kServerUrlKey) ?? UserDefaults.standard.string(forKey: kServerUrlKey)
        let url = (savedUrl != nil && !savedUrl!.isEmpty) ? savedUrl! : "https://admin.urbandevicecare.co.uk"
        self.serverBaseUrl = url
        
        let savedKey = KeychainSecurity.load(key: kPublishableKey) ?? UserDefaults.standard.string(forKey: kPublishableKey)
        self.publishableApiKey = (savedKey != nil && !savedKey!.isEmpty) ? savedKey! : "pk_c7904d9e7fcc12a1a42277a4e0e33e3479c9653efeed505bdc70dc442d21b067"
        
        let hasConfigured = UserDefaults.standard.bool(forKey: kHasConfiguredKey)
        
        loadMockCatalog()
        loadMockCustomers()
        
        if !hasConfigured {
            self.isFirstLaunchSetupOpen = true
            self.statusNotice = "First startup: please confirm Medusa server URL."
        } else {
            checkServerHealthAndSync()
        }
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
    
    public func saveServerConfig(newUrl: String, newKey: String? = nil) {
        var cleanUrl = newUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }
        if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
            cleanUrl = "https://" + cleanUrl
        }
        self.serverBaseUrl = cleanUrl
        _ = KeychainSecurity.save(key: kServerUrlKey, value: cleanUrl)
        UserDefaults.standard.set(cleanUrl, forKey: kServerUrlKey)
        
        if let key = newKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            self.publishableApiKey = key
            _ = KeychainSecurity.save(key: kPublishableKey, value: key)
            UserDefaults.standard.set(key, forKey: kPublishableKey)
        }
        
        UserDefaults.standard.set(true, forKey: kHasConfiguredKey)
        self.isFirstLaunchSetupOpen = false
        self.showSettingsSheet = false
        
        checkServerHealthAndSync()
    }
    
    public func testConnection(urlToTest: String, completion: @escaping (Bool, String) -> Void) {
        var cleanUrl = urlToTest.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") { cleanUrl = String(cleanUrl.dropLast()) }
        if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
            cleanUrl = "https://" + cleanUrl
        }
        
        guard let url = URL(string: "\(cleanUrl)/health") else {
            completion(false, "Invalid URL format")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            Task { @MainActor in
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    completion(true, "✔ Connected! (\(latencyMs)ms latency)")
                } else if let error = error {
                    completion(false, "✖ Connection failed: \(error.localizedDescription)")
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    completion(false, "✖ Server returned HTTP \(code)")
                }
            }
        }.resume()
    }
    
    public func checkServerHealthAndSync() {
        statusNotice = "Connecting to \(serverBaseUrl)..."
        guard let url = URL(string: "\(serverBaseUrl)/health") else {
            self.isConnected = false
            self.connectionStatusText = "Offline (Invalid URL)"
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            Task { @MainActor in
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    self.isConnected = true
                    self.connectionStatusText = "Online (Medusa v2)"
                    self.fetchLiveCatalog()
                } else {
                    self.isConnected = false
                    self.connectionStatusText = "Offline (Local Catalog)"
                    self.statusNotice = "Could not reach \(self.serverBaseUrl). Using local catalog."
                }
            }
        }.resume()
    }
    
    public func fetchLiveCatalog() {
        guard let url = URL(string: "\(serverBaseUrl)/store/products?limit=100&fields=*variants,*variants.calculated_price") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue(publishableApiKey, forHTTPHeaderField: "x-publishable-api-key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]] else {
                return
            }
            
            var liveParts: [ProductPart] = []
            for p in products {
                let pTitle = p["title"] as? String ?? "Part"
                let variants = p["variants"] as? [[String: Any]] ?? []
                for v in variants {
                    guard let vId = v["id"] as? String,
                          let vTitle = v["title"] as? String else { continue }
                    let sku = v["sku"] as? String
                    let barcode = (v["barcode"] as? String) ?? sku
                    var price: Double = 0.0
                    if let calcPrice = v["calculated_price"] as? [String: Any] {
                        if let amt = calcPrice["calculated_amount"] as? NSNumber {
                            price = amt.doubleValue
                        } else if let orig = calcPrice["original_amount"] as? NSNumber {
                            price = orig.doubleValue
                        }
                    }
                    liveParts.append(ProductPart(
                        id: vId,
                        title: vTitle,
                        productTitle: pTitle,
                        sku: sku,
                        barcode: barcode,
                        price: price
                    ))
                }
            }
            
            let finalParts = liveParts
            Task { @MainActor in
                if !finalParts.isEmpty {
                    self.catalog = finalParts
                    self.isConnected = true
                    self.connectionStatusText = "Online (Medusa v2)"
                    self.statusNotice = "✔ Synced \(finalParts.count) live parts from \(self.serverBaseUrl)"
                }
            }
        }.resume()
    }
    
    public func fetchServerSession() {
        checkServerHealthAndSync()
    }
    
    public func searchCatalog(query: String = "") {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            fetchLiveCatalog()
            return
        }
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBaseUrl)/store/products?q=\(encoded)&limit=50&fields=*variants,*variants.calculated_price") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue(publishableApiKey, forHTTPHeaderField: "x-publishable-api-key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]] else { return }
            
            var results: [ProductPart] = []
            for p in products {
                let pTitle = p["title"] as? String ?? ""
                let variants = p["variants"] as? [[String: Any]] ?? []
                for v in variants {
                    guard let vId = v["id"] as? String,
                          let vTitle = v["title"] as? String else { continue }
                    let sku = v["sku"] as? String
                    let barcode = (v["barcode"] as? String) ?? sku
                    var price: Double = 0.0
                    if let calcPrice = v["calculated_price"] as? [String: Any],
                       let amt = calcPrice["calculated_amount"] as? NSNumber {
                        price = amt.doubleValue
                    }
                    results.append(ProductPart(
                        id: vId,
                        title: vTitle,
                        productTitle: pTitle,
                        sku: sku,
                        barcode: barcode,
                        price: price
                    ))
                }
            }
            let finalResults = results
            Task { @MainActor in
                if !finalResults.isEmpty {
                    self.catalog = finalResults
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
        
        // 1. Check loaded catalog first for instant response
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
        
        // 2. Query remote server store search endpoint
        guard let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBaseUrl)/store/products?q=\(encoded)&limit=5&fields=*variants,*variants.calculated_price") else {
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue(publishableApiKey, forHTTPHeaderField: "x-publishable-api-key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            Task { @MainActor in
                self.isProcessing = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let products = json["products"] as? [[String: Any]],
                      !products.isEmpty else {
                    self.statusNotice = "✖ No match for \"\(code)\""
                    NSSound.beep()
                    return
                }
                
                for p in products {
                    let pTitle = p["title"] as? String ?? ""
                    let variants = p["variants"] as? [[String: Any]] ?? []
                    if let v = variants.first(where: {
                        let sku = $0["sku"] as? String
                        let barcode = $0["barcode"] as? String
                        let title = $0["title"] as? String ?? ""
                        return sku?.caseInsensitiveCompare(code) == .orderedSame ||
                               barcode?.caseInsensitiveCompare(code) == .orderedSame ||
                               title.localizedCaseInsensitiveContains(code)
                    }) ?? variants.first {
                        let vId = v["id"] as? String ?? ""
                        let vTitle = v["title"] as? String ?? ""
                        let sku = v["sku"] as? String
                        let barcode = (v["barcode"] as? String) ?? sku
                        var price: Double = 0.0
                        if let calcPrice = v["calculated_price"] as? [String: Any],
                           let amt = calcPrice["calculated_amount"] as? NSNumber {
                            price = amt.doubleValue
                        }
                        let part = ProductPart(id: vId, title: vTitle, productTitle: pTitle, sku: sku, barcode: barcode, price: price)
                        self.addToCart(part: part)
                        self.statusNotice = "✔ Added \(part.displayTitle) [SKU: \(sku ?? "N/A")]"
                        return
                    }
                }
                
                self.statusNotice = "✖ No match found for \"\(code)\""
                NSSound.beep()
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
    
    // MARK: - Custom Items
    
    public func addCustomItem(title: String, price: Double, quantity: Int = 1, sku: String? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty && price >= 0 && quantity > 0 else { return }
        let customSku = (sku?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? "CUSTOM-\(Int.random(in: 1000...9999))" : sku!.trimmingCharacters(in: .whitespacesAndNewlines)
        let part = ProductPart(
            id: "cust_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999))",
            title: cleanTitle,
            productTitle: cleanTitle,
            sku: customSku,
            barcode: nil,
            price: price,
            inventoryQuantity: 999,
            isCustom: true
        )
        for _ in 0..<quantity {
            addToCart(part: part)
        }
        statusNotice = "✔ Added custom item: \(cleanTitle) (\(String(format: "KES %.2f", price)))"
    }
    
    // MARK: - Staff Authentication (Zero PIN)
    
    public func loginWithStaffMember(_ staff: Cashier) {
        createStaffSession(for: staff, token: "tok_staff_\(staff.id)")
    }
    
    public func loginWithMedusaCredentials(email: String, password: String, completion: @escaping (Bool, String) -> Void) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check local staff profiles first for fast offline access
        if let staff = availableStaff.first(where: { $0.email.caseInsensitiveCompare(cleanEmail) == .orderedSame }) {
            createStaffSession(for: staff, token: "tok_admin_\(staff.id)")
            completion(true, "✔ Welcome, \(staff.name)!")
            return
        }
        
        guard let url = URL(string: "\(serverBaseUrl)/auth/user/emailpass") else {
            completion(false, "Invalid server URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        let body: [String: String] = ["email": cleanEmail, "password": cleanPassword]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["token"] as? String {
                        let namePart = cleanEmail.components(separatedBy: "@").first?.capitalized ?? "Staff"
                        let staff = Cashier(
                            id: "usr_\(Int(Date().timeIntervalSince1970))",
                            name: namePart,
                            email: cleanEmail,
                            role: cleanEmail.contains("tech") ? "Repair Technician" : "Admin"
                        )
                        self.createStaffSession(for: staff, token: token)
                        completion(true, "✔ Welcome, \(namePart)!")
                        return
                    }
                }
                completion(false, "✖ Invalid Medusa email or password")
            }
        }.resume()
    }
    
    public func createStaffSession(for staff: Cashier, token: String? = nil) {
        self.cashier = staff
        let session = StaffSession(
            staffId: staff.id,
            staffName: staff.name,
            staffEmail: staff.email,
            staffRole: staff.role,
            token: token
        )
        self.currentSession = session
        self.isLoggedIn = true
        self.statusNotice = "Active Session: \(staff.name) [\(staff.role)]"
        NSSound.beep()
    }
    
    public func lockTillSession() {
        self.isLoggedIn = false
        self.statusNotice = "Till locked. Sign in with Medusa Admin credentials to resume."
    }
    
    public func switchCashier() {
        if let currentIdx = availableStaff.firstIndex(where: { $0.id == cashier.id }) {
            let nextIdx = (currentIdx + 1) % availableStaff.count
            createStaffSession(for: availableStaff[nextIdx])
        } else {
            createStaffSession(for: availableStaff[0])
        }
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
        
        // If no customer is explicitly selected, default to the logged-in user as customer
        let effectiveCustomer: POSCustomer
        let wasExplicitCustomer: Bool
        if let cust = selectedCustomer {
            effectiveCustomer = cust
            wasExplicitCustomer = true
        } else {
            effectiveCustomer = POSCustomer(
                id: cashier.id,
                firstName: cashier.name,
                lastName: nil,
                email: cashier.email,
                phone: nil,
                companyName: "Urban Device Care Staff",
                hasAccount: true
            )
            wasExplicitCustomer = false
        }
        
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
            customerName: effectiveCustomer.fullName,
            customerPhone: effectiveCustomer.phone,
            customerCompany: effectiveCustomer.companyName,
            trackingUrl: "https://track.urbandevicecare.co.uk/order/\(orderNum)"
        )
        let escPosBytes = NativeThermalPrinter.generateEscPos58mm(data: receiptData)
        lastReceiptBytesCount = escPosBytes.count
        
        // Post to /api/pos/checkout
        guard let url = URL(string: "\(serverBaseUrl)/api/pos/checkout") else {
            finishLocalSale(orderNum: orderNum, customerName: effectiveCustomer.fullName, wasExplicit: wasExplicitCustomer)
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
                "total": $0.lineTotal,
                "is_custom": $0.part.isCustom
            ] as [String: Any] },
            "cashier": [
                "id": cashier.id,
                "first_name": cashier.name,
                "email": cashier.email,
                "role": cashier.role
            ] as [String: Any],
            "session_id": currentSession?.id ?? "ses_default",
            "tender": [
                "type": selectedTenderType,
                "amount": grandTotal,
                "tendered": Double(tenderInputText) ?? grandTotal,
                "change": changeDue
            ] as [String: Any],
            "terminal_type": "macos_swiftui",
            "repair_ticket_id": linkedRepairTicket?.id as Any,
            "customer": [
                "id": effectiveCustomer.id,
                "first_name": effectiveCustomer.firstName,
                "last_name": effectiveCustomer.lastName ?? "",
                "email": effectiveCustomer.email,
                "phone": effectiveCustomer.phone ?? "",
                "company_name": effectiveCustomer.companyName ?? ""
            ] as [String: Any]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = currentSession?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 3.0
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            Task { @MainActor in
                self.finishLocalSale(orderNum: orderNum, customerName: effectiveCustomer.fullName, wasExplicit: wasExplicitCustomer)
                completion?(orderNum)
            }
        }.resume()
    }
    
    public func finishLocalSale(orderNum: String, customerName: String? = nil, wasExplicit: Bool = true) {
        isProcessing = false
        cart.removeAll()
        tenderInputText = ""
        let cName = customerName ?? selectedCustomer?.fullName ?? "\(cashier.name) (Staff Account)"
        selectedCustomer = nil
        statusNotice = "✔ Order \(orderNum) completed! Tagged to \(cashier.name) [\(cashier.role)] for \(cName). Receipt: \(lastReceiptBytesCount) bytes"
        NSSound.beep()
    }
    
    // MARK: - Customer Pipeline & Quick Creation
    
    public func searchCustomers(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        customerSearchText = q
        guard !q.isEmpty else {
            searchCustomerResults = localCustomers
            return
        }
        
        let lowerQ = q.lowercased()
        searchCustomerResults = localCustomers.filter {
            $0.fullName.lowercased().contains(lowerQ) ||
            ($0.phone?.lowercased().contains(lowerQ) ?? false) ||
            $0.email.lowercased().contains(lowerQ) ||
            ($0.companyName?.lowercased().contains(lowerQ) ?? false)
        }
        
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBaseUrl)/api/pos/customers?q=\(encoded)") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        if let token = currentSession?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["customers"] as? [[String: Any]] else { return }
            
            let parsed = list.compactMap { item -> POSCustomer? in
                guard let id = item["id"] as? String,
                      let first = item["first_name"] as? String,
                      let email = item["email"] as? String else { return nil }
                let last = item["last_name"] as? String
                let phone = item["phone"] as? String
                let company = item["company_name"] as? String
                return POSCustomer(id: id, firstName: first, lastName: last, email: email, phone: phone, companyName: company, hasAccount: true)
            }
            
            Task { @MainActor in
                if !parsed.isEmpty {
                    for c in parsed {
                        if !self.localCustomers.contains(where: { $0.id == c.id || $0.email == c.email }) {
                            self.localCustomers.append(c)
                        }
                    }
                    self.searchCustomerResults = self.localCustomers.filter {
                        $0.fullName.lowercased().contains(lowerQ) ||
                        ($0.phone?.lowercased().contains(lowerQ) ?? false) ||
                        $0.email.lowercased().contains(lowerQ) ||
                        ($0.companyName?.lowercased().contains(lowerQ) ?? false)
                    }
                }
            }
        }.resume()
    }
    
    public func selectCustomer(_ customer: POSCustomer) {
        selectedCustomer = customer
        isCustomerSearchOpen = false
        customerSearchText = ""
        statusNotice = "✔ Linked client: \(customer.fullName)"
        NSSound.beep()
    }
    
    public func clearSelectedCustomer() {
        selectedCustomer = nil
        statusNotice = "Client unlinked from active order."
    }
    
    @discardableResult
    public func quickAddCustomer(
        firstName: String,
        lastName: String,
        phone: String,
        email: String? = nil,
        companyName: String? = nil
    ) -> POSCustomer {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let comp = companyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let givenEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let cleanPhone = ph.filter { $0.isLetter || $0.isNumber }.lowercased()
        var finalEmail = !givenEmail.isEmpty ? givenEmail.lowercased() : "walkin_\(cleanPhone.isEmpty ? String(Int(Date().timeIntervalSince1970)) : cleanPhone)@pos.urbandevicecare.co.uk"
        
        // Check if customer with this email already exists locally
        if let existing = localCustomers.first(where: { $0.email.lowercased() == finalEmail.lowercased() }) {
            let isSame = existing.firstName.caseInsensitiveCompare(first) == .orderedSame &&
                         (existing.lastName?.caseInsensitiveCompare(last) == .orderedSame || (existing.lastName == nil && last.isEmpty))
            if isSame {
                selectedCustomer = existing
                isCustomerSearchOpen = false
                showQuickCustomerSheet = false
                customerSearchText = ""
                statusNotice = "✔ Selected existing registered client: \(existing.fullName)"
                NSSound.beep()
                return existing
            }
            // Shared phone with different name: append counter for uniqueness
            var counter = 2
            while localCustomers.contains(where: { $0.email.lowercased() == "walkin_\(cleanPhone)_\(counter)@pos.urbandevicecare.co.uk" }) {
                counter += 1
            }
            finalEmail = "walkin_\(cleanPhone)_\(counter)@pos.urbandevicecare.co.uk"
        }
        
        let newCustomer = POSCustomer(
            id: "cus_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 1000...9999))",
            firstName: first,
            lastName: last.isEmpty ? nil : last,
            email: finalEmail,
            phone: ph.isEmpty ? nil : ph,
            companyName: (comp?.isEmpty ?? true) ? nil : comp,
            hasAccount: true // Medusa v2 registered customer constraint
        )
        
        // Add to local list
        localCustomers.insert(newCustomer, at: 0)
        
        // CRITICAL ZERO-CLICK REQUIREMENT: Immediately auto-select newly created customer
        selectedCustomer = newCustomer
        isCustomerSearchOpen = false
        showQuickCustomerSheet = false
        customerSearchText = ""
        statusNotice = "✔ Registered & autoselected client: \(newCustomer.fullName)"
        NSSound.beep()
        
        // Asynchronously post to /api/pos/customers
        if let url = URL(string: "\(serverBaseUrl)/api/pos/customers") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.0
            var payload: [String: Any] = [
                "first_name": first,
                "last_name": last,
                "phone": ph,
                "email": finalEmail
            ]
            if let c = comp, !c.isEmpty { payload["company_name"] = c }
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request).resume()
        }
        
        return newCustomer
    }
    
    private func loadMockCustomers() {
        localCustomers = [
            POSCustomer(
                id: "cus_01JOHN_DOE",
                firstName: "John",
                lastName: "Doe",
                email: "john.doe@example.com",
                phone: "+254712345678",
                companyName: "Nairobi Tech Ltd",
                hasAccount: true
            ),
            POSCustomer(
                id: "cus_02JANE_SMITH",
                firstName: "Jane",
                lastName: "Smith",
                email: "jane.smith@urbandevicecare.co.uk",
                phone: "+254722998877",
                companyName: "Urban Studios",
                hasAccount: true
            )
        ]
        searchCustomerResults = localCustomers
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
    
    // MARK: - Workshop Intake & Repairs Pipeline
    
    public var filteredRepairs: [RepairTicketRecord] {
        var list = repairs
        if repairFilterStatus != "all" {
            list = list.filter { $0.status.lowercased() == repairFilterStatus.lowercased() }
        }
        let q = repairSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.ticketNumber.lowercased().contains(q) ||
                ($0.customerName?.lowercased().contains(q) ?? false) ||
                ($0.customerPhone?.lowercased().contains(q) ?? false) ||
                ($0.deviceName?.lowercased().contains(q) ?? false) ||
                ($0.serialNumber?.lowercased().contains(q) ?? false) ||
                $0.issueDescription.lowercased().contains(q)
            }
        }
        return list
    }
    
    public func fetchRepairs() {
        guard let url = URL(string: "\(serverBaseUrl)/api/pos/repairs?status=all") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        if let token = currentSession?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = (json["repairs"] as? [[String: Any]]) ?? (json["repair_tickets"] as? [[String: Any]]) else { return }
            
            let parsed = list.compactMap { item -> RepairTicketRecord? in
                guard let id = item["id"] as? String,
                      let num = item["ticket_number"] as? String ?? item["ticketNumber"] as? String else { return nil }
                let cId = item["customer_id"] as? String ?? item["customerId"] as? String
                let cName = item["customer_name"] as? String ?? item["customerName"] as? String
                let cPhone = item["customer_phone"] as? String ?? item["customerPhone"] as? String
                let cEmail = item["customer_email"] as? String ?? item["customerEmail"] as? String
                let techName = item["technician_name"] as? String ?? item["technicianName"] as? String
                let techId = item["technician_id"] as? String ?? item["technicianId"] as? String
                
                let devDict = item["device"] as? [String: Any]
                let brand = devDict?["brand"] as? String ?? item["brand"] as? String
                let model = devDict?["model_name"] as? String ?? item["model_name"] as? String ?? item["modelName"] as? String
                let dName = item["device_name"] as? String ?? item["deviceName"] as? String ?? "\(brand ?? "Apple") \(model ?? "Device")".trimmingCharacters(in: .whitespaces)
                let sNum = devDict?["serial_number"] as? String ?? item["serial_number"] as? String ?? item["serialNumber"] as? String
                let imei = devDict?["imei"] as? String ?? item["imei"] as? String
                let condition = devDict?["condition"] as? String ?? item["condition"] as? String
                let status = item["status"] as? String ?? "received"
                let issue = item["issue_description"] as? String ?? item["issueDescription"] as? String ?? ""
                let acc = item["accessories"] as? String
                let pass = item["passcode"] as? String
                
                let partsEst = (item["parts_estimate"] as? NSNumber)?.doubleValue ?? 0.0
                let laborEst = (item["labor_estimate"] as? NSNumber)?.doubleValue ?? 0.0
                let totalEst = (item["total_estimate"] as? NSNumber)?.doubleValue ?? (partsEst + laborEst)
                let partsAct = (item["parts_actual"] as? NSNumber)?.doubleValue ?? 0.0
                let laborAct = (item["labor_actual"] as? NSNumber)?.doubleValue ?? 0.0
                let totalAct = (item["total_actual"] as? NSNumber)?.doubleValue ?? 0.0
                let amtPaid = (item["amount_paid"] as? NSNumber)?.doubleValue ?? (item["deposit_amount"] as? NSNumber)?.doubleValue ?? 0.0
                let balDue = (item["balance_due"] as? NSNumber)?.doubleValue ?? max(0, totalEst - amtPaid)
                let payStatus = item["payment_status"] as? String ?? (amtPaid >= totalEst && totalEst > 0 ? "captured" : amtPaid > 0 ? "partially_paid" : "pending")
                let warranty = (item["warranty_months"] as? NSNumber)?.intValue ?? 3
                let terms = (item["terms_accepted"] as? Bool) ?? true
                let wiped = (item["data_wiped_consent"] as? Bool) ?? true
                
                var parsedNotes: [RepairNote] = []
                if let rawNotes = item["notes"] as? [[String: Any]] {
                    for n in rawNotes {
                        let nId = n["id"] as? String ?? "note_\(UUID().uuidString)"
                        let content = n["content"] as? String ?? ""
                        let isInt = n["is_internal"] as? Bool ?? false
                        let date = n["created_at"] as? String ?? ""
                        parsedNotes.append(RepairNote(id: nId, content: content, isInternal: isInt, createdAt: date))
                    }
                }
                
                var parsedUpdates: [RepairUpdate] = []
                if let rawUpd = item["updates"] as? [[String: Any]] {
                    for u in rawUpd {
                        let uId = u["id"] as? String ?? "upd_\(UUID().uuidString)"
                        let st = u["status"] as? String ?? ""
                        let note = u["note"] as? String
                        let date = u["created_at"] as? String ?? ""
                        parsedUpdates.append(RepairUpdate(id: uId, status: st, note: note, createdAt: date))
                    }
                }
                
                let date = item["created_at"] as? String ?? item["createdAt"] as? String ?? ""
                
                return RepairTicketRecord(
                    id: id,
                    ticketNumber: num,
                    customerId: cId,
                    customerName: cName,
                    customerPhone: cPhone,
                    customerEmail: cEmail,
                    technicianName: techName,
                    technicianId: techId,
                    brand: brand,
                    modelName: model,
                    deviceName: dName,
                    serialNumber: sNum,
                    imei: imei,
                    condition: condition,
                    status: status,
                    issueDescription: issue,
                    accessories: acc,
                    passcode: pass,
                    partsEstimate: partsEst,
                    laborEstimate: laborEst,
                    totalEstimate: totalEst,
                    partsActual: partsAct,
                    laborActual: laborAct,
                    totalActual: totalAct,
                    amountPaid: amtPaid,
                    depositAmount: amtPaid,
                    balanceDue: balDue,
                    paymentStatus: payStatus,
                    warrantyMonths: warranty,
                    termsAccepted: terms,
                    dataWipedConsent: wiped,
                    notes: parsedNotes,
                    updates: parsedUpdates,
                    createdAt: date
                )
            }
            
            Task { @MainActor in
                self.repairs = parsed
            }
        }.resume()
    }
    
    public func updateRepairStatus(ticketId: String, status: String, note: String? = nil, completion: ((Bool) -> Void)? = nil) {
        if let idx = repairs.firstIndex(where: { $0.id == ticketId || $0.ticketNumber == ticketId }) {
            repairs[idx].status = status
            if let note = note, !note.isEmpty {
                let upd = RepairUpdate(status: status, note: note)
                repairs[idx].updates.append(upd)
            }
        }
        statusNotice = "✔ Status updated to \(status)"
        
        if let url = URL(string: "\(serverBaseUrl)/api/pos/repairs") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.5
            if let token = currentSession?.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let payload: [String: Any] = [
                "action": "update_status",
                "ticket_id": ticketId,
                "status": status,
                "note": note ?? ""
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse)?.statusCode == 200
                Task { @MainActor in
                    completion?(ok)
                }
            }.resume()
        } else {
            completion?(true)
        }
    }
    
    public func addRepairNote(ticketId: String, content: String, isInternal: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if let idx = repairs.firstIndex(where: { $0.id == ticketId || $0.ticketNumber == ticketId }) {
            let newNote = RepairNote(content: content, isInternal: isInternal)
            repairs[idx].notes.append(newNote)
        }
        statusNotice = "✔ Added note to ticket"
        
        if let url = URL(string: "\(serverBaseUrl)/api/pos/repairs") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.5
            if let token = currentSession?.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let payload: [String: Any] = [
                "action": "add_note",
                "ticket_id": ticketId,
                "content": content,
                "is_internal": isInternal
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse)?.statusCode == 200
                Task { @MainActor in
                    completion?(ok)
                }
            }.resume()
        } else {
            completion?(true)
        }
    }
    
    public func createRepairIntake(
        customerName: String,
        customerPhone: String,
        customerEmail: String?,
        deviceBrand: String,
        deviceModel: String,
        deviceSerial: String?,
        imei: String? = nil,
        condition: String? = nil,
        technicianName: String? = nil,
        technicianId: String? = nil,
        deviceType: String = "laptop",
        passcode: String? = nil,
        issueDescription: String,
        accessories: String? = nil,
        partsEstimate: Double = 0.0,
        laborEstimate: Double = 0.0,
        estimate: Double,
        deposit: Double,
        termsAccepted: Bool = true,
        dataWipedConsent: Bool = true,
        completion: ((RepairTicketRecord) -> Void)? = nil
    ) {
        let ticketNum = "REP-\(Int.random(in: 10000...99999))"
        let effectiveCustomerName = !customerName.isEmpty ? customerName : (selectedCustomer?.fullName ?? cashier.name)
        let effectiveCustomerPhone = !customerPhone.isEmpty ? customerPhone : (selectedCustomer?.phone ?? "+254 700 000 000")
        let effectiveCustomerEmail = customerEmail ?? selectedCustomer?.email ?? cashier.email
        let dName = "\(deviceBrand) \(deviceModel)".trimmingCharacters(in: .whitespacesAndNewlines)
        let balDue = max(0, estimate - deposit)
        let payStatus = deposit >= estimate && estimate > 0 ? "captured" : deposit > 0 ? "partially_paid" : "pending"
        
        let record = RepairTicketRecord(
            id: "rep_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999))",
            ticketNumber: ticketNum,
            customerId: selectedCustomer?.id ?? cashier.id,
            customerName: effectiveCustomerName,
            customerPhone: effectiveCustomerPhone,
            customerEmail: effectiveCustomerEmail,
            technicianName: technicianName ?? cashier.name,
            technicianId: technicianId ?? cashier.id,
            brand: deviceBrand,
            modelName: deviceModel,
            deviceName: dName.isEmpty ? "Generic Device" : dName,
            serialNumber: deviceSerial,
            imei: imei,
            condition: condition,
            status: "received",
            issueDescription: issueDescription,
            accessories: accessories,
            passcode: passcode,
            partsEstimate: partsEstimate,
            laborEstimate: laborEstimate,
            totalEstimate: estimate,
            amountPaid: deposit,
            depositAmount: deposit,
            balanceDue: balDue,
            paymentStatus: payStatus,
            warrantyMonths: 3,
            termsAccepted: termsAccepted,
            dataWipedConsent: dataWipedConsent
        )
        
        repairs.insert(record, at: 0)
        statusNotice = "✔ Booked Repair #\(ticketNum) for \(effectiveCustomerName)"
        NSSound.beep()
        
        // Post to remote Medusa repair plugin
        if let url = URL(string: "\(serverBaseUrl)/api/pos/repairs") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.5
            if let token = currentSession?.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let payload: [String: Any] = [
                "device": [
                    "brand": deviceBrand,
                    "model_name": deviceModel,
                    "serial_number": deviceSerial ?? "",
                    "imei": imei ?? "",
                    "condition": condition ?? "",
                    "device_type": deviceType,
                    "customer_id": selectedCustomer?.id ?? cashier.id
                ] as [String: Any],
                "ticket": [
                    "customer_name": effectiveCustomerName,
                    "customer_phone": effectiveCustomerPhone,
                    "customer_email": effectiveCustomerEmail,
                    "customer_id": selectedCustomer?.id ?? cashier.id,
                    "issue_description": issueDescription,
                    "accessories": accessories ?? "",
                    "passcode": passcode ?? "",
                    "technician_name": technicianName ?? cashier.name,
                    "technician_id": technicianId ?? cashier.id,
                    "parts_estimate": partsEstimate,
                    "labor_estimate": laborEstimate,
                    "total_estimate": estimate,
                    "amount_paid": deposit,
                    "terms_accepted": termsAccepted,
                    "data_wiped_consent": dataWipedConsent
                ] as [String: Any]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request).resume()
        }
        
        completion?(record)
    }
    
    public func tenderRepairBalance(ticket: RepairTicketRecord) {
        guard ticket.balanceDue > 0 else {
            statusNotice = "Repair #\(ticket.ticketNumber) has no remaining balance due."
            NSSound.beep()
            return
        }
        
        let repairPart = ProductPart(
            id: "rep_bal_\(ticket.id)",
            title: "Repair Balance #\(ticket.ticketNumber) - \(ticket.deviceName ?? "Device")",
            productTitle: "Repair Ticket #\(ticket.ticketNumber)",
            sku: ticket.ticketNumber,
            barcode: ticket.ticketNumber,
            price: ticket.balanceDue,
            inventoryQuantity: 1,
            isCustom: true
        )
        
        if selectedCustomer == nil, let cName = ticket.customerName {
            selectedCustomer = POSCustomer(
                id: ticket.customerId ?? "cus_repair_\(ticket.id)",
                firstName: cName,
                lastName: nil,
                email: ticket.customerEmail ?? "repair_\(ticket.ticketNumber.lowercased())@pos.urbandevicecare.co.uk",
                phone: ticket.customerPhone,
                companyName: "Repair Client",
                hasAccount: true
            )
        }
        
        addToCart(part: repairPart)
        activeTab = "pos"
        statusNotice = "✔ Loaded Repair #\(ticket.ticketNumber) balance (KES \(String(format: "%.2f", ticket.balanceDue))) into cart."
        NSSound.beep()
    }
}
