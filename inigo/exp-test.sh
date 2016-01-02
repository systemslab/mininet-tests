#!/bin/bash
export DRYRUN=1
unset DRYRUN

#export TEST_TCPS="dctcp cdg cubic inigo"
#export TEST_ECN="ecn"
export TEST_TCPS="reno+ecn+rcv-dctcp cubic+ecn+rcv-dctcp"
export TEST_ECN=""
export TEST_AQM=""
#export TEST_RCV="rcv-cong rcv-dctcp"
export TEST_RCV=""

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

export TEST_TCPS="cubic reno"
export TEST_ECN=""
export TEST_RCV="rcv-cong"
export TEST_EXTRA_ARGS="--rcv-fairness 1"
./run-experiment.sh iperf convergence-${N}flows-fairness1
./postprocess.sh iperf convergence-${N}flows-fairness1

export TEST_TCPS="dctcp+hostecn+rcv-mark reno+hostecn+rcv-mark cubic+hostecn+rcv-mark"
export TEST_ECN=""
export TEST_RCV=""
export TEST_EXTRA_ARGS=""
./run-experiment.sh iperf convergence-${N}flows-mark
./postprocess.sh iperf convergence-${N}flows-mark

# ECN failure mode, switch not configured
#export TEST_TCPS="inigo+ecn inigo+hostecn"
export TEST_TCPS="dctcp+hostecn inigo+hostecn"
export TEST_ECN=""
export TEST_AQM=""
export TEST_RCV=""
#./run-experiment.sh iperf convergence-${N}flows
#./postprocess.sh iperf convergence-${N}flows

# AQM testing
#export TEST_TCPS="dctcp+hostecn+fqcodel cdg+hostecn+fqcodel cubic+hostecn+fqcodel inigo+hostecn+fqcodel"
#export TEST_TCPS="cubic cubic+hostecn+fqcodel"
export TEST_TCPS="dctcp cdg cubic inigo"
export TEST_ECN="hostecn"
export TEST_AQM="fqcodel"
export TEST_RCV=""
export TEST_EXTRA_ARGS="--hostbw 0.9"
#./run-experiment.sh iperf convergence-${N}flows-aqm
#./postprocess.sh iperf convergence-${N}flows-aqm

# reset tech to initial settings
export TEST_TCPS="dctcp cdg cubic inigo"
export TEST_ECN="ecn"
export TEST_AQM=""
export TEST_RCV=""

# Receiver side dctcp
#export TEST_TCPS="cubic"
#export TEST_ECN=""
#export TEST_RCV="rcv-dctcp"
#export TEST_EXTRA_ARGS="--switchecn --rcv-fairness 0"
#./run-experiment.sh iperf convergence-${N}flows
#./postprocess.sh iperf convergence-${N}flows

# Receiver side congestion control with microsecond timestamps
#export TEST_TCPS="cubic"
#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10 --tcp-us-tstamp --tcpdump"
#export TEST_ECN=""
#./run-experiment.sh iperf convergence-${N}flows-rcv_cc-microsecond
#./postprocess.sh iperf convergence-${N}flows-rcv_cc-microsecond
#./postprocess.sh iperf convergence-${N}flows-rcv_cc-microsecond

# Testing fairness by increasing the delay for each subsequent client
#export TEST_EXTRA_ARGS="--dctcp-args \"subwnd=$f\" --delayinc 2"
#./run-experiment.sh iperf convergence-${N}flows-fairness
#./postprocess.sh iperf convergence-${N}flows-fairness

for i in $(ls -d iperf-convergence-${N}flows*); do
  cp ../util/bw_stats-convergence-${N}flows.py /tmp/
  chmod u+x /tmp/bw_stats-convergence-${N}flows.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-convergence-${N}flows.py
  echo "print_stats(results)" >> /tmp/bw_stats-convergence-${N}flows.py
  /tmp/bw_stats-convergence-${N}flows.py > $i/bw_stats.txt
done
