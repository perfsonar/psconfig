#!/bin/bash

CURRENTDIR=$(pwd)
LIBDIR=$CURRENTDIR/../lib

export PERL5LIB=$PERL5LIB:$LIBDIR

if [ -z "$1" ]
then
    /usr/bin/TestRunner.pl MeshConfigSuite
else
    /usr/bin/TestRunner.pl $1
fi

