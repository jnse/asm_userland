#!/bin/bash -e

SRC_DIR=$1

echo "---------------------------------------"
echo "- Baseline malloc test (glibc malloc) -"
echo "---------------------------------------"
echo ""
time ${SRC_DIR}/malloc_baseline
echo ""
echo ""
echo "---------------------------------------"
echo "- asm_userland malloc                 -"
echo "---------------------------------------"
echo ""
time ${SRC_DIR}/malloc_bench
echo ""
