export interface DocumentReceiptRequest {
  order_id: string;
  order_number: string;
  store_name: string;
  cashier_name: string;
  terminal_id: string;
  items: Array<{
    title: string;
    quantity: number;
    unit_price: number;
    total: number;
    tax: number;
  }>;
  subtotal: number;
  tax: number;
  grand_total: number;
  currency: string;
}

export class DocumentsPluginIntegration {
  public async generateFiscalReceiptDocument(data: DocumentReceiptRequest): Promise<{
    document_id: string;
    document_url: string;
    fiscal_invoice_number: string;
    qr_code_payload: string;
  }> {
    const fiscalNumber = `INV-${Date.now().toString().slice(-6)}`;
    const documentId = `doc_${Date.now()}`;
    const qrPayload = `https://documents.urbandevicecare.co.uk/invoice/${fiscalNumber}`;

    return {
      document_id: documentId,
      document_url: `https://api.urbandevicecare.co.uk/admin/documents/${documentId}/pdf`,
      fiscal_invoice_number: fiscalNumber,
      qr_code_payload: qrPayload,
    };
  }
}
