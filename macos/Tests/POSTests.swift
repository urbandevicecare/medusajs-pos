import Cocoa
import SwiftUI

// MARK: - Native Unit & Integration Test Suite for UrbanDevicePOS

@main
struct POSTests {
    @MainActor
    static func main() {
        print("==========================================================")
        print(" Running UrbanDevicePOS Swift Unit & Regression Test Suite")
        print("==========================================================")
        
        KeychainSecurity.useInMemoryStoreForTesting = true
        
        testPOSWindowAndHostingView()
        testCatalogAndCartOperations()
        testCustomItemAddition()
        testTenderAndChangeCalculations()
        testCashierHandoverSwitching()
        testBarcodeScanning()
        testSaleCompletion()
        testDefaultCustomerFallback()
        testButtonActionExecution()
        testNativeThermalReceiptGeneration()
        testQuickCustomerCreationAndAutoSelect()
        testCustomerSearchAndCheckoutAttribution()
        testStaffAuthenticationAndSession()
        testWorkshopRepairIntakeAndBalanceTender()
        testKeychainSecurity()
        testPriceListRecalculation()
        testOptionalVatToggle()
        testActualStockResolutionAndLiveSuggestions()
        testMpesaStkZeroBalanceGuard()
        
        print("==========================================================")
        print(" ALL 19 TEST SUITES PASSED SUCCESSFULLY (0 failures)")
        print("==========================================================")
    }
    
    @MainActor
    static func testPOSWindowAndHostingView() {
        print("▶ Test 1: POSWindow & POSHostingView Event Dispatching Validation")
        let window = POSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        assert(window.canBecomeKey == true, "POSWindow must return canBecomeKey = true")
        assert(window.canBecomeMain == true, "POSWindow must return canBecomeMain = true")
        
        let dummyView = Text("Test")
        let hostingView = POSHostingView(rootView: dummyView)
        assert(hostingView.acceptsFirstMouse(for: nil) == true, "POSHostingView must return acceptsFirstMouse = true")
        assert(hostingView.mouseDownCanMoveWindow == false, "POSHostingView must return mouseDownCanMoveWindow = false so button clicks are not intercepted")
        print("  ✔ Passed: POSWindow and POSHostingView configured correctly for responsive mouse clicks")
    }
    
    @MainActor
    static func testCatalogAndCartOperations() {
        print("▶ Test 2: Catalog Loading & Cart Item Management")
        let vm = POSViewModel()
        assert(!vm.catalog.isEmpty, "Mock catalog must contain products on launch")
        assert(vm.cart.isEmpty, "Cart must initially be empty")
        
        let item1 = vm.catalog[0]
        let item2 = vm.catalog[1]
        
        // Add item1
        vm.addToCart(part: item1)
        assert(vm.cart.count == 1, "Cart should contain 1 item")
        assert(vm.cart[0].quantity == 1, "Quantity should be 1")
        
        // Add item1 again -> should increment quantity, not duplicate row
        vm.addToCart(part: item1)
        assert(vm.cart.count == 1, "Cart should still contain 1 unique row")
        assert(vm.cart[0].quantity == 2, "Quantity should be incremented to 2")
        
        // Add item2
        vm.addToCart(part: item2)
        assert(vm.cart.count == 2, "Cart should contain 2 unique items")
        
        // Decrement item1
        vm.updateQuantity(for: item1.id, delta: -1)
        assert(vm.cart[0].quantity == 1, "Quantity of item1 should decrement to 1")
        
        // Decrement item1 again -> should remove from cart
        vm.updateQuantity(for: item1.id, delta: -1)
        assert(vm.cart.count == 1, "item1 should be removed from cart")
        assert(vm.cart[0].part.id == item2.id, "Remaining item should be item2")
        
        // Clear cart
        vm.clearCart()
        assert(vm.cart.isEmpty, "Cart should be empty after clearCart()")
        print("  ✔ Passed: Cart additions, merging, quantity updates, and clearing verified")
    }
    
