#!/bin/bash

echo "Building Kinesis Analytics app..."
#mkdir ../build
mvn -f ./app/kinesis-analytics-app/pom.xml clean package