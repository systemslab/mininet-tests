#!/bin/bash

#export TEST_TCPS="cubic cdg dctcp+ecn inigo"
#export TEST_TCPS="cubic cubic+hostecn"
export TEST_TCPS="inigo inigo+ecn"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="500"
export TEST_DELAY="2"

export TEST_FLOW_DURATION=5
export TEST_FLOW_OFFSET=0

export TEST_SIZE=21


# erratic
# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=10 ssmarkthresh=100 markthresh=174 minor_congestion=10 major_congestion=900 dctcp_alpha_on_init=1024 persistent_congestion=10\""

# hi qlen=400, but stable
# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=20 ssmarkthresh=174 markthresh=300 minor_congestion=100 major_congestion=990 dctcp_alpha_on_init=250 persistent_congestion=10\""
# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=20 ssmarkthresh=174 markthresh=174 minor_congestion=100 major_congestion=990 dctcp_alpha_on_init=500 persistent_congestion=10\""

# mid qlen=250, but stable
# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=15 ssmarkthresh=100 markthresh=150 minor_congestion=1 major_congestion=990 dctcp_alpha_on_init=500 persistent_congestion=10\""

# mid qlen=200, but stable
# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=12 ssmarkthresh=80 markthresh=120 minor_congestion=0 major_congestion=990 dctcp_alpha_on_init=1024 persistent_congestion=10\""

# export TEST_EXTRA_ARGS="--inigo-args \"slowstart_rtt_observations_needed=12 ssmarkthresh=40 markthresh=200 minor_congestion=0 major_congestion=990 dctcp_alpha_on_init=1024 persistent_congestion=10\""

#export TEST_EXTRA_ARGS="--inigo-args \"markthresh=100 minor_congestion=10 dctcp_alpha_on_init=1024 persistent_congestion=10\""
#export TEST_EXTRA_ARGS="--inigo-args \"markthresh=174 dctcp_alpha_on_init=1024\""
#export TEST_EXTRA_ARGS="--loss \"random 2.5%\""

#export TEST_EXTRA_ARGS="--rcv-cong 1"

./run-inigo.sh iperf incast-20flows
