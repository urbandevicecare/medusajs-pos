# Medusa v2 POS Plugin (`medusajs-pos-plugin`)

Official Medusa v2 POS plugin providing POS cash drawer sessions, barcode scanning, POS checkout workflows, and quick-add customer registration for retail operations.

## Features

- **Dynamic Catalog & Customer Sync**: Real-time integration with MedusaJS Product and Customer modules.
- **Quick Customer Registration**: Auto-registers walk-in clients (`has_account: true`) with phone number and collision-proof RFC fallback emails (`walkin_{phone}@pos.urbandevicecare.co.uk`), zero-click auto-attaching them to current orders.
- **RegisterModule**: Cash drawer opening float, cash sales tracking, payouts, and Z-report closing reconciliation.
- **Fast Barcode Resolution (`GET /admin/pos/scan`)**: Resolves 1D SKU, EAN-13, UPC-A, Repair Tickets (`REP-*`), and serial numbers with inventory availability.
- **Atomic POS Checkout (`POST /admin/pos/checkout`)**: Converts draft orders, captures cash/terminal/split payments, generates tax receipts, and reconciles cash register shifts atomically.
- **Ecosystem Bridges**: Native inter-module integration with `Meduajs-repair-plugin`, `medusajs-documents-plugin`, and `paystack`.

## Installation

Add to your Medusa v2 project:
```bash
npm install medusajs-pos-plugin
```

In `medusa-config.js` or `medusa-config.ts`:
```typescript
module.exports = defineConfig({
  projectConfig: { ... },
  modules: [
    {
      resolve: "medusajs-pos-plugin/modules/register",
    },
  ],
  plugins: [
    {
      resolve: "medusajs-pos-plugin",
      options: {
        enableRepairBridge: true,
        enableDocumentsBridge: true,
        enablePaystackBridge: true,
      },
    },
  ],
});
```

## API Endpoints

- `GET /admin/pos/scan?code=<barcode>`: Instant variant & repair ticket lookup.
- `GET /admin/customers?q=<query>`: Live customer search by name, phone, or company.
- `POST /admin/customers`: Quick-add customer with `has_account: true` and auto-generated fallback email.
- `POST /admin/pos/checkout`: Complete transaction and deduct store stock.
- `GET /admin/pos/sessions`: List active register sessions and shifts.
- `POST /admin/pos/sessions`: Open or close register shift with float reconciliation.
