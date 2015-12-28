#!/bin/bash

export TEST_TCPS="reno dctcp cubic cdg inigo"
export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="reno cubic cdg inigo"
#export TEST_BEST="dctcp+ecn inigo+ecn inigo cdg"

export TEST_BW="500"
export TEST_DELAY="2"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=0

export TEST_SIZE=9


./run-experiment.sh iperf incast-${TEST_SIZE}flows
./postprocess.sh iperf incast-${TEST_SIZE}flows

# Receiver side congestion control
export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
export TEST_ECN=""
./run-experiment.sh iperf incast-${TEST_SIZE}flows-rcv_cc
./postprocess.sh iperf incast-${TEST_SIZE}flows-rcv_cc

for i in $(ls -d iperf-incast-${TEST_SIZE}flows*); do
  cp ../util/bw_stats-incast.py /tmp/
  chmod u+x /tmp/bw_stats-incast.py
  cat $i/iperf.aggr/* >> /tmp/bw_stats-incast.py
  echo "print_stats(results)" >> /tmp/bw_stats-incast.py
  /tmp/bw_stats-incast.py ${TEST_BW} $((${TEST_SIZE} - 1)) ${TEST_FLOW_DURATION} > $i/bw_stats.txt
done
