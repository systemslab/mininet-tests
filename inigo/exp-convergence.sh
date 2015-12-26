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


# dctcp
#echo "file net/ipv4/tcp_input.c line 291 +p" > control
# rfd
#echo "file net/ipv4/tcp_input.c line 362 +p" > control

#./run-experiment.sh iperf convergence-5flows
#./postprocess.sh iperf convergence-5flows

# Receiver side dctcp
#export TEST_TCPS="cubic"
#export TEST_ECN=""
#export TEST_EXTRA_ARGS="--switchecn --rcv-dctcp 1 --rcv-fairness 0"
#./run-experiment.sh iperf convergence-5flows-rcv_dctcp
#./postprocess.sh iperf convergence-5flows-rcv_dctcp

# Receiver side congestion control
#export TEST_TCPS="inigo"
export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
export TEST_ECN=""
./run-experiment.sh iperf convergence-5flows-rcv_cc
./postprocess.sh iperf convergence-5flows-rcv_cc

# Receiver side congestion control with microsecond timestamps
#export TEST_TCPS="cubic"
#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 20 --tcp-us-tstamp --tcpdump"
#export TEST_ECN=""
#./run-experiment.sh iperf convergence-5flows-rcv_cc-microsecond
#./postprocess.sh iperf convergence-5flows-rcv_cc-microsecond

# Receiver side ecn marking
#export TEST_TCPS="cubic+hostecn"
#export TEST_EXTRA_ARGS="--rcv-mark 1 --tcpdump"
#export TEST_ECN=""
#./run-experiment.sh iperf convergence-5flows-rcv_mark
#./postprocess.sh iperf convergence-5flows-rcv_mark

# Testing fairness by increasing the delay for each subsequent client
#export TEST_EXTRA_ARGS="--dctcp-args \"subwnd=$f\" --delayinc 2"
#./run-experiment.sh iperf convergence-5flows-fairness

for i in $(ls -d iperf-convergence-5flows*); do
  cp ../util/bw_stats-convergence-5flows.py /tmp/
  chmod u+x /tmp/bw_stats-convergence-5flows.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-convergence-5flows.py
  echo "print_stats(results)" >> /tmp/bw_stats-convergence-5flows.py
  /tmp/bw_stats-convergence-5flows.py > $i/bw_stats.txt
done
