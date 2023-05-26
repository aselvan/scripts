# 
# myutils.py --- misl collection of functions, classes to use in python code
#
# Author:  Arul Selvan
# Version: May 15, 2023
#
"""
Misl collection of functions, classes

The module contains the following public functions & classes:

    - getArgParser -- create & return a commone/base argparse object that 
        can be used as a 'parent' to extend for each calling script's needs
  
    - getLogger -- create & return a logger with stdout & file in single instance

    - checkConnectivity -- Check if there is internet connectivity

    - getLogFilename -- construct a log filename i.e. /tmp/<scriptname>.log

    - requireRoot -- check if the user is 'root' otherwise, exit

    - SendMail -- send mail

This module and other modules are on 'python_modules' directory which is 
one level up i.e. root directory of the scripts git repo so add modules 
path before importing this file as shown below or alternatively you can 
append <git_repo_root>/python_modules to PYTHONPATH environment variable.

  sys.path.append(os.path.join(os.path.dirname(__file__),'../python_modules'))
  import myutils

"""

import argparse
import subprocess
import time
import sys
import logging
import os
from pathlib import Path

__version__ = '23.05.26'
__all__ = [
  'getArgParser',
  'getLogger'
  'checkConnectivity',
  'getLogFilename',
  'requireRoot'
  'SendMail'
  'getMyName'
  'getIP'
  'runPopen'
]

PING_HOST="8.8.8.8"
PING_INTERVAL=10
PING_ATTEMPT=3
VERBOSE=False
LOG_FORMATTER="[%(asctime)s] [%(levelname)s] %(message)s"
DATE_FMT="%m/%d/%Y %H:%M:%S"
arg_parser = None
logger = None
tmp_dir="/tmp"


# ---------------- getArgParser ---------------------
def getArgParser(description=None,name=None):
  """ 
  create & return a commone/base argparse object. Use as follows in calling script, note the
  spefication of conflict_handler to ensure extended classes can override the options as needed

  myparser = argparse.ArgumentParser(parents=[myutils.getArgParser("desc","name")], 
    description="my description",prog="myname.py",conflict_handler="resolve")
  """

  global arg_parser

  if arg_parser is not None:
    return arg_parser
  
  # base parser to have common args for any script like -v, -e etc
  arg_parser = argparse.ArgumentParser(description=description,prog=name)
  arg_parser.add_argument("-l", "--log",
    help="directly maps to logger levels [default: %(default)s]", default="INFO",
    dest="logLevel", choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'])
  arg_parser.add_argument("-e", "--email", help="email address to send mail", type=str)

  return arg_parser

# ---------------- getLogger ---------------------
def getLogger(logFileName=None, logLevel="INFO"):

  """ 
  create & return a logger with stdout & file in single instance. If logfilename is not 
  provided, only stdout logger will be created.
  """

  global logger

  if logger is not None:
    return logger

  logger = logging.getLogger()
  logger.setLevel(logging.getLevelName(logLevel))
  formatter = logging.Formatter(LOG_FORMATTER,datefmt=DATE_FMT)

  stdout_handler = logging.StreamHandler(sys.stdout)
  stdout_handler.setFormatter(formatter)
  logger.addHandler(stdout_handler)

  # if path/file name provided, create filehandler and combine
  if logFileName is not None:
    file_handler = logging.FileHandler(logFileName, mode='w', delay=True)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

  return logger


# ---------------- checkConnectivity ---------------------
def checkConnectivity(
  ping_host=PING_HOST, 
  ping_interval=PING_INTERVAL, 
  ping_attempt=PING_ATTEMPT):

  """Return the True if there is connectivity, False otherwise. """
  
  cmd=f"ping -t{ping_interval} -c3 -q {ping_host}".split()
  
  for i in range(ping_attempt):
    cp = subprocess.run(cmd, capture_output=True, text=True)
    if (cp.returncode == 0):
      return True
    getLogger().debug(f"no response from {ping_host} ; errorcode={cp.returncode}")
    time.sleep(ping_interval)

  return False


# ---------------- getMyName---------------------
def getMyName(scriptPath):
  return str(Path(os.path.basename(scriptPath)));

# ---------------- getLogFilename ---------------------
def getLogFilename(scriptPath):
  global tmp_dir
  # extract script file name and use to create /tmp/<scriptname>.log for logFileName
  fName = Path(os.path.basename(scriptPath));
  return tmp_dir + "/" + str(fName.with_suffix(".log"))


# ---------------- requireRoot ---------------------
def requireRoot():
  if (os.geteuid() != 0):
    getLogger().fatal("root access is needed to run this script, exiting...")
    sys.exit(1)

# ---------------- runPopen ---------------------
def runPopen(cmd):
  """
  Execute a string of piped commands passed as the argument. If all is well, 
  this will return the output of the pipe(s), otherwise raises exception
  """

  process = os.popen(cmd)
  result=process.read().strip()
  rc=process.close()
  if (rc != None):
    getLogger().error(f"pipe command \"{cmd}\" failed")
    raise Exception(f"Pipe command \"{cmd}\" failed, errorCode = {rc}")

  return result

# ---------------- getIP ---------------------
def getIP(iface):
  pipe_cmd=f"ifconfig {iface}"+"| grep 'inet '|awk '{print $2;}'"
  return runPopen(pipe_cmd)
  
# ---------------- SendMail class  ---------------------
class SendMail:
  """
  Simple mail class using commandline mail instead of python's smtpllib library
  as our need for now is just send a quick text based mail, don't need all the 
  bells & whistles comes w/ the python module.
  """

  #init method
  def __init__(self,address, subject):
    self.address = address
    self.subject = subject

  def setAddress(self,address):
    self.address = address

  def setSubject(self,subject):
    self.subject = subject

  def setBody(self, body):
    self.body = body

  def send(self):
    # send the mail
    mail_cmd=f"echo \"{self.body}\" | mail -s \"{self.subject}\" {self.address}"
    getLogger().debug("mail.cmd="+str(mail_cmd))
    cp = subprocess.call(mail_cmd,shell=True)
    if (cp > 0 ):
      getLogger().debug(f"send mail failed ; errorcode={cp}")
      raise Exception(f"Error sending mail, errorCode = {cp}")
    
  # to use in print()
  def __str__(self):
    return f"SendMail: subject: {self.subject}; address: {self.address}"

