#!/usr/bin/env -S deno run -A --watch=routes/,islands/

import "preact/jsx-runtime";
import "preact/jsx-dev-runtime";
import { Builder } from "fresh/dev";

const builder = new Builder();

if (Deno.args.includes("build")) {
  await builder.build();
} else {
  await builder.listen(() => import("./main.ts"));
}
