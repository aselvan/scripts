/*
** DeleteTmp --- cron job to cleanup a dedicated temporary folder in gDrive
**
** Small appscript program to check if the /tmp in gDrive has any directories 
** over 30 days old, if so mark it as trashed so google can remove it. This is 
** typically used for files we share to other people and don't want to keep 
** using data
**
** Prereq/notes: 
**   * gDrive must have a folder called 'tmp' on root and directories are
**     created under that to be garbage collected.
**   * Files in /tmp are not touched
**   * optionally, if folder name ends with .nnn like "baz.100" then the  
**     number 100 is assumed to be the # days to keep instead of default 30.
** 
** Author:  Arul Selvan
** Version: Dec 1, 2018
*/

// global vars
var tmpDir="tmp";
var logDirName="logs";
var logFileName="rundaily.log";
var myEmail="yourgmail@gmail.com";
var emailSubject="runDaily log";
var defaultDaysToKeep=30;

// private: function writes everything in Logger to a permanant log file
// Note: call this function at the end.
function writeToLogFile_() {
  var rootDir = DriveApp.getRootFolder();
  
  // create logdir if needed at the root folder
  var logDirs = rootDir.getFoldersByName(logDirName);
  var logDir;
  if (logDirs.hasNext()) {
    logDir=logDirs.next();
    //Logger.log("Log Directory exists: "+ logDir);
  } 
  else {
    logDir=rootDir.createFolder(logDirName);
    //Logger.log("Log Directory created: "+ logDir);
  }
  // create logfile if needed inside log folder.  
  var logFile;
  var logFiles = logDir.getFilesByName(logFileName);
  if (logFiles.hasNext()) {
    logFile = logFiles.next();
    //Logger.log("Log file exists: "+ logFile);
  }
  else {
    logFile = logDir.createFile(logFileName, logFileName, MimeType.PLAIN_TEXT);
    //Logger.log("Log file created: "+ logFile);
  }
  
  // now, write everything to logfile
  logFile.setContent(Logger.getLog());
}

// This function is triggered to run every 12 hrs
function runDaily() {
  var trashedAny=false;
  Logger.log("----------------- " + logFileName + " -----------------");
  Logger.log("runDaily start: "+ new Date());
  
  var rootDir = DriveApp.getRootFolder();
  var tmpDirs = rootDir.getFoldersByName(tmpDir).next().getFolders();
  
  // recurse through all files in here to see if they are older than 'daysToKeep' days
  Logger.log("Checking for expiry of all entries in '"+ tmpDir + "'");
  while ( tmpEntry = tmpDirs.hasNext() ) {
    var tmpEntry= tmpDirs.next();
    var name = tmpEntry.getName();

    Logger.log("Folder Name: " + tmpEntry.getName());
    Logger.log("\tCreated: " + tmpEntry.getDateCreated());
    // check if dir name contains '.nnn' where nnn is days to keep instead of default 30
    if (name.indexOf(".") != -1) {
      var dtk=name.substring(name.indexOf(".")+1,name.length);
      daysToKeep = parseInt(dtk,10);
    }
    else {
      daysToKeep=defaultDaysToKeep;
    }
    var retentionPeriod = daysToKeep * 24 * 60 * 60 * 1000;
    if (new Date() - tmpEntry.getDateCreated() > retentionPeriod) {
      Logger.log("\tAction: expired because it is more than %s days old, deleting ...",daysToKeep);
      tmpEntry.setTrashed(true); 
      Logger.log("\tStatus: " + tmpEntry.getName() + " is deleted? " + tmpEntry.isTrashed());
      trashedAny=true;
    }
    else {
        Logger.log("\tStatus: not older than %s days, skipping ...",daysToKeep);
    }
  }

  // send mail only if we deleted anything
  if (trashedAny) {
    Logger.log("Deleted something, so sending mail...");
    MailApp.sendEmail(myEmail, emailSubject, Logger.getLog());
  }
  else {
    Logger.log("Nothing deleted, no mail sent.");
  }
  
  Logger.log("runDaily end: "+ new Date());
  // log to file
  writeToLogFile_();
}

