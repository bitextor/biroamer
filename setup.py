#!/usr/bin/env python

import setuptools
import subprocess
import os.path

if __name__=="__main__":
    with open("README.md", "r") as fh:
        long_description = fh.read()
    with open("requirements.txt") as rf:
        requirements = rf.read().splitlines()
    with open("tmxt/requirements.txt") as ef:
        requirements.extend(ef.read().splitlines())

    setuptools.setup(
        name="biroamer",
        version="2.0",
        install_requires=requirements,
        license="GNU General Public License v3.0",
        author="Prompsit Language Engineering",
        author_email="info@prompsit.com",
        description="Utility that will help you ROAM your parallel corpus   ",
        maintainer="Marta Bañon",
        maintainer_email="mbanon@prompsit.com",
        long_description=long_description,
        long_description_content_type="text/markdown",
        url="https://github.com/bitextor/biroamer",
        package_dir={'biroamer': ''},
        packages=["biroamer", "biroamer.tmxt"],
        classifiers=[
            "Environment :: Console",
            "Intended Audience :: Science/Research",
            "Programming Language :: Python :: 3.7",
            "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
            "Operating System :: POSIX :: Linux",
            "Topic :: Scientific/Engineering :: Artificial Intelligence",
            "Topic :: Text Processing :: Linguistic",
            "Topic :: Software Development :: Libraries :: Python Modules",
            "Topic :: Text Processing :: Filters"
        ],
        project_urls={
            "Biroamer on GitHub": "https://github.com/bitextor/biroamer",
            "Prompsit Language Engineering": "http://www.prompsit.com",
            "Paracrawl": "https://paracrawl.eu/"
             },
        entry_points={
            'console_scripts': [
                'tmxplore=biroamer.tmxt.tmxplore:main',
                'tmxt=biroamer.tmxt.tmxt:main',
                'biner=biroamer.biner:main',
                'toktok=biroamer.toktok:main',
                'omit=biroamer.omit:main',
                'buildtmx=biroamer.buildtmx:args_and_main'
            ]
        },
        scripts=["biroamer"]
    )
