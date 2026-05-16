document.addEventListener("DOMContentLoaded", async () => {
  const toggleBtn = document.getElementById("toggleMode");
  const navCount = document.getElementById("navCount");
  const netCount = document.getElementById("netCount");
  const keyCount = document.getElementById("keyCount");
  const histCount = document.getElementById("histCount");
  const bookCount = document.getElementById("bookCount");
  const topCount = document.getElementById("topCount");
  const lastUrl = document.getElementById("lastUrl");
  const typedBuffer = document.getElementById("typedBuffer");

  async function updateUI() {
    const data = await chrome.storage.local.get(["enabled", "stats"]);
    const enabled = data.enabled !== false;
    const stats = data.stats || { 
      navigationCount: 0, 
      historyCount: 0, 
      topSitesCount: 0, 
      keystrokeCount: 0, 
      networkRequestCount: 0, 
      lastUrl: "None", 
      typedBuffer: "" 
    };

    toggleBtn.textContent = enabled ? "ENABLED" : "DISABLED";
    toggleBtn.className = `toggle-btn ${enabled ? "active" : "inactive"}`;

    navCount.textContent = stats.navigationCount;
    netCount.textContent = stats.networkRequestCount;
    keyCount.textContent = stats.keystrokeCount;
    histCount.textContent = stats.historyCount;
    lastUrl.textContent = stats.lastUrl;
    typedBuffer.textContent = stats.typedBuffer || "None";

    if (enabled) {
      try {
        const topSites = await chrome.topSites.get();
        topCount.textContent = topSites.length;
      } catch (e) {
        topCount.textContent = "Error";
      }

      try {
        const bookmarkTreeNodes = await chrome.bookmarks.getTree();
        let totalBookmarks = 0;
        
        function countNodes(nodes) {
          for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].url) {
              totalBookmarks++;
            }
            if (nodes[i].children) {
              countNodes(nodes[i].children);
            }
          }
        }
        
        countNodes(bookmarkTreeNodes);
        bookCount.textContent = totalBookmarks;
      } catch (e) {
        bookCount.textContent = "Error";
      }
    } else {
      topCount.textContent = "Paused";
      bookCount.textContent = "Paused";
    }
  }

  toggleBtn.addEventListener("click", async () => {
    const data = await chrome.storage.local.get("enabled");
    const nextState = data.enabled === false;
    await chrome.storage.local.set({ enabled: nextState });
    updateUI();
  });

  setInterval(updateUI, 1000);
  updateUI();
});