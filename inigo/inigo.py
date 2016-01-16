#!/usr/bin/python
import sys
sys.path = ['../'] + sys.path

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.log import lg, output
from mininet.node import CPULimitedHost, OVSController
from mininet.link import TCLink
from mininet.util import irange, custom, quietRun, dumpNetConnections
from mininet.cli import CLI

from time import sleep, time
import multiprocessing
from subprocess import *
import re
import termcolor as T
import argparse

import os
from util.monitor import monitor_cpu, monitor_qlen, monitor_devs_ng

parser = argparse.ArgumentParser(description="Inigo tester (Star topology)")
# EXAMPLE: sudo python inigo.py --debug -n 3 --bw 100 --delay 10 -d tmp
parser.add_argument('--debug',
                    dest="debug",
                    action="store_true",
                    help="Debug",
                    default=False)

parser.add_argument('--iperf',
                    dest="iperf",
                    action="store_true",
                    help="Execute a basic iperf test",
                    default=False)

parser.add_argument('--convergence',
                    dest="convergence",
                    action="store_true",
                    help="Execute an iperf test similar to DCTCP's Fig. 16 convergence test",
                    default=False)

parser.add_argument('--flent',
                    dest="flent",
                    action="store",
                    help="Execute a Flent experiment instead of basic iperf test",
                    default=None)

parser.add_argument('--pcc',
                    dest="pcc",
                    action="store_true",
                    help="Execute a pcc test",
                    default=False)

parser.add_argument('--sysconfidence',
                    dest="sysconfidence",
                    action="store",
                    help="Execute a System Confidence experiment instead of basic iperf test",
                    default=None)

parser.add_argument('--bottleneck',
                    dest="bottleneck",
                    action="store",
                    help="Limit bandwidth on switch links to X*bw, 0 < X <= 1.0, default 1.0",
                    default=1.0)

parser.add_argument('--bw', '-B',
                    dest="bw",
                    action="store",
                    help="Bandwidth of links",
                    required=True)

parser.add_argument('--delay',
                    dest="delay",
                    help="Delay of each link from switch in milliseconds",
                    required=True)
# 1000 Mbps
#	default="0.012")
# 100 Mbps
#	default="0.123)
# 10 Mbps
#	default="1.23

parser.add_argument('--delayinc',
                    dest="delayinc",
                    help="Increase each link's delay by X ms more than the previous link (RTT fairness testing)",
                    default="0")

parser.add_argument('--loss',
                    dest="loss",
                    help="loss on switch links. for example 'random 2%' see man tc-netperf for details, default 0%",
                    default="")

parser.add_argument('--dir', '-d',
                    dest="dir",
                    action="store",
                    help="Directory to store outputs",
                    required=True)

parser.add_argument('-n',
                    dest="n",
                    action="store",
                    help="Number of nodes in star ",
                    required=True)

parser.add_argument('-t',
                    dest="t",
                    action="store",
                    help="Seconds to run the experiment",
                    default=30)

parser.add_argument('--offset',
                    dest="offset",
                    action="store",
                    help="Seconds between clients start",
                    default=0)

parser.add_argument('-u', '--udp',
                    dest="udp",
                    action="store_true",
                    help="Run UDP test",
                    default=False)

parser.add_argument('--use-hfsc',
                    dest="use_hfsc",
                    action="store_true",
                    help="Use HFSC qdisc",
                    default=False)

parser.add_argument('--maxq',
                    dest="maxq",
                    action="store",
                    help="Max buffer size of each interface",
                    default=425)

parser.add_argument('--speedup-bw',
                    dest="speedup_bw",
                    action="store",
                    help="Speedup bw for switch interfaces",
                    default=-1)

parser.add_argument('--dctcp',
                    dest="dctcp",
                    action="store_true",
                    help="Enable DCTCP module",
                    default=False)

parser.add_argument('--dctcp-args',
                    dest="dctcp_args",
                    action="store",
                    help="DCTCP module args",
                    default="")

parser.add_argument('--dctcpe',
                    dest="dctcpe",
                    action="store_true",
                    help="Enable DCTCPE module",
                    default=False)

parser.add_argument('--inigo',
                    dest="inigo",
                    action="store_true",
                    help="Enable Inigo module",
                    default=False)

