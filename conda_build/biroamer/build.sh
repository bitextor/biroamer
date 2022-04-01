
# Build and install fast_align
pushd fast_align > /dev/null

mkdir build && cd build
CPATH="$PREFIX/include:$CPATH" cmake "-DCMAKE_INSTALL_PREFIX=$PREFIX" ..
CPATH="$PREFIX/include:$CPATH" LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH" make -j

popd > /dev/null

# Install Biroamer
export PIP_NO_INDEX="False" # We are downloading requisites from PyPi
export PIP_NO_DEPENDENCIES="False" # We need the dependencies from our defined dependencies
export PIP_IGNORE_INSTALLED="False" # We need to take into account the dependencies

$PYTHON -m pip install .
$PYTHON -c "from flair.models import SequenceTagger; SequenceTagger.load('flair/ner-english-fast')"