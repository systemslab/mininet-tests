#!/bin/bash

export TEST_TCPS="inigo"
export TEST_AQM="cake"

export TEST_BW="110"
export TEST_DELAY="13ms"

export TEST_FLOW_DURATION=20
export TEST_FLOW_OFFSET=5

export TEST_SIZE=3

export TEST_EXTRA_ARGS="--maxq 4000"

./run-inigo.sh rrul_be
