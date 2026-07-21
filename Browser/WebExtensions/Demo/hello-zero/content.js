(async function () {
  const badge = document.createElement("div");
  badge.id = "zero-hello-extension-badge";
  badge.textContent = "Hello from a Firefox extension in Zero";
  document.documentElement.appendChild(badge);

  try {
    const response = await browser.runtime.sendMessage({
      type: "page-hello",
      payload: { href: location.href, title: document.title }
    });
    if (response && response.visits) {
      badge.textContent = `Hello Zero · visits ${response.visits}`;
    }
  } catch (error) {
    badge.textContent = "Hello Zero (messaging unavailable)";
    console.error(error);
  }
})();
