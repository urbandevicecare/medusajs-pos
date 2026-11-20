import { App, staticFiles } from "fresh";
import type { State } from "./lib/utils.ts";

export const app = new App<State>();

app.use(staticFiles());

// Include filesystem-based routes
app.fsRoutes();

if (import.meta.main) {
  const port = parseInt(Deno.env.get("PORT") || "8000");
  console.log(`🚀 Fresh.js Web POS server running at http://localhost:${port}`);
  Deno.serve({ port }, app.handler());
}
