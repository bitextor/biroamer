#!/bin/bash
set -eo pipefail

export LANG=C.UTF-8

# Get the script directory
DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ -x $DIR/build/fast_align/fast_align ] || [ -x $DIR/build/fast_align/atools ]; then
    PATH=$DIR/fast_align/build:$PATH
elif [ -x $CONDA_PREFIX/fast_align/build/fast_align ] || [ -x $CONDA_PREFIX/fast_align/build/atools ]; then
    PATH=$CONDA_PREFIX/fast_align/build:$PATH
fi

TMXT=tmxt
OMIT_COMMAND=omit
FASTALIGN=fast_align
ATOOLS=atools
export NER=biner
BUILDTMX=buildtmx
NODELTEMP=false

JOBS=$(getconf _NPROCESSORS_ONLN)
BLOCKSIZE=10000
SEED=$RANDOM

TOKL1=toktok
TOKL2=toktok

get_seeded_random()
{
    seed="$1"
    openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
        </dev/zero 2>/dev/null
}

ner_job ()
{
    local slot=$1
    local slot=$((slot-1))
    # Determine gpu slot
    if  which nvidia-smi >/dev/null; then
        # If there is cuda available check for the env variable
        if [ -z ${CUDA_VISIBLE_DEVICES+x} ]; then
            # if CUDA variable not defined, use provided slot
            export CUDA_VISIBLE_DEVICES=$slot
        elif [[ -z "$CUDA_VISIBLE_DEVICES" ]]; then
            : # If it's empty, do nothing
            # ner won't use gpu in this case
        else
            # if it's defined, use the GPU that pointed out by the slot
            IFS=',' read -r -a array <<< "$CUDA_VISIBLE_DEVICES"
            export CUDA_VISIBLE_DEVICES=${array[$slot]}
        fi
    fi
    # For non-gpu don't redefine CUDA env variable

    $NER
}
export -f ner_job

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
    echo "    -p                Do not delete temporary directory"
    echo "    -h                Shows this message"
}

# Read optional arguments
while getopts ":s:a:j:b:m:t:T:pho" options
do
    case "${options}" in
        s) SEED=$OPTARG;;
        a) ALIGN_CORPUS=$OPTARG;;
        j) JOBS=$OPTARG;;
        b) BLOCKSIZE=$OPTARG;;
        m) MIX_CORPUS=$OPTARG;;
        o) OMIT=true;;
        p) NODELTEMP=true;;
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

# Determine number of gpu jobs
if  which nvidia-smi >/dev/null; then
    if [ -z ${CUDA_VISIBLE_DEVICES+x} ]; then
        # For undefined variable use all GPUs
        NER_JOBS=$(nvidia-smi -L | wc -l)
        echo Using all $NER_JOBS GPUs >&2
    elif [[ -z "$CUDA_VISIBLE_DEVICES" ]]; then
        # For empty variable use as many as CPUs
        NER_JOBS=$JOBS
        echo Disabled GPUs, using $NER_JOBS CPUs >&2
    else
        # Defined not empy variable, count devices
        NER_JOBS=$(echo ${CUDA_VISIBLE_DEVICES//,/ } | wc -w)
        echo Using $NER_JOBS GPUs >&2
    fi
else
    NER_JOBS=$JOBS
    echo No GPUs available, using $NER_JOBS CPUs >&2
fi


MYTEMPDIR=$(mktemp -d)
if [ "$NODELTEMP" = false ]; then
    # Remove temporary dir when script fails or finishes
    trap "rm -Rr $MYTEMPDIR" EXIT
fi
echo "Using temporary directory $MYTEMPDIR" 1>&2

# Extract from TMX, omit, mix and shuffle
cat /dev/stdin \
    | $TMXT --codelist $L1,$L2,source-document,custom-score \
    | $OMIT_COMMAND \
    | cat - $MIX_CORPUS \
    | shuf --random-source=<(get_seeded_random $SEED) \
    >$MYTEMPDIR/omitted-all

cut -f1-2 $MYTEMPDIR/omitted-all >$MYTEMPDIR/omitted-mixed

cut -f3- $MYTEMPDIR/omitted-all >$MYTEMPDIR/omitted-data


# Append corpus to improve alignment
if [ ! -z $ALIGN_CORPUS ]
then
    CAT="tail -$(cat $MYTEMPDIR/omitted-mixed | wc -l)"
    cat $ALIGN_CORPUS $MYTEMPDIR/omitted-mixed >$MYTEMPDIR/add-corpus
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
    | cat \
    | parallel -k -j$NER_JOBS -l $BLOCKSIZE --pipe ner_job {%} \
    |  paste - $MYTEMPDIR/omitted-data \
    | grep -v '<entity>' \
    |  awk -F"\t" '{ print $3"\t"$4"\t"$1"\t"$2"\t"$5}' 


echo "Removing temporary directory $MYTEMPDIR" 1>&2
