// Intercept external http(s) navigations inside Chromium/Chrome --app / PWA
// windows and hand them to LinkSheet via the background native host.
// Filename is versioned so --load-extension picks up updates.

(function () {
  "use strict";

  let isApp = false;
  try {
    if (window.matchMedia("(display-mode: standalone)").matches) isApp = true;
    if (window.matchMedia("(display-mode: minimal-ui)").matches) isApp = true;
    if (window.navigator.standalone === true) isApp = true;
  } catch (_) {
    /* ignore */
  }

  try {
    chrome.runtime.sendMessage({ type: "isAppWindow" }, (response) => {
      if (chrome.runtime.lastError) return;
      if (response && response.isApp) isApp = true;
    });
  } catch (_) {
    /* ignore */
  }

  const pageHost = location.hostname.toLowerCase();

  function resolveHttpUrl(href) {
    try {
      const u = new URL(String(href), location.href);
      if (u.protocol !== "http:" && u.protocol !== "https:") return null;
      return u.href;
    } catch (_) {
      return null;
    }
  }

  function isCrossHost(href) {
    try {
      const u = new URL(String(href), location.href);
      return u.hostname.toLowerCase() !== pageHost;
    } catch (_) {
      return false;
    }
  }

  function findAnchor(ev) {
    const path = typeof ev.composedPath === "function" ? ev.composedPath() : [];
    for (const el of path) {
      if (el && el.tagName === "A" && el.href) return el;
    }
    const t = ev.target;
    if (t && typeof t.closest === "function") return t.closest("a[href]");
    return null;
  }

  function handoff(url) {
    try {
      chrome.runtime.sendMessage({ type: "open", url });
    } catch (_) {
      /* extension context gone */
    }
  }

  function onClick(ev) {
    if (!isApp) return;
    if (ev.defaultPrevented) return;
    if (ev.button !== 0 && ev.button !== 1) return;
    const anchor = findAnchor(ev);
    if (!anchor) return;

    const url = resolveHttpUrl(anchor.href);
    if (!url || !isCrossHost(url)) return;

    ev.preventDefault();
    ev.stopImmediatePropagation();
    handoff(url);
  }

  document.addEventListener("click", onClick, true);
  document.addEventListener("auxclick", onClick, true);

  const originalOpen = window.open;
  window.open = function (url, ...rest) {
    if (isApp && url) {
      const resolved = resolveHttpUrl(url);
      if (resolved && isCrossHost(resolved)) {
        handoff(resolved);
        return null;
      }
    }
    return originalOpen.apply(this, [url, ...rest]);
  };
})();
