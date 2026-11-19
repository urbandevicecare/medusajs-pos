export async function GET(req: any, res: any) {
  const orderId = req.params?.id || req.query?.order_id || "POS-100234";

  const receipt = {
    order_id: orderId,
    store_name: "Urban Device Care",
    cashier_name: "Nelly K.",
    terminal_id: "cs30_terminal_01",
    date: new Date().toISOString(),
    escpos_download_url: `/admin/pos/receipt/${orderId}/escpos`,
    tracking_url: `https://track.urbandevicecare.co.uk/order/${orderId}`,
  };

  res.json(receipt);
}
