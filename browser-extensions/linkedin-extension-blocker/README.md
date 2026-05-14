# LinkedIn Extension Blocker

**Blocks LinkedIn from reading/scanning all your browser plugins.**

## Overview

LinkedIn repeatedly scans your browser for thousands of known extensions, which is not only a privacy concern but also wastes CPU cycles, especially if you keep LinkedIn open as an active tab, as many users do. I found that LinkedIn website runs a poorly designed detection loop that attempts to load a specific resource from each extension to determine whether it is installed or not. When this process is repeated across thousands of extensions, it results in unnecessary CPU usage with no real benefit. I found that LinkedIn looped through 4,678 extension IDs on every refresh, while others have reported more than 6,000+. Regardless of the exact count, pounding your CPU with thousands of pointless checks is **downright insane!**

Read the link below for additional details.

[LinkedIn browser survillance](https://www.linkedin.com/pulse/linkedin-accused-extensive-browser-surveillance-pdfze/)

## What does this extension do?

This is a very simple extension that injects an interceptor code to catch LinkedIn’s attempts to load extension resources and deny those requests. It includes a debug flag (off by default) that lets you see which extension resources were blocked if you want to observe the behavior. Other than that, the extension does absolutely nothing else.

## Installation (Chrome/Brave/Edge)

1. Copy all the files and folders to a permanent folder on your laptop/desktop
2. Open `chrome://extensions/`
3. Activate "Developer mode"
4. Click on "Load unpacked" and select the folder you copied the files at step #1 when prompted


## About this plugin

- Manifest V3
- Intercepts *window.fetch* call and inserts code to deny access while browser is on linkedin.com website
- No backend, no tracking, no external servers, no permission of any sort needed.

## License

Released on MIT license.
