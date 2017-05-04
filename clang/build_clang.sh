#!/bin/bash

# NOTE: to sucessfully build lldb on Mac OS X, you will have to do this:
# https://llvm.org/svn/llvm-project/lldb/trunk/docs/code-signing.txt

if [[ $# -eq 0 ]] ; then
    echo "Usage:"
    echo "  build_clang TARGET_DIR"
    echo "Example:"
    echo "  build_clang ~/clang400"
    exit 1
fi

if [ "$(uname -s)" == "Darwin" ]; then
  export CC=`which clang`
  export CXX=`which clang++`
  export NCPUS=`sysctl -n hw.ncpu`
elif [ "$(uname -s)" == "Linux" ]; then
  export GCCDIR=$(dirname `which gcc`)/../
  export CC=$GCCDIR/bin/gcc
  export CXX=$GCCDIR/bin/g++
  export GCC_CMAKE_OPTION="-DGCC_INSTALL_PREFIX=$GCCDIR"
  export NCPUS=`nproc`
fi

TARGET_DIR=`pwd`
if [ ! -z "$1" ]; then
  TARGET_DIR=$1
fi

CURRENT_DIR=`pwd`
TARGET_INSTALL_DIR=$TARGET_DIR/install
TARGET_BUILD_DIR=$TARGET_DIR/build

# Build Clang
mkdir -p ${TARGET_BUILD_DIR}
cd ${TARGET_BUILD_DIR}
cmake -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${TARGET_INSTALL_DIR} ${GCC_CMAKE_OPTION} ../llvm
make -j${NCPUS}
make install

#make check-libcxx -j${NCPUS}

cd ${TARGET_DIR}

if [ "$(uname -s)" == "Linux" ]; then

  # Export relevant environment variables to be able to call Clang
  export PATH=${TARGET_INSTALL_DIR}/bin:$PATH
  export LD_LIBRARY_PATH=${TARGET_INSTALL_DIR}/lib:$LD_LIBRARY_PATH

  # Compile libcxxabi
  mkdir ${TARGET_DIR}/libcxxabi/build
  cd ${TARGET_DIR}/libcxxabi/build
  cmake -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ ..
  make -j${NCPUS}
  mv lib/* ${TARGET_INSTALL_DIR}/lib/

  # Compile libcxx
  mkdir ${TARGET_DIR}/libcxx/build
  cd ${TARGET_DIR}/libcxx/build
  CC=clang CXX=clang++ cmake -G "Unix Makefiles" -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_LIBCXXABI_INCLUDE_PATHS="../../libcxxabi/include" -DLIBCXX_CXX_ABI_INCLUDE_PATHS="../../libcxxabi/include" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${TARGET_INSTALL_DIR} ..
  make -j${NCPUS} && make install

fi

cd ${CURRENT_DIR}
