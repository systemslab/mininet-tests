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
elif [ "$1" == "pcc" ]; then
  experiment="pcc"
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
# all combinations of tcp, ecn, aqm, and receiver-side techniques are tried
# plotting scripts may be limited to a fewer number
#tcps="reno westwood vegas cubic inigo dctcp"
tcps=${TEST_TCPS:="cubic"}
ntcps=$(echo $tcps | awk -F' ' '{print NF}')
#ecn=ecn
ecn=${TEST_ECN:=""}
#aqms="fq fqcodel cake"
aqms=${TEST_AQM:=""}
#rcvs="rcv-cong rcv-dctcp rcv-mark"
rcvs=${TEST_RCV:=""}

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
  sudo sysctl -w net.ipv4.tcp_rcv_congestion_control=0
  sudo sysctl -w net.ipv4.tcp_rcv_ecn_marking=0
  for tcp_mod in $(lsmod | perl -ne '/^(tcp_\w+)/ && print "$1\n"'); do
      sudo rmmod $tcp_mod
  done

  local tcpA="${1}"
  local tcpB="${2}"
  local tcpC="${3}"
  local tcpD="${4}"
  local tech="${1}"
  allargs="--${experiment} ${exp_opt}"

  eval "$(echo ${1} | perl -ne '/(\w+)/ && print "tech1=$1\n"')"
  eval "$(echo ${1} | perl -ne '/(\w+)\+([\w-]+)/ && print "tech1=$1; tech2=$2\n"')"
  eval "$(echo ${1} | perl -ne '/(\w+)\+([\w-]+)\+([\w-]+)/ && print "tech1=$1; tech2=$2; tech3=$3\n"')"
  eval "$(echo ${1} | perl -ne '/(\w+)\+([\w-]+)\+([\w-]+)\+([\w+-])/ && print "tech1=$1; tech2=$2; tech3=$3; tech4=$4\n"')"

  if [ "$tech1" ]; then
     allargs="$allargs --${tech1}"
  fi
  if [ "$tech2" ]; then
     allargs="$allargs --${tech2}"
  fi
  if [ "$tech3" ]; then
     allargs="$allargs --${tech3}"
  fi
  if [ "$tech4" ]; then
     allargs="$allargs --${tech4}"
  fi

  if [ "$tcpB" ]; then
     allargs="$allargs --${tcpB}"
     tech="${tcpA}+${tcpB}"
  fi
  if [ "$tcpC" ]; then
     allargs="$allargs --${tcpC}"
     tech="${tcpA}+${tcpB}+${tcpC}"
  fi
  if [ "$tcpD" ]; then
     allargs="$allargs --${tcpD}"
     tech="${tcpA}+${tcpB}+${tcpC}+${tcpD}"
  fi
  odir=$experiment-$tech-$note

  allargs=" --dir $odir $commonargs $allargs"
  echo runexperiment tech="$tech" odir="$odir" args="$*"
  echo -e "\tallargs=\"$allargs\""

  mkdir -p $odir
  touch $odir/experiment.log
  if [ -n "$DRYRUN" ]; then
    return 0
  fi

  echo sudo python inigo.py $allargs | tee -a $odir/experiment.log
  sudo bash -c "python inigo.py $allargs 2>&1 | tee -a $odir/experiment.log"
  #expstatus=$?
  #if [ $expstatus -lt 1 ]; then
  #  exit
  #fi

  sudo mn -c

  sudo sysctl -w net.ipv4.tcp_congestion_control=cubic
  sudo sysctl -w net.ipv4.tcp_rcv_congestion_control=0
  sudo sysctl -w net.ipv4.tcp_rcv_ecn_marking=0
  for tcp_mod in $(lsmod | perl -ne '/^(tcp_\w+)/ && print "$1\n"'); do
      sudo rmmod $tcp_mod
  done

  sudo dmesg > $odir/dmesg.txt
}

for tcp in $tcps; do
  #echo runexperiment ${tcp}
  runexperiment ${tcp}

  if [ "$rcvs" ]; then
    for rcv in $rcvs; do
      #echo runexperiment ${tcp} ${rcv}
      runexperiment ${tcp} ${rcv}

      if [ "$aqms" ]; then
        for aqm in $aqms; do
          #echo runexperiment ${tcp} ${aqm} ${rcv}
          runexperiment ${tcp} ${aqm} ${rcv}
          runexperiment ${tcp} ${aqm}

          if [ "${ecn}" ]; then
            #echo runexperiment ${tcp} ${ecn} ${aqm} ${rcv}
            runexperiment ${tcp} ${ecn} ${aqm} ${rcv}
            runexperiment ${tcp} ${ecn} ${aqm}
          fi
        done
      elif [ "${ecn}" ]; then
        #echo runexperiment ${tcp} ${ecn} ${rcv}
        runexperiment ${tcp} ${ecn} ${rcv}
        runexperiment ${tcp} ${ecn}
      fi
    done
  elif [ "$aqms" ]; then
    for aqm in $aqms; do
      #echo runexperiment ${tcp} ${aqm}
      runexperiment ${tcp} ${aqm}

      if [ "${ecn}" ]; then
        #echo runexperiment ${tcp} ${ecn} ${aqm}
        runexperiment ${tcp} ${ecn} ${aqm}
        runexperiment ${tcp} ${ecn}
      fi
    done
  elif [ "${ecn}" ]; then
    #echo runexperiment ${tcp} ${ecn}
    runexperiment ${tcp} ${ecn}
  fi
done
