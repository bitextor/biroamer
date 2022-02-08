# biroamer

![License](https://img.shields.io/badge/License-GPLv3-blue.svg)

Biroamer is a small utility that will help you anonymise or, better said, ROAM (Random, Omit, Anonymize and Mix) your parallel corpus. It will read an input TMX and output a ROAMed TMX. This means that the resulting TMX will have sentences from the input file randomly shuffled and omitted (around of 10% of the setences will be removed), mixed with another corpus, and with named entities highlighted using `<hi></hi>` tags.

Currently, Biroamer identifies named entities using [Flair](https://github.com/flairNLP/flair) NER tagger on one side of the corpus (only English has been tested, but other languages could also be used) and tag the equivalent named-entity on the other side of the corpus using word alignments as computed by [fast_align](https://github.com/clab/fast_align).

## Installation instructions

### Download

```bash
git clone --recursive http://github.com/bitextor/biroamer.git
```

### Requirements

* Python >= 3.7
* GNU Parallel

### Build fast_align

Install packages required by fast_align:

```bash
sudo apt install libgoogle-perftools-dev libsparsehash-dev
```

And build it:

```bash
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/your/prefix/path
make -j all install
```

### Install Python requirements

```bash
pip install .
```

Download Flair model
```
python -c "from flair.models import SequenceTagger; SequenceTagger.load('flair/ner-english-fast')"
```

## Usage

The script receives a TMX file as an input and outputs another TMX.
The needed parameters are `lang1` and `lang2` (in ISO 639-1 format).
Optionally a corpus in Moses format (tab-separated sentences: `sent1` `\t` `sent2`) in the same language combination used in the parameters can be given to be mixed with the input corpus.
Also using `-o` will randomly omit about 10% of the sentences from the input corpus.

```bash
Usage: biroamer [options] <lang1> <lang2>
Options:
    -s SEED           Set random seed for reprodibility
    -a ALIGN_CORPUS   Extra corpus to improve alignment
                      It won't be included in the output
    -j JOBS           Number of jobs to run in parallel
    -b BLOCKSIZE      Number of lines for each job to be processed
    -m MIX_CORPUS     A corpus to mix with
    -o                Enable random omitting of sentences
    -t TOKL1          External tokenizer command for lang1
    -T TOKL2          External tokenizer command for lang2
    -h                Shows this message
```

If the input corpus plus the mixing corpus are not big enough (at least 100K sentences) to compute word alignments to tag named entities in the other side of the corpus, it is advised to use the `-a` option to add more sentences and improve this alignment.

If your mixing corpus is in TMX format, you can use `tmxt` (included in this repository)
to obtain a sample of size $SIZE in the aforementioned Moses format:

```bash
$ cat mixing-corpus.tmx | python tmxt/tmxt.py --codelist l1,l2 | head -$SIZE > mix-corpus.txt
```

### Example

With `en-es-file.tmx` being an input TMX file containing translation units like:

```text
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

```text
Can you trust your neighbours?        ¿Puedes confiar en tus vecinos?
Bert and Margaret raised seven sons in the 50's.       Bert y Margaret criaron siete hijos en los 50.
```

And after running the following command:

```bash
$ cat en-es-file.tmx | biroamer -o -m mix-corpus-en-es.txt en es > result-en-es.tmx
```

Will result in `results-en-es.tmx` being like:

```text
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

External tokenizer command can be used with `-t` and `-T` for `lang1` and `lang2` respectively.
For example:

```bash
$ cat en-es-file.tmx \
    | biroamer \
        -o -m mix-corpus-en-es.txt \
        -t "mosesdecoder/scripts/tokenizer/tokenizer.perl -l en -no-escape" \
        -T "mosesdecoder/scripts/tokenizer/tokenizer.perl -l es -no-escape" \
        en es \
        > result-en-es.tmx
```

But it is recommended to use the default tokenizer unless you are working with a language that NLTK does not [support](https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/tokenizers/punkt.zip).
Also note that the tokenizer command is already parallelized inside biroamer using parallel, so it is advised to use single-threaded commands.

### Disable GPU
By default, Flair uses GPUs if available.
If you want to disable GPU processing or choose which GPUs should use, you just need to set `CUDA_VISIBLE_DEVICES` environment variable.

To avoid using GPU:
```bash
$ cat en-es-file.tmx | CUDA_VISIBLE_DEVICES="" biroamer -o -m mix-corpus-en-es.txt en es > result-en-es.tmx
```

or use only 2 of 4 available:
```bash
$ cat en-es-file.tmx | CUDA_VISIBLE_DEVICES="0,1" biroamer -o -m mix-corpus-en-es.txt en es > result-en-es.tmx
```

___

![Connecting Europe Facility](https://www.paracrawl.eu/images/logo_en_cef273x39.png)

All documents and software contained in this repository reflect only the authors' view. The Innovation and Networks Executive Agency of the European Union is not responsible for any use that may be made of the information it contains.
