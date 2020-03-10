#!/bin/bash

export LANG=C.UTF-8

if [ "$1" == "-h" ]
then
    echo "Usage: ./`basename $0` <lang1> <lang2> <mix_corpus> [seed]"
    exit 0
fi

# Get the script directory
DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OMIT="python3 $DIR/omit.py"
MIX=$3
FASTALIGN=$DIR/fast_align/build/fast_align
ATOOLS=$DIR/fast_align/build/atools
TMXT="python3 $DIR/tmxt/tmxt.py"
NER="python3 $DIR/biner.py"
BUILDTMX="python3 $DIR/buildtmx.py"

PROCS=$(getconf _NPROCESSORS_ONLN)
BLOCKSIZE=100000

L1=$1
L2=$2

TOKL1="python3 $DIR/toktok.py"
TOKL2="python3 $DIR/toktok.py"

MYTEMPDIR=$(mktemp -d)
echo "Using temporary directory $MYTEMPDIR" 1>&2

# Set seed for reproducibility
if [ $# -eq 4 ]; then
    SEED=$4
else
    SEED=$RANDOM
fi
get_seeded_random()
{
    seed="$1"
    openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
        </dev/zero 2>/dev/null
}

cat /dev/stdin | \
    $TMXT --codelist $L1,$L2 | \
    $OMIT -s $SEED | \
    cat - $MIX | \
    shuf --random-source=<(get_seeded_random $SEED) > $MYTEMPDIR/omitted-mixed

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
$BUILDTMX $L1 $L2

echo "Removing temporary directory $MYTEMPDIR" 1>&2

rm -Rf $MYTEMPDIR
