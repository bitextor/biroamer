#!/bin/bash

export LANG=C.UTF-8

if [ "$1" == "-h" ]
then
    echo "Usage: ./`basename $0` <lang1> <lang2> <mix_corpus>"
    exit 0
fi

OMIT="python3 ./omit.py"
MIX=$3
FASTALIGN=./fast_align/build/fast_align
ATOOLS=./fast_align/build/atools
TMXT="python3 ./tmxt/tmxt.py"
NER="python3 ./biner.py"
BUILDTMX="python3 ./buildtmx.py"

PROCS=4
BLOCKSIZE=100000

L1=$1
L2=$2

TOKL1="python3 ./toktok.py"
TOKL2="python3 ./toktok.py"

MYTEMPDIR=$(mktemp -d)
echo "Using temporary directory $MYTEMPDIR" 1>&2

cat /dev/stdin | \
    $TMXT --codelist $L1,$L2 | \
    parallel -j$PROCS -k -l $BLOCKSIZE --pipe $OMIT | \
    cat - $MIX | \
    shuf > $MYTEMPDIR/omitted-mixed

# ANONYMIZE
cut -f1 $MYTEMPDIR/omitted-mixed | parallel -j$PROCS -k -l $BLOCKSIZE --pipe $TOKL1 | tr "[[:upper:]]" "[[:lower:]]" >$MYTEMPDIR/f1.tok
cut -f2 $MYTEMPDIR/omitted-mixed | parallel -j$PROCS -k -l $BLOCKSIZE --pipe $TOKL2 | tr "[[:upper:]]" "[[:lower:]]" >$MYTEMPDIR/f2.tok

paste $MYTEMPDIR/f1.tok $MYTEMPDIR/f2.tok | sed 's%'$'\t''% ||| %g' >$MYTEMPDIR/fainput

$FASTALIGN -i $MYTEMPDIR/fainput -I 6 -d -o -v >$MYTEMPDIR/forward.align 
$FASTALIGN -i $MYTEMPDIR/fainput -I 6 -d -o -v -r >$MYTEMPDIR/reverse.align
$ATOOLS -i $MYTEMPDIR/forward.align -j $MYTEMPDIR/reverse.align -c grow-diag-final-and >$MYTEMPDIR/symmetric.align

rm -Rf $MYTEMPDIR/forward.align $MYTEMPDIR/reverse.align $MYTEMPDIR/fainput

paste $MYTEMPDIR/omitted-mixed $MYTEMPDIR/f1.tok $MYTEMPDIR/f2.tok $MYTEMPDIR/symmetric.align |\
parallel -k -j$PROCS -l $BLOCKSIZE --pipe $NER | \
#$NER | \
python3 buildtmx.py $L1 $L2

echo "Removing temporary directory $MYTEMPDIR" 1>&2

rm -Rf $MYTEMPDIR
