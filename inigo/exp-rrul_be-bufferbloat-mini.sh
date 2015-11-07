#!/bin/bash

export TEST_TCPS="cubic inigo"
export TEST_ECN="ecn"
export TEST_AQM="cake"

export TEST_BW="10"
export TEST_DELAY="10"

export TEST_FLOW_DURATION=60
export TEST_FLOW_OFFSET=10

export TEST_SIZE=3

export TEST_EXTRA_ARGS="--maxq 4000"

./run-inigo.sh rrul_be lowspeed-highbloat