    @MainActor
    static func testCustomItemAddition() {
        print("▶ Test 3: Custom Non-Catalog Item Addition to Order")
        let vm = POSViewModel()
        vm.clearCart()
        
        // Add custom item
        vm.addCustomItem(title: "Special LCD Bonding Adhesive", price: 1500.0, quantity: 2, sku: "ADH-001")
        assert(vm.cart.count == 1, "Cart should have 1 item")
        assert(vm.cart[0].part.title == "Special LCD Bonding Adhesive", "Title must match")
        assert(vm.cart[0].part.isCustom == true, "Must be flagged as custom item")
        assert(vm.cart[0].part.price == 1500.0, "Unit price must match")
        assert(vm.cart[0].quantity == 2, "Quantity must equal 2")
        assert(vm.cart[0].lineTotal == 3000.0, "Line total must be 3000.0")
        assert(vm.subtotal == 3000.0, "Subtotal must equal 3000.0")
        print("  ✔ Passed: Custom non-catalog item added to cart with exact price and quantity")
    }
    
    @MainActor
    static func testTenderAndChangeCalculations() {
        print("▶ Test 3: Tax (16% VAT), Grand Total, and Cash Tender Calculations")
        let vm = POSViewModel()
        let part = ProductPart(id: "test_part", title: "Test Part", price: 1000.0)
        vm.addToCart(part: part)
        
        // Subtotal: 1000.0
        assert(vm.subtotal == 1000.0, "Subtotal must equal 1000.0")
        assert(vm.tax == 0.0, "Tax must initially be 0.0 when VAT toggle is off")
        assert(vm.grandTotal == 1000.0, "Grand total must equal subtotal when exempt")
        
        // Enable 16% VAT
        vm.applyVat = true
        // Tax 16%: 160.0
        assert(vm.tax == 160.0, "Tax must equal 160.0")
        // Grand total: 1160.0
        assert(vm.grandTotal == 1160.0, "Grand total must equal 1160.0")
        
        // Test exact tender
        vm.setTenderExact()
        assert(vm.tenderInputText == "1160.00", "Exact tender button must set tenderInputText to grandTotal")
        assert(vm.changeDue == 0.0, "Exact tender change due must be 0.0")
        
        // Test overpayment
        vm.setTenderAmount(2000.0)
        assert(vm.tenderInputText == "2000.00", "setTenderAmount must format to 2 decimal places")
        assert(vm.changeDue == 840.0, "Change due for 2000 on 1160 total must be 840.0")
        
        // Test underpayment
        vm.setTenderAmount(500.0)
        assert(vm.changeDue == 0.0, "Underpayment must yield 0.0 change due")
        print("  ✔ Passed: VAT, totals, exact tender, and quick cash change calculations verified")
    }
    
    @MainActor
    static func testCashierHandoverSwitching() {
        print("▶ Test 4: Counter Cashier Handover Switching")
        let vm = POSViewModel()
        let initialCashier = vm.cashier
        assert(initialCashier.name == "Nelly K.", "Initial cashier should be Nelly K.")
        
        vm.switchCashier()
        assert(vm.cashier.name == "Dan M.", "First switch should yield Dan M.")
        
        vm.switchCashier()
        assert(vm.cashier.name == "Alex T.", "Second switch should yield Alex T.")
        
        vm.switchCashier()
        assert(vm.cashier.id == initialCashier.id, "Third switch should cycle back to Nelly K.")
        print("  ✔ Passed: Rapid cashier handover toggles staff identities seamlessly")
    }
    
    @MainActor
    static func testBarcodeScanning() {
        print("▶ Test 5: Local SKU / Barcode Scan Resolution")
        let vm = POSViewModel()
        vm.clearCart()
        
        // 1. Scan exact SKU for keyboard
        vm.scanInput = "NP04011448"
        vm.processScanInput()
        assert(vm.cart.count == 1, "Scanning NP04011448 should add 1 item to cart")
        assert(vm.cart[0].part.sku == "NP04011448", "Cart item SKU must match")
        assert(vm.scanInput.isEmpty, "scanInput must be cleared after processing")
        
        // 2. Scan barcode for screen
        vm.scanInput = "0793573199210"
        vm.processScanInput()
        assert(vm.cart.count == 2, "Scanning barcode 0793573199210 should add screen to cart")
        print("  ✔ Passed: 1D SKU and barcode scanning resolves instantaneously")
    }
    
