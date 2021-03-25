#!/bin/bash

flink_app_source_dir=./app/flink-app
lambda_build_dir=build
lambda_source_dir=./app/lambda-function
lambda=stocks.py
lambda_target=stocks.zip

display_usage() {
    echo "This script must be invoked with a supported action"
    echo "available actions: [build_all clean_all build_flink clean_flink build_lambda clean_lambda]"
    echo ""
}

clean_flink_app() {
    echo "cleaning flink app"
    mvn -f $flink_app_source_dir/pom.xml clean
}

package_flink_app() {
    echo "packaging flink app"
    mvn -f $flink_app_source_dir/pom.xml package
}

clean_lambda() {
    echo "cleaning lambda"
    rm -rf $lambda_build_dir
}

package_lambda() {
    echo "packaging lambda"
    mkdir $lambda_build_dir
    zip -j $lambda_build_dir/$lambda_target $lambda_source_dir/$lambda
}

# clean flink app
if [[ ( $1 == "clean_all") ]]
then 
  clean_flink_app
  clean_lambda
fi

# package lambda
if [[ ( $1 == "build_all") ]]
then
  clean_lambda
  package_lambda
  clean_flink_app
  package_flink_app
fi

# clean flink app
if [[ ( $1 == "clean_flink") ]]
then 
  clean_flink_app
fi

# package flink app
if [[ ( $1 == "build_flink") ]]
then 
  clean_flink_app
  package_flink_app
fi

# clean lambda
if [[ ( $1 == "clean_lambda") ]]
then 
  clean_lambda
fi

# package lambda
if [[ ( $1 == "build_lambda") ]]
then
  clean_lambda
  package_lambda
fi

# display usage
if [[ $# -le 1 ]]
then
  if [[ $1 != 'build_all' && $1 != 'clean_all' && $1 != 'clean_flink' && $1 != 'flink' && $1 != 'clean_lambda' && $1 != 'lambda' ]]
  then
    display_usage
    exit 1
  fi
fi
