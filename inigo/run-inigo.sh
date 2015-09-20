#!/bin/bash

UTIL_DIR=$PWD/../util
export PATH=$PATH:$UTIL_DIR

# usage: ./run-inigo.sh <experiment> [<descriptive note>]
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

# different techniques to compare
# all combinations of tcp, ecn, and aqm are tried
# current queue plotting limit is 8
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
delay=${TEST_DELAY:="10ms"}	# delay per link, so RTT is 2X
rtt_us=$(echo ${TEST_DELAY} | perl -ne '/(.*)ms/ && print $1*1000*2')
t=${TEST_FLOW_DURATION:=30}
offset=${TEST_FLOW_OFFSET:=10}	# seconds between client starts
n=${TEST_SIZE:=3}		# 1 server and n-1 clients
maxq=${TEST_MAXQ:=425}		# size of bottleneck queue

extra_args=${TEST_EXTRA_ARGS:=""}
commonargs="--bw $bw --delay $delay --maxq $maxq -t $t --offset $offset -n $n $extra_args $exp_opt"

echo commmonargs: $commonargs
echo rtt_us: $rtt_us

zoodir=$experiment-zoo-$note
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
  echo postprocess tech="$tech" odir="$odir"
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
    server="10.0.0.1"
    # separate to/from 10.0.0.1 (also filters out 127.0.0.1, etc.)
    grep -E "10.0.0.[0-9]+:[0-9]+ ${server}:" tcp_probe.txt > tcp_probe-to-10.0.0.1
    #grep -E "${server}:[0-9]+ 10.0.0.[0-9]+" tcp_probe.txtinigo > tcp_probe-from-10.0.0.1

    # doing this for each raw file (pre-downsampled) can take a long time
    # uncomment if you still want it
    # echo plot_tcpprobe.R $server $rtt_us tcp_probe-to-10.0.0.1
    # plot_tcpprobe.R $server $rtt_us tcp_probe-to-10.0.0.1
    # mv srtt-${server}.png srtt-${server}-${tech}.png
    # mv srtt-cdf-${server}.png srtt-cdf-${server}-${tech}.png
    # mv cwnd-${server}.png cwnd-${server}-${tech}.png
    # mv cwnd+ssthresh+wnd-${server}.png cwnd+ssthresh+wnd-${server}-${tech}.png
    # mv cwnd+ssthresh-${server}.png cwnd+ssthresh-${server}-${tech}.png
    # mv ssthresh-${server}.png ssthresh-${server}-${tech}.png
    # mv wnd-${server}.png wnd-${server}-${tech}.png

    # only keep the downsampled version, since the original grows so big
    downsample tcp_probe-to-10.0.0.1 ../$zoodir/tcp_probe_downsampled/${tech}
    #downsample tcp_probe-from-10.0.0.1 ../$zoodir/tcp_probe_downsampled/${tech}-from-10.0.0.1
    rm tcp_probe.txt
    cd -
  fi

  if [ "$experiment" == "iperf" ]; then
    # timestamp,saddress,sport,daddress,dport,interval,transferred_bytes,bps
    for i in $(seq 2 $n); do
      perl -ne "/10\.0\.0\.$i,/ && /(0\.0-1\.0)|([^0]+\.0-)/ && s/(\d+)\.0-\d+\.0/\$1/ && print" $odir/iperf_h1.txt > $odir/iperf-h$i
    done
    cd $odir

    echo plot_iperf.R $bw $offset $(ls iperf-h*)
    plot_iperf.R $bw $offset $(ls iperf-h*)
    mv iperf.png iperf-${tech}.png

    grep -Ev ",(0.0-[^1])|,(0.0-1[0-9]+)" iperf_h1.txt | sed 's/-/,/' > iperf_h1.txt.fixed
    for i in $(seq 2 $n); do
      tshift=$(($offset * ($i - 2)))
      perl -pi.bak -e "s/(5001,10.0.0.$i,\d+,\d+,)(\d+\.?\d+),/\"\$1\".(\$2 + $tshift).\",\"/e" iperf_h1.txt.fixed
    done
    echo plot_iperf_stacked.R iperf_h1.txt.fixed
    plot_iperf_stacked.R iperf_h1.txt.fixed
    mv iperf-stacked.png iperf-stacked-${tech}.png

    cd -
    mv $odir/iperf.png $zoodir/iperf-${tech}.png
  fi

  # move remaining pngs
  mv $odir/*.png $zoodir/

  [ -f $odir/h1_tcpdump.pcap ] && bz $odir/h1_tcpdump.pcap
}

function runexperiment () {
  local loc_tcp="${1}"
  local loc_ecn="${2}"
  local loc_aqm="${3}"
  local loc_tech="${1}"
  allargs=""

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

  echo sudo python inigo.py $allargs
  sudo bash -c "python inigo.py $allargs 2>&1 | tee -a $odir/experiment.log"
  #expstatus=$?
  #if [ $expstatus -lt 1 ]; then
  #  exit
  #fi

  echo postprocess $loc_tech $odir
  postprocess $loc_tech $odir

  sudo mn -c

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

touch $zoodir/experiment.log
cd $zoodir/qlen_s1-eth1

for tcp in $tcps; do
  echo plot_queue.R ${tcp}*
  plot_queue.R ${tcp}* 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all-${tcp}.png
  mv qlen-cdf.png qlen-cdf-all-${tcp}.png
done

if [ $ntcps -gt 1 ]; then
  echo plot_queue.R *
  plot_queue.R * 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all.png
  mv qlen-cdf.png qlen-cdf-all.png

  echo plot_queue.R $tcps
  plot_queue.R $tcps 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all-plain.png
  mv qlen-cdf.png qlen-cdf-all-plain.png

  if [ "$ecn" ]; then
    echo plot_queue.R *+${ecn}
    plot_queue.R *+${ecn} 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-all+${ecn}.png
    mv qlen-cdf.png qlen-cdf-all+${ecn}.png
  fi

  for aqm in $aqms; do
    echo plot_queue.R *+${aqm}
    plot_queue.R *+${aqm} 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-all+${aqm}.png
    mv qlen-cdf.png qlen-cdf-all+${aqm}.png

    if [ "$ecn" ]; then
      echo plot_queue.R *+${ecn}+${aqm}
      plot_queue.R *+${ecn}+${aqm} 2>&1 | tee -a ../experiment.log
      mv qlen.png qlen-all+${ecn}+${aqm}.png
      mv qlen-cdf.png qlen-cdf-all+${ecn}+${aqm}.png
    fi
  done

  if [ "$expected_www_techs" ]; then
    echo plot_queue.R $expected_www_techs
    plot_queue.R $expected_www_techs 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-expectedwww.png
    mv qlen-cdf.png qlen-cdf-expectedwww.png
  fi

  if [ "$best_techs" ]; then
    echo plot_queue.R $best_techs
    plot_queue.R $best_techs 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-best.png
    mv qlen-cdf.png qlen-cdf-best.png
  fi
fi

for tcp in $tcps; do
  for f in $(ls ${tcp}* | grep -Ev "bz|.py"); do
    bz $f
  done
done
mv *png ../
cd - # end qlen plotting

cd $zoodir/tcp_probe_downsampled
if [ $ntcps -gt 1 ]; then
  tech="all"
  echo plot_tcpprobe_srtt.R $rtt_us *
  plot_tcpprobe_srtt.R $rtt_us * 2>&1 | tee -a ../experiment.log
  mv srtt.png srtt-${tech}.png
  mv srtt-cdf.png srtt-cdf-${tech}.png

  tech="all-plain"
  echo plot_tcpprobe_srtt.R $rtt_us $tcps
  plot_tcpprobe_srtt.R $rtt_us $tcps 2>&1 | tee -a ../experiment.log
  mv srtt.png srtt-${tech}.png
  mv srtt-cdf.png srtt-cdf-${tech}.png

  if [ "$ecn" ]; then
    echo plot_queue.R *+${ecn}
    plot_queue.R *+${ecn} 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-all+${ecn}.png
    mv qlen-cdf.png qlen-cdf-all+${ecn}.png

    tech="all-ecn"
    echo plot_tcpprobe_srtt.R $rtt_us *+${ecn}
    plot_tcpprobe_srtt.R $rtt_us *+${ecn} 2>&1 | tee -a ../experiment.log
    mv srtt.png srtt-${tech}.png
    mv srtt-cdf.png srtt-cdf-${tech}.png
  fi
fi

for tcp in $tcps; do
  if [ $(ls -1 ${tcp}* | wc -l) -gt 1 ]; then
    tech="all-$tcp"
    echo plot_tcpprobe_srtt.R $rtt_us ${tcp}*
    plot_tcpprobe_srtt.R $rtt_us ${tcp}* 2>&1 | tee -a ../experiment.log
    mv srtt.png srtt-${tech}.png
    mv srtt-cdf.png srtt-cdf-${tech}.png
  fi
done

if [ $(basename $(pwd)) == "tcp_probe_downsampled" ]; then
  for tcp in $tcps; do
    for f in $(ls ${tcp}* | grep -Ev "bz|.py"); do
      bz $f
    done
  done
  mv *png ../
fi
cd - # end tcp_probe plotting