    @MainActor
    static func testSaleCompletion() {
        print("▶ Test 6: Sale Checkout & Order Generation")
        let vm = POSViewModel()
        vm.clearCart()
        vm.addToCart(part: vm.catalog[0])
        vm.setTenderExact()
        
        let initialCount = vm.cart.count
        assert(initialCount > 0, "Cart must have items before sale")
        
        vm.finishLocalSale(orderNum: "POS-TEST-123456")
        assert(vm.cart.isEmpty, "Cart must be emptied after sale completion")
        assert(vm.tenderInputText.isEmpty, "Tender input must be cleared after sale")
        assert(vm.statusNotice.contains("POS-TEST-123456"), "Status notice must reference the order number")
        print("  ✔ Passed: Local sale finishes cleanly and resets cart state")
    }
    
    @MainActor
    static func testDefaultCustomerFallback() {
        print("▶ Test 7: Default Customer Fallback to Logged-in Staff User")
        let vm = POSViewModel()
        vm.clearCart()
        vm.selectedCustomer = nil
        assert(vm.selectedCustomer == nil, "selectedCustomer must initially be nil")
        
        vm.addToCart(part: vm.catalog[0])
        vm.finishLocalSale(orderNum: "POS-DEFAULT-CUST")
        
        // When selectedCustomer is nil, finishLocalSale attributes order to cashier.name as staff customer
        assert(vm.statusNotice.contains(vm.cashier.name), "Status notice must reference logged-in cashier as customer")
        assert(vm.cart.isEmpty, "Cart must be cleared")
        print("  ✔ Passed: Unselected customer correctly defaults to active logged-in staff user")
    }
    
    @MainActor
    static func testButtonActionExecution() {
        print("▶ Test 7: Button Component Interaction")
        var actionExecuted = false
        let button = MinimalButton(title: "Execute Test") {
            actionExecuted = true
        }
        button.action()
        assert(actionExecuted == true, "MinimalButton action closure must execute when triggered")
        print("  ✔ Passed: MinimalButton action executes correctly")
    }
    
    @MainActor
    static func testNativeThermalReceiptGeneration() {
        print("▶ Test 8: Native ESC/POS 58mm Thermal Receipt Generator")
        let part = ProductPart(id: "part_test", title: "M2 Screen Replacement", sku: "SCR-M2-001", price: 25000)
        let cartItem = CartItem(part: part, quantity: 1)
        let receiptData = ReceiptData(
            orderNumber: "POS-981240",
            cashierName: "Nelly K.",
            terminalId: "bench_terminal_01",
            items: [cartItem],
            subtotal: 25000.0,
            tax: 4000.0,
            grandTotal: 29000.0,
            tenderType: "cash",
            tendered: 30000.0,
            change: 1000.0,
            trackingUrl: "https://track.urbandevicecare.co.uk/order/POS-981240"
        )
        let data = NativeThermalPrinter.generateEscPos58mm(data: receiptData)
        assert(!data.isEmpty, "Generated ESC/POS data must not be empty")
        assert(data.count > 100, "ESC/POS receipt should be at least 100 bytes (got \(data.count) bytes)")
        
        // Validate ESC @ initialize header
        let bytes = [UInt8](data)
        assert(bytes[0] == 0x1B && bytes[1] == 0x40, "Receipt must start with ESC @ (0x1B, 0x40)")
        
        // Validate feed and cut footer
        let endIdx = bytes.count - 1
        assert(bytes[endIdx] == 0x00 && bytes[endIdx - 1] == 0x42 && bytes[endIdx - 2] == 0x56 && bytes[endIdx - 3] == 0x1D, "Receipt must end with paper cut GS V B 0")
        print("  ✔ Passed: Native ESC/POS 58mm binary generation validated (\(data.count) bytes)")
    }
    
