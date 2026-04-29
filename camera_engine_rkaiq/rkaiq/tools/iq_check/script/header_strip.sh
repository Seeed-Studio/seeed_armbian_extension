#!/bin/sh -e

INPUT=$1
OUTPUT=$2

# Strip preprocessor line markers and system header content
# The old tac|sed pipeline broke when system headers appeared mid-file
# (e.g., stdbool.h included from rk_aiq_comm.h) because it deleted
# everything from the LAST system header reference to the beginning.
cat $INPUT | grep -v '^#' | sed '/__fsid_t/d' | sed -e 's/_Bool/_Bool\n/' | sed -e 's/\r//g' > $OUTPUT
