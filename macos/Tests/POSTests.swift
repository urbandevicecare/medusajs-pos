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
        
        testPOSWindowAndHostingView()
        testCatalogAndCartOperations()
        testTenderAndChangeCalculations()
        testCashierHandoverSwitching()
        testBarcodeScanning()
        testSaleCompletion()
        testButtonActionExecution()
        testNativeThermalReceiptGeneration()
        testQuickCustomerCreationAndAutoSelect()
        testCustomerSearchAndCheckoutAttribution()
        
        print("==========================================================")
        print(" ALL 10 TEST SUITES PASSED SUCCESSFULLY (0 failures)")
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
    static func testTenderAndChangeCalculations() {
        print("▶ Test 3: Tax (16% VAT), Grand Total, and Cash Tender Calculations")
        let vm = POSViewModel()
        let part = ProductPart(id: "test_part", title: "Test Part", price: 1000.0)
        vm.addToCart(part: part)
        
        // Subtotal: 1000.0
        assert(vm.subtotal == 1000.0, "Subtotal must equal 1000.0")
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
}
