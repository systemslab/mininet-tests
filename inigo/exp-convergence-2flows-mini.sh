#!/bin/bash

export TEST_TCPS="cdg inigo"
#export TEST_ECN="ecn"
#export TEST_AQM="cake"

#export TEST_WWW="cubic+cake inigo+cake"
#export TEST_BEST="cubic+ecn+cake inigo+ecn+cake"

export TEST_BW="10"
export TEST_DELAY="10ms"

export TEST_FLOW_DURATION=60
export TEST_FLOW_OFFSET=30

export TEST_SIZE=3

#export TEST_EXTRA_ARGS="--loss \"random 2%\""

./run-inigo.sh
