const pinStaffStore: Record<string, { id: string; name: string; email: string; role: string }> = {
  "1234": { id: "usr_01KRV9NELLY", name: "Nelly K.", email: "nelly@urbandevicecare.co.uk", role: "admin" },
  "5555": { id: "usr_02TECH_DAN", name: "Dan M.", email: "dan@urbandevicecare.co.uk", role: "technician" },
  "9876": { id: "usr_03TECH_JAMES", name: "James O.", email: "tech@urbandevicecare.co.uk", role: "technician" },
};

export async function POST(req: any, res: any) {
  const pin = req.body?.pin;
  if (!pin || !pinStaffStore[pin]) {
    return res.status(401).json({ error: "Invalid PIN code" });
  }
  const staff = pinStaffStore[pin];
  return res.json({
    success: true,
    cashier: staff,
    token: `jwt_pin_${staff.id}`,
  });
}