parser.add_argument('--inigo-args',
                    dest="inigo_args",
                    action="store",
                    help="Inigo module args",
                    default="")

parser.add_argument('--inigo_rttonly',
                    dest="inigo_rttonly",
                    action="store_true",
                    help="Enable Inigo module",
                    default=False)

parser.add_argument('--reno',
                    dest="reno",
                    action="store_true",
                    help="Enable Reno module",
                    default=False)

parser.add_argument('--vegas',
                    dest="vegas",
                    action="store_true",
                    help="Enable Vegas module",
                    default=False)

parser.add_argument('--westwood',
                    dest="westwood",
                    action="store_true",
                    help="Enable Westwood module",
                    default=False)

parser.add_argument('--cubic',
                    dest="cubic",
                    action="store_true",
                    help="Enable CUBIC module",
                    default=False)

parser.add_argument('--cdg',
                    dest="cdg",
                    action="store_true",
                    help="Enable CDG module",
                    default=False)

parser.add_argument('--cdg-args',
                    dest="cdg_args",
                    action="store",
                    help="CDG module args",
                    default="use_tolerance=1")

parser.add_argument('--relentless',
                    dest="relentless",
                    action="store_true",
                    help="Enable Relentless module",
                    default=False)

parser.add_argument('--disable-offload',
                    dest="disable_offload",
                    action="store_true",
                    help="Disable offload support",
                    default=False)

parser.add_argument('--mss',
                    dest="mss",
                    action="store",
                    help="set Maximum Segment Size for TCP",
                    default=0)

parser.add_argument('--ecn',
                    dest="ecn",
                    action="store_true",
                    help="Enable ECN (net.ipv4.tcp_ecn) hosts and DCTCP-style ECN marking on switches",
                    default=False)

parser.add_argument('--switchecn',
                    dest="switchecn",
                    action="store_true",
                    help="Enable DCTCP-style ECN marking on switches",
                    default=False)

parser.add_argument('--hostecn',
                    dest="hostecn",
                    action="store_true",
                    help="Enable ECN (net.ipv4.tcp_ecn)",
                    default=False)

parser.add_argument('--hostbw',
                    dest="hostbw",
                    action="store",
                    help="Set bandwidth on clients to X*bw of bottleneck link, default 0, means unlimited",
                    default=0)

parser.add_argument('--fq',
                    dest="fq",
                    action="store_true",
                    help="Enable FQ qdisc",
                    default=False)

parser.add_argument('--fqcodel',
                    dest="fqcodel",
                    action="store_true",
                    help="Enable FQ_Codel qdisc",
                    default=False)

parser.add_argument('--cake',
                    dest="cake",
                    action="store_true",
                    help="Enable Cake qdisc",
                    default=False)

parser.add_argument('--use-bridge',
                    dest="use_bridge",
                    action="store_true",
                    help="Use Linux Bridge as switch",
                    default=False)

parser.add_argument('--tcpdump',
                    dest="tcpdump",
                    action="store_true",
                    help="Run tcpdump on host interfaces",
                    default=False)

parser.add_argument('--more-monitoring',
                    dest="more_monitoring",
                    action="store_true",
                    help="Increase amount of monitoring",
                    default=False)

parser.add_argument('--no-tcp-probe',
                    dest="no_tcp_probe",
                    action="store_true",
                    help="Don't monitor using tcp_probe module (cwnd)",
                    default=False)

parser.add_argument('--rcv-cong',
                    dest="rcv_cong",
                    action="store_true",
                    help="Enable receiver-based congestion control",
                    default=False)

parser.add_argument('--rcv-dctcp',
                    dest="rcv_dctcp",
                    action="store_true",
                    help="Enable receiver-based dctcp",
                    default=False)

parser.add_argument('--rcv-mark',
                    dest="rcv_mark",
                    action="store_true",
                    help="Enable receiver-based ECN marking",
                    default=False)

parser.add_argument('--rcv-fairness',
                    dest="rcv_fairness",
                    action="store",
                    help="Adjust receiver's RTT-fairness (0 to disable)",
                    default=10)

parser.add_argument('--rcv-rebase',
                    dest="rcv_rebase",
                    action="store",
                    help="Rebase receiver's congestion window when RFD total < 0 (0 to disable, 1 to 1024 back off fraction of window)",
                    default=0)

