#!/bin/bash
set -eo pipefail

export LANG=C.UTF-8

# Get the script directory
DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OMIT_COMMAND="python3 $DIR/omit.py"
FASTALIGN=$DIR/fast_align/build/fast_align
ATOOLS=$DIR/fast_align/build/atools
TMXT="python3 $DIR/tmxt/tmxt.py"
NER="python3 $DIR/biner.py"
BUILDTMX="python3 $DIR/buildtmx.py"

JOBS=$(getconf _NPROCESSORS_ONLN)
BLOCKSIZE=100000
SEED=$RANDOM

TOKL1="python3 $DIR/toktok.py"
TOKL2="python3 $DIR/toktok.py"

get_seeded_random()
{
    seed="$1"
    openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
        </dev/zero 2>/dev/null
}

usage () {
    echo "Usage: `basename $0` [options] <lang1> <lang2>"
    echo "Options:"
    echo "    -s SEED           Set random seed for reprodibility"
    echo "    -a ALIGN_CORPUS   Extra corpus to improve alignment"
    echo "                      It won't be included in the output"
    echo "    -j JOBS           Number of jobs to run in parallel"
    echo "    -b BLOCKSIZE      Number of lines for each job to be processed"
    echo "    -m MIX_CORPUS     A corpus to mix with"
    echo "    -o                Enable random omitting of sentences"
    echo "    -t TOKL1          External tokenizer command for lang1"
    echo "    -T TOKL2          External tokenizer command for lang2"
    echo "    -h                Shows this message"
}

# Read optional arguments
while getopts ":s:a:j:b:m:t:T:ho" options
do
    case "${options}" in
        s) SEED=$OPTARG;;
        a) ALIGN_CORPUS=$OPTARG;;
        j) JOBS=$OPTARG;;
        b) BLOCKSIZE=$OPTARG;;
        m) MIX_CORPUS=$OPTARG;;
        o) OMIT=true;;
        t) TOKL1=$OPTARG;;
        T) TOKL2=$OPTARG;;
        h) usage
            exit 0;;
        \?) usage 1>&2
            exit 1;;
    esac
done
if [ "$OMIT" = true ]; then
    OMIT_COMMAND="$OMIT_COMMAND -s $SEED"
else
    OMIT_COMMAND=cat
fi

# Read mandatory arguments
L1=${@:$OPTIND:1}
L2=${@:$OPTIND+1:1}
if [ -z "$L1" ] || [ -z "$2" ]
then
    echo "Error: <lang1> and <lang2> are mandatory" 1>&2
    echo "" 1>&2
    usage 1>&2
    exit 1
fi

MYTEMPDIR=$(mktemp -d)
echo "Using temporary directory $MYTEMPDIR" 1>&2

# Extract from TMX, omit, mix and shuffle
cat /dev/stdin \
    | $TMXT --codelist $L1,$L2 \
    | $OMIT_COMMAND \
    | cat - $MIX_CORPUS \
    | shuf --random-source=<(get_seeded_random $SEED) \
    >$MYTEMPDIR/omitted-mixed

# Append corpus to improve alignment
if [ ! -z $ALIGN_CORPUS ]
then
    CAT="head -$(cat $MYTEMPDIR/omitted-mixed | wc -l)"
    cat $MYTEMPDIR/omitted-mixed $ALIGN_CORPUS > $MYTEMPDIR/add-corpus
    mv $MYTEMPDIR/add-corpus $MYTEMPDIR/omitted-mixed
else
    CAT=cat
fi

# ANONYMIZE

# Tokenize
cut -f1 $MYTEMPDIR/omitted-mixed \
    | parallel -j$JOBS -k -l $BLOCKSIZE --pipe $TOKL1 \
    | awk '{print tolower($0)}' \
    >$MYTEMPDIR/f1.tok
cut -f2 $MYTEMPDIR/omitted-mixed \
    | parallel -j$JOBS -k -l $BLOCKSIZE --pipe $TOKL2 \
    | awk '{print tolower($0)}' \
    >$MYTEMPDIR/f2.tok

paste $MYTEMPDIR/f1.tok $MYTEMPDIR/f2.tok | sed 's%'$'\t''% ||| %g' >$MYTEMPDIR/fainput

# Word-alignments
export OMP_NUM_THREADS=$JOBS
$FASTALIGN -i $MYTEMPDIR/fainput -I 6 -d -o -v >$MYTEMPDIR/forward.align
$FASTALIGN -i $MYTEMPDIR/fainput -I 6 -d -o -v -r >$MYTEMPDIR/reverse.align
$ATOOLS -i $MYTEMPDIR/forward.align -j $MYTEMPDIR/reverse.align -c grow-diag-final-and >$MYTEMPDIR/symmetric.align

rm -Rf $MYTEMPDIR/forward.align $MYTEMPDIR/reverse.align $MYTEMPDIR/fainput

# NER and build TMX
paste $MYTEMPDIR/omitted-mixed $MYTEMPDIR/f1.tok $MYTEMPDIR/f2.tok $MYTEMPDIR/symmetric.align \
    | $CAT \
    | parallel -k -j$JOBS -l $BLOCKSIZE --pipe $NER \
    | $BUILDTMX $L1 $L2

echo "Removing temporary directory $MYTEMPDIR" 1>&2

rm -Rf $MYTEMPDIR
