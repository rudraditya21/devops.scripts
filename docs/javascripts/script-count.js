(() => {
  const BADGE_ID = "script-total-badge";

  function normalizePath(href) {
    try {
      const url = new URL(href, window.location.href);
      let path = url.pathname || "";

      if (!path) {
        return "";
      }

      path = path.replace(/\/{2,}/g, "/");
      if (path.startsWith("scripts/")) {
        path = `/${path}`;
      }

      return path.replace(/\/+$/, "");
    } catch {
      return "";
    }
  }

  function getScriptDocCount() {
    const paths = new Set();

    document.querySelectorAll("a[href]").forEach((anchor) => {
      const href = anchor.getAttribute("href");
      if (!href || href.startsWith("#")) {
        return;
      }

      const path = normalizePath(href);
      if (!path || !path.includes("/scripts/")) {
        return;
      }

      paths.add(path);
    });

    return paths.size;
  }

  function renderBadge() {
    const container = document.querySelector("header .ml-auto");
    if (!container) {
      return;
    }

    const count = getScriptDocCount();
    if (count <= 0) {
      return;
    }

    let badge = document.getElementById(BADGE_ID);
    if (!badge) {
      badge = document.createElement("span");
      badge.id = BADGE_ID;
      badge.className = "script-total-badge";
      container.prepend(badge);
    }

    badge.textContent = `Total Scripts: ${count}`;
    badge.setAttribute("aria-label", `Total scripts ${count}`);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderBadge, { once: true });
  } else {
    renderBadge();
  }

  window.addEventListener("load", renderBadge);
})();