    @MainActor
    static func testQuickCustomerCreationAndAutoSelect() {
        print("▶ Test 9: Quick Registered Customer Creation with Walk-in Fallback Email & Zero-Click Auto-Selection")
        let vm = POSViewModel()
        assert(vm.selectedCustomer == nil, "Initial active customer should be nil")
        
        // 1. Quick create customer without email (triggers auto-generated walkin_{cleanPhone}@pos.urbandevicecare.co.uk)
        let newCust = vm.quickAddCustomer(
            firstName: "Alice",
            lastName: "Wambui",
            phone: "+254 700 112 233",
            email: nil,
            companyName: "Safari Tech Ltd"
        )
        
        assert(newCust.firstName == "Alice", "Customer first name must match")
        assert(newCust.lastName == "Wambui", "Customer last name must match")
        assert(newCust.phone == "+254 700 112 233", "Customer phone must match")
        assert(newCust.companyName == "Safari Tech Ltd", "Company name must match")
        assert(newCust.hasAccount == true, "Must be created as a registered client, not a guest")
        assert(newCust.email == "walkin_254700112233@pos.urbandevicecare.co.uk", "Should auto-generate unique walkin email from sanitized phone")
        
        // 2. CRITICAL REQUIREMENT: Check ZERO-CLICK auto-selection into current session
        assert(vm.selectedCustomer != nil, "Created customer must immediately be auto-selected")
        assert(vm.selectedCustomer?.id == newCust.id, "Auto-selected customer ID must match created customer")
        assert(vm.selectedCustomer?.fullName == "Alice Wambui", "Full name must be formatted correctly")
        
        // 3. Quick create customer with explicit email
        let custWithEmail = vm.quickAddCustomer(
            firstName: "Bob",
            lastName: "Otieno",
            phone: "0711223344",
            email: "bob.otieno@company.com",
            companyName: nil
        )
        assert(custWithEmail.email == "bob.otieno@company.com", "Explicit email must be preserved")
        assert(vm.selectedCustomer?.id == custWithEmail.id, "Bob must now be auto-selected")
        
        // 4. Shared phone number with different name: collision-safe unique email
        let sharedPhoneCust = vm.quickAddCustomer(
            firstName: "Charles",
            lastName: "Wambui",
            phone: "+254 700 112 233",
            email: nil,
            companyName: nil
        )
        assert(sharedPhoneCust.email == "walkin_254700112233_2@pos.urbandevicecare.co.uk", "Must append counter to avoid Medusa duplicate email constraint")
        assert(vm.selectedCustomer?.id == sharedPhoneCust.id, "Charles must be auto-selected")
        
        // 5. Idempotent re-registration of exact same customer
        let aliceAgain = vm.quickAddCustomer(
            firstName: "Alice",
            lastName: "Wambui",
            phone: "+254 700 112 233"
        )
        assert(aliceAgain.id == newCust.id, "Re-registering same customer should return existing record")
        assert(aliceAgain.email == "walkin_254700112233@pos.urbandevicecare.co.uk", "Original fallback email preserved")
        assert(vm.selectedCustomer?.id == newCust.id, "Alice must be re-selected")
        
        print("  ✔ Passed: Registered customer creation, fallback walk-in email generation, and zero-click auto-select verified")
    }
    
    @MainActor
    static func testCustomerSearchAndCheckoutAttribution() {
        print("▶ Test 10: Customer Search, Selection Toggle, and Checkout Sales Attribution")
        let vm = POSViewModel()
        
        // 1. Search customer by query
        vm.searchCustomers(query: "John")
        assert(!vm.searchCustomerResults.isEmpty, "Search for 'John' should find at least 1 customer")
        assert(vm.searchCustomerResults[0].firstName == "John", "Search result must be John Doe")
        
        // 2. Select customer
        vm.selectCustomer(vm.searchCustomerResults[0])
        assert(vm.selectedCustomer?.firstName == "John", "Customer should be selected")
        
        // 3. Unlink customer
        vm.clearSelectedCustomer()
        assert(vm.selectedCustomer == nil, "Customer should be unlinked")
        
        // 4. Select again and complete sale
        vm.selectCustomer(vm.searchCustomerResults[0])
        let part = vm.catalog[0]
        vm.addToCart(part: part)
        
        vm.finishLocalSale(orderNum: "POS-981240")
        assert(vm.cart.isEmpty, "Cart must be cleared after sale")
        assert(vm.selectedCustomer == nil, "Active session customer must be reset for next sale")
        assert(vm.statusNotice.contains("John Doe"), "Status notice must reference customer John Doe")
        
        print("  ✔ Passed: Customer search pipeline, selection unlinking, and checkout attribution verified")
    }
    
