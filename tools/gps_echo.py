#!/usr/bin/python
#
# gps_echo.py
#   Simple script to read gps from gps device connected to serial port. The output
#   is meant for constructing a google map location URL based on the lat/lon data 
#   read as shown below.
#
#   https://www.google.com/maps?q=`python gps_echo.py`"
#  
# Author:  Arul Selvan
# Version: Sep 4, 2022
#
# Prereq: 
#   apt-get install python-serial python-nmea2
#
import serial
import time
import string
import pynmea2

# serial port where GPS device is connected
port="/dev/ttyAMA0"
s=serial.Serial(port, baudrate=9600, timeout=0.5)
dataout = pynmea2.NMEAStreamReader()

while True:
   if s.in_waiting:
     try:
       line=s.readline()
     except:
       print("ERROR: failed reading gps serial device at: "+ port)
       quit()

     if line[0:6] == "$GPRMC":
       msg=pynmea2.parse(line)
       lat=msg.latitude
       lon=msg.longitude
       gps = str(lat) + "," + str(lon)
       print(gps)
       exit()

