# MedusaJS POS Ecosystem (`medusajs-pos`)

A minimalist, ultra-high-performance Point-of-Sale (POS) ecosystem designed specifically for MedusaJS v2, the Medusa Repair Plugin (`Meduajs-repair-plugin`), Documents plugin (`medusajs-documents-plugin`), and Paystack plugin (`medusajs-paystack-plugin`).

Built with **100% native platform code (zero headless browser / zero WebView bloat)** to achieve the absolute smallest binary footprint and maximum operational speed.

---

## 📦 Release v2.3.0 Distribution Packages

Ready-to-use distribution packages are packaged in `dist/` and published to the GitHub Releases page:

| Package | Archive File | Platform / Target | Footprint |
| :--- | :--- | :--- | :--- |
| **Medusa v2 POS Plugin** | `medusajs-pos-plugin-v2.3.0.zip` | Medusa v2 Backend / Node.js | **87 KB** |
| **Fresh.js Web POS** | `medusajs-webpos-freshjs-v2.3.0.zip` | Deno / Fresh 2.x Storefront | **190 KB** |
| **macOS Native POS** | `UrbanDevicePOS-macOS-v2.3.0.zip` | macOS 12+ (x86_64 / Apple Silicon) | **2.0 MB** (1.2 MB binary) |
| **Android CS30 POS** | `UrbanDevicePOS-android-CS30-v2.3.0.zip` | Handheld Smart POS Model CS30 (Android 11) | **1.2 MB** (1.8 MB APK) |

### Key What's New in v2.3.0 (Full 4-Platform Parity):
1. **Automatic Price List Recalculation**:
   - Active price lists (`/admin/price-lists?status=active`), customer group tiers (VIP 10% Off, Wholesale 20% Off, Corporate 15% Off), customer `discount_rate` override, and auto-repricing on customer select/unlink/switch/item add.
   - Visual price badge: `🏷️ [PriceList] (was KES XXX)` in catalog and cart across Web, macOS, and Android.
2. **Live Item Search Suggestions & Infinite Scroll Catalog**:
   - Live item lookup with genuine stock and price suggestions as typing, with keyboard and touch selection.
   - Parts and services catalog with live stock resolution.
3. **Actual In-Stock Quantity Resolution**:
   - True stock calculated from variants, inventory items, and location levels; badges `• X in stock` (green) or `• 0 in stock (Out of stock)` (red).
   - Cart warning `(Exceeds stock!)` in bold red if cart quantity exceeds available stock. Zero fake fallback 10.
4. **Optional 16% VAT Interactive Toggle**:
   - Defaults to `false` (exempt). When off: VAT is `KES 0.00 (Exempt)` and total due equals subtotal. Reflected in thermal receipts and printed output.
5. **Repair Tickets Tabular Rows Layout**:
   - Tabular rows layout (not cards), columns: Ticket # & Date | Device & Issue | Client (`Apex Electronics (John Kamau)` / company name / customer name, never "Workshop Client") | Tech / Serial | Status | Payment | Balance Due | View button.
   - Removed add to cart / tender buttons from list rows.
6. **Repair Inspection Modal & STK Button**:
   - View button opens inspection modal with client, device, and fault details.
   - Footer features `Push M-Pesa STK` button, disabled if balance is 0 (`Push M-Pesa STK (Balance: KES 0.00 - Paid)`).
7. **M-Pesa STK Push Express Checkout**:
   - Interactive dialog/sheet with Safaricom M-Pesa green branding (`#00A344`), pre-filled customer phone number, 60s countdown timer, polling verification, and zero balance guard (disabled when balance <= 0).

---

## Architecture Overview

| Component | Technology | Footprint | Description |
| :--- | :--- | :--- | :--- |
| **macOS Desktop POS** | **100% Native Swift / SwiftUI / AppKit** | **480 KB** | Direct Mach-O binary. Inspired by MacVDMTool's high-density layout. Zero Electron/Tauri/WKWebView dependencies. |
| **Android Terminal POS** | **100% Native Kotlin / Java** | **1.8 MB** | Pure native Android app for CS30 smart POS & handheld ETRs. ProGuard/R8 minified. Zero Capacitor/Cordova/Chromium WebView. Direct CS30 device node & USB thermal printer drivers. Native CameraX barcode scanner. |
| **Web POS** | **Fresh.js (Deno)** | **Islands (0 KB base)** | Lightweight web POS on Deno runtime using islands architecture with Preact signals. Laser scanner wedge interceptor (< 35ms burst detection). |
| **Medusa v2 Backend POS Plugin** | **TypeScript (Medusa v2 Framework)** | **Lightweight Plugin** | `RegisterModule` (drawer sessions, cash movements, reconciliation), workflows (`posCheckoutWorkflow`, `quickCustomerWorkflow`), canonical REST endpoints (`/admin/customers`, `/admin/pos/*`), and deep integrations with Repair, Documents, and Paystack. |

