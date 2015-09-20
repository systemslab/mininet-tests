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
parser.add_argument('--debug',
                    dest="debug",
                    action="store_true",
                    help="Debug",
                    default=False)

parser.add_argument('--iperf',
                    dest="iperf",
                    action="store_true",
                    help="Execute a basic iperf test",
                    default=True)

parser.add_argument('--convergence',
                    dest="convergence",
                    action="store_true",
                    help="Execute an iperf test similar to DCTCP's Fig. 16 convergence test",
                    default=True)

parser.add_argument('--flent',
                    dest="flent",
                    action="store",
                    help="Execute a Flent experiment instead of basic iperf test",
                    default=None)

parser.add_argument('--sysconfidence',
                    dest="sysconfidence",
                    action="store",
                    help="Execute a System Confidence experiment instead of basic iperf test",
                    default=None)

parser.add_argument('--bw', '-B',
                    dest="bw",
                    action="store",
                    help="Bandwidth of links",
                    required=True)

parser.add_argument('--delay',
                    dest="delay",
                    default="0.123ms  0.05ms distribution normal  ")
# 1000 Mbps
#	default="0.012ms  0.001ms distribution normal  ")
# 100 Mbps
#	default="0.123ms  0.05ms distribution normal  ")
# 10 Mbps
#	default="1.23ms  0.5ms distribution normal  ")

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
                    help="Seconds between iperf client starts",
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

parser.add_argument('--disable-offload',
                    dest="disable_offload",
                    action="store_true",
                    help="Disable offload support",
                    default=False)

parser.add_argument('--ecn',
                    dest="ecn",
                    action="store_true",
                    help="Enable ECN (net.ipv4.tcp_ecn) and on switch",
                    default=False)

parser.add_argument('--hostecn',
                    dest="hostecn",
                    action="store_true",
                    help="Enable ECN (net.ipv4.tcp_ecn)",
                    default=False)

parser.add_argument('--hostbw',
                    dest="hostbw",
                    action="store",
                    help="Limit bandwidth on clients to X*bw of bottleneck link, 0 < X <= 1.0, default 1.0",
                    default=1.0)

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
                    action="store",
                    help="Enable receiver-based congestion control (0 to disable, 1 for RTT-based threshold, >1 for custom threshold in microseconds)",
                    default=0)

args = parser.parse_args()
args.n = int(args.n)
args.bw = float(args.bw)
args.hostbw = float(args.hostbw)
if args.speedup_bw == -1:
    args.speedup_bw = args.bw
args.n = max(args.n, 2)

netem_args = "limit {}".format(args.maxq)
if args.delay != "":
    netem_args += " delay {}".format(args.delay)
if args.loss != "":
    netem_args += " loss {}".format(args.loss)

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
		   'delay': args.delay,
		   'enable_ecn': args.ecn,
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
        output('waiting for', server,
               'to listen on port', port, '\n')
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
        return

    node.popen("sysctl -w net.ipv4.tcp_ecn=1", shell=True).wait()

