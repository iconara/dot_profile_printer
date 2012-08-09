#!/bin/bash

cd $(dirname $0)

for ex in *.rb; do
  echo "Running $ex"
  ruby --profile.api $ex
  for fmt in pdf png; do
    input=$(echo $ex | sed 's/\.rb/\.gv/')
    output=$(echo $ex | sed "s/\.rb/\.$fmt/")
    dot $input -T$fmt -o $output
  done
done
