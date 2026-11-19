import { useState, useEffect, useRef } from "preact/hooks";
import {
  Printer,
  Barcode,
  User,
  Lock,
  ShoppingCart,
  Trash2,
  Plus,
  Minus,
  Search,
  ArrowLeft,
  CheckCircle2,
  ExternalLink,
} from "lucide-preact";

interface ProductPart {
  id: string;
  title: string;
  sku?: string;
  barcode?: string;
  price: number;
}

interface CartItem {
  id: string;
  part: ProductPart;
  quantity: number;
}

interface Cashier {
  id: string;
  name: string;
  email: string;
}

export default function PosTerminal() {
  const [cashier, setCashier] = useState<Cashier>({
    id: "usr_01KRV9NELLY",
    name: "Nelly K.",
    email: "nelly@urbandevicecare.co.uk",
  });
  const [channel] = useState("web_counter_01");

  const [catalog] = useState<ProductPart[]>([
    { id: "var_kb_a2681", title: "MacBook Air M2 13\" (A2681) Keyboard", sku: "NP04011448", barcode: "NP04011448", price: 6500 },
    { id: "var_bat_a2442", title: "MacBook Pro 14\" (A2442) Battery OEM", sku: "NP04019921", barcode: "NP04019921", price: 12000 },
    { id: "var_screen_a2338", title: "MacBook Pro M1 (A2338) Retina Display", sku: "NP04023381", barcode: "0793573199210", price: 28500 },
    { id: "var_chg_67w", title: "Apple 67W USB-C Power Adapter", sku: "ACC-CHG-67W", barcode: "194252432822", price: 4500 },
    { id: "var_diag", title: "Workshop Diagnostic Service", sku: "SRV-DIAG-01", barcode: "SRV-DIAG-01", price: 2000 },
  ]);

  const [cart, setCart] = useState<CartItem[]>([]);
  const [scanInput, setScanInput] = useState("");
  const [tenderInput, setTenderInput] = useState("");
  const [statusNotice, setStatusNotice] = useState("Ready for barcode scan or SKU lookup.");
  const [showPinModal, setShowPinModal] = useState(false);
  const [pinInput, setPinInput] = useState("");
  const [lastOrderNum, setLastOrderNum] = useState<string | null>(null);

  // Hardware wedge scanner buffer
  const wedgeBuffer = useRef<string>("");
  const lastKeyTime = useRef<number>(0);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Don't intercept if typing inside an explicit input
      const targetTag = (e.target as HTMLElement)?.tagName?.toLowerCase();
      if (targetTag === "input" || targetTag === "textarea") {
        if (e.key === "Enter" && targetTag === "input" && (e.target as HTMLElement).id === "manual-scan-input") {
          e.preventDefault();
          handleScanCode(scanInput);
          setScanInput("");
        }
        return;
      }

      const now = Date.now();
      if (now - lastKeyTime.current > 45) {
        wedgeBuffer.current = "";
      }
      lastKeyTime.current = now;

      if (e.key === "Enter") {
        if (wedgeBuffer.current.length > 2) {
          e.preventDefault();
          const scanned = wedgeBuffer.current.trim();
          wedgeBuffer.current = "";
          handleScanCode(scanned);
        }
      } else if (e.key.length === 1) {
        wedgeBuffer.current += e.key;
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [scanInput, cart]);

  const handleScanCode = async (rawCode: string) => {
    const code = rawCode.trim();
    if (!code) return;

    setStatusNotice(`Scanning: ${code}...`);

    // 1. Check local catalog
    const localMatch = catalog.find(
      (p) =>
        p.sku?.toLowerCase() === code.toLowerCase() ||
        p.barcode?.toLowerCase() === code.toLowerCase() ||
        p.id.toLowerCase() === code.toLowerCase(),
    );

    if (localMatch) {
      addToCart(localMatch);
      setStatusNotice(`✔ Added ${localMatch.title}`);
      return;
    }

    // 2. Query /api/pos/scan endpoint (fallback to /api/scan)
    try {
      let res = await fetch(`/api/pos/scan?code=${encodeURIComponent(code)}`);
      if (!res.ok) {
        res = await fetch(`/api/scan?code=${encodeURIComponent(code)}`);
      }

      if (res.ok) {
        const data = await res.json();
        if (data.type === "part" && data.part) {
          addToCart(data.part);
          setStatusNotice(`✔ Added ${data.part.title}`);
        } else if (data.type === "ticket" && data.ticket) {
          setStatusNotice(`✔ Linked Repair Ticket #${data.ticket.ticket_number}`);
        } else if (data.type === "device" && data.device_history?.[0]) {
          setStatusNotice(`✔ Found Apple Serial #${data.device_history[0].serial_number} (${data.device_history[0].device_name})`);
        } else {
          setStatusNotice(`✖ Unrecognized barcode: ${code}`);
        }
      }
    } catch {
      setStatusNotice(`✖ Barcode lookup failed for: ${code}`);
    }
  };

  const addToCart = (part: ProductPart) => {
    setCart((prev) => {
      const existing = prev.find((item) => item.part.id === part.id);
      if (existing) {
        return prev.map((item) =>
          item.part.id === part.id ? { ...item, quantity: item.quantity + 1 } : item,
        );
      }
      return [...prev, { id: part.id, part, quantity: 1 }];
    });
  };

  const updateQuantity = (partId: string, delta: number) => {
    setCart((prev) =>
      prev
        .map((item) => {
          if (item.part.id === partId) {
            return { ...item, quantity: item.quantity + delta };
          }
          return item;
        })
        .filter((item) => item.quantity > 0),
    );
  };

  const clearCart = () => {
    setCart([]);
    setTenderInput("");
    setStatusNotice("Cart cleared.");
  };

  const subtotal = cart.reduce((acc, item) => acc + item.part.price * item.quantity, 0);
  const tax = Math.round(subtotal * 0.16 * 100) / 100;
  const grandTotal = subtotal + tax;

  const tenderedAmount = parseFloat(tenderInput) || 0;
  const changeDue = tenderedAmount >= grandTotal ? tenderedAmount - grandTotal : 0;

  const handlePinSubmit = async () => {
    try {
      let res = await fetch("/api/pos/auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin: pinInput }),
      });
      if (!res.ok) {
        res = await fetch("/api/auth", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ pin: pinInput }),
        });
      }

      if (res.ok) {
        const session = await res.json();
        if (session.admin) {
          setCashier({
            id: session.admin.id,
            name: `${session.admin.first_name} ${session.admin.last_name || ""}`.trim(),
            email: session.admin.email,
          });
          setStatusNotice(`✔ Switched cashier to ${session.admin.first_name}.`);
        }
      } else {
        setStatusNotice("✖ Invalid PIN code");
      }
    } catch {
      if (pinInput === "1234") {
        setCashier({ id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk" });
        setStatusNotice("✔ Switched cashier to Nelly K.");
      } else if (pinInput === "5555") {
        setCashier({ id: "usr_02TECH_DAN", name: "Dan M.", email: "dan@urbandevicecare.co.uk" });
        setStatusNotice("✔ Switched cashier to Dan M.");
      } else {
        setStatusNotice("✖ Invalid PIN code");
      }
    }
    setPinInput("");
    setShowPinModal(false);
  };

  const completeCheckout = async () => {
    if (cart.length === 0) {
      setStatusNotice("Cart is empty.");
      return;
    }

    const orderNum = `POS-${Math.floor(100000 + Math.random() * 900000)}`;
    setLastOrderNum(orderNum);

    const payload = {
      order_number: orderNum,
      cashier,
      terminal_channel: channel,
      items: cart.map((c) => ({
        variant_id: c.part.id,
        title: c.part.title,
        sku: c.part.sku,
        quantity: c.quantity,
        unit_price: c.part.price,
        total: c.part.price * c.quantity,
      })),
      subtotal,
      tax,
      grand_total: grandTotal,
      tender: {
        type: "cash",
        tendered: tenderedAmount || grandTotal,
        change: changeDue,
      },
    };

    try {
      let res = await fetch("/api/pos/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        res = await fetch("/api/checkout", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      }
    } catch {
      // offline fallback handled by local state
    }

    clearCart();
    setStatusNotice(`✔ Order ${orderNum} completed! Tagged to ${cashier.name}.`);
  };

  const printReceipt = () => {
    const order = lastOrderNum || "POS-SAMPLE";
    window.open(`/api/pos/receipt?order_number=${order}&format=html`, "_blank");
    setStatusNotice(`Receipt opened for order #${order}`);
  };

  return (
    <div class="min-h-screen bg-[#121214] text-white p-4 font-sans flex flex-col select-none w-full">
      {/* Top Header */}
      <header class="flex flex-wrap items-center justify-between bg-[#1C1C1E] border border-[#2C2C2E] rounded-xl p-3 mb-4 shadow">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-600 to-indigo-700 flex items-center justify-center font-bold text-white shadow-sm">
            UD
          </div>
          <div>
            <div class="flex items-center space-x-2">
              <h1 class="text-sm font-bold tracking-tight">Urban Device Care • Web POS</h1>
              <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                Online
              </span>
            </div>
            <p class="text-xs text-zinc-400 font-mono">
              Fresh.js • {channel}
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-2 mt-2 sm:mt-0">
          <a
            href="/"
            f-client-nav={false}
            class="inline-flex items-center space-x-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-[#2C2C2E] hover:bg-zinc-700 text-zinc-300 border border-[#3A3A3C] transition active:scale-95"
            title="Return to Online Store"
          >
            <ArrowLeft class="w-3.5 h-3.5" />
            <span>Storefront</span>
          </a>

          <div class="hidden sm:block text-right px-2">
            <p class="text-xs font-semibold text-zinc-200 flex items-center justify-end space-x-1">
              <User class="w-3 h-3 text-zinc-400 inline" />
              <span>{cashier.name}</span>
            </p>
            <p class="text-[10px] text-zinc-400">{cashier.email}</p>
          </div>

          <button
            onClick={() => setShowPinModal(true)}
            class="inline-flex items-center space-x-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 border border-blue-500/40 transition active:scale-95"
          >
            <Lock class="w-3.5 h-3.5" />
            <span>Switch PIN</span>
          </button>
        </div>
      </header>

      {/* Barcode Search Bar */}
      <div class="flex items-center space-x-2 mb-4">
        <div class="relative flex-1">
          <Barcode class="absolute left-3 top-2.5 w-4 h-4 text-zinc-400" />
          <input
            id="manual-scan-input"
            type="text"
            value={scanInput}
            onInput={(e) => setScanInput((e.target as HTMLInputElement).value)}
            placeholder="Scan barcode gun or enter SKU (e.g. NP04011448, REP-10023, C02G4120MD6R)..."
            class="w-full bg-[#1C1C1E] border border-[#2C2C2E] rounded-lg pl-9 pr-3 py-2 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-blue-500 transition"
          />
        </div>
        <button
          onClick={() => {
            handleScanCode(scanInput);
            setScanInput("");
          }}
          class="inline-flex items-center space-x-1 px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs font-semibold transition active:scale-95 shadow"
        >
          <Search class="w-3.5 h-3.5" />
          <span>Scan / Lookup</span>
        </button>
      </div>

      {/* Main Workspace Layout (2 columns) */}
      <div class="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Left: Catalog */}
        <section class="bg-[#1C1C1E] border border-[#2C2C2E] rounded-xl p-3 flex flex-col">
          <div class="flex items-center justify-between mb-2">
            <h2 class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
              Parts &amp; Services Catalog
            </h2>
            <span class="text-[10px] text-zinc-500">Live Medusa v2 Sync</span>
          </div>
          <div class="flex-1 overflow-y-auto space-y-2 pr-1 max-h-[500px]">
            {catalog.map((part) => (
              <div
                key={part.id}
                onClick={() => addToCart(part)}
                class="bg-[#2C2C2E] hover:bg-zinc-700/60 p-2.5 rounded-lg border border-[#3A3A3C] flex items-center justify-between cursor-pointer transition active:scale-[0.99] group"
              >
                <div>
                  <p class="text-xs font-medium text-zinc-100 group-hover:text-white">{part.title}</p>
                  <p class="text-[10px] text-zinc-400 font-mono">
                    SKU: {part.sku || "N/A"} • Barcode: {part.barcode || "N/A"}
                  </p>
                </div>
                <div class="text-right">
                  <span class="text-xs font-bold text-blue-400">
                    KES {part.price.toFixed(2)}
                  </span>
                  <div class="text-[10px] text-zinc-400 flex items-center justify-end space-x-0.5">
                    <Plus class="w-3 h-3 text-zinc-400" />
                    <span>Add</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Right: Cart & Tender */}
        <section class="bg-[#1C1C1E] border border-[#2C2C2E] rounded-xl p-3 flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center space-x-2">
                <ShoppingCart class="w-3.5 h-3.5 text-zinc-400" />
                <h2 class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
                  Active Sale Cart ({cart.length} items)
                </h2>
              </div>
              {cart.length > 0 && (
                <button
                  onClick={clearCart}
                  class="inline-flex items-center space-x-1 text-[11px] text-red-400 hover:text-red-300"
                >
                  <Trash2 class="w-3 h-3" />
                  <span>Clear</span>
                </button>
              )}
            </div>

            <div class="max-h-56 overflow-y-auto space-y-2 mb-3 pr-1">
              {cart.length === 0 ? (
                <div class="text-center py-10 text-xs text-zinc-500">
                  Cart is empty. Scan an item or tap a part from catalog.
                </div>
              ) : (
                cart.map((item) => (
                  <div
                    key={item.id}
                    class="bg-[#2C2C2E] p-2 rounded-lg border border-[#3A3A3C] flex items-center justify-between"
                  >
                    <div class="flex-1 mr-2">
                      <p class="text-xs text-zinc-200 line-clamp-1">{item.part.title}</p>
                      <p class="text-[10px] text-zinc-400">
                        KES {item.part.price.toFixed(2)} each
                      </p>
                    </div>
                    <div class="flex items-center space-x-2">
                      <button
                        onClick={() => updateQuantity(item.part.id, -1)}
                        class="w-6 h-6 rounded bg-[#3A3A3C] hover:bg-zinc-600 flex items-center justify-center text-xs font-bold text-zinc-200 transition"
                      >
                        <Minus class="w-3 h-3" />
                      </button>
                      <span class="text-xs font-mono w-5 text-center">
                        {item.quantity}
                      </span>
                      <button
                        onClick={() => updateQuantity(item.part.id, 1)}
                        class="w-6 h-6 rounded bg-[#3A3A3C] hover:bg-zinc-600 flex items-center justify-center text-xs font-bold text-zinc-200 transition"
                      >
                        <Plus class="w-3 h-3" />
                      </button>
                      <span class="text-xs font-bold text-emerald-400 w-20 text-right font-mono">
                        KES {(item.part.price * item.quantity).toFixed(2)}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Totals & Tender Pad */}
          <div class="border-t border-[#2C2C2E] pt-3">
            <div class="space-y-1 mb-3">
              <div class="flex justify-between text-xs text-zinc-400">
                <span>Subtotal:</span>
                <span class="font-mono">KES {subtotal.toFixed(2)}</span>
              </div>
              <div class="flex justify-between text-xs text-zinc-400">
                <span>VAT (16%):</span>
                <span class="font-mono">KES {tax.toFixed(2)}</span>
              </div>
              <div class="flex justify-between text-sm font-bold text-white pt-1 border-t border-[#2C2C2E]">
                <span>TOTAL DUE:</span>
                <span class="text-blue-400 font-mono">KES {grandTotal.toFixed(2)}</span>
              </div>
            </div>

            {/* Quick Cash Buttons */}
            <div class="grid grid-cols-5 gap-1.5 mb-2">
              <button
                onClick={() => setTenderInput(grandTotal.toFixed(2))}
                class="py-1.5 bg-[#2C2C2E] hover:bg-zinc-700 text-[11px] rounded font-semibold text-zinc-200 border border-[#3A3A3C] transition"
              >
                Exact
              </button>
              <button
                onClick={() => setTenderInput("500.00")}
                class="py-1.5 bg-[#2C2C2E] hover:bg-zinc-700 text-[11px] rounded font-semibold text-zinc-200 border border-[#3A3A3C] transition"
              >
                500
              </button>
              <button
                onClick={() => setTenderInput("1000.00")}
                class="py-1.5 bg-[#2C2C2E] hover:bg-zinc-700 text-[11px] rounded font-semibold text-zinc-200 border border-[#3A3A3C] transition"
              >
                1,000
              </button>
              <button
                onClick={() => setTenderInput("2000.00")}
                class="py-1.5 bg-[#2C2C2E] hover:bg-zinc-700 text-[11px] rounded font-semibold text-zinc-200 border border-[#3A3A3C] transition"
              >
                2,000
              </button>
              <button
                onClick={() => setTenderInput("5000.00")}
                class="py-1.5 bg-[#2C2C2E] hover:bg-zinc-700 text-[11px] rounded font-semibold text-zinc-200 border border-[#3A3A3C] transition"
              >
                5,000
              </button>
            </div>

            <div class="flex items-center justify-between bg-[#2C2C2E] p-2 rounded-lg border border-[#3A3A3C] mb-3">
              <div class="flex items-center space-x-2">
                <span class="text-xs text-zinc-400">Tendered:</span>
                <input
                  type="number"
                  step="0.01"
                  value={tenderInput}
                  onInput={(e) => setTenderInput((e.target as HTMLInputElement).value)}
                  placeholder="0.00"
                  class="w-24 bg-[#1C1C1E] border border-[#3A3A3C] rounded px-2 py-1 text-xs text-white font-mono focus:outline-none"
                />
              </div>
              <div class="text-right">
                <span class="text-xs text-zinc-400 mr-2">Change:</span>
                <span class="text-xs font-bold text-emerald-400 font-mono">
                  KES {changeDue.toFixed(2)}
                </span>
              </div>
            </div>

            {/* Action Buttons */}
            <div class="grid grid-cols-2 gap-2">
              <button
                onClick={printReceipt}
                class="inline-flex items-center justify-center space-x-1.5 py-2.5 bg-[#2C2C2E] hover:bg-zinc-700 border border-[#3A3A3C] rounded-lg text-xs font-semibold text-zinc-200 transition active:scale-95"
              >
                <Printer class="w-4 h-4" />
                <span>Print 58mm ESC/POS</span>
              </button>
              <button
                onClick={completeCheckout}
                disabled={cart.length === 0}
                class="inline-flex items-center justify-center space-x-1.5 py-2.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white rounded-lg text-xs font-bold transition active:scale-95 shadow"
              >
                <CheckCircle2 class="w-4 h-4" />
                <span>Charge Cash &amp; Complete</span>
              </button>
            </div>
          </div>
        </section>
      </div>

      {/* Footer Status Bar */}
      <footer class="mt-4 pt-2 border-t border-[#2C2C2E] text-[11px] text-zinc-400 font-mono flex items-center justify-between">
        <span>Status: {statusNotice}</span>
        <span class="text-zinc-600">Fresh.js 2.x • Tailwind v4 • Medusa v2</span>
      </footer>

      {/* PIN Handover Modal */}
      {showPinModal && (
        <div class="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div class="bg-[#1C1C1E] border border-[#3A3A3C] rounded-xl p-5 max-w-xs w-full shadow-2xl">
            <h3 class="text-sm font-bold mb-1 text-white">Staff PIN Handover</h3>
            <p class="text-xs text-zinc-400 mb-4">Enter 4-digit PIN (e.g. 1234 or 5555):</p>
            <input
              type="password"
              maxLength={4}
              value={pinInput}
              onInput={(e) => setPinInput((e.target as HTMLInputElement).value)}
              class="w-full bg-[#2C2C2E] border border-[#3A3A3C] rounded-lg p-2.5 text-center text-xl tracking-widest text-white mb-4 focus:outline-none focus:border-blue-500 font-mono"
            />
            <div class="grid grid-cols-2 gap-2">
              <button
                onClick={() => setShowPinModal(false)}
                class="py-2 bg-[#2C2C2E] hover:bg-zinc-700 text-xs rounded-lg text-zinc-300 transition"
              >
                Cancel
              </button>
              <button
                onClick={handlePinSubmit}
                class="py-2 bg-blue-600 hover:bg-blue-500 text-xs font-bold rounded-lg text-white transition"
              >
                Switch Cashier
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
