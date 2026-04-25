(function () {
  var counter = 0;

  function renderMermaid() {
    if (!window.mermaid) {
      return;
    }

    window.mermaid.initialize({ startOnLoad: false });

    document.querySelectorAll(".mermaid").forEach(function (node) {
      if (node.dataset.processed === "true" || node.querySelector("svg")) {
        return;
      }

      var source = node.textContent.trim();
      if (!source) {
        return;
      }

      node.dataset.processed = "true";
      window.mermaid.render("mermaid-diagram-" + counter++, source).then(function (result) {
        node.innerHTML = result.svg;
        if (typeof result.bindFunctions === "function") {
          result.bindFunctions(node);
        }
      }).catch(function (error) {
        node.dataset.processed = "false";
        console.error("Mermaid render failed", error);
      });
    });
  }

  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(renderMermaid);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderMermaid);
  } else {
    renderMermaid();
  }
})();
