#!/bin/bash

export TEST_TCPS="inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="700"
export TEST_DELAY="1ms"

export TEST_FLOW_DURATION=60
export TEST_FLOW_OFFSET=0

export TEST_SIZE=21

export TEST_EXTRA_ARGS=""

./run-inigo.sh iperf incast-20flows
