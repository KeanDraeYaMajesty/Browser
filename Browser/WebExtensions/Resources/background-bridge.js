/**
 * Loaded into each extension background JSContext before background scripts.
 * Native calls arrive through `ZeroNative.call(method, argsJSON) -> JSON string`.
 */
(function(global) {
  const messageListeners = [];
  let nextRequestId = 1;
  const pending = {};

  function callNative(method, args) {
    const raw = ZeroNative.call(method, JSON.stringify(args || []));
    const parsed = JSON.parse(raw);
    if (parsed && parsed.error) {
      throw new Error(parsed.error);
    }
    return parsed ? parsed.result : null;
  }

  function callNativeAsync(method, args) {
    return new Promise((resolve, reject) => {
      try {
        resolve(callNative(method, args));
      } catch (error) {
        reject(error);
      }
    });
  }

  global.__zeroBackgroundDeliverMessage = function(messageJSON, senderJSON) {
    const message = JSON.parse(messageJSON);
    const sender = JSON.parse(senderJSON || "{}");
    const results = [];
    for (const listener of messageListeners) {
      try {
        const result = listener(message, sender, function() {});
        if (result !== undefined) results.push(result);
      } catch (error) {
        console.error("background onMessage error", error);
      }
    }
    return Promise.all(results.map(r => Promise.resolve(r))).then(values => {
      for (const value of values) {
        if (value !== undefined) return JSON.stringify({ result: value });
      }
      return JSON.stringify({ result: null });
    });
  };

  function storageLocal() {
    return {
      get: (keys) => callNativeAsync("storage.local.get", [keys === undefined ? null : keys]),
      set: (items) => callNativeAsync("storage.local.set", [items || {}]),
      remove: (keys) => callNativeAsync("storage.local.remove", [keys]),
      clear: () => callNativeAsync("storage.local.clear", [])
    };
  }

  const extensionId = ZeroNative.extensionId();

  const browser = {
    runtime: {
      id: extensionId,
      getManifest: () => callNativeAsync("runtime.getManifest", []),
      getURL: (path) => callNativeAsync("runtime.getURL", [path || ""]),
      sendMessage: (extensionIdOrMessage, messageMaybe) => {
        if (typeof extensionIdOrMessage === "string" && messageMaybe !== undefined) {
          return callNativeAsync("runtime.sendMessage", [extensionIdOrMessage, messageMaybe]);
        }
        return callNativeAsync("runtime.sendMessage", [extensionId, extensionIdOrMessage]);
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
      },
      onInstalled: {
        addListener: function() {},
        removeListener: function() {}
      }
    },
    storage: {
      local: storageLocal()
    },
    tabs: {
      query: (queryInfo) => callNativeAsync("tabs.query", [queryInfo || {}]),
      create: (createProperties) => callNativeAsync("tabs.create", [createProperties || {}]),
      get: (tabId) => callNativeAsync("tabs.get", [tabId]),
      getCurrent: () => callNativeAsync("tabs.getCurrent", []),
      sendMessage: (tabId, message) => callNativeAsync("tabs.sendMessage", [tabId, message]),
      executeScript: (tabIdOrDetails, detailsMaybe) => {
        if (typeof tabIdOrDetails === "number") {
          return callNativeAsync("tabs.executeScript", [tabIdOrDetails, detailsMaybe || {}]);
        }
        return callNativeAsync("tabs.executeScript", [null, tabIdOrDetails || {}]);
      }
    },
    i18n: {
      getMessage: (name) => String(name || "")
    },
    alarms: {
      create: function() {},
      clear: function() { return Promise.resolve(false); },
      onAlarm: { addListener: function() {}, removeListener: function() {} }
    }
  };

  global.browser = browser;
  global.chrome = browser;
  global.console = {
    log: function() { ZeroNative.log(Array.prototype.slice.call(arguments).join(" ")); },
    warn: function() { ZeroNative.log("[warn] " + Array.prototype.slice.call(arguments).join(" ")); },
    error: function() { ZeroNative.log("[error] " + Array.prototype.slice.call(arguments).join(" ")); },
    info: function() { ZeroNative.log("[info] " + Array.prototype.slice.call(arguments).join(" ")); }
  };
})(this);
