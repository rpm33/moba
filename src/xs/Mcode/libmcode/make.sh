#!/bin/sh

OPT="-fPIC -O2 -Wuninitialized -march=i686 "

rm -f *.o
rm -f libmcode.a
gcc ${OPT} -c libmcode.c
ar rc libmcode.a *.o
rm -f *.o

echo "MAKE libmcode.a finished"
