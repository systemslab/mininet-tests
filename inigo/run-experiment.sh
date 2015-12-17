#!/bin/bash

UTIL_DIR=$PWD/../util
export PATH=$PATH:$UTIL_DIR

# usage: ./run-experiment.sh <experiment> [<descriptive note>]
# if a Flent experiment isn't specified, then a simple iperf test is run
# if a descriptive note (no spaces allowed) isn't given, then a date is used
if [ -z "$1" ]; then
  experiment="iperf"
  exp_opt=""
elif [ "$1" == "iperf" ]; then
  experiment="iperf"
  exp_opt=""
else
  experiment=$1
  exp_opt="--flent $1"
fi

if [ -z "$2" ]; then
  note="$(date +%F-%H)"
else
  note="$2"
fi

# different techniques to compare:
# all combinations of tcp, ecn, and aqm are tried
# plotting scripts may be limited to a fewer number
#tcps="reno westwood vegas cubic inigo dctcp"
tcps=${TEST_TCPS:="cubic"}
ntcps=$(echo $tcps | awk -F' ' '{print NF}')
#ecn=ecn
ecn=${TEST_ECN:=""}
#aqms="fq fqcodel cake"
aqms=${TEST_AQM:=""}

# list combos for additional interesting plots
expected_www_techs=${TEST_WWW:=""}
best_techs=${TEST_BEST:=""}

# link properties
bw=${TEST_BW:=10}
delay=${TEST_DELAY:="10"}	# delay per link (ms), so RTT is 2X
rtt_us=$(( ${TEST_DELAY}*1000*2 ))
t=${TEST_FLOW_DURATION:=30}
offset=${TEST_FLOW_OFFSET:=10}	# seconds between client starts
n=${TEST_SIZE:=3}		# 1 server and n-1 clients
maxq=${TEST_MAXQ:=425}		# size of bottleneck queue

extra_args=${TEST_EXTRA_ARGS:=""}
commonargs="--bw $bw --delay $delay --maxq $maxq -t $t --offset $offset -n $n $extra_args $exp_opt"

echo commmonargs: $commonargs
echo rtt_us: $rtt_us

function runexperiment () {
  local loc_tcp="${1}"
  local loc_ecn="${2}"
  local loc_aqm="${3}"
  local loc_tech="${1}"
  allargs=""

  for tcp_mod in $(lsmod | perl -ne '/^(tcp_\w+)/ && print "$1\n"'); do
      sudo rmmod $tcp_mod
  done

  eval "$(echo ${1} | perl -ne '/(\w+)\+(\w+)/ && print "loc_tcp=$1; loc_ecn=$2\n"')"
  eval "$(echo ${1} | perl -ne '/(\w+)\+(\w+)\+(\w+)/ && print "loc_tcp=$1; loc_ecn=$2; loc_aqm=$3\n"')"

  # use loc_ecn and/or an loc_aqm?
  if [ "$loc_ecn" ]; then
     allargs="$allargs --${loc_ecn}"
     loc_tech="${loc_tcp}+${loc_ecn}"
  fi
  if [ "$loc_aqm" ]; then
     allargs="$allargs --${loc_aqm}"
     loc_tech="${loc_tcp}+${loc_ecn}+${loc_aqm}"
  fi
  odir=$experiment-$loc_tech-$note
  allargs=" --dir $odir $commonargs --${loc_tcp} $allargs"

  mkdir $odir
  touch $odir/experiment.log

  echo sudo python inigo.py $allargs | tee -a $odir/experiment.log
  sudo bash -c "python inigo.py $allargs 2>&1 | tee -a $odir/experiment.log"
  #expstatus=$?
  #if [ $expstatus -lt 1 ]; then
  #  exit
  #fi

  sudo mn -c

  sudo bash -c "echo cubic > /proc/sys/net/ipv4/tcp_congestion_control"

  for tcp_mod in $(lsmod | perl -ne '/^(tcp_\w+)/ && print "$1\n"'); do
      sudo rmmod $tcp_mod
  done

  sudo dmesg > $odir/dmesg.txt
}

for tcp in $tcps; do
  echo runexperiment ${tcp}
  runexperiment ${tcp}

  if [ "${ecn}" ]; then
    echo runexperiment ${tcp} ${ecn}
    runexperiment ${tcp} ${ecn}
  fi

  for aqm in $aqms; do
    echo runexperiment ${tcp} ${aqm}
    runexperiment ${tcp} ${aqm}

    if [ "${ecn}" ]; then
      echo runexperiment ${tcp} ${ecn} ${aqm}
      runexperiment ${tcp} ${ecn} ${aqm}
    fi
  done
done
