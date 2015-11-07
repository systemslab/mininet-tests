#!/bin/bash

export TEST_TCPS="cubic dctcp inigo"
export TEST_ECN="ecn"
export TEST_AQM="cake"

export TEST_WWW="cubic+cake inigo+cake"
export TEST_BEST="cubic+ecn+cake dctcp+ecn+cake inigo+ecn+cake"

export TEST_BW="110"
export TEST_DELAY="13"

export TEST_FLOW_DURATION=120
export TEST_FLOW_OFFSET=60

export TEST_SIZE=3

./run-inigo.sh rrul_be lowbloat
