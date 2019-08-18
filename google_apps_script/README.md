# Google Apps Scripts

### Scripts for google app script platform

- #### /DeleteTemp.cs
  This is a cron job like Google App Script to cleanup a dedicated temporary folder in gDrive. 
  If the directories are 30 days or older, they are marked as 'trashed' so google can reclaim 
  the space. This is typically used for files we share to other people and want to automatically 
  delete them after sometime so they dont use up gDrive storage.

