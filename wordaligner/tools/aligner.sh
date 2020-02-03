#!/bin/bash
# ./aligner.sh input1.csv.gz input2.csv.gz ...
# Generates results at /var/aligndata/output

L1=en
L2=es
DATA_DIR=/var/aligndata

MOSES_HOME=/opt/mosesdecoder
SCRIPTS=/opt/tools
EXTERNAL_BIN_DIR=/usr/local/bin

CLEAN_MINLEN=1
CLEAN_MAXLEN=50

PROCS=$(getconf _NPROCESSORS_ONLN)

# Create DATA_DIR if does not exist
if [ ! -d "$DATA_DIR" ]; then
  mkdir -p $DATA_DIR
fi

WORKSUBDIR=$(mktemp -p $DATA_DIR -d)
declare -A LENGTHS
# Extract from CSV 
for INPUT in $*; do
  NAME=$(basename $INPUT .csv.gz)
  zcat $INPUT | \
  python3 $SCRIPTS/extract_from_csv.py $L1 $L2 >$WORKSUBDIR/$NAME.$L1-$L2
  cat $WORKSUBDIR/$NAME.$L1-$L2
done >$WORKSUBDIR/TOTAL.$L1-$L2

# Tokenize both sides independently
cut -f1 $WORKSUBDIR/TOTAL.$L1-$L2 | \
parallel --pipe -k -j$PROCS -l 50000 \
  $MOSES_HOME/scripts/tokenizer/tokenizer.perl -no-escape -l $L1 | \
gawk '{if(match($0, /^([^[:alnum:]]|[ ])+/)){ print substr($0, RSTART, RLENGTH) "\t" substr($0, RSTART+RLENGTH);} else{print "\t" $0}}' >$WORKSUBDIR/TOTAL.toktabs.$L1
cut -f1 $WORKSUBDIR/TOTAL.toktabs.$L1 >$WORKSUBDIR/TOTAL.pretok.$L1
cut -f2 $WORKSUBDIR/TOTAL.toktabs.$L1 >$WORKSUBDIR/TOTAL.tok.$L1

cut -f2 $WORKSUBDIR/TOTAL.$L1-$L2 | \
parallel --pipe -k -j$PROCS -l 50000 \
  $MOSES_HOME/scripts/tokenizer/tokenizer.perl -no-escape -l $L2 | \
gawk '{if(match($0, /^([^[:alnum:]]|[ ])+/)){ print substr($0, RSTART, RLENGTH) "\t" substr($0, RSTART+RLENGTH);} else{print "\t" $0}}' >$WORKSUBDIR/TOTAL.toktabs.$L2
cut -f1 $WORKSUBDIR/TOTAL.toktabs.$L2 >$WORKSUBDIR/TOTAL.pretok.$L2
cut -f2 $WORKSUBDIR/TOTAL.toktabs.$L2 >$WORKSUBDIR/TOTAL.tok.$L2

# Train truecaser
if (( PROCS > 1 )); then
  $MOSES_HOME/scripts/recaser/train-truecaser.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L1.model \
    --corpus $WORKSUBDIR/TOTAL.tok.$L1 &
  $MOSES_HOME/scripts/recaser/train-truecaser.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L2.model \
    --corpus $WORKSUBDIR/TOTAL.tok.$L2
  wait
else 
  $MOSES_HOME/scripts/recaser/train-truecaser.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L1.model \
    --corpus $WORKSUBDIR/TOTAL.tok.$L1
  $MOSES_HOME/scripts/recaser/train-truecaser.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L2.model \
    --corpus $WORKSUBDIR/TOTAL.tok.$L2
fi

# Truecase text
cat $WORKSUBDIR/TOTAL.tok.$L1 | \
parallel --pipe -k -j$PROCS -l 50000 \
  $MOSES_HOME/scripts/recaser/truecase.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L1.model >$WORKSUBDIR/TOTAL.true.$L1
cat $WORKSUBDIR/TOTAL.tok.$L2 | \
parallel --pipe -k -j$PROCS -l 50000 \
  $MOSES_HOME/scripts/recaser/truecase.perl \
    --model $WORKSUBDIR/TOTAL.truecaser.$L2.model >$WORKSUBDIR/TOTAL.true.$L2

# Paste pretoks
paste $WORKSUBDIR/TOTAL.pretok.$L1 $WORKSUBDIR/TOTAL.true.$L1 | \
gawk '{gsub("[ ]*\t", " "); gsub("^[ ]+", ""); print;}' >$WORKSUBDIR/TOTAL.truepre.$L1

paste $WORKSUBDIR/TOTAL.pretok.$L2 $WORKSUBDIR/TOTAL.true.$L2 | \
gawk '{gsub("[ ]*\t", " "); gsub("^[ ]+", ""); print;}' >$WORKSUBDIR/TOTAL.truepre.$L2


# Clean corpus
$MOSES_HOME/scripts/training/clean-corpus-n.perl \
  $WORKSUBDIR/TOTAL.truepre $L1 $L2 $WORKSUBDIR/TOTAL.clean \
  $CLEAN_MINLEN $CLEAN_MAXLEN $WORKSUBDIR/TOTAL.retained

# Direct alignment
$MOSES_HOME/scripts/training/train-model.perl \
  --alignment grow-diag-final-and \
  --root-dir $WORKSUBDIR \
  --corpus $WORKSUBDIR/TOTAL.clean -f $L1 -e $L2 \
  --mgiza --mgiza-cpus=$((PROCS/2)) --parallel \
  --first-step 1 --last-step 3 \
  --external-bin-dir $EXTERNAL_BIN_DIR \
  --temp-dir $DATA_DIR

mv $WORKSUBDIR/model/aligned.grow-diag-final-and $WORKSUBDIR/TOTAL.$L1-$L2.symali
  
# Reverse alignment (faster)
$MOSES_HOME/scripts/training/train-model.perl \
  --alignment grow-diag-final-and \
  --root-dir $WORKSUBDIR \
  --corpus $WORKSUBDIR/TOTAL.clean -f $L2 -e $L1 \
  --mgiza --mgiza-cpus=$((PROCS/2)) --parallel \
  --first-step 3 --last-step 3 \
  --external-bin-dir $EXTERNAL_BIN_DIR \
  --temp-dir $DATA_DIR

mv $WORKSUBDIR/model/aligned.grow-diag-final-and $WORKSUBDIR/TOTAL.$L2-$L1.symali

zcat $WORKSUBDIR/giza.$L1-$L2/$L1-$L2.A3.final.gz | \
python3 $SCRIPTS/a3_to_pharaoh.py | \
cut -f2,5 >$WORKSUBDIR/TOTAL.$L1-$L2.aliscore

zcat $WORKSUBDIR/giza.$L2-$L1/$L2-$L1.A3.final.gz | \
python3 $SCRIPTS/a3_to_pharaoh.py | \
cut -f2,5 >$WORKSUBDIR/TOTAL.$L2-$L1.aliscore

python3 $SCRIPTS/generate_output.py $L1 $L2 $WORKSUBDIR $*

#clean
rm -Rf $WORKSUBDIR

echo "SUCCESS: results are at $DATA_DIR/output"