---

## 1. macOS Native App (`macos/`)
- **Native Implementation**: 100% Pure Swift & SwiftUI using `NSApplication` and custom `POSHostingView` / `POSWindow` to guarantee mouse clicks and keyboard events are never intercepted by window background dragging.
- **Compiled Mach-O Binary**: **480 KB** (stripped symbols, `-O` optimization).
- **Features**:
  - Live cash register calculations (16% VAT, subtotal, change due).
  - Quick tender cash buttons (KES 500, 1000, 2000, 5000, and Exact).
  - Fast cashier PIN switch handover (Nelly K., Dan M., Alex T.).
  - 1D linear barcode gun wedge interceptor and SKU resolver.
  - Native 58mm ESC/POS thermal receipt byte generation (`NativeThermalPrinter`).
  - Dynamic customer search and Quick Customer modal sheet with instant auto-selection.
- **Tests & Build**:
  ```bash
  # Run native Swift unit & integration test suite (10 test suites)
  npm run test:mac
  # or: bash macos/test.sh

  # Build optimized macOS .app bundle
  npm run build:mac
  # or: bash macos/build.sh
  ```
  The ready-to-run macOS app is output at `macos/UrbanDevicePOS.app` and mirrored to the root `UrbanDevicePOS.app`.

---

## 2. Android CS30 Native Smart POS App (`android/`)
- **Native Implementation**: 100% Pure Android Kotlin/Java (no Capacitor, no Cordova, no Chromium/WebKit).
- **Compiled Release APK**: **1.8 MB** using R8/ProGuard shrinking (`minifyEnabled true`, `shrinkResources true`).
- **Hardware Integrations for CS30 Android 11 Smart POS**:
  - **Thermal Printer Driver**: Direct Linux character device nodes (`/dev/ttyMT0`, `/dev/ttyMT1`, `/dev/ttyS0`, `/dev/ttyS1`, `/dev/usb/lp0`, `/dev/printer`) and USB Host Printer Class (Class 7).
  - **ESC/POS 58mm Engine**: Formatted 32-column receipts featuring Code 128 barcode of order/ticket number, cashier identity, itemized charges, and 2D QR tracking/Paystack code.
  - **Hardware Scanner Broadcast Receiver**: `CS30BarcodeReceiver` intercepts hardware broadcast intents from CS30 / Sunmi / Newland / Zebra scan engines.
  - **Native CameraX Barcode Scanner**: Real-time viewfinder scanning with ZXing core decoding.
  - **Hardware Wedge Interceptor**: Intercepts USB/Bluetooth scanner gun bursts (< 45ms inter-character delay).
  - **Quick Customer Registration**: Counter dialog with zero-click auto-selection for walk-in clients.
- **Tests & Build**:
  ```bash
  # Run native Android JUnit tests
  npm run test:android
  # or: cd android && ./gradlew test

  # Build optimized release APK
  npm run build:android
  # or: bash android/build_native_apk.sh
  ```
  The ready-to-install Android APK is output at `android/UrbanDevicePOS.apk` and mirrored to the root `UrbanDevicePOS.apk`.

---

