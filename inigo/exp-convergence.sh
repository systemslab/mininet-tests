#!/bin/bash

export TEST_TCPS="reno dctcp cubic cdg inigo"
export TEST_ECN="ecn"
#export TEST_AQM="cake"

export TEST_WWW="reno cubic cdg inigo"
export TEST_BEST="dctcp+ecn inigo+ecn inigo cdg"

export TEST_BW="500"
export TEST_DELAY="2"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5

export TEST_SIZE=6



./run-experiment.sh iperf convergence-5flows
./postprocess.sh iperf convergence-5flows

# Receiver side congestion control
#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
#./run-experiment.sh iperf convergence-5flows-rcvcc

# Testing fairness by increasing the delay for each subsequent client
#export TEST_EXTRA_ARGS="--dctcp-args \"subwnd=$f\" --delayinc 2"
#./run-experiment.sh iperf convergence-5flows-fairness

cp ../util/bw_stats-convergence-5flows.py /tmp/
chmod u+x /tmp/bw_stats-convergence-5flows.py
cat iperf-convergence-5flows/iperf.aggr/* >> /tmp/bw_stats-convergence-5flows.py
echo "print_stats(results)" >> /tmp/bw_stats-convergence-5flows.py
/tmp/bw_stats-convergence-5flows.py > iperf-convergence-5flows/bw_stats.txt
