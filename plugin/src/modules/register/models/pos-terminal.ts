export interface POSTerminal {
  id: string;
  name: string;
  location: string;
  default_channel: string;
  currency_code: string;
  default_tax_rate: number;
  is_active: boolean;
}
