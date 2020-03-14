#!/bin/sh

# 
# tesla_adapter_check.sh - check for availability of tesla nema adapter 10-50
#
# Author:  Arul Selvan
# Version: Mar 12, 2020

available_msg="14-50 adapter is possibly available"
email_addr="foo@bar.com"
email_msg="tesla adapter"

wget -O - -q https://shop.tesla.com/product/gen-2-nema-adapters |grep "value=.* data-sku=\"1099344-10-D"|grep data-uri >/dev/null 2>&1

if [ $? -eq 0 ] ; then
  echo $available_msg
  echo $available_msg | mail -s "$email_msg" $email_addr
fi
