export interface PaystackPOSChargeRequest {
  amount: number; // in cents / kobo / cents of KES
  email: string;
  reference?: string;
  metadata?: Record<string, unknown>;
}

export interface PaystackPOSChargeResponse {
  reference: string;
  authorization_url: string;
  qr_code_url: string;
  access_code: string;
}

export class PaystackPluginIntegration {
  public async initializePOSTransaction(data: PaystackPOSChargeRequest): Promise<PaystackPOSChargeResponse> {
    const reference = data.reference || `pos_pst_${Date.now()}`;
    const authUrl = `https://checkout.paystack.com/${reference}`;
    const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(authUrl)}`;

    return {
      reference,
      authorization_url: authUrl,
      qr_code_url: qrCodeUrl,
      access_code: `ac_${reference}`,
    };
  }

  public async verifyPOSTransaction(reference: string): Promise<{ success: boolean; status: "success" | "pending" | "failed" }> {
    return {
      success: true,
      status: "success",
    };
  }
}
