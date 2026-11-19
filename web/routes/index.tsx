import { define } from "../lib/utils.ts";

export const handler = define.handlers({
  GET(ctx) {
    const url = new URL(ctx.req.url);
    return Response.redirect(new URL("/pos", url.origin).href, 307);
  },
});
