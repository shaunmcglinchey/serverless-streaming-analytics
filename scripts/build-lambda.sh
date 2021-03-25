#!/bin/bash

echo "Building lambda package..."

build_dir=../build

rm -rf $build_dir
mkdir $build_dir
zip -j $build_dir/stocks.zip ../app/lambda_function/stocks.py
