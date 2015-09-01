#!/bin/bash

export TEST_TCPS="dctcp+hostecn cubic cubic+hostecn cdg cdg+hostecn inigo inigo+hostecn"
#export TEST_TCPS="dctcp inigo"
#export TEST_TCPS="dctcp+hostecn cubic+hostecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="500"
export TEST_DELAY="2ms"

export TEST_FLOW_DURATION=150
export TEST_FLOW_OFFSET=30

export TEST_SIZE=6

export TEST_EXTRA_ARGS=""

./run-inigo.sh iperf convergence-5flows
