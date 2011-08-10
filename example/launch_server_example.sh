#!/usr/bin/env bash

export PYTHONPATH=kohlrabi/:example/:$PYTHONPATH
echo 
echo Starting Kohlrabi Server using config.yaml.example
echo Try visiting http://localhost:8888/kohlrabi/
echo run: \'python ./pusher_example.py\' to push some sample data to the server
echo Press C-c to stop
echo

python -m main -c example/config.yaml.example