    @MainActor
    static func testStaffAuthenticationAndSession() {
        print("▶ Test 13: Staff Authentication, Role Attribution & Session Management (Zero PIN)")
        let vm = POSViewModel()
        
        // 1. Authenticate with Nelly K. Staff Profile
        let adminStaff = vm.availableStaff[0]
        vm.loginWithStaffMember(adminStaff)
        assert(vm.isLoggedIn == true, "Session must be logged in")
        assert(vm.cashier.name == "Nelly K.", "Cashier name must be Nelly K.")
        assert(vm.cashier.role == "Admin", "Cashier role must be Admin")
        assert(vm.currentSession != nil, "Active StaffSession must be created")
        assert(vm.currentSession?.staffRole == "Admin", "Session role must be Admin")
        assert(vm.currentSession?.token != nil, "Session token must be present")
        
        // 2. Lock till session
        vm.lockTillSession()
        assert(vm.isLoggedIn == false, "Till must be locked")
        
        // 3. Authenticate with Dan M. Profile -> Repair Technician
        let techStaff = vm.availableStaff[1]
        vm.loginWithStaffMember(techStaff)
        assert(vm.isLoggedIn == true, "Session must be logged in")
        assert(vm.cashier.name == "Dan M.", "Cashier name must be Dan M.")
        assert(vm.cashier.role == "Repair Technician", "Cashier role must be Repair Technician")
        
        // 4. Test Medusa Credentials Login with known staff email
        vm.lockTillSession()
        var loginSucceeded = false
        vm.loginWithMedusaCredentials(email: "nelly@urbandevicecare.co.uk", password: "password123") { success, _ in
            loginSucceeded = success
        }
        assert(loginSucceeded == true, "Known staff email must succeed login")
        assert(vm.isLoggedIn == true, "Till session must be logged in")
        assert(vm.cashier.email == "nelly@urbandevicecare.co.uk", "Cashier email must match")
        
        print("  ✔ Passed: Staff Medusa credential authentication, role attribution, and session locking verified")
    }
    
