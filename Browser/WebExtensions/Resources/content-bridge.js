/**
 * Injected into pages before extension content scripts.
 * Provides a Firefox-style `browser` / `chrome` API subset bridged to native Zero.
 *
 * Expects `__ZERO_EXTENSION_ID__` to be replaced with the extension id string.
 */
(function() {
  if (window.__zeroWebExtensionBridgeInstalled && window.__zeroWebExtensionId === "__ZERO_EXTENSION_ID__") {
    return;
  }
  window.__zeroWebExtensionBridgeInstalled = true;
  window.__zeroWebExtensionId = "__ZERO_EXTENSION_ID__";

  const extensionId = "__ZERO_EXTENSION_ID__";
  let nextRequestId = 1;
  const pending = new Map();
  const messageListeners = [];

  function post(method, args) {
    return new Promise((resolve, reject) => {
      const requestId = String(nextRequestId++);
      pending.set(requestId, { resolve, reject });
      try {
        window.webkit.messageHandlers.webExtension.postMessage({
          extensionId,
          requestId,
          method,
          args: args || [],
          source: "content"
        });
      } catch (error) {
        pending.delete(requestId);
        reject(error);
      }
    });
  }

  window.__zeroWebExtensionHandleNativeResponse = function(payload) {
    const entry = pending.get(payload.requestId);
    if (!entry) return;
    pending.delete(payload.requestId);
    if (payload.error) {
      entry.reject(new Error(payload.error));
    } else {
      entry.resolve(payload.result);
    }
  };

  window.__zeroWebExtensionDeliverMessage = function(message, sender) {
    const results = [];
    for (const listener of messageListeners) {
      try {
        const result = listener(message, sender || {}, function() {});
        if (result !== undefined) results.push(result);
      } catch (error) {
        console.error("Zero extension onMessage error", error);
      }
    }
    return Promise.all(results.map(r => Promise.resolve(r))).then(values => {
      for (const value of values) {
        if (value !== undefined) return value;
      }
      return null;
    });
  };

  function storageLocal() {
    return {
      get: (keys) => post("storage.local.get", [keys === undefined ? null : keys]),
      set: (items) => post("storage.local.set", [items || {}]),
      remove: (keys) => post("storage.local.remove", [keys]),
      clear: () => post("storage.local.clear", [])
    };
  }

  const browser = {
    runtime: {
      id: extensionId,
      getManifest: () => post("runtime.getManifest", []),
      getURL: (path) => post("runtime.getURL", [path || ""]),
      sendMessage: (extensionIdOrMessage, messageMaybe) => {
        if (typeof extensionIdOrMessage === "string" && messageMaybe !== undefined) {
          return post("runtime.sendMessage", [extensionIdOrMessage, messageMaybe]);
        }
        return post("runtime.sendMessage", [extensionId, extensionIdOrMessage]);
      },
      onMessage: {
        addListener: (listener) => {
          if (typeof listener === "function") messageListeners.push(listener);
        },
        removeListener: (listener) => {
          const index = messageListeners.indexOf(listener);
          if (index >= 0) messageListeners.splice(index, 1);
        },
        hasListener: (listener) => messageListeners.includes(listener)
      }
    },
    storage: {
      local: storageLocal()
    },
    tabs: {
      query: (queryInfo) => post("tabs.query", [queryInfo || {}]),
      create: (createProperties) => post("tabs.create", [createProperties || {}]),
      get: (tabId) => post("tabs.get", [tabId]),
      getCurrent: () => post("tabs.getCurrent", []),
      sendMessage: (tabId, message) => post("tabs.sendMessage", [tabId, message]),
      executeScript: (tabIdOrDetails, detailsMaybe) => {
        if (typeof tabIdOrDetails === "number") {
          return post("tabs.executeScript", [tabIdOrDetails, detailsMaybe || {}]);
        }
        return post("tabs.executeScript", [null, tabIdOrDetails || {}]);
      }
    },
    i18n: {
      getMessage: (name) => String(name || "")
    }
  };

  window.browser = browser;
  window.chrome = browser;
})();
