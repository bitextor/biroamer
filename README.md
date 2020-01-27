# biroamer

## Installation instructions

### Download

```
$ git clone --recurse-submodules http://gitlab.prompsit.com/paracrawl/biroamer.git
```

### Build fast_align

```
$ cd fast_align
$ mkdir build
$ cd build
$ cmake ..
$ make -j
```

### Install python requirements

```
$ pip3 install -r requirements.txt
```


## Usage

```
zcat l1-l2-file.tmx.gz | ./biroamer.sh l1 l2 > result-l1-l2.tmx.gz
```
