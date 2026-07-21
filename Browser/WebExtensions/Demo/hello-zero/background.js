chrome.runtime.onInstalled.addListener(() => {
  console.log("[Hello Zero] installed via WKWebExtension");
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "hello-zero-ping") {
    sendResponse({ ok: true, engine: "WKWebExtension" });
    return true;
  }
  return false;
});
