# biroamer

![License](https://img.shields.io/badge/License-GPLv3-blue.svg)

Biroamer is a small utility that will help you to ROAM (Random Omit Anonymize and Mix) your parallel corpus.
It will read the input TMX and output another TMX.
The resulting TMX will have its sentences randomly shuffled and omitted, mixed with another corpus, and its named entities highlighted with `<hi></hi>` tags.

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
The script receives a TMX file as an input and outputs another TMX. The needed parameters are `lang1`, `lang2` and a corpus in Moses format (tab-separated sentences: `sent1` `\t` `sent2`) for mixing.
```
Usage: biroamer.sh [options] <lang1> <lang2> <mix_corpus>
Options:
    -s SEED           Set random seed for reprodibility
    -a ALIGN_CORPUS   Extra corpus to improve alignment
                      It won't be included in the output
    -j JOBS           Number of jobs to run in parallel
    -b BLOCKSIZE      Number of lines for each job to be processed
    -h                Shows this message
```
If the input corpus plus the mixing corpus is not bigger enough (at least 100K sentences) it is advised to use `-a` option to add more sentences and improve the alignment.

### Example
```
$ cat l1-l2-file.tmx | ./biroamer.sh l1 l2 mix-corpus-l1-l2.txt > result-l1-l2.tmx
```
If your mixing corpus is in TMX format you can use `tmxt`, included in this repository, to obtain a sample in moses format:
```
$ cat mix-corpus.tmx | python tmxt/tmxt.py --codelist l1,l2 | head -$SIZE > mix-corpus.txt
```

## Configuration
Some of the parameters can be configured by changing variables in the `biroamer.sh` script:
 * $TOKL1 and $TOKL2: the tokenizer scripts for `lang1` and `lang2` respectively. Tokenizers have to read sentences from stdin and output the tokenized ones to stdout.
 * $PROCS: number of jobs to use in parallel, defaults to number of processes. Note that fastalign will use all the available processos regardless of the $PROCS value.
 * $BLOCKSIZE: the size of the blocks (in lines) for each parallel job. Not recommended lower than 10,000.

In the anonymization part, biroamer highlights named entities tagged as `PERSON` by [Spacy](https://spacy.io/) NER tagger, but sometimes entities are misclassified (e.g. tagging a person name as an organization name). So, if you want to be conservative you can configure the `ENTITIES` variable of `biner.py` and add more tags (see . For example:
```
ENTITIES = {"PERSON", "ORG", "GPE", "FAC", "PRODUCT"}
```
Are the ones that are most commonly confused with `PERSON`. See https://spacy.io/api/annotation#named-entities for more information about the tags.


___

![Connecting Europe Facility](https://www.paracrawl.eu/images/logo_en_cef273x39.png)

All documents and software contained in this repository reflect only the authors' view. The Innovation and Networks Executive Agency of the European Union is not responsible for any use that may be made of the information it contains.
