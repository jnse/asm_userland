#!/bin/bash

# Usage: fatal <message>
#
# Writes message to STDERR and exits nonzero.
#
function fatal()
{
    echo "$1" 1>&2
    exit 1
}

# -----------------------------------------------------------------------------

if [ -z $1 ]; then
    fatal "Missing argument: output file."
fi
OUTFILE=$1
UNISTD_FILE="unistd_"
if [ $(getconf LONG_BIT) == "64" ]; then
    UNISTD_FILE="${UNISTD_FILE}64.h"
else
    UNISTD_FILE="${UNISTD_FILE}32.h"
fi
mkdir -p include
echo '%ifndef SYSCALLS_INCL' > ${OUTFILE}
echo '%define SYSCALLS_INCL' >> ${OUTFILE}
echo '' >> ${OUTFILE}
cat /usr/include/asm/${UNISTD_FILE} |\
  grep '#define' |\
  grep '__NR' |\
  sed 's/#define __NR/%define syscall/' >> ${OUTFILE}
echo '' >> ${OUTFILE}
echo '%endif' >> ${OUTFILE}