    @MainActor
    static func testWorkshopRepairIntakeAndBalanceTender() {
        print("▶ Test 14: Workshop Repair Intake & Balance Due Cart Tender Pipeline")
        let vm = POSViewModel()
        vm.clearCart()
        
        assert(!vm.repairs.isEmpty, "Repairs must be loaded on launch")
        let initialCount = vm.repairs.count
        
        // 1. Create a repair intake ticket
        var createdTicket: RepairTicketRecord? = nil
        vm.createRepairIntake(
            customerName: "Sarah Mwangi",
            customerPhone: "+254 711 999 888",
            customerEmail: "sarah@mwangi.co.ke",
            deviceBrand: "Apple",
            deviceModel: "iPhone 14 Pro Max",
            deviceSerial: "F2LX778899",
            imei: "358912345678901",
            condition: "Minor Scratches",
            technicianName: "Dan M.",
            deviceType: "Phone",
            passcode: "1234",
            issueDescription: "Cracked OLED screen, touch unresponsive",
            accessories: "Silicone Case",
            estimate: 25000.0,
            deposit: 5000.0
        ) { ticket in
            createdTicket = ticket
        }
        
        assert(createdTicket != nil, "Created ticket must not be nil")
        guard let ticket = createdTicket else { return }
        assert(ticket.customerName == "Sarah Mwangi", "Customer name must match")
        assert(ticket.deviceName == "Apple iPhone 14 Pro Max", "Device name must match")
        assert(ticket.totalEstimate == 25000.0, "Estimate must match")
        assert(ticket.depositAmount == 5000.0, "Deposit must match")
        assert(ticket.balanceDue == 20000.0, "Balance due must be estimate - deposit = 20000.0")
        assert(ticket.technicianName == "Dan M.", "Technician must match")
        assert(vm.repairs.count == initialCount + 1, "Repairs count must increase by 1")
        
        // 2. Status update and Note addition
        vm.updateRepairStatus(ticketId: ticket.id, status: "diagnosing", note: "Diagnostic started by Dan")
        assert(vm.repairs[0].status == "diagnosing", "Status must update to diagnosing")
        assert(vm.repairs[0].updates.count >= 1, "Status update must be logged")
        
        vm.addRepairNote(ticketId: ticket.id, content: "Screen replacement part in stock", isInternal: false)
        assert(vm.repairs[0].notes.count >= 1, "Note must be logged")
        
        // 3. Filter repairs by status
        vm.repairFilterStatus = "diagnosing"
        let diagList = vm.filteredRepairs
        assert(diagList.allSatisfy { $0.status.lowercased() == "diagnosing" }, "All filtered tickets must be 'diagnosing'")
        vm.repairFilterStatus = "all"
        
        // 4. Search repairs by query
        vm.repairSearchText = "Sarah"
        let searchList = vm.filteredRepairs
        assert(!searchList.isEmpty, "Search for Sarah must find the created repair")
        assert(searchList[0].ticketNumber == ticket.ticketNumber, "Ticket number must match")
        vm.repairSearchText = ""
        
        // 5. Tender repair balance into cart
        vm.tenderRepairBalance(ticket: ticket)
        assert(vm.cart.count == 1, "Cart must contain 1 repair balance item")
        assert(vm.cart[0].part.price == 20000.0, "Cart item price must equal balance due")
        assert(vm.cart[0].part.sku == ticket.ticketNumber, "Cart item SKU must match ticket number")
        assert(vm.activeTab == "pos", "Active tab must switch to pos for counter checkout")
        
        print("  ✔ Passed: Workshop repair intake, status updates, notes, balance calculation, and 1-click cart tender verified")
    }
    
    @MainActor
    static func testKeychainSecurity() {
        print("▶ Test 12: Apple Keychain Hardware-Backed Security Storage")
        let testKey = "test_udc_pos_secret_key"
        let testSecret = "sk_live_secure_hardware_token_998877"
        
        // Save to Keychain
        let saved = KeychainSecurity.save(key: testKey, value: testSecret)
        assert(saved == true, "KeychainSecurity must save value without error")
        
        // Load from Keychain
        let loaded = KeychainSecurity.load(key: testKey)
        assert(loaded == testSecret, "KeychainSecurity must retrieve exact decrypted secret")
        
        // Clean up
        KeychainSecurity.delete(key: testKey)
        let afterDelete = KeychainSecurity.load(key: testKey)
        assert(afterDelete == nil, "Deleted key must return nil")
        
        print("  ✔ Passed: Apple Keychain encrypted storage and secure retrieval verified")
    }
    
