#!/bin/bash

export TEST_TCPS="cubic inigo"
export TEST_ECN="ecn"
export TEST_AQM="cake"

export TEST_WWW="cubic+cake inigo+cake"
export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="10"
export TEST_DELAY="10ms"

export TEST_FLOW_DURATION=30
export TEST_FLOW_OFFSET=10

export TEST_SIZE=3

#export TEST_EXTRA_ARGS="--debug --inigo-args \"deadline_aware=1\""

./run-inigo.sh
