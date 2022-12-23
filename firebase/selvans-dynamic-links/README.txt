README
======
To make changes to web app. The web app defined is just empty and does nothing
but forward requests to link shortening. When changes are needed, just  modify 
firebase.json as needed and do a deploy.

Initial setup:
=============
brew install firebase-tools

Development steps:
=================

* run 'firebase login' [if not installed or logged in already]
* run 'firebase init' [select the correct project from cloud to work with]
* make changes to firbase.json as needed, deploy static files, webapp etc to public/ dir etc
* run 'firebase deploy'