parser.add_argument('--tcp-us-tstamp',
                    dest="tcp_us_tstamp",
                    action="store_true",
                    help="enable microsecond resolution TCP timestamps (default ms)",
                    default=False)

parser.add_argument('--disable_tcp_early_retrans',
                    dest="tcp_early_retrans",
                    action="store_false",
                    help="disable TCP early retransmit (default enabled)",
                    default=True)

parser.add_argument('--disable_tcp_fack',
                    dest="tcp_fack",
                    action="store_false",
                    help="disable TCP fast retransmit (default enabled)",
                    default=True)

args = parser.parse_args()
args.n = int(args.n)
args.bw = float(args.bw)
args.mss = int(args.mss)
args.bottleneck = float(args.bottleneck)
args.hostbw = float(args.hostbw)
if args.speedup_bw == -1:
    args.speedup_bw = args.bw
args.delay = float(args.delay)
args.delayinc = float(args.delayinc)
args.n = max(args.n, 2)

# calculate threshold according to DCTCP's 0.17*BDP rule of thumb
# assume delay is in ms, and only added on switch ports
# delay is OWD and in ms, so multiply by 2 for RTT and 1000 for microseconds
# bw is in Mbps, so divide by 8 (Mega and micro cancel)
bdp = 2 * args.delay * args.bottleneck * args.bw * 1000 / 8
if args.ecn or args.switchecn:
    if args.disable_offload:
        avpkt=1000
        burst=5000
    else:
        avpkt=65500
        burst=avpkt

    dctcpK = max(int(0.17 * bdp), avpkt)
    red_args="limit 1000000b avpkt {} min {}b max {}b ecn".format(avpkt, dctcpK, dctcpK+burst)
    print "bw={} delay={}ms bdp={}".format(args.bottleneck * args.bw, args.delay, bdp)
    print "red_args={}".format(red_args)

if not os.path.exists(args.dir):
    os.makedirs(args.dir)

if args.use_bridge:
    from mininet.node import Bridge as Switch
else:
    from mininet.node import OVSKernelSwitch as Switch

lg.setLogLevel('info')

class StarTopo(Topo):

    def __init__(self, n=3, bw=100):
        # Add default members to class.
        super(StarTopo, self ).__init__()

        # Host and link configuration

        # Note that even though we enable ecn and delay to every link here,
        # we'll remove the red and netem qdiscs later on the hosts and leave them on switches.
        # This is because netem doesn't always play nice with other qdiscs, and
        # having on switch egress should be enough. Also, we'll want to test other AQMs on the hosts.
        hconfig = {'cpu': -1}
	lconfig = {'bw': bw, 
		   'delay': '{}ms'.format(args.delay),
		   'enable_ecn': args.ecn or args.switchecn,
		   'max_queue_size': int(args.maxq),
		   'use_hfsc': args.use_hfsc,
		   'speedup': float(args.speedup_bw)
		  }

        print '~~~~~~~~~~~~~~~~~> BW = %s' % bw

        # Create switch and host nodes
        for i in xrange(n):
            self.addHost('h%d' % (i+1), **hconfig)

        self.addSwitch('s1',)

        for i in xrange(1, n+1):
            self.addLink('h%d' % (i), 's1', **lconfig)

def waitListening(client, server, port):
    "Wait until server is listening on port"
    if not 'telnet' in client.cmd('which telnet'):
        raise Exception('Could not find telnet')
    cmd = ('sh -c "echo A | telnet -e A %s %s"' %
           (server.IP(), port))
    i = 0
    while (i < 10) and 'Connected' not in client.cmd(cmd):
        i += 1
        output('waiting for', server, 'to listen on port', port, '\n')
        sleep(.5)

def progress(t):
    while t > 0:
        print T.colored('  %3d seconds left  \r' % (t), 'cyan'),
        t -= 1
        sys.stdout.flush()
        sleep(1)
    print '\r\n'

