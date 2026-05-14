(function() {
  const currentScript = document.currentScript || document.querySelector('script[data-debug]');
  const isDebug = currentScript ? currentScript.dataset.debug === 'true' : false;
  const originalFetch = window.fetch;
  window.fetch = async function(...args) {
    const url = args[0] instanceof URL ? args[0].href : args[0];
    if (typeof url === 'string' && url.includes('chrome-extension://')) {
      if (isDebug) {
        console.log('%c[LinkedIn Extension Blocker]%c: ' + url, 'background: #d32f2f; color: white; padding: 2px 5px;', 'color: #d32f2f; font-weight: bold;');
      }
      return new Response(null, { status: 403 });
    }
    return originalFetch.apply(this, args);
  };
  
  console.log('%c[LinkedIn Extension Blocker v1.2.1]%c', 'background: #222; color: #bada55; padding: 2px 5px;', 'color: #333');
})();
