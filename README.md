# biroamer
Biroamer is a small utility that will help you to ROAM(Random Omit Anonymize and Mix) your parallel corpus. It will read the input TMX and output another TMX. The rexulting TMX will have its sentences randomly shuffled and omitted, mixed with another corpus and entities highlighted with `<hi> </hi>` tags.

## Installation instructions

### Download

```
$ git clone --recursive http://gitlab.prompsit.com/paracrawl/biroamer.git
```

### Requirements

 * Python >= 3.7
 * GNU Parallel

### Build fast_align
Install packages required by fast_align:
```
sudo apt-get install libgoogle-perftools-dev libsparsehash-dev
```

And build it:
```
$ cd fast_align
$ mkdir build
$ cd build
$ cmake ..
$ make -j
```

### Install Python requirements

```
$ pip install -r requirements.txt
$ python -m spacy download en_core_web_sm
```


## Usage
The script receives a TMX file as an input and outputs another TMX. The needed parameters are `lang1`, `lang2` and a corpus in moses format (tab-separated sentences: `sent1` `\t` `sent2`) for mixing.
```
$ cat l1-l2-file.tmx | ./biroamer.sh l1 l2 mix-corpus-l1-l2.txt > result-l1-l2.tmx
```
If your mixing corpus is in TMX format you can use `tmxt`, included in this repository, to obtain a sample in moses format:
```
cat mix-corpus.tmx | python tmxt/tmxt.py --codelist l1,l2 | head -$SIZE > mix-corpus.txt
```

## Configuration
Some of the parameters can be configured changing the variables of the `biroamer.sh` script:
 * $TOKL1 and $TOKL2: the tokenizer scripts for `lang1` and `lang2` respectively. Tokenizers have to read sentences from stdin and output the tokenized ones to stdout.
 * $PROCS: number of jobs to use in parallel, defaults to number of processes. Note that fastalign will use all the available processos regardless of the $PROCS value.
 * $BLOCKSIZE: the size of the blocks (in lines) for each parallel job. Not recommended lower than 10,000.
