#!/bin/bash

#export TEST_TCPS="cubic cdg dctcp+ecn inigo"
export TEST_TCPS="dctcp cubic+ecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="500"
export TEST_DELAY="2ms"

export TEST_FLOW_DURATION=20
#export TEST_FLOW_OFFSET=30

export TEST_SIZE=2

#export TEST_EXTRA_ARGS="--loss \"random 2.5%\""

./run-inigo.sh iperf convergence-2flows-mini
