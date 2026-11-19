import { createDefine } from "fresh";
import { HttpTypes } from "@medusajs/types";

// This specifies the type of "ctx.state" which is used to share
// data among middlewares, layouts and routes.
export interface State {
  shared?: string;
  title?: string;
  description?: string;
  hideLayout?: boolean;
  isLoggedIn?: boolean;
  isRepairModuleInstalled?: boolean;
  customer?: HttpTypes.StoreCustomer;
  order?: HttpTypes.StoreOrder;
  orders?: HttpTypes.StoreOrder[];
  cart?: HttpTypes.StoreCart;
  categories?: any[];
  [key: string]: any;
}

export const define = createDefine<State>();

export const STORE_NAME = Deno.env.get("STORE_NAME") || "Urban Device Care";
export const STORE_DOMAIN = Deno.env.get("STORE_DOMAIN") || "urbandevicecare.co.uk";
export const LOGO_URL = Deno.env.get("LOGO_URL") || "/logo.svg";

export function formatProviderName(id: string): string {
  return id
    .replace(/^pp_/, "")
    .replace(/[_-]/g, " ")
    .split(" ")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}
