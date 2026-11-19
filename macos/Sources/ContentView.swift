import SwiftUI
import AppKit

// MARK: - Interactive Button Style for Tactile Pressed Feedback

public struct InteractiveButtonStyle: ButtonStyle {
    public var isPrimary: Bool = false
    public var isDestructive: Bool = false
    public var isDisabled: Bool = false
    
    public init(isPrimary: Bool = false, isDestructive: Bool = false, isDisabled: Bool = false) {
        self.isPrimary = isPrimary
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isDisabled ? 0.5 : (configuration.isPressed ? 0.75 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Minimalist Reusable Button (MacVDMTool Aesthetic)

public struct MinimalButton: View {
    public let title: String
    public var isPrimary: Bool = false
    public var isDestructive: Bool = false
    public var isRunning: Bool = false
    public var isDisabled: Bool = false
    public var action: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        title: String,
        isPrimary: Bool = false,
        isDestructive: Bool = false,
        isRunning: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isPrimary = isPrimary
        self.isDestructive = isDestructive
        self.isRunning = isRunning
        self.isDisabled = isDisabled
        self.action = action
    }
    
    private var effectiveTextColor: Color {
        if isDisabled { return Color.secondary.opacity(0.6) }
        if isPrimary { return Color.white }
        if isDestructive { return Color.red }
        return Color.primary
    }
    
    private var effectiveBackgroundColor: Color {
        if isDisabled { return Color.gray.opacity(0.08) }
        if isPrimary {
            return isHovered ? Color.blue.opacity(0.85) : Color.blue
        }
        if isDestructive {
            return isHovered ? Color.red.opacity(0.25) : Color.red.opacity(0.12)
        }
        return isHovered ? Color.gray.opacity(0.2) : Color.gray.opacity(0.08)
    }
    
    private var effectiveStrokeColor: Color {
        if isDisabled { return Color.gray.opacity(0.15) }
        if isPrimary { return Color.blue }
        if isDestructive { return Color.red.opacity(0.35) }
        return isHovered ? Color.gray.opacity(0.4) : Color.gray.opacity(0.25)
    }
    
    public var body: some View {
        Button(action: {
            guard !isDisabled && !isRunning else { return }
            action()
        }) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(effectiveTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(effectiveBackgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(effectiveStrokeColor, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveButtonStyle(isPrimary: isPrimary, isDestructive: isDestructive, isDisabled: isDisabled || isRunning))
        .disabled(isDisabled || isRunning)
        .onHover { hovering in
            if !isDisabled && !isRunning {
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

// MARK: - Row Views

public struct CatalogRowView: View {
    public let part: ProductPart
    public let onAdd: () -> Void
    
    @State private var isHovered: Bool = false
    
    public var body: some View {
        Button(action: onAdd) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.displayTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let sku = part.sku {
                            Text("SKU: \(sku)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        if let barcode = part.barcode {
                            Text("BC: \(barcode)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(part.formattedPrice)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("Stock: \(part.inventoryQuantity)")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
            }
            .padding(8)
            .background(isHovered ? Color.blue.opacity(0.08) : Color.gray.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.blue.opacity(0.35) : Color.gray.opacity(0.15), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

public struct CartRowView: View {
    public let item: CartItem
    public let onIncrement: () -> Void
    public let onDecrement: () -> Void
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.part.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if let sku = item.part.sku {
                    Text("SKU: \(sku)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Button(action: onDecrement) {
                    Text("-")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InteractiveButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                
                Text("\(item.quantity)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 24, alignment: .center)
                
                Button(action: onIncrement) {
                    Text("+")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InteractiveButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            Text(item.formattedLineTotal)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 75, alignment: .trailing)
        }
        .padding(6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Main Native macOS POS View

public struct ContentView: View {
    @ObservedObject public var viewModel: POSViewModel
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if !viewModel.isConnected {
                offlinePromptView
            } else if !viewModel.isLoggedIn {
                StaffLoginView(viewModel: viewModel)
            } else {
                mainPosView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $viewModel.isFirstLaunchSetupOpen) {
            ServerSettingsSheet(viewModel: viewModel, isFirstLaunch: true)
        }
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            ServerSettingsSheet(viewModel: viewModel, isFirstLaunch: false)
        }
        .sheet(isPresented: $viewModel.showQuickCustomerSheet) {
            QuickCustomerSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var offlinePromptView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 6) {
                Text("Unable to Connect to Medusa Server")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("Please check your internet connection or verify your remote server settings.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Target Server: \(viewModel.serverBaseUrl)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 2)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.checkServerHealthAndSync()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Retry Connection")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                
                Button(action: {
                    viewModel.showSettingsSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("Server Settings")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var mainPosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar
            Divider()
            customerBarAndSearch
            Divider()
            HStack(alignment: .top, spacing: 14) {
                scannerAndCatalogPane
                Divider()
                cartAndTenderPane
            }
            Divider()
            footerBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    @ViewBuilder
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Urban Device Care POS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Server Settings button
            Button(action: {
                viewModel.showSettingsSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                    Text("Server")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            Menu {
                Button("retail_counter_1") { viewModel.selectedChannel = "retail_counter_1" }
                Button("bench_terminal_01") { viewModel.selectedChannel = "bench_terminal_01" }
                Button("workshop_intake") { viewModel.selectedChannel = "workshop_intake" }
            } label: {
                Text("\(viewModel.selectedChannel) ▾")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 120)
            
            Button(action: {
                viewModel.checkServerHealthAndSync()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.connectionStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .help("Click to refresh connection & live catalog")
            
            // Staff & Role Badge
            HStack(spacing: 4) {
                Image(systemName: viewModel.cashier.role == "Admin" ? "crown.fill" : (viewModel.cashier.role == "Repair Technician" ? "wrench.and.screwdriver.fill" : "person.circle.fill"))
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                Text("[\(viewModel.cashier.role)] \(viewModel.cashier.name)")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button(action: {
                viewModel.lockTillSession()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Lock Till")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
    }
    
    @ViewBuilder
    private var customerBarAndSearch: some View {
        if let cust = viewModel.selectedCustomer {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundColor(.green)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cust.fullName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Registered Client")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        if let comp = cust.companyName, !comp.isEmpty {
                            Text("• \(comp)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        if let phone = cust.phone, !phone.isEmpty {
                            Text("Tel: \(phone)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Text("Email: \(cust.email)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.clearSelectedCustomer()
                }) {
                    Text("Unlink")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(InteractiveButtonStyle(isDestructive: true))
            }
            .padding(8)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search client by name, phone, email, company...", text: $viewModel.customerSearchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11))
                            .onSubmit {
                                viewModel.searchCustomers(query: viewModel.customerSearchText)
                            }
                            .onChange(of: viewModel.customerSearchText) { newQuery in
                                viewModel.searchCustomers(query: newQuery)
                            }
                        if !viewModel.customerSearchText.isEmpty {
                            Button(action: {
                                viewModel.customerSearchText = ""
                                viewModel.searchCustomers(query: "")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    Button(action: {
                        viewModel.showQuickCustomerSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                            Text("+ Quick Customer")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(InteractiveButtonStyle(isPrimary: true))
                }
                
                if !viewModel.customerSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        if !viewModel.searchCustomerResults.isEmpty {
                            ForEach(viewModel.searchCustomerResults.prefix(3)) { cust in
                                Button(action: {
                                    viewModel.selectCustomer(cust)
                                }) {
                                    HStack {
                                        Text(cust.fullName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if let comp = cust.companyName {
                                            Text("(\(comp))")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(cust.phone ?? cust.email)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("Select →")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(4)
                                    .background(Color.gray.opacity(0.04))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else {
                            HStack {
                                Text("No customer matching \"\(viewModel.customerSearchText)\"")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    viewModel.showQuickCustomerSheet = true
                                }) {
                                    Text("+ Quick Register Client")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(4)
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    @ViewBuilder
    private var scannerAndCatalogPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCANNER & INVENTORY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("1D & 2D Active")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .foregroundColor(.secondary)
                TextField("Scan 1D barcode SKU (e.g. NP04011448) or press Enter...", text: $viewModel.scanInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .onSubmit {
                        viewModel.processScanInput()
                    }
                if !viewModel.scanInput.isEmpty {
                    Button(action: {
                        viewModel.processScanInput()
                    }) {
                        Text("Add")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(InteractiveButtonStyle(isPrimary: true))
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(viewModel.catalog) { part in
                        CatalogRowView(part: part) {
                            viewModel.addToCart(part: part)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var cartAndTenderPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVE ORDER HUD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if !viewModel.cart.isEmpty {
                    Button(action: {
                        viewModel.clearCart()
                    }) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(InteractiveButtonStyle(isDestructive: true))
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            
            if viewModel.cart.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "cart")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Cart is empty")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Scan barcode or click catalog part")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 105, maxHeight: 105)
                .background(Color.gray.opacity(0.04))
                .cornerRadius(6)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.cart) { item in
                            CartRowView(
                                item: item,
                                onIncrement: { viewModel.updateQuantity(for: item.part.id, delta: 1) },
                                onDecrement: { viewModel.updateQuantity(for: item.part.id, delta: -1) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 110)
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text("Subtotal:").font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "KES %.2f", viewModel.subtotal)).font(.system(size: 10, design: .monospaced))
                }
                HStack {
                    Text("VAT (16%):").font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "KES %.2f", viewModel.tax)).font(.system(size: 10, design: .monospaced))
                }
                Divider()
                HStack {
                    Text("GRAND TOTAL:").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(String(format: "KES %.2f", viewModel.grandTotal))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK CASH TENDER").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    MinimalButton(title: "Exact") { viewModel.setTenderExact() }
                    MinimalButton(title: "1,000") { viewModel.setTenderAmount(1000) }
                    MinimalButton(title: "2,000") { viewModel.setTenderAmount(2000) }
                    MinimalButton(title: "5,000") { viewModel.setTenderAmount(5000) }
                }
                HStack {
                    Text("Cash:").font(.system(size: 10)).foregroundColor(.secondary)
                    TextField("Amount", text: $viewModel.tenderInputText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 70)
                    Spacer()
                    Text("Change:")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                    Text(String(format: "KES %.2f", viewModel.changeDue))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(6)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
            }
            
            MinimalButton(
                title: "Complete & Print Receipt",
                isPrimary: true,
                isRunning: viewModel.isProcessing,
                isDisabled: viewModel.cart.isEmpty
            ) {
                viewModel.completeSale()
            }
        }
        .frame(width: 280)
    }
    
    @ViewBuilder
    private var footerBar: some View {
        HStack {
            Text(viewModel.statusNotice)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text("Cashier ID: \(viewModel.cashier.id)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}

// MARK: - Fast Quick Customer Registration Sheet

public struct QuickCustomerSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var companyName: String = ""
    @State private var errorMessage: String? = nil
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
        let query = viewModel.customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmail = query.contains("@")
        let isPhone = !isEmail && (query.range(of: "^[0-9+ -]{5,}$", options: .regularExpression) != nil)
        
        var fName = ""
        var lName = ""
        if !isEmail && !isPhone && !query.isEmpty {
            let parts = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if parts.count >= 2 {
                fName = parts[0]
                lName = parts.dropFirst().joined(separator: " ")
            } else {
                fName = query
            }
        }
        
        _firstName = State(initialValue: fName)
        _lastName = State(initialValue: lName)
        _phone = State(initialValue: isPhone ? query : "")
        _email = State(initialValue: isEmail ? query : "")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Add Customer")
                        .font(.system(size: 14, weight: .bold))
                    Text("Medusa v2 Registered Client (Auto-Selected)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    viewModel.showQuickCustomerSheet = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("First Name *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("Alice", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Name *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("Wambui", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone Number *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("+254 700 112 233", text: $phone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Email").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    Text("(Optional - fallback generated)").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
                }
                TextField("client@example.com (or leave empty)", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                Text("If omitted, generates walkin_{phone}@pos.urbandevicecare.co.uk")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Company Name").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    Text("(Optional)").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
                }
                TextField("Safari Tech Ltd", text: $companyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
            }
            
            Divider()
            
            HStack(spacing: 8) {
                MinimalButton(title: "Cancel") {
                    viewModel.showQuickCustomerSheet = false
                }
                MinimalButton(title: "Register & Auto-Select", isPrimary: true) {
                    let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !f.isEmpty else {
                        errorMessage = "First name is required"
                        return
                    }
                    guard !l.isEmpty else {
                        errorMessage = "Last name is required"
                        return
                    }
                    guard !p.isEmpty else {
                        errorMessage = "Phone number is required"
                        return
                    }
                    // Auto-selects newly created customer immediately
                    viewModel.quickAddCustomer(
                        firstName: f,
                        lastName: l,
                        phone: p,
                        email: email.isEmpty ? nil : email,
                        companyName: companyName.isEmpty ? nil : companyName
                    )
                }
            }
        }
        .padding(18)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Staff Authentication View (PIN / Medusa Credentials)

public struct StaffLoginView: View {
    @ObservedObject public var viewModel: POSViewModel
    @State private var loginMode: Int = 0 // 0: Quick PIN, 1: Medusa Credentials
    @State private var enteredPin: String = ""
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var errorMessage: String? = nil
    @State private var isAuthenticating: Bool = false
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 18) {
            Spacer()
            
            // App Branding Header
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)
                    Text("Urban Device Care POS")
                        .font(.system(size: 20, weight: .bold))
                }
                Text("Select your staff profile or enter PIN to begin your counter session")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Mode Picker
            Picker("", selection: $loginMode) {
                Text("Staff Quick PIN").tag(0)
                Text("Medusa Account").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 280)
            
            if loginMode == 0 {
                // Quick Staff PIN Cards
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.availableStaff) { staff in
                            Button(action: {
                                viewModel.createStaffSession(for: staff)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: staff.role == "Admin" ? "crown.fill" : (staff.role == "Repair Technician" ? "wrench.and.screwdriver.fill" : "person.fill"))
                                        .font(.system(size: 20))
                                        .foregroundColor(staff.role == "Admin" ? .orange : (staff.role == "Repair Technician" ? .blue : .green))
                                    Text(staff.name)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(staff.role)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text("PIN: \(staff.pin ?? "----")")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .frame(width: 105, height: 95)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                        }
                    }
                    
                    // Direct numeric PIN entry
                    HStack(spacing: 8) {
                        SecureField("Enter 4-Digit PIN", text: $enteredPin)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14, design: .monospaced))
                            .frame(width: 160)
                            .onSubmit {
                                submitPin()
                            }
                        
                        Button(action: {
                            submitPin()
                        }) {
                            Text("Sign In")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    }
                }
            } else {
                // Medusa Credentials Login
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Medusa Admin Email")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("admin@urbandevicecare.co.uk", text: $emailInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12))
                            .frame(width: 280)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        SecureField("••••••••", text: $passwordInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12))
                            .frame(width: 280)
                            .onSubmit {
                                submitMedusaLogin()
                            }
                    }
                    
                    Button(action: {
                        submitMedusaLogin()
                    }) {
                        HStack(spacing: 6) {
                            if isAuthenticating {
                                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                            }
                            Text("Authenticate Session")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 280)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAuthenticating)
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Server footer info
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Connected: \(viewModel.serverBaseUrl)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                Button(action: {
                    viewModel.showSettingsSheet = true
                }) {
                    Text("Change")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func submitPin() {
        let p = enteredPin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return }
        if viewModel.loginWithPin(pin: p) {
            errorMessage = nil
        } else {
            errorMessage = "✖ Incorrect staff PIN code"
            NSSound.beep()
        }
    }
    
    private func submitMedusaLogin() {
        let e = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = passwordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty && !p.isEmpty else {
            errorMessage = "Email and password are required"
            return
        }
        isAuthenticating = true
        errorMessage = nil
        viewModel.loginWithMedusaCredentials(email: e, password: p) { success, msg in
            isAuthenticating = false
            if !success {
                errorMessage = msg
                NSSound.beep()
            }
        }
    }
}

// MARK: - Server Configuration Sheet (First Startup & Reconfiguration)

public struct ServerSettingsSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    public var isFirstLaunch: Bool = false
    
    @State private var serverUrl: String = ""
    @State private var apiKey: String = ""
    @State private var isTesting: Bool = false
    @State private var testStatusMessage: String? = nil
    @State private var isTestSuccess: Bool = false
    
    public init(viewModel: POSViewModel, isFirstLaunch: Bool = false) {
        self.viewModel = viewModel
        self.isFirstLaunch = isFirstLaunch
        _serverUrl = State(initialValue: viewModel.serverBaseUrl)
        _apiKey = State(initialValue: viewModel.publishableApiKey)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFirstLaunch ? "Welcome to Urban Device Care POS" : "Medusa Server Configuration")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Configure your Medusa v2 server endpoint for real-time catalog & customer sync.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SERVER BASE URL").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                TextField("https://admin.urbandevicecare.co.uk", text: $serverUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12, design: .monospaced))
                
                // Quick preset buttons
                HStack(spacing: 6) {
                    Button(action: {
                        serverUrl = "https://admin.urbandevicecare.co.uk"
                    }) {
                        Text("Remote Production")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        serverUrl = "http://localhost:9000"
                    }) {
                        Text("Local Medusa (9000)")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        serverUrl = "http://localhost:8000"
                    }) {
                        Text("Local Fresh (8000)")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("PUBLISHABLE API KEY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Text("(Required for Storefront API)").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
                }
                TextField("pk_c7904d9e7fcc...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
            }
            
            // Test connection row
            HStack(spacing: 8) {
                Button(action: {
                    isTesting = true
                    testStatusMessage = "Testing connection..."
                    viewModel.testConnection(urlToTest: serverUrl) { success, message in
                        isTesting = false
                        isTestSuccess = success
                        testStatusMessage = message
                    }
                }) {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "bolt.fill").font(.system(size: 10))
                        }
                        Text("Test Connection")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTesting)
                
                if let msg = testStatusMessage {
                    Text(msg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isTestSuccess ? .green : .red)
                }
            }
            
            Divider()
            
            HStack(spacing: 8) {
                if !isFirstLaunch {
                    MinimalButton(title: "Cancel") {
                        viewModel.showSettingsSheet = false
                    }
                }
                MinimalButton(title: isFirstLaunch ? "Save & Connect" : "Save Settings", isPrimary: true) {
                    viewModel.saveServerConfig(newUrl: serverUrl, newKey: apiKey)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

