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
                    if let badge = part.appliedPriceList, let orig = part.originalPrice, orig > part.price {
                        Text("🏷️ \(badge) (was KES \(String(format: "%.2f", orig)))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(part.formattedPrice)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    if part.inventoryQuantity > 0 {
                        Text("• \(part.inventoryQuantity) in stock")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text("• 0 in stock (Out of stock)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.red)
                    }
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
                HStack(spacing: 4) {
                    if let sku = item.part.sku {
                        Text("SKU: \(sku)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if item.part.inventoryQuantity > 0 {
                        Text("• \(item.part.inventoryQuantity) in stock")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    } else {
                        Text("• 0 in stock")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                    if item.quantity > item.part.inventoryQuantity {
                        Text("(Exceeds stock!)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                if let badge = item.appliedPriceList, let orig = item.originalPrice, orig > item.part.price {
                    Text("🏷️ \(badge) (was KES \(String(format: "%.2f", orig)))")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(3)
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
        .sheet(isPresented: $viewModel.showCustomItemSheet) {
            CustomItemSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showIntakeSheet) {
            RepairIntakeSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedRepair) { ticket in
            RepairDetailsSheet(viewModel: viewModel, ticket: ticket)
        }
        .sheet(isPresented: $viewModel.showStkModal) {
            MpesaStkSheet(viewModel: viewModel)
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
            if viewModel.activeTab == "pos" {
                customerBarAndSearch
                Divider()
                HStack(alignment: .top, spacing: 14) {
                    scannerAndCatalogPane
                    Divider()
                    cartAndTenderPane
                }
            } else {
                repairsWorkshopPane
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
            
            // Sleek minimalist navigation control ("POS" and "Repairs")
            HStack(spacing: 2) {
                Button(action: { viewModel.activeTab = "pos" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "cart")
                            .font(.system(size: 11, weight: .semibold))
                        Text("POS")
                            .font(.system(size: 11, weight: viewModel.activeTab == "pos" ? .semibold : .regular))
                    }
                    .foregroundColor(viewModel.activeTab == "pos" ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(viewModel.activeTab == "pos" ? Color.blue.opacity(0.9) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    viewModel.activeTab = "repairs"
                    viewModel.fetchRepairs()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Repairs")
                            .font(.system(size: 11, weight: viewModel.activeTab == "repairs" ? .semibold : .regular))
                        if !viewModel.repairs.isEmpty {
                            Text("\(viewModel.repairs.count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(viewModel.activeTab == "repairs" ? Color.white.opacity(0.2) : Color.primary.opacity(0.08))
                                .foregroundColor(viewModel.activeTab == "repairs" ? .white : .secondary)
                                .cornerRadius(4)
                        }
                    }
                    .foregroundColor(viewModel.activeTab == "repairs" ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(viewModel.activeTab == "repairs" ? Color.blue.opacity(0.9) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(2)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.leading, 8)
            
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
                
                HStack(spacing: 4) {
                    Text("Default Client:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(viewModel.cashier.name) (Staff Account)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal, 2)
                
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
                Button(action: {
                    viewModel.showCustomItemSheet = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                        Text("+ Custom Item")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                Text("1D & 2D Active")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .foregroundColor(.secondary)
                TextField("Scan 1D barcode SKU (e.g. NP04011448) or search part title...", text: $viewModel.scanInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .onChange(of: viewModel.scanInput) { q in
                        viewModel.updateSearchSuggestions(query: q)
                    }
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
            
            if viewModel.showItemSuggestions && !viewModel.itemSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("SUGGESTIONS (\(viewModel.itemSuggestions.count))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { viewModel.showItemSuggestions = false }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.system(size: 11))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(viewModel.itemSuggestions) { sug in
                                Button(action: {
                                    viewModel.addToCart(part: sug)
                                    viewModel.scanInput = ""
                                    viewModel.showItemSuggestions = false
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sug.displayTitle)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            HStack(spacing: 6) {
                                                if let sku = sug.sku {
                                                    Text("SKU: \(sku)")
                                                        .font(.system(size: 8, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                }
                                                if sug.inventoryQuantity > 0 {
                                                    Text("• \(sug.inventoryQuantity) in stock")
                                                        .font(.system(size: 8, weight: .medium))
                                                        .foregroundColor(.green)
                                                } else {
                                                    Text("• 0 in stock (Out of stock)")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(.red)
                                                }
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(sug.formattedPrice)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(.primary)
                                            if let badge = sug.appliedPriceList {
                                                Text("🏷️ \(badge)")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(6)
                                    .background(Color.blue.opacity(0.04))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 180)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            
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
                    Toggle("VAT (16%):", isOn: $viewModel.applyVat)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.applyVat {
                        Text(String(format: "KES %.2f", viewModel.tax)).font(.system(size: 10, design: .monospaced))
                    } else {
                        Text("KES 0.00 (Exempt)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    }
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
            
            VStack(spacing: 6) {
                MinimalButton(
                    title: "Complete & Print Receipt (Cash)",
                    isPrimary: true,
                    isRunning: viewModel.isProcessing,
                    isDisabled: viewModel.cart.isEmpty || viewModel.grandTotal <= 0
                ) {
                    viewModel.completeSale()
                }
                
                Button(action: {
                    viewModel.openCartStkModal()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("Push M-Pesa STK")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(viewModel.cart.isEmpty || viewModel.grandTotal <= 0 ? Color.green.opacity(0.3) : Color(red: 0.0, green: 0.64, blue: 0.27))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.cart.isEmpty || viewModel.grandTotal <= 0)
                .onHover { h in if h && !viewModel.cart.isEmpty && viewModel.grandTotal > 0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
        }
        .frame(width: 280)
    }
    
    @ViewBuilder
    private var repairsWorkshopPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search repairs by ticket #, client, phone, serial or device...", text: $viewModel.repairSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                }
                .padding(6)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
                
                Picker("Status", selection: $viewModel.repairFilterStatus) {
                    Group {
                        Text("All Statuses").tag("all")
                        Text("Dropoff").tag("pending_dropoff")
                        Text("Received").tag("received")
                        Text("Diagnosing").tag("diagnosing")
                        Text("Awaiting Approval").tag("awaiting_approval")
                        Text("Repairing").tag("repairing")
                    }
                    Group {
                        Text("Ready for Pickup").tag("ready")
                        Text("Completed").tag("completed")
                        Text("Collected").tag("collected")
                        Text("Cancelled").tag("cancelled")
                        Text("Refunded").tag("refunded")
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
                
                Button(action: {
                    viewModel.fetchRepairs()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    viewModel.showIntakeSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("+ Book Repair Intake")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if viewModel.filteredRepairs.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No repair tickets match the selected filter.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Button(action: {
                        viewModel.showIntakeSheet = true
                    }) {
                        Text("+ Create First Repair Ticket")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("TICKET # & DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 95, alignment: .leading)
                        Text("DEVICE & ISSUE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                        Text("CLIENT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 140, alignment: .leading)
                        Text("TECH / SERIAL").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
                        Text("STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 90, alignment: .center)
                        Text("PAYMENT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 80, alignment: .center)
                        Text("BALANCE DUE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 90, alignment: .trailing)
                        Text("ACTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(4)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.filteredRepairs) { ticket in
                                RepairTicketRowView(ticket: ticket, onViewDetails: {
                                    viewModel.selectedRepair = ticket
                                })
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Repair Ticket Row View (Tabular List)

public struct RepairTicketRowView: View {
    public let ticket: RepairTicketRecord
    public let onViewDetails: () -> Void
    
    @State private var isHovered: Bool = false
    
    private var statusColor: Color {
        switch ticket.status.lowercased() {
        case "ready": return .green
        case "repairing": return .blue
        case "diagnosing": return .purple
        case "received": return .orange
        case "awaiting_approval": return .yellow
        case "pending_dropoff": return .secondary
        case "completed": return .gray
        case "collected": return .teal
        case "cancelled", "refunded": return .red
        default: return .secondary
        }
    }
    
    private var paymentBadgeText: String {
        switch ticket.paymentStatus.lowercased() {
        case "paid", "captured": return "Paid"
        case "partially_paid": return "Partially Paid"
        case "refunded": return "Refunded"
        default: return "Unpaid"
        }
    }
    
    private var paymentBadgeColor: Color {
        switch ticket.paymentStatus.lowercased() {
        case "paid", "captured": return .green
        case "partially_paid": return .orange
        case "refunded": return .purple
        default: return .red
        }
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Ticket # & Date
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.ticketNumber)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text(String(ticket.createdAt.prefix(10)))
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(width: 95, alignment: .leading)
            
            // Device & Issue
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.deviceName ?? "\(ticket.brand ?? "") \(ticket.modelName ?? "")".trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(ticket.issueDescription)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            
            // Client (Never "Workshop Client")
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.clientDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let phone = ticket.customerPhone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, alignment: .leading)
            
            // Tech / Serial
            VStack(alignment: .leading, spacing: 2) {
                Text("Tech: \(ticket.technicianName ?? "-")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("S/N: \(ticket.serialNumber ?? "-")")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 110, alignment: .leading)
            
            // Status
            Text(ticket.status.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .cornerRadius(4)
                .frame(width: 90, alignment: .center)
            
            // Payment
            Text(paymentBadgeText)
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(paymentBadgeColor.opacity(0.12))
                .foregroundColor(paymentBadgeColor)
                .cornerRadius(4)
                .frame(width: 80, alignment: .center)
            
            // Balance Due
            Text(String(format: "KES %.2f", ticket.balanceDue))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(ticket.balanceDue > 0 ? .orange : .green)
                .frame(width: 90, alignment: .trailing)
            
            // Action (View only)
            Button(action: onViewDetails) {
                Text("View")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60, alignment: .trailing)
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.blue.opacity(0.06) : Color.gray.opacity(0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Custom Non-Catalog Item Sheet

public struct CustomItemSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    @State private var title: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1
    @State private var skuText: String = ""
    @State private var errorMessage: String? = nil
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cart.badge.plus")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("+ Add Custom Non-Catalog Item")
                        .font(.system(size: 13, weight: .bold))
                    Text("Create arbitrary counter item or one-off fee")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { viewModel.showCustomItemSheet = false }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Item Title / Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("e.g. Tempered Glass + Screen Fitting", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
            }
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit Price (KES) *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("1500.00", text: $priceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    Stepper("\(quantity)", value: $quantity, in: 1...99)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SKU / Barcode Reference").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    Text("(Optional)").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
                }
                TextField("CUSTOM-01", text: $skuText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12, design: .monospaced))
            }
            
            Divider()
            
            HStack(spacing: 8) {
                MinimalButton(title: "Cancel") {
                    viewModel.showCustomItemSheet = false
                }
                MinimalButton(title: "Add to Order", isPrimary: true) {
                    let cleanT = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanT.isEmpty else {
                        errorMessage = "Item title is required"
                        return
                    }
                    guard let p = Double(priceText), p >= 0 else {
                        errorMessage = "Valid unit price is required"
                        return
                    }
                    viewModel.addCustomItem(title: cleanT, price: p, quantity: quantity, sku: skuText.isEmpty ? nil : skuText)
                    viewModel.showCustomItemSheet = false
                }
            }
        }
        .padding(18)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Workshop Repair Intake Sheet

public struct RepairIntakeSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    
    @State private var customerName: String = ""
    @State private var customerPhone: String = ""
    @State private var customerEmail: String = ""
    @State private var deviceBrand: String = "Apple"
    @State private var deviceModel: String = ""
    @State private var deviceSerial: String = ""
    @State private var imei: String = ""
    @State private var condition: String = "Good"
    @State private var deviceType: String = "Laptop"
    @State private var passcode: String = ""
    @State private var technicianName: String = ""
    @State private var issueDescription: String = ""
    @State private var accessories: String = ""
    @State private var estimateText: String = ""
    @State private var depositText: String = ""
    @State private var selectedPartId: String = ""
    @State private var termsAccepted: Bool = true
    @State private var dataWipedConsent: Bool = true
    @State private var errorMessage: String? = nil
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
        if let cust = viewModel.selectedCustomer {
            _customerName = State(initialValue: cust.fullName)
            _customerPhone = State(initialValue: cust.phone ?? "")
            _customerEmail = State(initialValue: cust.email)
        } else {
            _customerName = State(initialValue: viewModel.cashier.name)
            _customerEmail = State(initialValue: viewModel.cashier.email)
        }
        _technicianName = State(initialValue: viewModel.cashier.name)
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Book Workshop Repair Ticket")
                            .font(.system(size: 13, weight: .bold))
                        Text("Connected 1-to-1 with Medusa Repair Plugin")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { viewModel.showIntakeSheet = false }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
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
                
                Group {
                    // Client Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CUSTOMER DETAILS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Name *").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("Customer Name", text: $customerName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Phone *").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("+254 700 000 000", text: $customerPhone)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    
                    // Device Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DEVICE DETAILS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Brand *").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("e.g. Apple", text: $deviceBrand)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Model *").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("e.g. MacBook Pro 16-inch (A2485)", text: $deviceModel)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                        }
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Serial #").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("C02G...", text: $deviceSerial)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("IMEI").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("3589...", text: $imei)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Condition").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("e.g. Good, Minor Scratches", text: $condition)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                        }
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Passcode / PIN").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("e.g. 1234 or Pattern", text: $passcode)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Assigned Technician").font(.system(size: 9)).foregroundColor(.secondary)
                                TextField("Technician Name", text: $technicianName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    
                    // Fault Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reported Issue / Fault Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        TextField("Describe symptoms, liquid spill, drops, damaged components...", text: $issueDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11))
                    }
                    
                    // Accessories Left
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessories Left with Device").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        TextField("e.g. Charger, Case, Dongle, Box", text: $accessories)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11))
                    }
                    
                    // Live Catalog Part Selection
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Required Part (Live Medusa Catalog)").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.catalog.count) live parts").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        Picker("", selection: $selectedPartId) {
                            Text("-- No part / Diagnostic service only --").tag("")
                            ForEach(viewModel.catalog) { part in
                                Text("\(part.title) - KES \(String(format: "%.2f", part.price)) (Stock: \(part.inventoryQuantity))").tag(part.id)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .font(.system(size: 11))
                        .onChange(of: selectedPartId) { newId in
                            if let chosen = viewModel.catalog.first(where: { $0.id == newId }) {
                                estimateText = String(format: "%.2f", chosen.price + 2000.0)
                            } else {
                                estimateText = "2000.00"
                            }
                        }
                    }
                }
                
                // Financials
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Estimate (KES)").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        TextField("0.00", text: $estimateText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deposit Paid (KES)").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        TextField("0.00", text: $depositText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                
                // Terms and Consent
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Customer accepts diagnostic & repair terms", isOn: $termsAccepted)
                        .font(.system(size: 10))
                    Toggle("Customer acknowledges potential data loss / wipe consent", isOn: $dataWipedConsent)
                        .font(.system(size: 10))
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    MinimalButton(title: "Cancel") {
                        viewModel.showIntakeSheet = false
                    }
                    MinimalButton(title: "Create Ticket & Print Intake", isPrimary: true) {
                        let cName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let dModel = deviceModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        let issue = issueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard !cName.isEmpty else {
                            errorMessage = "Customer name is required"
                            return
                        }
                        guard !dModel.isEmpty else {
                            errorMessage = "Device model is required"
                            return
                        }
                        guard !issue.isEmpty else {
                            errorMessage = "Issue description is required"
                            return
                        }
                        
                        let est = Double(estimateText) ?? 0.0
                        let dep = Double(depositText) ?? 0.0
                        
                        viewModel.createRepairIntake(
                            customerName: cName,
                            customerPhone: customerPhone,
                            customerEmail: customerEmail.isEmpty ? nil : customerEmail,
                            deviceBrand: deviceBrand,
                            deviceModel: dModel,
                            deviceSerial: deviceSerial.isEmpty ? nil : deviceSerial,
                            imei: imei.isEmpty ? nil : imei,
                            condition: condition.isEmpty ? nil : condition,
                            technicianName: technicianName.isEmpty ? nil : technicianName,
                            technicianId: nil,
                            deviceType: deviceType,
                            passcode: passcode.isEmpty ? nil : passcode,
                            issueDescription: issue,
                            accessories: accessories.isEmpty ? nil : accessories,
                            estimate: est,
                            deposit: dep,
                            termsAccepted: termsAccepted,
                            dataWipedConsent: dataWipedConsent
                        )
                        viewModel.showIntakeSheet = false
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 480, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Repair Details Sheet

public struct RepairDetailsSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    public let ticket: RepairTicketRecord
    
    @State private var currentStatus: String
    @State private var statusNote: String = ""
    @State private var newNoteContent: String = ""
    @State private var isInternalNote: Bool = false
    @State private var noticeMessage: String? = nil
    
    public init(viewModel: POSViewModel, ticket: RepairTicketRecord) {
        self.viewModel = viewModel
        self.ticket = ticket
        _currentStatus = State(initialValue: ticket.status)
    }
    
    private var paymentBadgeText: String {
        switch ticket.paymentStatus.lowercased() {
        case "paid", "captured": return "Paid"
        case "partially_paid": return "Partially Paid"
        case "refunded": return "Refunded"
        default: return "Unpaid"
        }
    }
    
    private var paymentBadgeColor: Color {
        switch ticket.paymentStatus.lowercased() {
        case "paid", "captured": return .green
        case "partially_paid": return .orange
        case "refunded": return .purple
        default: return .red
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(ticket.ticketNumber)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                Text(currentStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                Text(paymentBadgeText)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(paymentBadgeColor.opacity(0.15))
                                    .foregroundColor(paymentBadgeColor)
                                    .cornerRadius(4)
                            }
                            Text("Created: \(ticket.createdAt)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { viewModel.selectedRepair = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let msg = noticeMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Divider()
                    
                    // Status Update Row matching Medusa Repair Plugin
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UPDATE TICKET STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Picker("", selection: $currentStatus) {
                                Group {
                                    Text("Dropoff").tag("pending_dropoff")
                                    Text("Received").tag("received")
                                    Text("Diagnosing").tag("diagnosing")
                                    Text("Awaiting Approval").tag("awaiting_approval")
                                    Text("Repairing").tag("repairing")
                                }
                                Group {
                                    Text("Ready for Pickup").tag("ready")
                                    Text("Completed").tag("completed")
                                    Text("Collected").tag("collected")
                                    Text("Cancelled").tag("cancelled")
                                    Text("Refunded").tag("refunded")
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 160)
                            
                            TextField("Status update note (optional)", text: $statusNote)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11))
                            
                            MinimalButton(title: "Save Status", isPrimary: true) {
                                viewModel.updateRepairStatus(ticketId: ticket.id, status: currentStatus, note: statusNote.isEmpty ? nil : statusNote)
                                noticeMessage = "Status updated to \(currentStatus)"
                                statusNote = ""
                            }
                        }
                    }
                    
                    Divider()
                }
                
                Group {
                    // Client & Tech Details
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CLIENT INFORMATION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            Text(ticket.clientDisplayName)
                                .font(.system(size: 12, weight: .bold))
                            if let ph = ticket.customerPhone, !ph.isEmpty { Text("Tel: \(ph)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                            if let em = ticket.customerEmail, !em.isEmpty { Text("Email: \(em)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WORKSHOP & TECH").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            Text("Tech: \(ticket.technicianName ?? viewModel.cashier.name)")
                                .font(.system(size: 11, weight: .semibold))
                            if let cond = ticket.condition, !cond.isEmpty { Text("Condition: \(cond)").font(.system(size: 10)).foregroundColor(.secondary) }
                            if let imei = ticket.imei, !imei.isEmpty { Text("IMEI: \(imei)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEVICE DETAILS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        Text(ticket.deviceName ?? "Generic Device")
                            .font(.system(size: 12, weight: .semibold))
                        HStack(spacing: 8) {
                            if let sn = ticket.serialNumber, !sn.isEmpty { Text("S/N: \(sn)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                            if let pc = ticket.passcode, !pc.isEmpty { Text("• Passcode: \(pc)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPORTED FAULT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        Text(ticket.issueDescription)
                            .font(.system(size: 11))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                    }
                    
                    if let acc = ticket.accessories, !acc.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACCESSORIES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            Text(acc).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                
                Group {
                    // Financials
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimate: KES \(String(format: "%.2f", ticket.totalEstimate))").font(.system(size: 11))
                            Text("Deposit: KES \(String(format: "%.2f", ticket.depositAmount))").font(.system(size: 11)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Balance Due").font(.system(size: 10)).foregroundColor(.secondary)
                            Text(String(format: "KES %.2f", ticket.balanceDue))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(ticket.balanceDue > 0 ? .orange : .green)
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(6)
                    
                    // Add Progress Note Row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADD PROGRESS NOTE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            TextField("Enter workshop note or diagnostic finding...", text: $newNoteContent)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11))
                            Toggle("Internal", isOn: $isInternalNote)
                                .font(.system(size: 10))
                            MinimalButton(title: "Add Note", isPrimary: false) {
                                let clean = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !clean.isEmpty else { return }
                                viewModel.addRepairNote(ticketId: ticket.id, content: clean, isInternal: isInternalNote)
                                newNoteContent = ""
                                noticeMessage = "Note logged successfully."
                            }
                        }
                    }
                    
                    // Notes & Updates Log
                    if !ticket.notes.isEmpty || !ticket.updates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES & STATUS HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            VStack(spacing: 4) {
                                ForEach(ticket.updates) { upd in
                                    HStack {
                                        Text("Status -> \(upd.status.capitalized)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                        if let n = upd.note, !n.isEmpty {
                                            Text("(\(n))").font(.system(size: 10)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(upd.createdAt).font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
                                    }
                                    .padding(4)
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(4)
                                }
                                ForEach(ticket.notes) { note in
                                    HStack {
                                        Text(note.content).font(.system(size: 10)).foregroundColor(.primary)
                                        Spacer()
                                        if note.isInternal {
                                            Text("INTERNAL")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(3)
                                        }
                                    }
                                    .padding(4)
                                    .background(Color.gray.opacity(0.06))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        MinimalButton(title: "Close") {
                            viewModel.selectedRepair = nil
                        }
                        Spacer()
                        if ticket.balanceDue > 0 {
                            Button(action: {
                                viewModel.openRepairStkModal(ticket: ticket)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                    Text("Push M-Pesa STK (KES \(String(format: "%.2f", ticket.balanceDue)))")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.0, green: 0.64, blue: 0.27))
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button(action: {}) {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Push M-Pesa STK (Balance: KES 0.00 - Paid)")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(true)
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 480, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Staff Authentication View (Medusa Credentials & Staff Presets - Zero PIN)

public struct StaffLoginView: View {
    @ObservedObject public var viewModel: POSViewModel
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var errorMessage: String? = nil
    @State private var isAuthenticating: Bool = false
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Branding Header
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    Text("Urban Device Care POS")
                        .font(.system(size: 22, weight: .bold))
                }
                Text("Enter Medusa Admin credentials to start your till session")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Medusa Credentials Login Form
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medusa Admin Email")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("admin@urbandevicecare.co.uk", text: $emailInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                        .frame(width: 300)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    SecureField("••••••••", text: $passwordInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                        .frame(width: 300)
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
                        Text("Sign In to Medusa Admin")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 300)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAuthenticating)
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
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

// MARK: - M-Pesa STK Push Express Checkout Sheet

public struct MpesaStkSheet: View {
    @ObservedObject public var viewModel: POSViewModel
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header with Safaricom branding
            HStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.64, blue: 0.27))
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIPA NA M-PESA ONLINE")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(red: 0.0, green: 0.64, blue: 0.27))
                    Text("Direct STK Push Prompt to Customer Phone")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    viewModel.cancelStkModal()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Amount Banner
            HStack {
                Text("Total Payable:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "KES %.2f", viewModel.stkAmount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(10)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(6)
            
            if viewModel.stkStep == "input" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer Safaricom M-Pesa Phone Number")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("2547XXXXXXXX", text: $viewModel.stkPhone)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                    
                    if let ref = viewModel.stkTicketId {
                        Text("Repair Ticket: \(ref)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    if !viewModel.stkNotice.isEmpty {
                        Text(viewModel.stkNotice)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 10) {
                        MinimalButton(title: "Cancel") {
                            viewModel.cancelStkModal()
                        }
                        
                        Button(action: {
                            viewModel.sendStkPush()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                Text("Send STK Push Prompt")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(viewModel.stkAmount <= 0 ? Color.gray : Color(red: 0.0, green: 0.64, blue: 0.27))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.stkAmount <= 0)
                    }
                    .padding(.top, 8)
                }
            } else if viewModel.stkStep == "sending" {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to Safaricom Daraja Gateway...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.stkStep == "polling" {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Awaiting PIN Entry on Phone")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("STK prompt sent to \(viewModel.stkPhone).\nPlease request the customer to enter their M-Pesa PIN.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(viewModel.stkCountdown)s remaining")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    if !viewModel.stkReference.isEmpty {
                        Text("Ref: \(viewModel.stkReference)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Button(action: {
                        viewModel.cancelStkModal()
                    }) {
                        Text("Cancel Prompt")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.stkStep == "success" {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    Text("Payment Received!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    Text(viewModel.stkNotice)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    MinimalButton(title: "Done", isPrimary: true) {
                        viewModel.cancelStkModal()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.stkStep == "failed" {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                    Text("STK Push Failed")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                    Text(viewModel.stkNotice)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        MinimalButton(title: "Retry", isPrimary: true) {
                            viewModel.stkStep = "input"
                        }
                        MinimalButton(title: "Close") {
                            viewModel.cancelStkModal()
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
}


