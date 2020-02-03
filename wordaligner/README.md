# Word aligner tool

## Introduction

This is a self-contained tool that provides all the requirements necessary to calculate word alignments for gzipped csv files in English and Spanish.

## Quick start

### Requirements

Just Docker.

### Image building

First, you need to compile the docker image:

```bash
$ docker build -t wordaligner:latest .
```
It will take a while.

### Running the examples

Now you can run the example task to check that everything works. I assume that your working directory is the directory containing this README.md file.

```bash
$ docker run --rm -v"$(pwd)/examples:/var/aligndata" wordaligner:latest /opt/tools/aligner.sh "/var/aligndata/*.csv.gz"
```

Finally, you can take a look at the results at the examples/output directory. They will have the same names as the input files but with the `-output.csv.gz` suffix.

## General usage

### The execution command

The general form of the execution command is the following:

```bash
$ docker run --rm -v"FULL_PATH_TO_YOUR_SHARED_DIRECTORY:/var/aligndata" wordaligner:latest /opt/tools/aligner.sh [/var/aligndata/file.csv.gz ...]
```
Where:
* `docker run` creates a container with the specified image (see below).
* The `--rm` parameter ensures that the Docker container will be removed after the execution.
* The parameter `-v"FULL_PATH_TO_YOUR_SHARED_DIRECTORY:/var/aligndata"` expects the full path of a shared folder between the Docker host (your machine) and the container, which will be used as input data source, output data repository and temporary folder. It is important for Docker that the path specified is a full path.
* The image of the Docker container, `wordaligner:latest`.
* The word aligner command `/opt/tools/aligner.sh`.
* The list of files to align `[/var/aligndata/file.csv.gz ...]`. You can specify `"var/aligndata/*.csv.gz"` to include all `csv.gz`files present in the `FULL_PATH_TO_YOUR_SHARED_DIRECTORY`folder. Please note that the double quotes enclosing this part of the command are required.

### Input data

It is expected to receive gzipped csv files, with a header with values "en" and "es". The files at the examples directory have the exact required format. You can specify as many as you have, want. And they need to be located in the shared directory

### Results

The results will consist in similar `csv.gz` files, one for each of the input files specified, and with matching names. Note that some of the sentences could disappear at the output if they are longer than 50 tokens of size. The resulting files will be located at `FULL_PATH_TO_YOUR_SHARED_DIRECTORY/output`.

