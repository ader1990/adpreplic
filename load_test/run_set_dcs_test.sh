#!/bin/bash

time erl -noshell -name avladu@adpreplic-client.com -s \
    run_test test_set_dcs "load_test_value.txt" -s init stop