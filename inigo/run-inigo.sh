#!/bin/bash

UTIL_DIR=$PWD/../util
export PATH=$PATH:$UTIL_DIR

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
tcps=${TEST_TCPS:="cubic"}
#ecn=ecn
ecn=${TEST_ECN:=""}
#aqm=fqcodel|cake
aqm=${TEST_AQM:=""}

# list combos for additional interesting plots
expected_www_techs=${TEST_WWW:=""}
best_techs=${TEST_BEST:=""}

# link properties
bw=${TEST_BW:=10}
delay=${TEST_DELAY:="10ms"}	# delay per link, so RTT is 2X
t=${TEST_FLOW_DURATION:=30}
offset=${TEST_FLOW_OFFSET:=10}	# seconds between client starts
n=${TEST_SIZE:=3}		# 1 server and n-1 clients
maxq=${TEST_MAXQ:=425}		# size of bottleneck queue

extra_args=${TEST_EXTRA_ARGS:=""}
commonargs="--bw $bw --delay $delay --maxq $maxq -t $t --offset $offset -n $n $extra_args $exp_opt"

echo commmonargs: $commonargs

zoodir=$experiment-zoo-n$n-bw$bw-d$delay
mkdir $zoodir

bz() {
    if hash pbzip2 2>/dev/null; then
        pbzip2 "$@"
    else
        bzip2 "$@"
    fi
}

function downsample () {
  infile=$1
  outfile=$2

  cat $infile | perl -e '
    my $percentage = $ARGV[0];
    my $outfile = $ARGV[1];
    open OUT1, ">", "$outfile" or die $!;
    while (<STDIN>) {
        if (rand(100) < $percentage) { print OUT1 $_; }
    }
    close OUT1 or die $!;
' 10 $outfile
}

