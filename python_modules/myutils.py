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

    - sendMail -- send mail

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

__version__ = '1.0'
__all__ = [
  'getArgParser',
  'getLogger'
  'checkConnectivity',
  'getLogFilename',
  'requireRoot'
  'sendMail'
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
def getArgParser(description,name):
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
  arg_parser.add_argument("-v", "--verbose",help="if enabled all messages will be printed, otherwise just info/warn/error", 
    action="store_const", const=True, default=False)
  arg_parser.add_argument("-e", "--email", help="email address to send mail", type=str)

  return arg_parser

# ---------------- getLogger ---------------------
def getLogger(logFileName=None, verbose=VERBOSE):

  """ 
  create & return a logger with stdout & file in single instance. If logfilename is not 
  provided, only stdout logger will be created.
  """

  global logger

  if logger is not None:
    return logger

  logger = logging.getLogger()
  if (verbose):
    logger.setLevel(logging.DEBUG)
  else:
    logger.setLevel(logging.INFO)
    
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
    # print (cp.stdout)
    time.sleep(ping_interval)

  return False

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

# ---------------- sendMail??? can be a class instead? ---------------------
def sendMail():
  print("send mail")


# ---------------- Foo example ---------------------
# example for a class
class Foo:

  #init method
  def __init__(self,name):
    self.name = name
  
  # to use in print()
  def __str__(self):
    return f"Class with a name {self.name}"


