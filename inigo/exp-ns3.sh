#!/bin/bash

export TEST_TCPS="reno westwood inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="100"
export TEST_DELAY="2"

export TEST_FLOW_DURATION=100
export TEST_FLOW_OFFSET=0

export TEST_SIZE=2

export TEST_EXTRA_ARGS="--hostbw 5.0 --maxq 100"

./run-inigo.sh iperf ns3