## 3. Web POS (`web/`) - Fresh.js (Deno)
- **Native Implementation**: Full-stack web application built on Fresh.js 2.x (Deno) with Preact, Preact Signals, and Tailwind CSS v4.
- **Storefront Slotting Integration (`urbandevicecare/medusa-freshjs-storefront`)**:
  - **Clean Standalone Route Module**: Lives under `routes/pos/` with `routes/pos/_middleware.ts` setting `ctx.state.hideLayout = true`, allowing `routes/_app.tsx` in `medusa-freshjs-storefront` to automatically hide public storefront navigation and footer.
  - **Fresh Island**: `islands/PosTerminal.tsx` with zero hydration overhead and modern `lucide-preact` icons.
  - **Medusa v2 Client Integration**: Fully aligned with storefront `lib/sdk.ts` using `@medusajs/js-sdk@2.21.0` for dynamic live catalog and customer queries with graceful offline fallback.
  - **Tailwind CSS v4 & Styling**: Matches storefront design tokens, dark theme counter interface, and fast cashier workflow.
  - **Seamless Slotting to Storefront**: To slot into `urbandevicecare/medusa-freshjs-storefront`, simply copy:
    ```bash
    cp -r web/routes/pos <storefront>/routes/
    cp -r web/routes/api/pos <storefront>/routes/api/
    cp web/islands/PosTerminal.tsx <storefront>/islands/
    cp -r web/services <storefront>/
    ```
- **Features**:
  - Interactive island `islands/PosTerminal.tsx` with live barcode scanning.
  - Hardware laser gun wedge interceptor (< 45ms inter-key delay).
  - Direct 58mm ESC/POS binary receipt download and HTML printable receipt.
  - Quick tender pad, change calculator, and 4-digit PIN handover modal.
  - Quick-add customer dialog with auto-population and zero-click selection.
  - Quick return link to storefront (`href="/"` with `f-client-nav={false}`).
- **Endpoints**:
  - Standard storefront path: `/api/pos/customers`, `/api/pos/scan`, `/api/pos/checkout`, `/api/pos/receipt`, `/api/pos/auth`
  - Canonical aliases: `/api/customers`, `/api/scan`, `/api/checkout`, `/api/receipt`, `/api/auth`
- **Tests & Execution**:
  ```bash
  # Run Deno automated tests (19 tests)
  npm run test:web
  # or: cd web && deno test -A tests/

  # Run Web POS development server
  npm run dev:web
  # or: cd web && deno task dev
  ```

---

## 4. Medusa Backend POS Plugin (`plugin/`)
- **Medusa v2 Framework Module**:
  - `RegisterModule`:
    - Entities: `RegisterSession`, `CashTransaction`, `POSTerminal`.
    - Service: `RegisterModuleService` manages drawer sessions (open, close, cash drop, cash in, refund) and automatic cash reconciliation (`closing - expected`).
  - Workflows:
    - `posCheckoutWorkflow`: Handles order creation with full cashier auditing (`cashier_id`, `cashier_name`, `terminal_channel`), inventory deductions, cash drawer logging, and downstream integrations.
    - `quickCustomerWorkflow`: Creates registered customer profile (`has_account: true`) with collision-safe unique fallback email if none provided.
    - `openRegisterSessionWorkflow`: Initializes session with opening float.
    - `closeRegisterSessionWorkflow`: Closes session and audits drawer cash difference.
    - `scanBarcodeWorkflow`: Resolves parts, repair tickets, and device serials.
  - Canonical API Endpoints:
    - `GET /admin/customers?q=...` & `POST /admin/customers`
    - `GET /admin/pos/customers` & `POST /admin/pos/customers`
    - `GET /admin/pos/scan`
    - `POST /admin/pos/checkout`
    - `GET/POST /admin/pos/sessions`
  - Integrations:
    - **Repair Plugin (`Meduajs-repair-plugin`)**: Resolves tickets (`REP-10023`), links tickets to POS orders, and marks repair tickets as `paid`.
    - **Documents Plugin (`medusajs-documents-plugin`)**: Generates legal fiscal invoice documents and QR payload verification.
    - **Paystack Plugin (`medusajs-paystack-plugin`)**: Generates dynamic Paystack QR code and handles electronic mobile payments.
- **Tests & Build**:
  ```bash
  # Run automated plugin test suite (13 tests)
  npm run test:plugin
  # or: cd plugin && npx tsx --test tests/**/*.test.ts

  # Build plugin TypeScript distribution
  npm run build:plugin
  ```

---

## Running All Test Suites
Run the entire test suite across all 4 platforms with a single command:
```bash
npm run test:all
```
This executes:
1. Native Swift macOS test suite (10 test suites)
2. Native Android JUnit test suite (4 unit test classes)
3. Fresh.js Deno test suite (19 tests)
4. Medusa Backend POS Plugin test suite (13 tests)
All 46+ tests pass with 0 failures across all platforms.