def enable_tcp_ecn(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_ecn=1", shell=True).wait()
        result = check_output(['cat', '/proc/sys/net/ipv4/tcp_ecn'])
        print "system ecn = {}".format(result)
        return

    node.popen("sysctl -w net.ipv4.tcp_ecn=1", shell=True).wait()
    result = node.cmd('cat /proc/sys/net/ipv4/tcp_ecn').rstrip('\r\n')
    print "{} ecn = {}".format(node, result)

def disable_tcp_ecn(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_ecn=0", shell=True).wait()
        result = check_output(['cat', '/proc/sys/net/ipv4/tcp_ecn'])
        print "system ecn = {}".format(result)
        return

    node.popen("sysctl -w net.ipv4.tcp_ecn=0", shell=True).wait()
    result = node.cmd('cat /proc/sys/net/ipv4/tcp_ecn').rstrip('\r\n')
    print "{} ecn = {}".format(node, result)

def enable_rcv_cong(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=1", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=1", shell=True).wait()

def disable_rcv_cong(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=0", shell=True).wait()

def enable_rcv_dctcp(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_dctcp=1", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_dctcp=1", shell=True).wait()

def disable_rcv_dctcp(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_dctcp=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_dctcp=0", shell=True).wait()

def enable_rcv_mark(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_ecn_marking=1", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_ecn_marking=1", shell=True).wait()

def disable_rcv_mark(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_ecn_marking=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_ecn_marking=0", shell=True).wait()

def set_rcv_fairness(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_cc_fairness={}".format(args.rcv_fairness), shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_cc_fairness={}".format(args.rcv_fairness), shell=True).wait()

def enable_rcv_rebase(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_cc_rebase={}".format(args.rcv_rebase), shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_cc_rebase={}".format(args.rcv_rebase), shell=True).wait()

def disable_rcv_rebase(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_cc_rebase=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_cc_rebase=0", shell=True).wait()

def enable_tcp_us_tstamp(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_us_tstamp=1", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_us_tstamp=1", shell=True).wait()

def disable_tcp_us_tstamp(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_us_tstamp=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_us_tstamp=0", shell=True).wait()

def disable_tcp_early_retrans(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_early_retrans=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_early_retrans=0", shell=True).wait()

def disable_tcp_fack(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_fack=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_fack=0", shell=True).wait()

def set_hostbw(node=None):
    if not node:
        return

    node.popen("tc qdisc del dev {}-eth0 root htb".format(node), shell=True).wait()
    node.popen("ifconfig {}-eth0 txqueuelen 2".format(node), shell=True).wait()
    node.popen("tc qdisc add dev {}-eth0 root handle 5: htb default 1".format(node), shell=True).wait()
    node.popen("tc class add dev {}-eth0 parent 5:0 classid 5:1 htb rate {}Mbit burst 15K".format(node, args.hostbw*args.bw), shell=True).wait()

def enable_fq(node=None):
    if not node:
        return

    node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq".format(node), shell=True).wait()

def enable_fqcodel(node=None):
    if not node:
        return

    rtt = 2*args.delay
    interval = 4*rtt        # on order of worst case RTT
    target = 0.05*interval  # 5% of worst case
    ecn = "noecn"
    if args.ecn or args.hostecn:
        ecn = "ecn"

    if args.bw <= 10:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 400 target {:.3f}ms interval {}ms quantum 500 {}".format(node, target, interval, ecn), shell=True).wait()
    elif args.bw <= 100:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 800 target {:.3f}ms interval {}ms {}".format(node, target, interval, ecn), shell=True).wait()
    else:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 1200 target {:.3f}ms interval {}ms {}".format(node, target, interval, ecn), shell=True).wait()

def enable_cake(node=None):
    if not node:
        return

    enable_tcp_ecn(node)
    Popen("modprobe sch_cake", shell=True)
    Popen("modprobe act_mirred", shell=True)

    # outbound
    node.popen("tc qdisc del dev {}-eth0 root htb".format(node), shell=True).wait()
    print "tc qdisc add dev {}-eth0 parent 5:1 handle 10: cake".format(node)
    node.popen("tc qdisc add dev {}-eth0 root cake bandwidth {}mbit".format(node, args.hostbw*args.bw), shell=True).wait()

    # inbound
    node.popen("ip link add name {}-ifb4eth0 type ifb".format(node), shell=True).wait()
    node.popen("tc qdisc del dev {}-eth0 ingress".format(node), shell=True).wait()
    node.popen("tc qdisc add dev {}-eth0 handle ffff: ingress".format(node), shell=True).wait()
    node.popen("tc qdisc del dev {}-ifb4eth0 root".format(node), shell=True).wait()
    node.popen("tc qdisc add dev {}-ifb4eth0 root cake bandwidth {}mbit besteffort".format(node, args.bw), shell=True).wait()
    # if you don't bring the device up your connection will lock up on the next step
    node.popen("ifconfig {}-ifb4eth0 up".format(node), shell=True).wait()
    node.popen("tc filter add dev {}-eth0 parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev {}-ifb4eth0".format(node, node), shell=True).wait()

args.tcp = ""

def enable_reno():
    Popen("/bin/echo reno > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "reno"

def enable_vegas():
    Popen("/bin/echo vegas > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "vegas"

def enable_westwood():
    Popen("/bin/echo westwood > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "westwood"

def enable_cubic():
    Popen("/bin/echo cubic > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "cubic"

def enable_cdg():
    Popen("modprobe tcp_cdg {}".format(args.cdg_args), shell=True)
    Popen("/bin/echo cdg > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "cdg"

def enable_relentless():
    Popen("/bin/echo relentless > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "relentless"

def disable_relentless():
    Popen("rmmod tcp_relentless", shell=True).wait()

def enable_dctcp():
    force_ecn = ""
    if args.ecn or args.switchecn or args.hostecn:
        force_ecn = "dctcp_force_ecn=1"

    Popen("modprobe tcp_dctcp {} {}".format(force_ecn, args.dctcp_args), shell=True)
    Popen("/bin/echo dctcp > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "dctcp"

def disable_dctcp():
    Popen("rmmod tcp_dctcp", shell=True).wait()

def enable_dctcpe():
    Popen("modprobe tcp_dctcpe", shell=True)
    Popen("/bin/echo dctcpe > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "dctcpe"

def disable_dctcpe():
    Popen("rmmod tcp_dctcpe", shell=True).wait()

def enable_inigo():
    force_ecn = ""
    if args.ecn or args.switchecn or args.hostecn:
        force_ecn = "inigo_force_ecn=1"

    output('loading inigo module\n')
    Popen("modprobe tcp_inigo {} {}".format(force_ecn, args.inigo_args), shell=True)
    output('setting tcp to inigo\n')
    Popen("/bin/echo inigo > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "inigo"

def disable_inigo():
    Popen("rmmod tcp_inigo", shell=True).wait()

def enable_inigo_rttonly():
    Popen("modprobe tcp_inigo_rttonly {}".format(args.inigo_args), shell=True)
    Popen("/bin/echo inigo_rttonly > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()
    args.tcp = "inigo_rtt_only"

def disable_inigo_rttonly():
    Popen("rmmod tcp_inigo_rttonly", shell=True).wait()

def main():
    seconds = int(args.t)
    offset = int(args.offset)

    topo = StarTopo(n=args.n, bw=(args.bottleneck * args.bw))
    net = Mininet(topo=topo, host=CPULimitedHost, link=TCLink, switch=Switch,
            controller=OVSController,
	    autoStaticArp=True)
    net.start()

    # global config

    disable_tcp_ecn() # ensure ECN isn't accidentally left on

    if args.dctcp:
        disable_dctcp()
        enable_dctcp()
    else:
        disable_dctcp()

    if args.dctcpe:
        disable_dctcpe()
        enable_dctcpe()
    else:
        disable_dctcpe()

    if args.inigo:
        disable_inigo()
        enable_inigo()
    else:
        disable_inigo()

    if args.inigo_rttonly:
        disable_inigo_rttonly()
        enable_inigo_rttonly()
    else:
        disable_inigo_rttonly()

    if args.relentless:
        disable_relentless()
        enable_relentless()
    else:
        disable_relentless()

    if args.reno:
        enable_reno()

    if args.vegas:
        enable_vegas()

    if args.westwood:
        enable_westwood()

    if args.cubic:
        enable_cubic()

    if args.cdg:
        enable_cdg()

    if args.ecn or args.hostecn:
        enable_tcp_ecn()
    else:
        disable_tcp_ecn()

    if args.rcv_cong:
        enable_rcv_cong()
    else:
        disable_rcv_cong()

    if args.rcv_dctcp:
        enable_rcv_dctcp()
    else:
        disable_rcv_dctcp()

    if args.rcv_mark:
        enable_rcv_mark()
    else:
        disable_rcv_mark()

    set_rcv_fairness()

    if args.rcv_rebase:
        enable_rcv_rebase()
    else:
        disable_rcv_rebase()

    if args.tcp_us_tstamp:
        enable_tcp_us_tstamp()
    else:
        disable_tcp_us_tstamp()

    if not args.tcp_early_retrans:
        disable_tcp_early_retrans()

    if not args.tcp_fack:
        disable_tcp_fack()

    s1 = net.getNodeByName('s1')
    h1 = net.getNodeByName('h1')
    h2 = net.getNodeByName('h2')

    cmd = "tc -s qdisc show > %s/tc-stats-before.txt" % (args.dir)
    s1.popen(cmd, shell=True)

    cmd = "sysctl -a > %s/sysctl.txt" % (args.dir)
    s1.popen(cmd, shell=True)

    for i in xrange(1, args.n):
        node_name = 'h%d' % (i+1)
        h = net.getNodeByName(node_name)
        cmd = "/bin/netstat -s > %s/netstat-%s-before.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)
        cmd = "/sbin/ifconfig > %s/ifconfig-%s-before.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)

    net.getNodeByName('h1').pexec("/bin/netstat -s > %s/netstat-h1-before.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/ifconfig > %s/ifconfig-h1-before.txt" %
	    args.dir, shell=True)

    # per node config
    for i in xrange(1, args.n + 1):
        nn = 'h%d' % (i)
        node = net.getNodeByName(nn)
        #print "configuring node {}".format(nn)

        if not args.disable_offload:
            print "%s enabling offload" % nn
            node.popen('for feature in tso ufo gso gro lro; do ethtool -K  %s-eth0 $feature on; done' % (nn), shell=True).wait()
        else:
            print "%s disabling offload" % nn
            #node.popen('for feature in tso ufo gso gro lro; do ethtool -K  %s-eth0 $feature off; done' % (nn), shell=True).wait()
            node.popen('ethtool -K  %s-eth0 tso off' % (nn), shell=True).wait()
            node.popen('ethtool -K  %s-eth0 gso off' % (nn), shell=True).wait()

        node.popen("ethtool -k %s-eth0 > %s/ethtool-%s-features.txt" % (nn, args.dir, nn), shell=True)

        if args.ecn or args.hostecn:
            enable_tcp_ecn(node)
        else:
            disable_tcp_ecn(node)

        #print "removing netem/red qdiscs"
        # we only want red and delay on switches so we can be free to add other qdiscs to hosts
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 red limit 1000000b avpkt 1000".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 netem".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 6: netem".format(node), shell=True).wait()

        # override mininet's netem settings
        #print "overriding switch netem settings"

        netem_args = "limit {}".format(args.maxq)
        if args.delay != "":
            if args.delayinc > 0.0:
                netem_args += " delay {}ms".format(args.delay + (i-1)*args.delayinc)
            else:
                netem_args += " delay {}ms".format(args.delay)
        if args.loss != "":
            netem_args += " loss {}".format(args.loss)

        s1.popen('tc qdisc change dev s1-eth{} handle 10: netem {}'.format(i, netem_args), shell=True).wait()

        if args.ecn or args.switchecn:
            # set threshold according to DCTCP's 0.17*BDP rule of thumb
            cmd="tc qdisc change dev s1-eth{} handle 6: red {}".format(i, red_args)
            s1.popen(cmd, shell=True).wait()
            # previous command sometimes clobbers netem
            cmd="tc qdisc add dev s1-eth{} parent 6: handle 10: netem {}".format(i, netem_args)
            s1.popen(cmd, shell=True).wait()

        if args.hostbw > 0.0 and not (args.cake) :
            set_hostbw(node)

        if args.fq:
            enable_fq(node)

        if args.fqcodel:
            #print "enabling fqcodel"
            enable_fqcodel(node)

        if args.cake:
            #print "enabling cake"
            enable_cake(node)

        if args.bw <= 10:
            #print "setting byte queue limits to 1514"
            node.popen('echo 1514 > /sys/class/net/%s-eth0/queues/tx-0/byte_queue_limits/limit' % (nn), shell=True)
        else:
            #print "setting byte queue limits to 3000"
            node.popen('echo 3000 > /sys/class/net/%s-eth0/queues/tx-0/byte_queue_limits/limit' % (nn), shell=True)

    tech = s1.cmd('cat /proc/sys/net/ipv4/tcp_congestion_control').rstrip('\r\n')
    if not tech == args.tcp and not args.pcc:
        output('ERROR: {} not loaded, aborting experiment\n'.format(args.tcp))
        net.stop()
        sys.exit(-1)

    if args.fqcodel:
        tech = tech + '+fqcodel'
    if args.cake:
        tech = tech + '+cake'
    if args.ecn:
        tech = tech + '+ecn'
    if args.switchecn:
        tech = tech + '+switchecn'
    if args.hostecn:
        if args.rcv_mark:
            tech = tech + '+rcv_ecn'
        else:
            tech = tech + '+hostecn'
    if args.rcv_cong:
            tech = tech + '+rcv_cc'
    if args.rcv_dctcp:
            tech = tech + '+rcv_dctcp'

    exp_desc="{} Mbps, {} one way delay, tech: {}".format(args.bw, args.delay, tech)
    exp_output="bw{}-d{}-{}".format(args.bw, args.delay, tech)
    print exp_desc

    if args.debug:
        CLI(net)

    clients = [net.getNodeByName('h%d' % (i+1)) for i in xrange(1, args.n)]

    if args.convergence and not args.pcc:
        args.iperf = True

    if args.iperf:
        print "starting iperf server"
        mss = ""
        if args.mss > 0:
            mss = "-M {} -m".format(args.mss)

        h1.sendCmd('iperf -s -y c -i 1 {} > {}/iperf_h1.txt'.format(mss, args.dir))
        waitListening(clients[0], h1, 5001)
    elif args.pcc:
        print "starting pcc server"
        h1.sendCmd('appserver &> {}/pcc_server.log'.format(args.dir))
        waitListening(clients[0], h1, 9000)
    elif args.flent:
        print "starting netperf server"
        h1.sendCmd('netserver')
        waitListening(clients[0], h1, 12865)

    monitors = []

    if not args.no_tcp_probe:
        Popen("rmmod tcp_probe; modprobe tcp_probe full=1; cat /proc/net/tcpprobe > %s/tcp_probe.txt" % args.dir, shell=True)
        print "Waiting for tcp_probe"
        progress(5)

    if args.more_monitoring:
        monitor = multiprocessing.Process(target=monitor_cpu, args=('%s/cpu.txt' % args.dir,))
        monitor.start()
        monitors.append(monitor)

        monitor = multiprocessing.Process(target=monitor_devs_ng, args=('%s/txrate.txt' % args.dir, 0.01))
        monitor.start()
        monitors.append(monitor)

    monitor = multiprocessing.Process(target=monitor_qlen, args=('s1-eth1', 0.01, '%s/qlen_s1-eth1.txt' % (args.dir)))
    monitor.start()
    monitors.append(monitor)

    print h2.cmd("echo h2 traffic control && tc qdisc show && tc class show dev h2-eth0")

    h2.popen('/bin/ping 10.0.0.1 > %s/ping.txt' % args.dir, shell=True)
    if args.more_monitoring or args.tcpdump:
	#for i in xrange(args.n):
	for i in xrange(1):
	    node_name = 'h%d' % (i+1)
	    net.getNodeByName(node_name).popen('tcpdump -ni %s-eth0 -s60 -w \
		    %s/%s_tcpdump.pcap' % (node_name, args.dir, node_name), 
		    shell=True)
            print "Waiting for tcpdump"
            progress(5)

    for i in xrange(1, args.n):
        node_name = 'h%d' % (i+1)
        h = net.getNodeByName(node_name)

        if args.iperf:
	    print "Starting iperf client {}".format(node_name)
            flowtime = seconds
            if offset > 0 and args.convergence:
                flowtime = seconds + (args.n - i - 1) * offset * 2
                print "client {} offset {} flowtime {}".format(i+1, (i+1 - 2)*offset, flowtime)

            mss = ""
            if args.mss > 0:
                mss = "-M {} -m".format(args.mss)

            if args.udp:
                cmd = 'iperf -c 10.0.0.1 -t %d -y c -i 1 %s -u -b %sM > %s/iperf_%s.txt' % (flowtime, mss, args.bw, args.dir, node_name)
            else:
                cmd = 'iperf -c 10.0.0.1 -t %d -i 1 %s > %s/iperf_%s.txt' % (flowtime, mss, args.dir, node_name)
            h.sendCmd(cmd)
        elif args.pcc:
	    print "Starting pcc client {}".format(node_name)
            cmd = 'appclient 10.0.0.1 9000 > %s/pcc_%s.txt' % (args.dir, node_name)
            h.sendCmd(cmd)
        elif args.flent:
            title = "{} {}".format(h, exp_desc)
            cmd = "flent -H 10.0.0.1 -p all {} -l {} -d {} -z --figure-width=8 --figure-height=8 -o {}/{}-{}-{}.png -t '{}'".format(args.flent, seconds, offset, args.dir, args.flent, exp_output, h, title)
            print cmd
	    print "Starting Flent's {} on {}".format(args.flent, h)
	    if (i+1) != args.n:
                h.sendCmd(cmd)
            else:
                h.popen(cmd, shell=True).wait()
        elif args.sysconfidence:
            cmd = '/usr/sbin/sshd'
            h.sendCmd(cmd)

	if (i+1) != args.n:
	    print "Waiting before starting next client"
            progress(offset)

    if args.sysconfidence:
        hostlist = ",".join(["h{}".format(x) for x in xrange(1, args.n)])
        cmd = 'mpirun -H {} ~mininet/bin/sysconfidence -t net -N mn_{}_B100K_{}'.format(hostlist, args.n, exp_output)
        h1.popen(cmd, shell=True).wait()

    if args.iperf:
        progress(seconds + (args.n - 3) * offset * 2 + 1)

    cmd = "tc -s qdisc show > %s/tc-stats-after.txt" % (args.dir)
    s1.popen(cmd, shell=True)

    for i in xrange(1, args.n):
        node_name = 'h%d' % (i+1)
        h = net.getNodeByName(node_name)
        cmd = "/bin/netstat -s > %s/netstat-%s-after.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)
        cmd = "/sbin/ifconfig > %s/ifconfig-%s-after.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)

    for monitor in monitors:
        monitor.terminate()

    net.getNodeByName('h1').pexec("/bin/netstat -s > %s/netstat-h1-after.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/ifconfig > %s/ifconfig-h1-after.txt" %
	    args.dir, shell=True)

    # config check
#    print s1.cmd("echo -n 'tcp_congestion_control ' && cat /proc/sys/net/ipv4/tcp_congestion_control")
#    print s1.cmd("echo s1 traffic control config && tc qdisc show && tc class show dev s1-eth1")
#    print s1.cmd("echo s1 traffic control stats && tc -s qdisc && tc -s class")
#
#    print h1.cmd('ping -i 0.01 -c 100 -q 10.0.0.2')
#    print h1.cmd("echo -n 'h1 tcp_ecn ' && cat /proc/sys/net/ipv4/tcp_ecn")
#    print h1.cmd("echo h1 traffic control && tc qdisc show && tc class show dev h1-eth0")
#    print h1.cmd("echo h1 traffic control stats && tc -s qdisc && tc -s class")
#    print h1.cmd("echo h1 byte_queue_limits/limit && cat /sys/class/net/h1-eth0/queues/tx-0/byte_queue_limits/limit")
#    print h1.cmd("echo h1 ifconfig && ifconfig h1-eth0")

    Popen("killall -9 cat ping top bwm-ng &> /dev/null", shell=True).wait()
    if args.iperf:
        Popen("killall -9 iperf &> /dev/null", shell=True).wait()
    if args.pcc:
        Popen("killall -9 appclient appserver &> /dev/null", shell=True).wait()
    if args.flent:
        Popen("killall -9 netserver &> /dev/null", shell=True).wait()

    net.stop()
    print "net stopped"

    sleep(2)
    enable_cubic()

    # rmmod kernel module for development purposes
    if args.dctcp:
        disable_dctcp()
    if args.inigo:
        disable_inigo()
    if args.inigo_rttonly:
        disable_inigo_rttonly()
    if args.relentless:
        disable_relentless()
    disable_rcv_cong()
    disable_rcv_mark()

if __name__ == '__main__':
    main()
