(function () {
  function ensureSwaggerStylesheet() {
    if (document.querySelector("link[data-cardano-ledger-wasi-swagger]")) {
      return;
    }

    var stylesheet = document.createElement("link");
    stylesheet.rel = "stylesheet";
    stylesheet.href = "https://unpkg.com/swagger-ui-dist@5/swagger-ui.css";
    stylesheet.setAttribute("data-cardano-ledger-wasi-swagger", "true");
    document.head.appendChild(stylesheet);
  }

  function initSwaggerUi() {
    var target = document.getElementById("swagger-ui");
    if (!target || typeof SwaggerUIBundle === "undefined") {
      return;
    }

    ensureSwaggerStylesheet();

    SwaggerUIBundle({
      url: new URL(
        "../openapi/cardano-ledger-functional.openapi.json",
        window.location.href
      ).toString(),
      dom_id: "#swagger-ui",
      deepLinking: true,
      presets: [SwaggerUIBundle.presets.apis],
      layout: "BaseLayout"
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initSwaggerUi);
  } else {
    initSwaggerUi();
  }
})();
