#!/usr/bin/python3
# 
# myutils_test.py -- quick and dirty test driver for myutils.py module
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

parser = argparse.ArgumentParser(parents=[myutils.getArgParser("a paraser",__file__)], 
  description="This is the test driver for myutils.py module",
  prog=__file__,conflict_handler="resolve")
#parser.print_help()
args=parser.parse_args()

#help(myutils)
print (myutils.checkConnectivity())

logger = myutils.getLogger(myutils.getLogFilename(__file__),True)
logger.info("this is info message")
logger.warning("this is warn message")
logger.error("this is error message")

time.sleep(2)
logger.debug("debug message")
myutils.requireRoot()

