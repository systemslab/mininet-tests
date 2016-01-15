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
export TEST_FLOW_OFFSET=0
export TEST_SIZE=9
N=$((${TEST_SIZE} - 1))

# Default
./run-experiment.sh iperf incast-${N}flows
./postprocess.sh iperf incast-${N}flows

# Unconfigured switch failure mode
export TEST_TCPS="dctcp+hostecn inigo+hostecn"
export TEST_ECN=""
export TEST_AQM=""
export TEST_RCV=""
./run-experiment.sh iperf incast-${N}flows-hostecn
./postprocess.sh iperf incast-${N}flows-hostecn

# AQM testing
#export TEST_TCPS="dctcp+hostecn+fqcodel cdg+hostecn+fqcodel cubic+hostecn+fqcodel inigo+hostecn+fqcodel"
#export TEST_TCPS="cubic cubic+hostecn+fqcodel"
export TEST_TCPS="dctcp cdg cubic inigo"
export TEST_ECN="hostecn"
export TEST_AQM="fqcodel"
export TEST_RCV=""
export TEST_EXTRA_ARGS="--hostbw 0.9"
./run-experiment.sh iperf incast-${N}flows-aqm
./postprocess.sh iperf incast-${N}flows-aqm

for i in $(ls -d iperf-incast-${N}flows*); do
  cp ../util/bw_stats-incast.py /tmp/
  chmod u+x /tmp/bw_stats-incast.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-incast.py
  echo "print_stats(results)" >> /tmp/bw_stats-incast.py
  /tmp/bw_stats-incast.py ${TEST_BW} $N ${TEST_FLOW_DURATION} > $i/bw_stats.txt
done
