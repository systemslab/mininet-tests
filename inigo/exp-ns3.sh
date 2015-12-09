#!/bin/bash

export TEST_TCPS="reno westwood inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="10"
export TEST_DELAY="45"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=0

export TEST_SIZE=2

export TEST_EXTRA_ARGS="--bottleneck 0.2"

./run-inigo.sh iperf ns3
