#!/bin/sh

#
# List symbols for all Objective-C classes
#

nm "$@"| grep 'OBJC_CLASS_\$_'|grep -v '_NS\|_UI'| \
  rev|cut -d' ' -f-1|rev|sort|uniq|cut -d'_' -f5-
