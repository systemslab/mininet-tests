#!/bin/bash

#export TEST_TCPS="cubic cubic+ecn cdg cdg+ecn reno dctcp+ecn vegas inigo_rttonly inigo_rttonly+ecn inigo inigo+ecn"
#export TEST_TCPS="cdg cubic dctcp inigo inigo_rttonly"
export TEST_TCPS="cdg cdg+ecn cubic cubic+ecn dctcp+ecn inigo inigo+ecn reno reno+ecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

export TEST_WWW="cdg cubic inigo reno"
export TEST_BEST="cdg+ecn cubic+ecn dctcp+ecn inigo inigo+ecn reno+ecn"

export TEST_BW="500"
export TEST_DELAY="2"
export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5

#export TEST_SIZE=3
#./run-inigo.sh iperf convergence-2flows

# export TEST_SIZE=6
# ./run-inigo.sh iperf convergence-5flows
# 
# export TEST_SIZE=21
# export TEST_FLOW_OFFSET=0
# ./run-inigo.sh iperf incast-20flows

# export TEST_TCPS="inigo inigo+ecn"
# export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=0\""
# unset TEST_WWW
# unset TEST_BEST
# export TEST_SIZE=6
# ./run-inigo.sh iperf convergence-5flows-fairness0
# export TEST_FLOW_OFFSET=0
# export TEST_SIZE=21
# ./run-inigo.sh iperf incast-20flows-fairness0

# export TEST_FLOW_DURATION=5
# export TEST_FLOW_OFFSET=5
# export TEST_SIZE=6
# export TEST_TCPS="cdg cubic inigo reno"
# export TEST_EXTRA_ARGS="--rcv-cong 1"
# ./run-inigo.sh iperf convergence-5flows-rcvcc
# 
# export TEST_FLOW_OFFSET=0
# export TEST_SIZE=21
# 
# ./run-inigo.sh iperf incast-20flows-rcvcc

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5
export TEST_SIZE=6
export TEST_TCPS="cdg+hostecn cubic+hostecn dctcp+hostecn inigo+hostecn reno+hostecn"
export TEST_EXTRA_ARGS="--rcv-mark 1"

./run-inigo.sh iperf convergence-5flows-rcvecn

export TEST_FLOW_OFFSET=0
export TEST_SIZE=21

./run-inigo.sh iperf incast-20flows-rcvecn

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5
export TEST_SIZE=6
export TEST_TCPS="cdg cubic inigo reno cdg+hostecn cubic+hostecn dctcp+hostecn inigo+hostecn reno+hostecn"
export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-mark 1"
./run-inigo.sh iperf convergence-5flows-rcvboth

export TEST_FLOW_OFFSET=0
export TEST_SIZE=21

./run-inigo.sh iperf incast-20flows-rcvboth

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5
export TEST_SIZE=6
export TEST_TCPS="cdg cubic inigo reno cdg+hostecn cubic+hostecn dctcp+hostecn inigo+hostecn reno+hostecn"
export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-mark 1 --rcv-rebase 512"
./run-inigo.sh iperf convergence-5flows-rcv-rebase

export TEST_FLOW_OFFSET=0
export TEST_SIZE=21

./run-inigo.sh iperf incast-20flows-rcv-rebase

# #export TEST_TCPS="inigo inigo+ecn"
# export TEST_TCPS="inigo"
# export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=0\""
# unset TEST_WWW
# unset TEST_BEST
# export TEST_SIZE=6
# ./run-inigo.sh iperf convergence-5flows-rcvcc-fairness0
# export TEST_FLOW_OFFSET=0
# export TEST_SIZE=21
# ./run-inigo.sh iperf incast-20flows-rcvcc-fairness0

exit
# need to get flent working again

export TEST_TCPS="cubic cdg dctcp+ecn inigo"
export TEST_BW="110"
export TEST_DELAY="13"
export TEST_FLOW_DURATION=80
export TEST_FLOW_OFFSET=40
export TEST_SIZE=3

# ./run-inigo.sh rrul_be lowbloat

export TEST_EXTRA_ARGS="--maxq 4000"

./run-inigo.sh rrul_be highbloat

export TEST_EXTRA_ARGS="--maxq 4000 --hostbw 0.90"

./run-inigo.sh rrul_be highbloat-throttled

export TEST_TCPS="inigo"
export TEST_EXTRA_ARGS="--maxq 4000"
./run-inigo.sh reno_cubic_cdg_inigo highbloat
