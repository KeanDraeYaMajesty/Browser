// Background script for the Hello Zero demo extension.
browser.runtime.onMessage.addListener(async (message, sender) => {
  if (message && message.type === "page-hello") {
    const key = "visits";
    const stored = await browser.storage.local.get(key);
    const visits = (stored[key] || 0) + 1;
    await browser.storage.local.set({ [key]: visits });
    console.log("Hello Zero visit #", visits, "from", sender && sender.tab && sender.tab.url);
    return { visits: visits, echo: message.payload || null };
  }
  return null;
});

console.log("Hello Zero background ready");
