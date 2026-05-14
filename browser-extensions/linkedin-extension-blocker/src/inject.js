(function() {
  if (chrome.runtime && chrome.runtime.id) {
    try {
      const script = document.createElement('script');
      script.src = chrome.runtime.getURL('src/patch.js');
      chrome.storage.local.get(['debug_enabled'], (res) => {
        script.dataset.debug = res.debug_enabled || false;
        (document.head || document.documentElement).appendChild(script);
        script.onload = () => script.remove();
      });
    } catch (e) {
      console.error('[LinkedIn Extension Blocker] injection failed:', e);
    }
  }
})();
