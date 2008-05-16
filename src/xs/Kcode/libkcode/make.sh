#!/bin/sh

OPT="-fPIC -O2 -Wuninitialized -march=i686 "

rm -f *.o
rm -f libkcode.a
gcc ${OPT} -c libkcode.c
ar rc libkcode.a *.o
rm -f *.o

