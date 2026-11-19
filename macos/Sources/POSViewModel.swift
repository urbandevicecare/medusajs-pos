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
        role: "Admin",
        pin: "1234"
    )
    
    // Staff authentication & session state
    @Published public var isLoggedIn: Bool = false
    @Published public var currentSession: StaffSession? = nil
    @Published public var availableStaff: [Cashier] = [
        Cashier(id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk", role: "Admin", pin: "1234"),
        Cashier(id: "usr_02TECH_DAN", name: "Dan M.", email: "dan@urbandevicecare.co.uk", role: "Repair Technician", pin: "5678"),
        Cashier(id: "usr_03CASH_ALEX", name: "Alex T.", email: "alex@urbandevicecare.co.uk", role: "Cashier", pin: "9012")
    ]
    
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
    
    public func loginWithPin(pin: String) -> Bool {
        guard let staff = availableStaff.first(where: { $0.pin == pin }) else {
            return false
        }
        createStaffSession(for: staff)
        return true
    }
    
    public func loginWithStaffMember(_ staff: Cashier) {
        createStaffSession(for: staff)
    }
    
    public func loginWithMedusaCredentials(email: String, password: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(serverBaseUrl)/auth/user/emailpass") else {
            completion(false, "Invalid server URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["token"] as? String {
                        let namePart = email.components(separatedBy: "@").first?.capitalized ?? "Staff"
                        let staff = Cashier(
                            id: "usr_\(Int(Date().timeIntervalSince1970))",
                            name: namePart,
                            email: email,
                            role: email.contains("tech") ? "Repair Technician" : "Admin"
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
        self.statusNotice = "Till locked. Enter PIN or login to resume."
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
            customerName: selectedCustomer?.fullName,
            customerPhone: selectedCustomer?.phone,
            customerCompany: selectedCustomer?.companyName,
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
        
        var payload: [String: Any] = [
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
            "repair_ticket_id": linkedRepairTicket?.id as Any
        ]
        
        if let cust = selectedCustomer {
            payload["customer"] = [
                "id": cust.id,
                "first_name": cust.firstName,
                "last_name": cust.lastName ?? "",
                "email": cust.email,
                "phone": cust.phone ?? "",
                "company_name": cust.companyName ?? ""
            ] as [String: Any]
        }
        
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
        let customerInfo = selectedCustomer != nil ? " for \(selectedCustomer!.fullName)" : ""
        selectedCustomer = nil
        statusNotice = "✔ Order \(orderNum) completed! Tagged to \(cashier.name) [\(cashier.role)]\(customerInfo). Receipt: \(lastReceiptBytesCount) bytes"
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
        request.timeoutInterval = 2.0
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
}
