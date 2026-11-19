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
        
        print("==========================================================")
        print(" ALL 8 TEST SUITES PASSED SUCCESSFULLY (0 failures)")
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
}
