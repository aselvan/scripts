const defaultStats = {
  navigationCount: 0,
  historyCount: 0,
  keystrokeCount: 0,
  networkRequestCount: 0,
  lastUrl: "None",
  typedBuffer: ""
};

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.set({ enabled: true, stats: defaultStats });
});

async function isEnabled() {
  const data = await chrome.storage.local.get("enabled");
  return data.enabled !== false;
}

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status === "complete" && tab.url) {
    if (!(await isEnabled())) return;
    const data = await chrome.storage.local.get("stats");
    const stats = data.stats || { ...defaultStats };
    stats.navigationCount++;
    stats.lastUrl = tab.url;
    await chrome.storage.local.set({ stats });
  }
});

chrome.history.onVisited.addListener(async () => {
  if (!(await isEnabled())) return;
  const data = await chrome.storage.local.get("stats");
  const stats = data.stats || { ...defaultStats };
  stats.historyCount++;
  await chrome.storage.local.set({ stats });
});

chrome.webRequest.onBeforeRequest.addListener(
  async (details) => {
    if (!(await isEnabled())) return;
    if (details.url.startsWith('chrome-extension://')) return;
    
    const data = await chrome.storage.local.get("stats");
    const stats = data.stats || { ...defaultStats };
    stats.networkRequestCount++;
    await chrome.storage.local.set({ stats });
  },
  { urls: ["<all_urls>"] }
);

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "KEYSTROKE") {
    isEnabled().then(async (enabled) => {
      if (!enabled) {
        sendResponse({ status: "disabled" });
        return;
      }
      
      const data = await chrome.storage.local.get("stats");
      const stats = data.stats || { ...defaultStats };
      stats.keystrokeCount++;
      
      let currentBuffer = stats.typedBuffer || "";
      currentBuffer += message.key;
      if (currentBuffer.length > 64) {
        currentBuffer = currentBuffer.slice(-64);
      }
      stats.typedBuffer = currentBuffer;
      
      await chrome.storage.local.set({ stats });
      sendResponse({ status: "logged" });
    });
    return true; 
  }
});
