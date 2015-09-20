#!/bin/bash

#export TEST_TCPS="dctcp+hostecn cubic cubic+hostecn cdg cdg+hostecn inigo inigo+hostecn"
#export TEST_TCPS="dctcp+ecn cubic+ecn cdg+ecn inigo inigo+ecn"
#export TEST_TCPS="dctcp+ecn inigo inigo+ecn"
#export TEST_TCPS="dctcp+hostecn cubic cubic+hostecn inigo"
#export TEST_TCPS="dctcp inigo"
export TEST_TCPS="inigo"
#export TEST_TCPS="dctcp+hostecn cubic+hostecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="500"
export TEST_DELAY="2ms"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5

export TEST_SIZE=6

#export TEST_EXTRA_ARGS="--convergence --rcv-cong 1"
#export TEST_EXTRA_ARGS="--rcv-cong 26"

for f in 0 10 13 16 20 23 30; do
  export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=$f\""
  ./run-inigo.sh iperf convergence-5flows
  mkdir fairness${f}
  mv iperf* fairness${f}/
done

# For use with tso branch of inigo
#for f in 13 16 20 23; do
#  for t in 0 1 2; do
#    export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=$f tso_accounting=${t}\""
#    ./run-inigo.sh iperf convergence-5flows
#    mkdir fairness${f}tso$t
#    mv iperf* fairness${f}tso${t}/
#  done
#done
