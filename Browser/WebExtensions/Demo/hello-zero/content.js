(function () {
  if (window.__helloZeroInjected) return;
  window.__helloZeroInjected = true;

  document.documentElement.setAttribute("data-hello-zero", "1");

  const badge = document.createElement("div");
  badge.id = "hello-zero-badge";
  badge.textContent = "Hello Zero";
  document.documentElement.appendChild(badge);

  try {
    chrome.runtime.sendMessage({ type: "hello-zero-ping" }, (response) => {
      if (response?.ok) {
        badge.title = "WKWebExtension runtime OK";
      }
    });
  } catch (_) {
    // Ignore if messaging is unavailable on this page.
  }

  console.log("[Hello Zero] content script active on", location.href);
})();