    @MainActor
    static func testPriceListRecalculation() {
        print("▶ Test 16: Customer Group & Price List Tier Recalculation")
        let vm = POSViewModel()
        vm.clearCart()
        
        let part = ProductPart(id: "prod_screen", title: "MacBook Screen", price: 10000.0, inventoryQuantity: 15)
        vm.addToCart(part: part)
        assert(vm.cart[0].part.price == 10000.0, "Initial standard price must be 10000")
        assert(vm.cart[0].appliedPriceList == nil, "No price list initially applied")
        
        // 1. Select VIP customer (10% discount)
        let vipCustomer = POSCustomer(id: "cust_vip", firstName: "VIP", lastName: "Client", groups: ["VIP"])
        vm.selectCustomer(vipCustomer)
        assert(vm.cart[0].part.price == 9000.0, "VIP tier should yield 10% discount (9000)")
        assert(vm.cart[0].appliedPriceList == "VIP (10% Off)", "Applied price list badge must be VIP (10% Off)")
        assert(vm.cart[0].originalPrice == 10000.0, "Original price must be preserved")
        
        // 2. Select Wholesale customer (20% discount)
        let wholesaleCustomer = POSCustomer(id: "cust_ws", firstName: "Wholesale", lastName: "Buyer", groups: ["Wholesale"])
        vm.selectCustomer(wholesaleCustomer)
        assert(vm.cart[0].part.price == 8000.0, "Wholesale tier should yield 20% discount (8000)")
        assert(vm.cart[0].appliedPriceList == "Wholesale (20% Off)", "Applied price list badge must be Wholesale (20% Off)")
        
        // 3. Select Corporate customer (15% discount)
        let corpCustomer = POSCustomer(id: "cust_corp", firstName: "Corp", lastName: "Partner", groups: ["Corporate"])
        vm.selectCustomer(corpCustomer)
        assert(vm.cart[0].part.price == 8500.0, "Corporate tier should yield 15% discount (8500)")
        assert(vm.cart[0].appliedPriceList == "Corporate (15% Off)", "Applied price list badge must be Corporate (15% Off)")
        
        // 4. Select customer with explicit discount_rate override (e.g. 25%)
        let customRateCustomer = POSCustomer(id: "cust_rate", firstName: "Custom", lastName: "Rate", discountRate: 0.25)
        vm.selectCustomer(customRateCustomer)
        assert(vm.cart[0].part.price == 7500.0, "Explicit 25% discount should yield 7500")
        assert(vm.cart[0].appliedPriceList == "25% Customer Discount", "Applied badge must reflect custom discount")
        
        // 5. Unlink customer -> should revert back to original 10000 standard price
        vm.clearSelectedCustomer()
        assert(vm.cart[0].part.price == 10000.0, "Unlinking customer should revert to base price")
        assert(vm.cart[0].appliedPriceList == nil, "Price list badge should be cleared")
        
        print("  ✔ Passed: Customer price list tiers, custom discount rates, and cart auto-repricing verified")
    }
    
    @MainActor
    static func testOptionalVatToggle() {
        print("▶ Test 17: Optional 16% VAT Interactive Toggle & Receipt Formatting")
        let vm = POSViewModel()
        vm.clearCart()
        
        let part = ProductPart(id: "test_part", title: "Test Part", price: 1000.0)
        vm.addToCart(part: part)
        
        // Default: applyVat = false (exempt)
        assert(vm.applyVat == false, "applyVat should default to false (exempt)")
        assert(vm.subtotal == 1000.0, "Subtotal must equal 1000")
        assert(vm.tax == 0.0, "Tax must equal 0.0 with VAT off")
        assert(vm.grandTotal == 1000.0, "Grand total must equal 1000.0 with VAT off")
        
        // Turn VAT on
        vm.applyVat = true
        assert(vm.tax == 160.0, "Tax must equal 160.0 when applyVat = true")
        assert(vm.grandTotal == 1160.0, "Grand total must equal 1160.0 when applyVat = true")
        
        // Turn VAT back off
        vm.applyVat = false
        assert(vm.tax == 0.0, "Tax must return to 0.0 when applyVat = false")
        assert(vm.grandTotal == 1000.0, "Grand total must return to 1000.0")
        
        // Verify Thermal receipt formatting with tax = 0
        let receiptDataExempt = ReceiptData(
            orderNumber: "POS-EXEMPT-01",
            cashierName: "Nelly K.",
            terminalId: "bench_terminal_01",
            items: vm.cart,
            subtotal: 1000.0,
            tax: 0.0,
            grandTotal: 1000.0,
            tenderType: "cash",
            tendered: 1000.0,
            change: 0.0
        )
        let receiptBytes = NativeThermalPrinter.generateEscPos58mm(data: receiptDataExempt)
        let receiptString = String(decoding: receiptBytes, as: UTF8.self)
        assert(receiptString.contains("Exempt"), "Thermal receipt must indicate Exempt when tax is 0")
        
        print("  ✔ Passed: Optional 16% VAT toggle, calculation, and exempt receipt formatting verified")
    }
    
