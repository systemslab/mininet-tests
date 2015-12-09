#!/bin/bash

#export TEST_TCPS="dctcp+hostecn cubic cubic+hostecn cdg cdg+hostecn inigo inigo+hostecn"
#export TEST_TCPS="dctcp+ecn cubic+ecn cdg+ecn inigo inigo+ecn"
#export TEST_TCPS="dctcp+ecn inigo inigo+ecn"
#export TEST_TCPS="dctcp+ecn"
#export TEST_TCPS="dctcp+hostecn cubic cubic+hostecn inigo"
#export TEST_TCPS="dctcp+hostecn cubic+hostecn"
#export TEST_TCPS="cubic+ecn dctcp+ecn relentless inigo cdg"
#export TEST_TCPS="dctcp+ecn relentless+ecn"
#export TEST_TCPS="dctcp+ecn relentless+ecn relentless inigo+ecn inigo"
#export TEST_TCPS="dctcp+ecn relentless+ecn"
export TEST_TCPS="relentless"
#export TEST_TCPS="dctcp+ecn inigo+ecn cdg+ecn cubic+ecn cdg cubic"
#export TEST_TCPS="dctcp+ecn inigo+ecn"
#export TEST_TCPS="inigo inigo+ecn"
#export TEST_TCPS="cubic cubic+hostecn dctcp+hostecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="100"
export TEST_DELAY="10"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=5

export TEST_SIZE=6

#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
#export TEST_EXTRA_ARGS="--rcv-cong 1 --rcv-fairness 10"
#./run-inigo.sh iperf convergence-5flows-rcvcc

#export TEST_EXTRA_ARGS="--disable-offload"
./run-inigo.sh iperf convergence-5flows
exit

# Testing just fairness
#for f in 10; do
#for f in 0 10 20 30 40 50 60; do
for f in 0 10 20; do
  echo check for module 
  lsmod | grep tcp_dctcp
  if [ $? -eq 0 ]; then
    sudo rmmod tcp_dctcp
    echo check for module again
    lsmod | grep tcp_dctcp
    if [ $? -eq 0 ]; then
      echo module still loaded, abort test
      exit
    fi
  fi

  export TEST_EXTRA_ARGS="--dctcp-args \"subwnd=$f\" --delayinc 2"
  ./run-inigo.sh iperf convergence-5flows
  mkdir fairness${f}
  mv iperf* fairness${f}/
done

exit

# For use with tso branch of inigo
#for f in 13 16 20 23; do
#  for t in 0 1 2; do
#    export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=$f tso_accounting=${t}\""
#    ./run-inigo.sh iperf convergence-5flows
#    mkdir fairness${f}tso$t
#    mv iperf* fairness${f}tso${t}/
#  done
#done

for g in 0 1 2 3 4 5 6 7 8; do
  export TEST_EXTRA_ARGS="--inigo-args \"rtt_fairness=10 dctcp_shift_g=${g}\""
  ./run-inigo.sh iperf convergence-5flows
  mkdir shiftg${g}
  mv iperf* shiftg${g}/
done

exit
