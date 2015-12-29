#!/bin/bash

export TEST_TCPS="dctcp cubic cdg inigo"
export TEST_ECN="ecn"
#export TEST_AQM="fqcodel"

#export TEST_WWW="cubic cdg inigo"
#export TEST_BEST="dctcp+ecn inigo+ecn inigo cdg"

export TEST_BW="500"
export TEST_DELAY="2"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5

export TEST_SIZE=6
N=$((${TEST_SIZE} - 1))

# Default
./run-experiment.sh iperf convergence-${N}flows
./postprocess.sh iperf convergence-${N}flows

# AQM testing
export TEST_TCPS="cubic+hostecn+fqcodel"
#export TEST_ECN="hostecn"
#export TEST_AQM="fqcodel"
export TEST_ECN=""
export TEST_AQM=""
export TEST_EXTRA_ARGS="--hostbw 0.9"
./run-experiment.sh iperf convergence-${N}flows-aqm
./postprocess.sh iperf convergence-${N}flows-aqm

# Receiver side dctcp
#export TEST_TCPS="cubic"
#export TEST_ECN=""
#export TEST_EXTRA_ARGS="--switchecn --rcv-dctcp 1 --rcv-fairness 0"
#./run-experiment.sh iperf convergence-${N}flows-rcv_dctcp
#./postprocess.sh iperf convergence-${N}flows-rcv_dctcp

# Receiver side congestion control
export TEST_ECN=""
export TEST_AQM=""
export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
./run-experiment.sh iperf convergence-${N}flows-rcv_cc
./postprocess.sh iperf convergence-${N}flows-rcv_cc

# Receiver side congestion control with microsecond timestamps
#export TEST_TCPS="cubic"
#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 20 --tcp-us-tstamp --tcpdump"
#export TEST_ECN=""
#./run-experiment.sh iperf convergence-${N}flows-rcv_cc-microsecond
#./postprocess.sh iperf convergence-${N}flows-rcv_cc-microsecond

# Receiver side ecn marking
#export TEST_TCPS="cubic+hostecn"
#export TEST_EXTRA_ARGS="--rcv-mark 1 --tcpdump"
#export TEST_ECN=""
#./run-experiment.sh iperf convergence-${N}flows-rcv_mark
#./postprocess.sh iperf convergence-${N}flows-rcv_mark

# Testing fairness by increasing the delay for each subsequent client
#export TEST_EXTRA_ARGS="--dctcp-args \"subwnd=$f\" --delayinc 2"
#./run-experiment.sh iperf convergence-${N}flows-fairness

for i in $(ls -d iperf-convergence-${N}flows*); do
  cp ../util/bw_stats-convergence-${N}flows.py /tmp/
  chmod u+x /tmp/bw_stats-convergence-${N}flows.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-convergence-${N}flows.py
  echo "print_stats(results)" >> /tmp/bw_stats-convergence-${N}flows.py
  /tmp/bw_stats-convergence-${N}flows.py > $i/bw_stats.txt
done