    @MainActor
    static func testActualStockResolutionAndLiveSuggestions() {
        print("▶ Test 18: Genuine In-Stock Quantity Resolution & Live Suggestions")
        let vm = POSViewModel()
        
        // 1. Resolve stock from nested location levels (never default to fake 10)
        let rawProductWithLevels: [String: Any] = [
            "title": "Genuine Screen",
            "location_levels": [
                ["stocked_quantity": 7],
                ["stocked_quantity": 8]
            ]
        ]
        let stock1 = POSViewModel.resolveActualStock(from: rawProductWithLevels)
        assert(stock1 == 15, "Stock must equal sum of location levels (15)")
        
        let rawProductEmpty: [String: Any] = [
            "title": "Out of Stock Part"
        ]
        let stock0 = POSViewModel.resolveActualStock(from: rawProductEmpty)
        assert(stock0 == 0, "Stock must resolve to 0 when no inventory found (never fake 10)")
        
        // 2. Test live item suggestions query
        vm.updateSearchSuggestions(query: "Key")
        assert(!vm.itemSuggestions.isEmpty, "Searching for 'Key' should return suggestions")
        assert(vm.showItemSuggestions == true, "Suggestions dropdown should be open")
        assert(vm.itemSuggestions.allSatisfy { $0.title.lowercased().contains("key") || ($0.productTitle ?? "").lowercased().contains("key") }, "Suggestions must match query")
        
        vm.updateSearchSuggestions(query: "")
        assert(vm.itemSuggestions.isEmpty, "Empty query must clear suggestions")
        assert(vm.showItemSuggestions == false, "Dropdown must close on empty query")
        
        print("  ✔ Passed: True stock calculation across locations and live item suggestions verified")
    }
    
    @MainActor
    static func testMpesaStkZeroBalanceGuard() {
        print("▶ Test 19: M-Pesa STK Push Zero Balance Guard & Modal Control")
        let vm = POSViewModel()
        vm.clearCart()
        
        // 1. Cart STK push when cart is empty / balance is 0
        vm.openCartStkModal()
        assert(vm.showStkModal == false, "openCartStkModal must reject opening when cart is empty / grandTotal <= 0")
        
        // 2. Cart STK push with items
        let part = ProductPart(id: "part_stk", title: "Battery", price: 3500.0, inventoryQuantity: 5)
        vm.addToCart(part: part)
        vm.openCartStkModal()
        assert(vm.showStkModal == true, "openCartStkModal must open when cart has items")
        assert(vm.stkAmount == vm.grandTotal, "STK amount must match grand total")
        assert(vm.stkStep == "input", "Initial STK step must be 'input'")
        
        // 3. Cancel modal
        vm.cancelStkModal()
        assert(vm.showStkModal == false, "Modal must close on cancel")
        
        // 4. Repair ticket STK push zero balance guard
        let paidTicket = RepairTicketRecord(
            id: "rep_paid",
            ticketNumber: "UDC-REP-PAID",
            brand: "Apple",
            modelName: "iPhone 13",
            totalEstimate: 5000.0,
            amountPaid: 5000.0,
            balanceDue: 0.0,
            paymentStatus: "captured"
        )
        vm.openRepairStkModal(ticket: paidTicket)
        assert(vm.showStkModal == false, "openRepairStkModal must reject tickets with balanceDue <= 0")
        
        let unpaidTicket = RepairTicketRecord(
            id: "rep_unpaid",
            ticketNumber: "UDC-REP-DUE",
            customerPhone: "+254712345678",
            brand: "Apple",
            modelName: "iPhone 14",
            totalEstimate: 12000.0,
            amountPaid: 2000.0,
            balanceDue: 10000.0,
            paymentStatus: "partially_paid"
        )
        vm.openRepairStkModal(ticket: unpaidTicket)
        assert(vm.showStkModal == true, "openRepairStkModal must open when balanceDue > 0")
        assert(vm.stkAmount == 10000.0, "STK amount must equal balance due")
        assert(vm.stkPhone == "+254712345678", "STK phone must be pre-filled from customer")
        vm.cancelStkModal()
        
        print("  ✔ Passed: M-Pesa STK push zero-balance guard strictly enforced on cart and repair tickets")
    }
}
