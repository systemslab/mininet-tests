#!/bin/bash

bash -x ./exp-convergence-2flows.sh
mv iperf* ~/src/tcp_inigo_experiments/iperf-convergence-2flows/
bash -x ./exp-convergence.sh
mv iperf* ~/src/tcp_inigo_experiments/iperf-convergence/
bash -x ./exp-incast.sh
mv iperf* ~/src/tcp_inigo_experiments/iperf-incast/
bash -x ./exp-rrul_be-bufferbloat.sh
mv rrul_be* ~/src/tcp_inigo_experiments/rrul_be-highbloat/
bash -x ./exp-rrul_be.sh
mv rrul_be* ~/src/tcp_inigo_experiments/rrul_be-lowbloat/
