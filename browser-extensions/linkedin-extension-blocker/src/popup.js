document.addEventListener('DOMContentLoaded', () => {
  const debugToggle = document.getElementById('debugToggle');
  chrome.storage.local.get(['debug_enabled'], (res) => {
    debugToggle.checked = res.debug_enabled || false;
  });
  debugToggle.addEventListener('change', () => {
    chrome.storage.local.set({ debug_enabled: debugToggle.checked });
  });
});