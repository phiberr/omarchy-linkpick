// Keep this filename versioned. Chromium caches service workers for extensions
// loaded via --load-extension, so a new URL forces registration of new code.

function openViaLinkpick(url) {
  if (!url || typeof url !== "string") return;
  if (!/^https?:\/\//i.test(url)) return;

  chrome.runtime.sendNativeMessage("io.github.phiberr.linkpick", { url }, () => {
    void chrome.runtime.lastError;
  });
}

function isHttpUrl(url) {
  return typeof url === "string" && /^https?:\/\//i.test(url);
}

function hostOf(url) {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (_) {
    return "";
  }
}

async function windowIsApp(windowId) {
  try {
    const win = await chrome.windows.get(windowId);
    return !!win && (win.type === "app" || win.type === "popup");
  } catch (_) {
    return false;
  }
}

async function waitForTabUrl(tabId, attempts) {
  for (let i = 0; i < attempts; i++) {
    try {
      const tab = await chrome.tabs.get(tabId);
      const url = tab.pendingUrl || tab.url || "";
      if (isHttpUrl(url)) return url;
    } catch (_) {
      return null;
    }
    await new Promise((r) => setTimeout(r, 40));
  }
  return null;
}

// X and other --app windows open external links as a new tab in the last
// focused normal browser window, with openerTabId pointing at the app tab.
chrome.tabs.onCreated.addListener((tab) => {
  void (async () => {
    if (!tab.openerTabId) return;

    let opener;
    try {
      opener = await chrome.tabs.get(tab.openerTabId);
    } catch (_) {
      return;
    }

    if (!(await windowIsApp(opener.windowId))) return;

    const url = await waitForTabUrl(tab.id, 15);
    if (!url) return;

    const openerHost = hostOf(opener.url || opener.pendingUrl || "");
    const urlHost = hostOf(url);
    if (openerHost && urlHost && openerHost === urlHost) return;

    try {
      await chrome.tabs.remove(tab.id);
    } catch (_) {
      /* tab may already be gone */
    }
    openViaLinkpick(url);
  })();
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || typeof message !== "object") return false;

  if (message.type === "open") {
    openViaLinkpick(message.url);
    sendResponse({ ok: true });
    return false;
  }

  if (message.type === "isAppWindow") {
    const windowId = sender.tab && sender.tab.windowId;
    if (windowId == null) {
      sendResponse({ isApp: false });
      return false;
    }
    windowIsApp(windowId).then((isApp) => sendResponse({ isApp }));
    return true;
  }

  return false;
});
