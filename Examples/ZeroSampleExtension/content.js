(function () {
  if (window.__zeroSampleExtensionInjected) return;
  window.__zeroSampleExtensionInjected = true;
  document.documentElement.setAttribute("data-zero-sample-extension", "1");
  console.log("[Zero Sample Extension] content script active on", location.href);
})();