function postprocess () {
  tech=$1
  odir=$2
  echo postprocess $tech $odir
  user=$(whoami)

  sudo chown -R $user $odir
  
  mkdir $zoodir/qlen_s1-eth1
  mv $odir/qlen_s1-eth1.txt $zoodir/qlen_s1-eth1/$tech
  
  #echo python $UTIL_DIR/plot_cpu.py -f $odir/cpu.txt -o $odir/cpu-${tech}.png
  #python $UTIL_DIR/plot_cpu.py -f $odir/cpu.txt -o $odir/cpu-${tech}.png
  #mv $odir/cpu-${tech}.png $zoodir/

  if [ -f $odir/tcp_probe.txt ]; then
    mkdir $zoodir/tcp_probe_downsampled
    cd $odir
    echo plot_tcpprobe.R tcp_probe.txt
    plot_tcpprobe.R tcp_probe.txt
    mv srtt.png srtt-${tech}.png
    mv srtt-cdf.png srtt-cdf-${tech}.png

    # only keep the downsampled version, since the original grows so big
    downsample tcp_probe.txt ../$zoodir/tcp_probe_downsampled/$tech
    rm tcp_probe.txt
    cd -
  fi

  if [ "$experiment" == "iperf" ]; then
    echo python $UTIL_DIR/plot_tcpprobe.py -f $zoodir/tcp_probe_downsampled/$tech -o $zoodir/cwnd-${tech}.png
    python $UTIL_DIR/plot_tcpprobe.py -f $zoodir/tcp_probe_downsampled/$tech -o $zoodir/cwnd-${tech}.png
  
    # timestamp,saddress,sport,daddress,dport,interval,transferred_bytes,bps
    for i in $(seq 2 $n); do
      perl -ne "/10\.0\.0\.$i,/ && /(0\.0-1\.0)|([^0]+\.0-)/ && s/(\d+)\.0-\d+\.0/\$1/ && print" $odir/iperf_h1.txt > $odir/iperf-h$i
    done
    cd $odir
    echo plot_iperf.R $bw $offset $(ls iperf-h*)
    plot_iperf.R $bw $offset $(ls iperf-h*)
    cd -
    mv $odir/iperf.png $zoodir/iperf-${tech}.png
  else
    ports=$(perl -ne '/10.0.0.1:(\d+)/ && print "$1\n"' $zoodir/tcp_probe_downsampled/$tech | sort | uniq | tr '\n' ' ')
    echo python $UTIL_DIR/plot_tcpprobe.py -f $zoodir/tcp_probe_downsampled/$tech -o $zoodir/cwnd-${tech}.png -p $ports
    python $UTIL_DIR/plot_tcpprobe.py -f $zoodir/tcp_probe_downsampled/$tech -o $zoodir/cwnd-${tech}.png -p $ports
  fi

  # move remaining pngs
  mv $odir/*.png $zoodir/

  [ -f $odir/h1_tcpdump.pcap ] && bz $odir/h1_tcpdump.pcap
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

  mkdir $odir
  touch $odir/experiment.log

  echo sudo python inigo.py $allargs
  sudo bash -c "python inigo.py $allargs 2>&1 | tee -a $odir/experiment.log"
  postprocess $tech $odir
}

for tcp in $tcps; do
  echo runexperiment ${tcp}
  runexperiment ${tcp}

  if [ "${ecn}" ]; then
    echo runexperiment ${tcp} ${ecn}
    runexperiment ${tcp} ${ecn}
  fi

  if [ "${aqm}" ]; then
    echo runexperiment ${tcp} ${aqm}
    runexperiment ${tcp} ${aqm}
  fi

  if [ "${ecn}" ] && [ "${aqm}" ]; then
    echo runexperiment ${tcp} ${ecn} ${aqm}
    runexperiment ${tcp} ${ecn} ${aqm}
  fi
done

cd $zoodir/qlen_s1-eth1
echo plot_queue.R $tcps
plot_queue.R $tcps
mv qlen.png qlen-all-plain.png
mv qlen-cdf.png qlen-cdf-all-plain.png

for tcp in $tcps; do
  echo plot_queue.R ${tcp}*
  plot_queue.R ${tcp}*
  mv qlen.png qlen-all-${tcp}.png
  mv qlen-cdf.png qlen-cdf-all-${tcp}.png
done

if [ "$ecn" ]; then
  echo plot_queue.R *+${ecn}
  plot_queue.R *+${ecn}
  mv qlen.png qlen-all+${ecn}.png
  mv qlen-cdf.png qlen-cdf-all+${ecn}.png
fi

if [ "$aqm" ]; then
  echo plot_queue.R *+${aqm}
  plot_queue.R *+${aqm}
  mv qlen.png qlen-all+${aqm}.png
  mv qlen-cdf.png qlen-cdf-all+${aqm}.png
fi

if [ "$ecn" ] && [ "$aqm" ]; then
  echo plot_queue.R *+${ecn}+${aqm}
  plot_queue.R *+${ecn}+${aqm}
  mv qlen.png qlen-all+${ecn}+${aqm}.png
  mv qlen-cdf.png qlen-cdf-all+${ecn}+${aqm}.png
fi

if [ "$expected_www_techs" ]; then
  echo plot_queue.R $expected_www_techs
  plot_queue.R $expected_www_techs
  mv qlen.png qlen-expectedwww.png
  mv qlen-cdf.png qlen-cdf-expectedwww.png
fi

if [ "$best_techs" ]; then
  echo plot_queue.R $best_techs
  plot_queue.R $best_techs
  mv qlen.png qlen-best.png
  mv qlen-cdf.png qlen-cdf-best.png
fi

for tcp in $tcps; do
  for f in $(ls ${tcp}*); do
    bz $f
  done
done
mv *png ../
cd - # end qlen plotting


cd $zoodir/tcp_probe_downsampled
echo plot_tcpprobe.R $tcps
plot_tcpprobe.R $tcps
mv srtt.png srtt-all-plain.png
mv srtt-cdf.png srtt-cdf-all-plain.png

for tcp in $tcps; do
  echo plot_tcpprobe.R ${tcp}*
  plot_tcpprobe.R ${tcp}*
  mv srtt.png srtt-all-${tcp}.png
  mv srtt-cdf.png srtt-cdf-all-${tcp}.png
done

for tcp in $tcps; do
  for f in $(ls ${tcp}*); do
    bz $f
  done
done
mv *png ../
cd - # end srtt plotting