def disable_tcp_ecn(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_ecn=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_ecn=0", shell=True).wait()

def enable_rcv_cong(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_congestion_control={}".format(args.rcv_cong), shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_congestion_control={}".format(args.rcv_cong), shell=True).wait()

def disable_rcv_cong(node=None):
    if not node:
        Popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=0", shell=True).wait()
        return

    node.popen("sysctl -w net.ipv4.tcp_rcv_congestion_control=0", shell=True).wait()

def limit_hostbw(node=None):
    if not node:
        return

    node.popen("tc qdisc del dev {}-eth0 root htb".format(node), shell=True).wait()
    node.popen("tc qdisc add dev {}-eth0 root handle 5: htb default 1 direct_qlen 2".format(node), shell=True).wait()
    node.popen("tc class add dev {}-eth0 parent 5:0 classid 5:1 htb rate {}Mbit burst 3k".format(node, args.hostbw*args.bw), shell=True).wait()

def enable_fq(node=None):
    if not node:
        return

    node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq".format(node), shell=True).wait()

def enable_fqcodel(node=None):
    if not node:
        return

    enable_tcp_ecn(node)

    if args.bw <= 10:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 400 quantum 500".format(node), shell=True).wait()
    elif args.bw <= 100:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 800".format(node), shell=True).wait()
    else:
        node.popen("tc qdisc add dev {}-eth0 parent 5:1 handle 10: fq_codel limit 1200".format(node), shell=True).wait()

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

def enable_reno():
    Popen("/bin/echo reno > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def enable_vegas():
    Popen("/bin/echo vegas > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def enable_westwood():
    Popen("/bin/echo westwood > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def enable_cubic():
    Popen("/bin/echo cubic > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def enable_cdg():
    Popen("modprobe tcp_cdg {}".format(args.cdg_args), shell=True)
    Popen("/bin/echo cdg > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def enable_dctcp():
    Popen("modprobe tcp_dctcp", shell=True)
    Popen("/bin/echo dctcp > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_dctcp():
    Popen("rmmod tcp_dctcp", shell=True).wait()

def enable_dctcpe():
    Popen("modprobe tcp_dctcpe", shell=True)
    Popen("/bin/echo dctcpe > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_dctcpe():
    Popen("rmmod tcp_dctcpe", shell=True).wait()

def enable_inigo():
    Popen("modprobe tcp_inigo {}".format(args.inigo_args), shell=True)
    Popen("/bin/echo inigo > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_inigo():
    Popen("rmmod tcp_inigo", shell=True).wait()

def enable_inigo_rttonly():
    Popen("modprobe tcp_inigo_rttonly {}".format(args.inigo_args), shell=True)
    Popen("/bin/echo inigo_rttonly > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_inigo_rttonly():
    Popen("rmmod tcp_inigo_rttonly", shell=True).wait()

def main():
    seconds = int(args.t)
    offset = int(args.offset)

    topo = StarTopo(n=args.n, bw=args.bw)
    net = Mininet(topo=topo, host=CPULimitedHost, link=TCLink, switch=Switch,
            controller=OVSController,
	    autoStaticArp=True)
    net.start()

    # global config

    disable_tcp_ecn() # ensure ECN isn't accidentally left on

    if args.dctcp:
        enable_dctcp()
    else:
        disable_dctcp()

    if args.dctcpe:
        enable_dctcpe()
    else:
        disable_dctcpe()

    if args.inigo:
        enable_inigo()
    else:
        disable_inigo()

    if args.inigo_rttonly:
        enable_inigo_rttonly()
    else:
        disable_inigo_rttonly()

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

    s1 = net.getNodeByName('s1')
    # set threshold according to DCTCP's 0.17*BDP rule of thumb
    # assume delay is in ms, and only added on switch ports
    bdp = 2 * float(args.delay[:-2]) * args.bw * 1000 / 8
    K = int(0.17 * bdp)
    for i in xrange(1, args.n + 1):
        s1.popen("tc qdisc change dev s1-eth{} handle 6: red limit 1000000b avpkt 1000b min {}b max {}b ecn".format(i, K, K+5000), shell=True).wait()

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
            print "%s enabling ecn" % nn
            enable_tcp_ecn(node)
        else:
            print "%s disabling ecn" % nn
            disable_tcp_ecn(node)

        #print "removing netem/red qdiscs"
        # we only want red and delay on switches so we can be free to add other qdiscs to hosts
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 red limit 1000000b avpkt 1000".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 netem".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 6: netem".format(node), shell=True).wait()

        # override mininet's netem settings
        #print "overriding switch netem settings"
        s1.popen('tc qdisc change dev s1-eth{} handle 10: netem {}'.format(i, netem_args), shell=True).wait()

        if args.hostbw < 1.0 and not (args.fq or args.fqcodel or args.cake) :
            limit_hostbw(node)

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
    if args.fqcodel:
        tech = tech + '+fqcodel'
    if args.cake:
        tech = tech + '+cake'
    if args.ecn:
        tech = tech + '+ecn'
    if args.hostecn:
        tech = tech + '+hostecn'

    exp_desc="{} Mbps, {} one way delay, tech: {}".format(args.bw, args.delay, tech)
    exp_output="bw{}-d{}-{}".format(args.bw, args.delay, tech)
    print exp_desc

    if args.debug:
        CLI(net)

    # extra config check
    print s1.cmd("echo -n 'tcp_congestion_control ' && cat /proc/sys/net/ipv4/tcp_congestion_control")
    print s1.cmd("echo s1 traffic control && tc qdisc show && tc class show dev s1-eth1")

    h1 = net.getNodeByName('h1')
    print h1.cmd('ping -i 0.01 -c 100 -q 10.0.0.2')
    print h1.cmd("echo -n 'h1 tcp_ecn ' && cat /proc/sys/net/ipv4/tcp_ecn")
    print h1.cmd("echo h1 traffic control && tc qdisc show && tc class show dev h1-eth0")
    print h1.cmd("echo h1 byte_queue_limits/limit && cat /sys/class/net/h1-eth0/queues/tx-0/byte_queue_limits/limit")

    clients = [net.getNodeByName('h%d' % (i+1)) for i in xrange(1, args.n)]

    if args.convergence:
        args.iperf = True

    print "starting iperf/netperf servers"
    if args.iperf:
        h1.sendCmd('iperf -s -y c -i 1 > {}/iperf_h1.txt'.format(args.dir))
        waitListening(clients[0], h1, 5001)
    elif args.flent:
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

    h2 = net.getNodeByName('h2')
    print h2.cmd("echo h2 traffic control && tc qdisc show && tc class show dev h2-eth0")

    h2.popen('/bin/ping 10.0.0.1 > %s/ping.txt' % args.dir, shell=True)
    if args.more_monitoring or args.tcpdump:
	#for i in xrange(args.n):
	for i in xrange(1):
	    node_name = 'h%d' % (i+1)
	    net.getNodeByName(node_name).popen('tcpdump -ni %s-eth0 -s0 -w \
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

            if args.udp:
                cmd = 'iperf -c 10.0.0.1 -t %d -y c -i 1 -u -b %sM > %s/iperf_%s.txt' % (flowtime, args.bw, args.dir, node_name)
            else:
                cmd = 'iperf -c 10.0.0.1 -t %d -i 1 > %s/iperf_%s.txt' % (flowtime, args.dir, node_name)
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

    for i in xrange(1, args.n):
        node_name = 'h%d' % (i+1)
        h = net.getNodeByName(node_name)
        cmd = "/bin/netstat -s > %s/netstat-%s.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)
        cmd = "/sbin/ifconfig > %s/ifconfig-%s.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)
        cmd = "/sbin/tc > %s/tc-stats-%s.txt" % (args.dir, node_name)
        h.popen(cmd, shell=True)

    for monitor in monitors:
        monitor.terminate()

    net.getNodeByName('h1').pexec("/bin/netstat -s > %s/netstat-h1.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/ifconfig > %s/ifconfig-h1.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/tc -s qdisc > %s/tc-stats-h1.txt" %
    	    args.dir, shell=True)
    net.getNodeByName('s1').pexec("/sbin/tc -s qdisc > %s/tc-stats-s1.txt" %
    	    args.dir, shell=True)

    Popen("killall -9 cat ping top bwm-ng iperf netserver &> /dev/null", shell=True).wait()
    net.stop()
    print "net stopped"

    sleep(2)
    enable_cubic()

    # rmmod kernel module for development purposes
    disable_inigo()
    disable_inigo_rttonly()

    if args.rcv_cong:
        disable_rcv_cong()

if __name__ == '__main__':
    main()
