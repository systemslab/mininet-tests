#!/bin/bash

#export TEST_TCPS="cubic cdg dctcp+ecn inigo"
#export TEST_TCPS="dctcp+hostecn cubic+hostecn cdg+hostecn inigo+hostecn"
#export TEST_TCPS="cubic+hostecn"
#export TEST_TCPS="cubic"
export TEST_TCPS="inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="500"
export TEST_DELAY="2ms"

export TEST_FLOW_DURATION=10
export TEST_FLOW_OFFSET=5

export TEST_SIZE=3

#export TEST_EXTRA_ARGS="--loss \"random 2.5%\""

# initial spike in qlen/srtt, good performance
#export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=20 ssmarkthresh=174 markthresh=300 minor_congestion=100 major_congestion=990 dctcp_alpha_on_init=250 persistent_congestion=10\""

#export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=8 ssmarkthresh=125 markthresh=174 minor_congestion=0 major_congestion=990 dctcp_alpha_on_init=0 persistent_congestion=10 rtt_fairness=20\""

./run-inigo.sh iperf convergence-2flows-mini
