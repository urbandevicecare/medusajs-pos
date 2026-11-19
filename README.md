# MedusaJS POS Ecosystem (`medusajs-pos`)

A minimalist, ultra-high-performance Point-of-Sale (POS) ecosystem designed specifically for MedusaJS v2, the Medusa Repair Plugin (`Meduajs-repair-plugin`), Documents plugin (`medusajs-documents-plugin`), and Paystack plugin (`medusajs-paystack-plugin`).

Built with **100% native platform code (zero headless browser / zero WebView bloat)** to achieve the absolute smallest binary footprint and maximum operational speed.

---

## Architecture Overview

| Component | Technology | Footprint | Description |
| :--- | :--- | :--- | :--- |
| **macOS Desktop POS** | **100% Native Swift / SwiftUI / AppKit** | **342 KB** | Direct Mach-O binary. Inspired by MacVDMTool's high-density layout. Zero Electron/Tauri/WKWebView dependencies. |
| **Android Terminal POS** | **100% Native Kotlin / Java** | **1.8 MB** | Pure native Android app for CS30 smart POS & handheld ETRs. ProGuard/R8 minified. Zero Capacitor/Cordova/Chromium WebView. Direct CS30 device node & USB thermal printer drivers. Native CameraX barcode scanner. |
| **Web POS** | **Fresh.js (Deno)** | **Islands (0 KB base)** | Lightweight web POS on Deno runtime using islands architecture with Preact signals. Laser scanner wedge interceptor (< 35ms burst detection). |
| **Medusa v2 Backend POS Plugin** | **TypeScript (Medusa v2 Framework)** | **Lightweight Plugin** | `RegisterModule` (drawer sessions, cash movements, reconciliation), workflows (`posCheckoutWorkflow`), custom API endpoints (`/admin/pos/*`), and deep integrations with Repair, Documents, and Paystack. |

---

## 1. macOS Native App (`macos/`)
- **Native Implementation**: 100% Pure Swift & SwiftUI using `NSApplication` and custom `POSHostingView` / `POSWindow` to guarantee mouse clicks and keyboard events are never intercepted by window background dragging.
- **Compiled Mach-O Binary**: **342 KB** (stripped symbols, `-O` optimization).
- **Features**:
  - Live cash register calculations (16% VAT, subtotal, change due).
  - Quick tender cash buttons (KES 500, 1000, 2000, 5000, and Exact).
  - Fast cashier PIN switch handover (Nelly K., Dan M., Alex T.).
  - 1D linear barcode gun wedge interceptor and SKU resolver.
  - Native 58mm ESC/POS thermal receipt byte generation (`NativeThermalPrinter`).
- **Tests & Build**:
  ```bash
  # Run native Swift unit & integration test suite (8 test suites)
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
- **Compiled Release APK**: **1.8 MB** (down from 4.1MB Capacitor wrapper) using R8/ProGuard shrinking (`minifyEnabled true`, `shrinkResources true`).
- **Hardware Integrations for CS30 Android 11 Smart POS**:
  - **Thermal Printer Driver**: Direct Linux character device nodes (`/dev/ttyMT0`, `/dev/ttyMT1`, `/dev/ttyS0`, `/dev/ttyS1`, `/dev/usb/lp0`, `/dev/printer`) and USB Host Printer Class (Class 7).
  - **ESC/POS 58mm Engine**: Formatted 32-column receipts featuring Code 128 barcode of order/ticket number, cashier identity, itemized charges, and 2D QR tracking/Paystack code.
  - **Hardware Scanner Broadcast Receiver**: `CS30BarcodeReceiver` intercepts hardware broadcast intents from CS30 / Sunmi / Newland / Zebra SE4500 scan engines.
  - **Native CameraX Barcode Scanner**: `CameraScannerActivity` provides real-time viewfinder scanning with ZXing core decoding.
  - **Hardware Wedge Interceptor**: Intercepts USB/Bluetooth scanner gun bursts (< 45ms inter-character delay).
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
  - **Medusa v2 Client Integration**: Fully aligned with storefront `lib/sdk.ts` using `@medusajs/js-sdk@2.21.0` for live catalog lookups with graceful offline fallback.
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
  - Quick return link to storefront (`href="/"` with `f-client-nav={false}`).
- **Endpoints**:
  - Standard storefront path: `/api/pos/scan`, `/api/pos/checkout`, `/api/pos/receipt`, `/api/pos/auth`
  - Backward-compatible legacy aliases: `/api/scan`, `/api/checkout`, `/api/receipt`, `/api/auth`
- **Tests & Execution**:
  ```bash
  # Run Deno automated tests (15 test suites)
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
    - `openRegisterSessionWorkflow`: Initializes session with opening float.
    - `closeRegisterSessionWorkflow`: Closes session and audits drawer cash difference.
    - `scanBarcodeWorkflow`: Resolves parts, repair tickets, and device serials.
  - Integrations:
    - **Repair Plugin (`Meduajs-repair-plugin`)**: Resolves tickets (`REP-10023`), links tickets to POS orders, and marks repair tickets as `paid`.
    - **Documents Plugin (`medusajs-documents-plugin`)**: Generates legal fiscal invoice documents and QR payload verification.
    - **Paystack Plugin (`medusajs-paystack-plugin`)**: Generates dynamic Paystack QR code and handles electronic mobile payments.
- **Tests & Build**:
  ```bash
  # Run automated plugin test suite
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
1. Native Swift macOS test suite (8 test suites)
2. Native Android JUnit test suite (4 unit test classes)
3. Fresh.js Deno test suite (7 tests)
4. Medusa Backend POS Plugin test suite (6 tests)
All 25 tests pass in total across all platforms.
