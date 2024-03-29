#!/usr/bin/env python3
# 
# myutils_test.py -- quick and dirty test harness for myutils.py module
#
# Author:  Arul Selvan
# Version: May 16, 2023
#

import sys
import argparse
import os
import pathlib
sys.path.append(os.path.join(os.path.dirname(__file__),'../python_modules'))
import myutils
import time

version="23.05.17"
my_path=__file__
my_name=myutils.getMyName(my_path)
my_desc=my_name+f" v{version} -- Test harness for the myutils.py module"


# test commandline parser (must be the first one so we can setup logger)
parser = argparse.ArgumentParser(parents=[myutils.getArgParser()],
  description=my_desc,prog=my_name,conflict_handler="resolve")
parser.add_argument("-i", "--integer", dest="counter",help="integer option with a list", default="0", choices=[0,1,2], type=int)
parser.add_argument("-d", "--data", dest="animal", help="string option with a list", choices=['cow','goat'], type=str)
parser.add_argument("-p", "--path", dest="path", help="path option, also a required", type=pathlib.Path,required=True)
parser.add_argument("-f", "--file", dest="fname", help="filename option", type=str)
args=parser.parse_args()

# test logger 
logger = myutils.getLogger(myutils.getLogFilename(my_path),args.logLevel)
logger.info("this is info message")
logger.warning("this is warn message")
logger.error("this is error message")
logger.debug("debug message")

# validate path
if not os.path.isdir(args.path):
  logger.error(str(args.path)+": is not a valid path!")

# if filename provided, validate
if (args.fname):
  if not os.path.isfile(args.fname):
    logger.error(args.fname+": is not a valid file!")

#parser.print_help()
#help(myutils)

# test the connectivity function
logger.debug(f"Connectivity: {myutils.checkConnectivity()}")

# test mail
m = myutils.SendMail("foo@bar.com", "python test mail")
m.setBody("mail body text for python text mail")
logger.debug (m)
#m.send()

# getIP
logger.info("My IP: "+myutils.getIP("en1"))

# test root
myutils.requireRoot()



