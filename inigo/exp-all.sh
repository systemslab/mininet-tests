#!/bin/bash

export TEST_TCPS="cubic cdg dctcp inigo"
export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo inigo+cake"
export TEST_BEST="cubic+ecn cdg cdg+ecn dctcp+ecn inigo inigo+ecn"

export TEST_BW="700"
export TEST_DELAY="0.25ms"
export TEST_FLOW_DURATION=40
export TEST_FLOW_OFFSET=8
export TEST_SIZE=3
export TEST_EXTRA_ARGS="--inigo-args \"markthresh=174 dctcp_alpha_on_init=0\""

./run-inigo.sh iperf convergence-2flows

export TEST_SIZE=6

./run-inigo.sh iperf convergence-5flows

export TEST_FLOW_OFFSET=0
export TEST_SIZE=21

./run-inigo.sh iperf incast-20flows

export TEST_TCPS="inigo"
export TEST_EXTRA_ARGS="--inigo-args \"markthresh=174 dctcp_alpha_on_init=1024 rtt_fairness=20\""
./run-inigo.sh iperf incast-20flows-conservative

export TEST_TCPS="cubic cdg dctcp inigo"
export TEST_BW="110"
export TEST_DELAY="13ms"
export TEST_FLOW_DURATION=80
export TEST_FLOW_OFFSET=40
export TEST_SIZE=3
export TEST_EXTRA_ARGS="--inigo-args \"markthresh=174 dctcp_alpha_on_init=0\""

./run-inigo.sh rrul_be lowbloat

export TEST_EXTRA_ARGS="--maxq 4000"

./run-inigo.sh rrul_be highbloat

export TEST_EXTRA_ARGS="--maxq 4000 --hostbw 0.90"

./run-inigo.sh rrul_be highbloat-throttled

# eventually, Inigo will need to hold its own in this fight
export TEST_TCPS="inigo"
./run-inigo.sh reno_cubic_westwood_inigo highbloat-throttled

export TEST_TCPS="cdg"
./run-inigo.sh reno_cubic_westwood_cdg highbloat-throttled
