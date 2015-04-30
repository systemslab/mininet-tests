#!/bin/bash

# usage: ./run-inigo.sh [<flent experiment>]
# if a Flent experiment isn't specified, then a simple iperf test is run
if [ -z "$1" ]; then
  experiment="iperf"
  exp_opt=""
else
  experiment=$1
  exp_opt="--flent $1"
fi

# different techniques to compare
# all combinations of tcp, ecn, and aqm are tried
# limit tcps and *_techs to at most 8 (queue plotting script limit)
#tcps="reno westwood vegas cubic inigo dctcp"
tcps="cubic inigo dctcp"
ecn="ecn"
aqm="fqcodel"
expected_www_techs="cubic cubic+$aqm inigo inigo+$aqm"
best_techs="cubic+ecn+$aqm dctcp+ecn+$aqm inigo+ecn+$aqm"

# link properties
bw=10
delay="10ms" # delay per link, so RTT is 2X
t=5
offset=1     # seconds between client starts
n=3
maxq=425
commonargs="--bw $bw --delay $delay --maxq $maxq -t $t --offset $offset -n $n $exp_opt"

echo commmonargs: $commonargs

zoodir=$experiment-zoo-n$n-bw$bw-d$delay
mkdir $zoodir

function postprocess () {
  tech=$1
  odir=$2
  echo postprocess $tech $odir
  user=$(whoami)
  sudo chown -R $user $odir
  
  cp $odir/qlen_s1-eth1.txt $zoodir/$tech
  
  if [ "$experiment" == "iperf" ]; then
    echo python ../util/plot_tcpprobe.py -f $odir/tcp_probe.txt -o $odir/cwnd-${tech}.png
    python ../util/plot_tcpprobe.py -f $odir/tcp_probe.txt -o $odir/cwnd-${tech}.png
    mv $odir/cwnd-${tech}.png $zoodir/
  
    # timestamp,saddress,sport,daddress,dport,interval,transferred_bytes,bps
    for i in $(seq 2 $n); do
      perl -ne "/10\.0\.0\.$i/ && ! /(0\.0-[^1])/ && print" $odir/iperf_h1.txt > $odir/host$i
    done
    cd $odir
    echo ../../util/plot_iperf.R $bw $offset host2 host3
    ../../util/plot_iperf.R $bw $offset host2 host3
    cd -
    mv $odir/iperf.png $zoodir/iperf-${tech}.png
  else
    ports=$(perl -ne '/10.0.0.1:(\d+)/ && print "$1\n"' $odir/tcp_probe.txt | sort | uniq | tr '\n' ' ')
    echo python ../util/plot_tcpprobe.py -f $odir/tcp_probe.txt -o $odir/cwnd-${tech}.png -p $ports
    python ../util/plot_tcpprobe.py -f $odir/tcp_probe.txt -o $odir/cwnd-${tech}.png -p $ports
    mv $odir/cwnd-${tech}.png $zoodir/

    # move remaining pngs
    mv $odir/*.png $zoodir/
  fi
}

function runexperiment () {
  tech="${1}"
  allargs=""
  if [ "$2" ]; then
     allargs="$allargs --${2}"
     tech="${1}+${2}"
  fi
  if [ "$3" ]; then
     allargs="$allargs --${3}"
     tech="${1}+${2}+${3}"
  fi
  odir=$experiment-$tech-n$n-bw$bw-d$delay
  allargs=" --dir $odir $commonargs --${1} $allargs"
  echo sudo python inigo.py $allargs
  sudo python inigo.py $allargs
  postprocess $tech $odir
}

for tcp in $tcps; do
  echo runexperiment ${tcp}
  runexperiment ${tcp}

  echo runexperiment ${tcp} ${ecn}
  runexperiment ${tcp} ${ecn}

  echo runexperiment ${tcp} ${aqm}
  runexperiment ${tcp} ${aqm}

  echo runexperiment ${tcp} ${ecn} ${aqm}
  runexperiment ${tcp} ${ecn} ${aqm}
done

cd $zoodir
echo ../../util/plot_queue.R $tcps
../../util/plot_queue.R $tcps
mv qlen.png qlen-all-plain.png
mv qlen-cdf.png qlen-cdf-all-plain.png

echo ../../util/plot_queue.R *+${ecn}
../../util/plot_queue.R *+${ecn}
mv qlen.png qlen-all+${ecn}.png
mv qlen-cdf.png qlen-cdf-all+${ecn}.png

echo ../../util/plot_queue.R *+${ecn}+${aqm}
../../util/plot_queue.R *+${ecn}+${aqm}
mv qlen.png qlen-all+${ecn}+${aqm}.png
mv qlen-cdf.png qlen-cdf-all+${ecn}+${aqm}.png

echo ../../util/plot_queue.R $expected_www_techs
../../util/plot_queue.R $expected_www_techs
mv qlen.png qlen-expectedwww.png
mv qlen-cdf.png qlen-cdf-expectedwww.png

echo ../../util/plot_queue.R $best_techs
../../util/plot_queue.R $best_techs
mv qlen.png qlen-best.png
mv qlen-cdf.png qlen-cdf-best.png
cd ..
