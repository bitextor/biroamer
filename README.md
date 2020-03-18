# biroamer

![License](https://img.shields.io/badge/License-GPLv3-blue.svg)

Biroamer is a small utility that will help you to ROAM (Random Omit Anonymize and Mix) your parallel corpus.
It will read the input TMX and output another TMX.
The resulting TMX will have its sentences randomly shuffled and omitted, mixed with another corpus, 
and its named entities highlighted with `<hi></hi>` tags.

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

The script receives a TMX file as an input and outputs another TMX. 
The needed parameters are `lang1` and `lang2` (in ISO 639-1 format) and a corpus in Moses format 
(tab-separated sentences: `sent1` `\t` `sent2`) for mixing.

```
Usage: biroamer.sh [options] <lang1> <lang2> <mix_corpus>
Options:
    -s SEED           Set random seed for reproducibility (relevant for Omitting and Randomizing steps)
    -a ALIGN_CORPUS   Extra corpus to improve alignment . It won't be included in the output
    -j JOBS           Number of jobs to run in parallel
    -b BLOCKSIZE      Number of lines for each job to be processed
    -h                Shows this message
```

If the input corpus plus the mixing corpus is not big enough (at least 100K sentences), 
it is advised to use the `-a` option to add more sentences and improve the alignment.

If your mixing corpus is in TMX format, you can use `tmxt` (included in this repository) 
to obtain a sample of size $SIZE in the aforementioned Moses format:

```
$ cat mixing-corpus.tmx | python tmxt/tmxt.py --codelist l1,l2 | head -$SIZE > mix-corpus.txt
```

### Example

With `en-es-file.tmx` being an input TMX file containing translation units like:

```
<tu>
    <tuv xml:lang="en">
        <seg>The e-mail address of John Doe is john@doe.com<seg>
    </tuv>
    <tuv xml:lang="es">
        <seg>El correo electrónico de John Doe es john@doe.com<seg>
    </tuv>
</tu>
```

Mixing corpus `mix-corpus-en-es.txt` being:

```
Can you trust your neighbours?        ¿Puedes confiar en tus vecinos?
Bert and Margaret raised seven sons in the 50's.       Bert y Margaret criaron siete hijos en los 50.
```

And after running the following command:

```
$ cat en-es-file.tmx | ./biroamer.sh en es mix-corpus-en-es.txt > result-en-es.tmx
```


Will result in `results-en-es.tmx` being like:

```
<tu>
    <tuv xml:lang="en">
        <seg><hi>Bert</hi> and <hi>Margaret</hi> raised seven sons in the 50's.<seg>
    </tuv>
    <tuv xml:lang="es">
        <seg><hi>Bert</hi> y <hi>Margaret</hi> criaron siete hijos en los 50.<seg>
    </tuv>
</tu>
<tu>
    <tuv xml:lang="en">
        <seg>The e-mail address of <hi>John Doe</hi> is <hi>john@doe.com</hi><seg>
    </tuv>
    <tuv xml:lang="es">
        <seg>El correo electrónico de <hi>John Doe</hi> es <hi>john@doe.com</hi><seg>
    </tuv>
</tu>
<tu>
    <tuv xml:lang="en">
        <seg>Can you trust your neighbours?<seg>
    </tuv>
    <tuv xml:lang="es">
        <seg>¿Puedes confiar en tus vecinos?<seg>
    </tuv>
</tu>
```


## Configuration

Some of the parameters can be configured by changing variables in the `biroamer.sh` script:
 * $TOKL1 and $TOKL2: the tokenizer scripts for `lang1` and `lang2` respectively. Tokenizers must be able to read sentences from stdin and output the tokenized ones to stdout.

In the anonymization step, biroamer highlights named entities tagged as `PERSON` by [Spacy](https://spacy.io/) NER tagger,
but sometimes entities are misclassified (e.g. by tagging a person name as an organization name). 
So, if you want to be conservative you can configure the `ENTITIES` variable of `biner.py` and add more tags. For example:

```
ENTITIES = {"PERSON", "ORG", "GPE", "FAC", "PRODUCT"}
```
Are the ones that are most commonly confused with `PERSON`. 
See https://spacy.io/api/annotation#named-entities for more information about the tags.


___

![Connecting Europe Facility](https://www.paracrawl.eu/images/logo_en_cef273x39.png)

All documents and software contained in this repository reflect only the authors' view. The Innovation and Networks Executive Agency of the European Union is not responsible for any use that may be made of the information it contains.
