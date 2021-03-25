#!/bin/bash

echo "Building Kinesis Analytics app..."
mvn -f ./app/kinesis-analytics-app/pom.xml clean package