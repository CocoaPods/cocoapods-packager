#!/bin/sh

#
# List symbols for all constants
#

nm "$@"|grep ' S '|grep -v 'OBJC\|\.eh$'| \
  cut -d_ -f2-|sort|uniq
nm "$@"|grep ' T '|cut -d_ -f2-|sort|uniq
