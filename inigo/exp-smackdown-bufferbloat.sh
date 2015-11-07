#!/bin/bash

export TEST_TCPS="inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="110"
export TEST_DELAY="13"

export TEST_FLOW_DURATION=20
export TEST_FLOW_OFFSET=10

export TEST_SIZE=2

export TEST_EXTRA_ARGS="--maxq 4000"

./run-inigo.sh reno_cubic_westwood_inigo highbloat-smackdown
