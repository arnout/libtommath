#!/bin/sh

die() {
  echo "$1 failed"
  echo "Exiting"
  exit $2
}
# A linear congruential generator is sufficient for the purpose.
SEED=3735928559
LCG() {
  SEED=$(((1103515245 * $SEED + 12345) % 2147483648))
  echo $SEED
}

median() {
  median=0;
  flag=1;
  for val in $* ; do
     if [ $flag -eq 1 ] ; then
        flag=$((flag + 1))
        continue
     elif [ $flag -eq 2 ] ; then
         median=$val
         flag=$((flag + 1))
         continue
     else
       if [ $median -lt $val ] ; then
          median=$((median + 1))
       fi
       if [ $median -gt $val ] ; then
          median=$((median - 1))
       fi
     fi
  done
  echo $median
}

MPWD=$(pwd)
FILE_NAME="tuning_list"
BNCORE_C="../bncore.c"
BACKUP_SUFFIX=".orig"
RNUM=0;
#############################################################################
# It would be a good idea to isolate these processes (with e.g.: cpuset)    #
#                                                                           #
# It is not a good idea to e.g: watch high resolution videos while this     #
# test are running if you do not have enough memory to avoid page faults.   #
#############################################################################

# Number of rounds overall.
LIMIT=100
# Number of loops for each input.
RLOOPS=10
# Offset ( > 0 ) . Runs tests with asymmetric input of the form 1:OFFSET
# Please use another destination for BNCORE_C if you change OFFSET, because the numbers
# with an offset different from 1 (one) are not usable as the general cut-off values
# in "bncore.c".
OFFSET=1
# Number ( >= 3 ) of positive results (TC-is-faster) accumulated until it is accepted.
# Due to the algorithm used to compute the median in this Posix compliant shell script
# the value needs to be 3 (three), not less, to keep the variation small.
LAG=3
# Keep the temporary file $FILE_NAME. Set to 0 (zero) to remove it at the end.
# The file is in a format fit to feed into R directly. If you do it and find the median
# of this program to be off by more than a couple: please contact the authors and report
# the numbers from this program and R and the standard deviation. This program is known
# to get larger errors if the standard deviation is larger than ~50.
KEEP_TEMP=1

echo "You might like to watch the numbers go up to $LIMIT but it will take a long time!"

# Might not have sufficient rights or disc full.
echo "km ks tc3m tc3s" > $FILE_NAME || die "Writing header to $FILE_NAME" $?
i=1
while [ $i -le $LIMIT ]; do
   RNUM=$(LCG)
   echo $i
   "$MPWD"/tune -t -r $RLOOPS -L $LAG -S "$RNUM" -o $OFFSET >> $FILE_NAME || die "tune" $?
   i=$((i + 1))
done

if [ $KEEP_TEMP -eq 0 ]; then
   rm -v $FILE_NAME || die "Removing $KEEP_TEMP" $?
fi

echo "Writing cut-off values to \"bncore.c\"."
echo "In case of failure: a copy of \"bncore.c\" is in \"bncore.c.orig\""

cp -v $BNCORE_C $BNCORE_C$BACKUP_SUFFIX || die "Making backup copy of bncore.c" $?

cat << END_OF_INPUT > $BNCORE_C || die "Writing header to bncore.c" $?
#include "tommath_private.h"
#ifdef BNCORE_C
/* LibTomMath, multiple-precision integer library -- Tom St Denis */
/* SPDX-License-Identifier: Unlicense */
/*
   Current values evaluated on an AMD A8-6600K (64-bit).
   Type "make tune" to optimize them for your machine but
   be aware that it may take a long time. It took 2:30 minutes
   on the aforementioned machine for example.
 */
END_OF_INPUT

# The Posix shell does not offer an array data type

i=1;
TMP=""
TMP=$(cat $FILE_NAME | cut -d' ' -f$i )
TMP=$(median $TMP )
echo "int KARATSUBA_MUL_CUTOFF = $TMP;"
echo "int KARATSUBA_MUL_CUTOFF = $TMP;" >> $BNCORE_C || die "(km) Appending to bncore.c" $?
i=$((i + 1))
TMP=$(cat $FILE_NAME | cut -d' ' -f$i )
TMP=$(median $TMP );
echo "int KARATSUBA_SQR_CUTOFF = $TMP;"
echo "int KARATSUBA_SQR_CUTOFF = $TMP;" >> $BNCORE_C || die "(ks) Appending to bncore.c" $?
i=$((i + 1))
TMP=$(cat $FILE_NAME | cut -d' ' -f$i)
TMP=$(median $TMP );
echo "int TOOM_MUL_CUTOFF = $TMP;"
echo "int TOOM_MUL_CUTOFF = $TMP;" >> $BNCORE_C || die "(tc3m) Appending to bncore.c" $?
i=$((i + 1))
TMP=$(cat $FILE_NAME | cut -d' ' -f$i)
TMP=$(median $TMP );
echo "int TOOM_SQR_CUTOFF = $TMP;"
echo "int TOOM_SQR_CUTOFF = $TMP;" >> $BNCORE_C || die "(tc3s) Appending to bncore.c" $?

echo "#endif" >> $BNCORE_C || die "(end) Appending to bncore.c" $?

