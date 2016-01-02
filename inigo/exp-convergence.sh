#!/bin/bash
export DRYRUN=1
unset DRYRUN

export TEST_TCPS="dctcp cdg cubic inigo"
export TEST_ECN="ecn"
export TEST_AQM=""
export TEST_RCV="rcv-cong"

export TEST_WWW="cubic cdg inigo"
export TEST_BEST="dctcp+ecn inigo+ecn inigo cdg"

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
#export TEST_TCPS="dctcp+hostecn+fqcodel cdg+hostecn+fqcodel cubic+hostecn+fqcodel inigo+hostecn+fqcodel"
#export TEST_TCPS="cubic cubic+hostecn+fqcodel"
export TEST_TCPS="dctcp cdg cubic inigo"
export TEST_ECN="hostecn"
export TEST_AQM="fqcodel"
export TEST_RCV=""
export TEST_EXTRA_ARGS="--hostbw 0.9"
./run-experiment.sh iperf convergence-${N}flows-aqm
./postprocess.sh iperf convergence-${N}flows-aqm

for i in $(ls -d iperf-convergence-${N}flows*); do
  cp ../util/bw_stats-convergence-${N}flows.py /tmp/
  chmod u+x /tmp/bw_stats-convergence-${N}flows.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-convergence-${N}flows.py
  echo "print_stats(results)" >> /tmp/bw_stats-convergence-${N}flows.py
  /tmp/bw_stats-convergence-${N}flows.py > $i/bw_stats.txt
done
