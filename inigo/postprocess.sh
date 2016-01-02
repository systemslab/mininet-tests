#!/bin/bash

UTIL_DIR=$PWD/../util
export PATH=$PATH:$UTIL_DIR

# usage: ./postprocess.sh <experiment> [<descriptive note>]
# if a Flent experiment isn't specified, then a simple iperf test is run
# if a descriptive note (no spaces allowed) isn't given, then a date is used
if [ -z "$1" ]; then
  experiment="iperf"
  exp_opt=""
elif [ "$1" = "iperf" ]; then
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

graphdir=$experiment-$note
mkdir -p $graphdir

bz () {
    if hash pbzip2 2>/dev/null; then
        pbzip2 "$@"
    else
        bzip2 "$@"
    fi
}

downsample () {
  infile=$1
  outfile=$2
  percentageX1000=$3

  cat $infile | perl -e '
    my $percentageX1000 = $ARGV[0];
    my $outfile = $ARGV[1];
    open OUT1, ">", "$outfile" or die $!;
    while (<STDIN>) {
        if (rand(100000) < $percentageX1000) { print OUT1 $_; }
    }
    close OUT1 or die $!;
' $percentageX1000 $outfile
}

postprocess () {
  local tcpA="${1}"
  local tcpB="${2}"
  local tcpC="${3}"
  local tcpD="${4}"
  local tech="${1}"
  allargs=""

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

  echo postprocess tech="$tech" odir="$odir" args="$*"
  user=$(whoami)

  sudo chown -R $user $odir
  if [ -n "$DRYRUN" ]; then
    return 0
  fi

  mkdir -p $graphdir/qlen
  mv $odir/qlen_s1-eth1.txt $graphdir/qlen/$tech &> /dev/null

  #echo python $UTIL_DIR/plot_cpu.py -f $odir/cpu.txt -o $odir/cpu-${tech}.png
  #python $UTIL_DIR/plot_cpu.py -f $odir/cpu.txt -o $odir/cpu-${tech}.png
  #mv $odir/cpu-${tech}.png $graphdir/ &> /dev/null

  mkdir -p $graphdir/pkt_stats
  pkt_stats.sh $odir > $graphdir/pkt_stats/$tech

  if [ -f $odir/tcp_probe.txt ]; then
    mkdir -p $graphdir/srtt
    cd $odir
    server="10.0.0.1"
    # separate to/from 10.0.0.1 (also filters out 127.0.0.1, etc.)
    grep -E "10.0.0.[0-9]+:[0-9]+ ${server}:" tcp_probe.txt > tcp_probe-to-10.0.0.1

    # doing this for each raw file (pre-downsampled) can take a long time
    echo plot_tcpprobe.R $server $rtt_us tcp_probe-to-10.0.0.1
    plot_tcpprobe.R $server $rtt_us tcp_probe-to-10.0.0.1
    mv srtt-${server}.png srtt-${server}-${tech}.png &> /dev/null
    mv srtt-cdf-${server}.png srtt-cdf-${server}-${tech}.png &> /dev/null
    mv srtt-pdf-${server}.png srtt-pdf-${server}-${tech}.png &> /dev/null
    mv cwnd-${server}.png cwnd-${server}-${tech}.png &> /dev/null
    mv cwnd+ssthresh+wnd-${server}.png cwnd+ssthresh+wnd-${server}-${tech}.png &> /dev/null
    mv cwnd+ssthresh-${server}.png cwnd+ssthresh-${server}-${tech}.png &> /dev/null
    mv ssthresh-${server}.png ssthresh-${server}-${tech}.png &> /dev/null
    mv wnd-${server}.png wnd-${server}-${tech}.png &> /dev/null

    #  we want to get the latency index from the full data set
    mv tcp_probe-to-10.0.0.1 ${tech}
    echo plot_tcpprobe_srtt.R $rtt_us ${tech}
    plot_tcpprobe_srtt.R $rtt_us ${tech} 2>&1 | tee -a srtts.txt
    perl -ne '/"([\w\+-]+) (\w+) latency .*index (\d\.\d+)"/ && print "$1 $3\n"' srtts.txt > latency_index.txt
    max_srtt=$(perl -ne '/"([\w\+-]+) max ([\d\.]+)"/ && print "$2"' srtts.txt)
    mv srtt-cdf.png srtt-cdf-${tech}-full.png &> /dev/null

    # only keep the downsampled version, since the original grows so big
    # plus, the points in the plots tend to only be visible with around 200 samples
    downsample ${tech} ../$graphdir/srtt/${tech} $((100000 * 200 / $(wc -l < ${tech})))
    grep $max_srtt ${tech} >> ../$graphdir/srtt/${tech}
    rm ${tech}
    cd -
  fi

  if [ "$experiment" = "iperf" ]; then
    # timestamp,saddress,sport,daddress,dport,interval,transferred_bytes,bps
    for i in $(seq 2 $n); do
      perl -ne "/10\.0\.0\.$i,/ && /(0\.0-1\.0)|([^0]+\.0-)/ && s/(\d+)\.0-\d+\.0/\$1/ && print" $odir/iperf_h1.txt > $odir/iperf-h$i
    done
    cd $odir

    echo plot_iperf.R $bw $offset $(ls iperf-h*)
    plot_iperf.R $bw $offset $(ls iperf-h*)
    mv iperf.png iperf-${tech}.png &> /dev/null

    grep -Ev ",(0.0-[^1])|,(0.0-1[0-9]+)" iperf_h1.txt | sed 's/-/,/' > iperf_h1.txt.fixed
    for i in $(seq 2 $n); do
      tshift=$(($offset * ($i - 2)))
      perl -pi.bak -e "s/(5001,10.0.0.$i,\d+,\d+,)(\d+\.?\d+),/\"\$1\".(\$2 + $tshift).\",\"/e" iperf_h1.txt.fixed
    done

    echo plot_iperf_stacked_trimmed.R $bw iperf_h1.txt.fixed
    plot_iperf_stacked_trimmed.R $bw iperf_h1.txt.fixed
    mv iperf-stacked.png iperf-stacked-${tech}.png &> /dev/null

    cd -
    mv $odir/iperf.png $graphdir/iperf-${tech}.png &> /dev/null

    mkdir -p $graphdir/iperf
    mv $odir/iperf_h1.txt $graphdir/iperf/${tech} &> /dev/null
    mkdir -p $graphdir/iperf.fixed
    mv $odir/iperf_h1.txt.fixed $graphdir/iperf.fixed/${tech} &> /dev/null

    mkdir -p $graphdir/iperf.aggr
    echo -n "results[\"${tech}\"] = [" > $graphdir/iperf.aggr/${tech}
    perl -ne '/\d+\.\d+\.\d+\.\d+,\d+,\d+,0\.0-([2-9]\.\d+|[1-9]\d+\.\d+),(\d+)/ && print "$2 * 8 / total_time,\n"' $graphdir/iperf/${tech} >> $graphdir/iperf.aggr/${tech}
    echo ']' >> $graphdir/iperf.aggr/${tech}
  fi

  # move remaining pngs
  mv $odir/*.png $graphdir/ &> /dev/null

  # use gzip for pcap since wireshark understands that, but not other compression
  [ -f $odir/h1_tcpdump.pcap ] && gzip $odir/h1_tcpdump.pcap
} # end postprocess()

for tcp in $tcps; do
  #echo postprocess ${tcp}
  postprocess ${tcp}

  if [ "$rcvs" ]; then
    for rcv in $rcvs; do
      #echo postprocess ${tcp} ${rcv}
      postprocess ${tcp} ${rcv}

      if [ "$aqms" ]; then
        for aqm in $aqms; do
          #echo postprocess ${tcp} ${aqm} ${rcv}
          postprocess ${tcp} ${aqm} ${rcv}
          postprocess ${tcp} ${aqm}

          if [ "${ecn}" ]; then
            #echo postprocess ${tcp} ${ecn} ${aqm} ${rcv}
            postprocess ${tcp} ${ecn} ${aqm} ${rcv}
            postprocess ${tcp} ${ecn} ${aqm}
          fi
        done
      elif [ "${ecn}" ]; then
        #echo postprocess ${tcp} ${ecn} ${rcv}
        postprocess ${tcp} ${ecn} ${rcv}
        postprocess ${tcp} ${ecn}
      fi
    done
  elif [ "$aqms" ]; then
    for aqm in $aqms; do
      #echo postprocess ${tcp} ${aqm}
      postprocess ${tcp} ${aqm}

      if [ "${ecn}" ]; then
        #echo postprocess ${tcp} ${ecn} ${aqm}
        postprocess ${tcp} ${ecn} ${aqm}
        postprocess ${tcp} ${ecn}
      fi
    done
  elif [ "${ecn}" ]; then
    #echo postprocess ${tcp} ${ecn}
    postprocess ${tcp} ${ecn}
  fi
done

echo Comparison plots

if [ -n "$DRYRUN" ]; then
  exit
fi

touch $graphdir/experiment.log

cat $experiment-*-$note/latency_index.txt | sort > $graphdir/latency_index.txt

cd $graphdir/pkt_stats
grep -A1 seg * > ../pkt_stats.txt
cd -

cd $graphdir/qlen

for tcp in $tcps; do
  echo plot_queue.R ${tcp}*
  plot_queue.R ${tcp}* 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all-${tcp}.png &> /dev/null
  mv qlen-cdf.png qlen-cdf-all-${tcp}.png &> /dev/null
done

if [ $ntcps -gt 1 ]; then
  echo plot_queue.R *
  plot_queue.R * 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all.png &> /dev/null
  mv qlen-cdf.png qlen-cdf-all.png &> /dev/null

  echo plot_queue.R $tcps
  plot_queue.R $tcps 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all-plain.png &> /dev/null
  mv qlen-cdf.png qlen-cdf-all-plain.png &> /dev/null

  if [ "$ecn" ]; then
    echo plot_queue.R *+${ecn}
    plot_queue.R *+${ecn} 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-all+${ecn}.png &> /dev/null
    mv qlen-cdf.png qlen-cdf-all+${ecn}.png &> /dev/null
  fi

  for aqm in $aqms; do
    echo plot_queue.R *+${aqm}
    plot_queue.R *+${aqm} 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-all+${aqm}.png &> /dev/null
    mv qlen-cdf.png qlen-cdf-all+${aqm}.png &> /dev/null

    if [ "$ecn" ]; then
      echo plot_queue.R *+${ecn}+${aqm}
      plot_queue.R *+${ecn}+${aqm} 2>&1 | tee -a ../experiment.log
      mv qlen.png qlen-all+${ecn}+${aqm}.png &> /dev/null
      mv qlen-cdf.png qlen-cdf-all+${ecn}+${aqm}.png &> /dev/null
    fi
  done

  if [ "$expected_www_techs" ]; then
    echo plot_queue.R $expected_www_techs
    plot_queue.R $expected_www_techs 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-expectedwww.png &> /dev/null
    mv qlen-cdf.png qlen-cdf-expectedwww.png &> /dev/null
  fi

  if [ "$best_techs" ]; then
    echo plot_queue.R $best_techs
    plot_queue.R $best_techs 2>&1 | tee -a ../experiment.log
    mv qlen.png qlen-best.png &> /dev/null
    mv qlen-cdf.png qlen-cdf-best.png &> /dev/null
  fi
fi

# uncomment if you want to compress stuff
# for tcp in $tcps; do
#  for f in $(ls ${tcp}* | grep -Ev "bz|.py|png"); do
#    bz $f
#  done
#done

mv *png ../ &> /dev/null
cd - # end qlen plotting

cd $graphdir/srtt
tech="all"
echo plot_tcpprobe_srtt.R $rtt_us *
plot_tcpprobe_srtt.R $rtt_us * 2>&1 | tee -a ../experiment.log
mv srtt.png srtt-${tech}.png &> /dev/null
mv srtt-cdf.png srtt-cdf-${tech}.png &> /dev/null

tech="all-plain"
echo plot_tcpprobe_srtt.R $rtt_us $tcps
plot_tcpprobe_srtt.R $rtt_us $tcps 2>&1 | tee -a ../experiment.log
mv srtt.png srtt-${tech}.png &> /dev/null
mv srtt-cdf.png srtt-cdf-${tech}.png &> /dev/null

if [ "$ecn" ]; then
  echo plot_queue.R *+${ecn}
  plot_queue.R *+${ecn} 2>&1 | tee -a ../experiment.log
  mv qlen.png qlen-all+${ecn}.png &> /dev/null
  mv qlen-cdf.png qlen-cdf-all+${ecn}.png &> /dev/null

  tech="all-ecn"
  echo plot_tcpprobe_srtt.R $rtt_us *+${ecn}
  plot_tcpprobe_srtt.R $rtt_us *+${ecn} 2>&1 | tee -a ../experiment.log
  mv srtt.png srtt-${tech}.png &> /dev/null
  mv srtt-cdf.png srtt-cdf-${tech}.png &> /dev/null
fi

for tcp in $tcps; do
  if [ $(ls -1 ${tcp}* | wc -l) -gt 1 ]; then
    tech="all-$tcp"
    echo plot_tcpprobe_srtt.R $rtt_us ${tcp}*
    plot_tcpprobe_srtt.R $rtt_us ${tcp}* 2>&1 | tee -a ../experiment.log
    mv srtt.png srtt-${tech}.png &> /dev/null
    mv srtt-cdf.png srtt-cdf-${tech}.png &> /dev/null
  fi
done

if [ $(basename $(pwd)) = "srtt" ]; then
  # uncomment if you want to compress
  # for tcp in $tcps; do
  #   for f in $(ls ${tcp}* | grep -Ev "bz|.py|png"); do
  #     bz $f
  #   done
  # done
  mv *png ../ &> /dev/null
fi
cd - # end tcp_probe plotting
