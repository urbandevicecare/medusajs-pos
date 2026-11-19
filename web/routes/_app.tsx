import { define } from "../lib/utils.ts";
import { Partial } from "fresh/runtime";
import { STORE_NAME } from "../lib/utils.ts";

export default define.page(function App({ Component, state }) {
  const title = (state.title as string) ||
    `${STORE_NAME} • Web POS Terminal`;
  const description = (state.description as string) ||
    "Workshop and Counter POS Terminal for Urban Device Care";

  return (
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="view-transition" content="same-origin" />
        <title>{title}</title>
        <meta name="description" content={description} />
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body
        f-client-nav
        f-view-transition
        class={`min-h-screen bg-[#121214] font-sans text-white flex flex-col ${
          state?.hideLayout ? "print:bg-white" : ""
        }`}
      >
        <Partial name="main">
          <Component />
        </Partial>
      </body>
    </html>
  );
});
