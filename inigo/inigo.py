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

parser.add_argument('--flent',
                    dest="flent",
                    action="store",
                    help="Execute a Flent experiment instead of basic iperf test",
                    default=None)

parser.add_argument('--bw', '-B',
                    dest="bw",
                    action="store",
                    help="Bandwidth of links",
                    required=True)

parser.add_argument('--dir', '-d',
                    dest="dir",
                    action="store",
                    help="Directory to store outputs",
                    required=True)

parser.add_argument('-n',
                    dest="n",
                    action="store",
                    help="Number of nodes in star.  Must be >= 3",
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

parser.add_argument('--inigo',
                    dest="inigo",
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

parser.add_argument('--ecn',
                    dest="ecn",
                    action="store_true",
                    help="Enable ECN (net.ipv4.tcp_ecn)",
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

parser.add_argument('--delay',
	dest="delay",
	default="0.123ms  0.05ms distribution normal  ")
# 1000 Mbps
#	default="0.012ms  0.001ms distribution normal  ")
# 100 Mbps
#	default="0.123ms  0.05ms distribution normal  ")
# 10 Mbps
#	default="1.23ms  0.5ms distribution normal  ")

args = parser.parse_args()
args.n = int(args.n)
args.bw = float(args.bw)
if args.speedup_bw == -1:
    args.speedup_bw = args.bw
args.n = max(args.n, 2)

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
    while 'Connected' not in client.cmd(cmd):
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
    node.popen("tc qdisc add dev {}-eth0 root cake bandwidth {}mbit".format(node, args.bw), shell=True).wait()

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

def enable_dctcp():
    Popen("modprobe tcp_dctcp", shell=True)
    Popen("/bin/echo dctcp > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_dctcp():
    Popen("rmmod tcp_dctcp", shell=True).wait()

def enable_inigo():
    Popen("modprobe tcp_inigo markthresh=180 dctcp_alpha_on_init=500 rtt_fairness=0 stabilize=0", shell=True)
    Popen("/bin/echo inigo > /proc/sys/net/ipv4/tcp_congestion_control", shell=True).wait()

def disable_inigo():
    Popen("rmmod tcp_inigo", shell=True).wait()

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

    if args.inigo:
        enable_inigo()
    else:
        disable_inigo()

    if args.reno:
        enable_reno()

    if args.vegas:
        enable_vegas()

    if args.westwood:
        enable_westwood()

    if args.cubic:
        enable_cubic()

    if args.ecn:
        enable_tcp_ecn()
    else:
        disable_tcp_ecn()

    # per node config
    for i in xrange(1, args.n + 1):
        nn = 'h%d' % (i)
        node = net.getNodeByName(nn)
        node.popen('ethtool -K  %s-eth0 tso off' % (nn), shell=True)
        node.popen('ethtool -K  %s-eth0 gso off' % (nn), shell=True)
        node.popen('ethtool -K  %s-eth0 gro off' % (nn), shell=True)
        node.popen('ethtool -K  %s-eth0 lro off' % (nn), shell=True)
        node.popen("ethtool -k %s-eth0 > %s/ethtool-%s-features.txt" % (nn, args.dir, nn), shell=True)

        if args.ecn:
            enable_tcp_ecn(node)
        else:
            disable_tcp_ecn(node)

        # we only want red and delay on switches
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 red limit 1000000b avpkt 1000".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 6: netem".format(node), shell=True).wait()
        node.popen("tc qdisc del dev {}-eth0 parent 5:1 netem".format(node), shell=True).wait()
        # and let's configure htb to have a smaller queue
        node.popen("tc qdisc del dev {}-eth0 root htb".format(node), shell=True).wait()
        node.popen("tc qdisc add dev {}-eth0 root handle 5: htb default 1 direct_qlen 2".format(node), shell=True).wait()
        node.popen("tc class add dev {}-eth0 parent 5:0 classid 5:1 htb rate 100Mbit burst 3k".format(node), shell=True).wait()

        if args.fqcodel:
            enable_fqcodel(node)

        if args.cake:
            enable_cake(node)

        if args.bw <= 10:
            node.popen('echo 1514 > /sys/class/net/%s-eth0/queues/tx-0/byte_queue_limits/limit' % (nn), shell=True)
        else:
            node.popen('echo 3000 > /sys/class/net/%s-eth0/queues/tx-0/byte_queue_limits/limit' % (nn), shell=True)

    s1 = net.getNodeByName('s1')

    tech = s1.cmd('cat /proc/sys/net/ipv4/tcp_congestion_control').rstrip('\r\n')
    if args.fqcodel:
        tech = tech + '+fqcodel'
    if args.cake:
        tech = tech + '+cake'
    if args.ecn:
        tech = tech + '+ecn'

    exp_desc="{} Mbps, {} one way delay, tech: {}".format(args.bw, args.delay, tech)
    exp_output="bw{}-d{}-{}".format(args.bw, args.delay, tech)
    print exp_desc

    if args.debug:
        CLI(net)

    h1 = net.getNodeByName('h1')
    print h1.cmd('ping -c 2 10.0.0.2')

    # extra config check
    print s1.cmd("echo -n 'tcp_congestion_control ' && cat /proc/sys/net/ipv4/tcp_congestion_control")
    print h1.cmd("echo -n 'h1 tcp_ecn ' && cat /proc/sys/net/ipv4/tcp_ecn")
    print h1.cmd("echo h1 traffic control && tc qdisc show && tc class show dev h1-eth0")

    clients = [net.getNodeByName('h%d' % (i+1)) for i in xrange(1, args.n)]

    if not args.flent:
        h1.sendCmd('iperf -s -y c -i 1 > {}/iperf_h1.txt'.format(args.dir))
        waitListening(clients[0], h1, 5001)
    else:
        h1.sendCmd('netserver')
        waitListening(clients[0], h1, 12865)

    monitors = []

    if not args.no_tcp_probe:
        Popen("rmmod tcp_probe; modprobe tcp_probe; cat /proc/net/tcpprobe > %s/tcp_probe.txt" % args.dir, shell=True)
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

    #CLI(net)

    h2 = net.getNodeByName('h2')
    print h2.cmd("echo h2 traffic control && tc qdisc show")

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

        if not args.flent:
	    print "Starting iperf client {}".format(node_name)
            if args.udp:
                cmd = 'iperf -c 10.0.0.1 -t %d -y c -i 1 -u -b %sM > %s/iperf_%s.txt' % (seconds, args.bw, args.dir, node_name)
            else:
                cmd = 'iperf -c 10.0.0.1 -t %d -i 1 > %s/iperf_%s.txt' % (seconds, args.dir, node_name)
            h.sendCmd(cmd)
        else:
            title = "{} {}".format(h, exp_desc)
            cmd = "netperf-wrapper -H 'h1' -p all_scaled {} -l {} -x --figure-width=8 --figure-height=8 -o {}/{}-{}-{}.png -t '{}'".format(args.flent, seconds, args.dir, args.flent, exp_output, h, title)
            print cmd
	    print "Starting Flent's {} on {}".format(args.flent, h)
	    if (i+1) != args.n:
                h.sendCmd(cmd)
            else:
                h.popen(cmd, shell=True).wait()

	if (i+1) != args.n:
	    print "Waiting before starting next client"
            progress(offset)

    if not args.flent:
        progress(seconds + 1)

    for monitor in monitors:
        monitor.terminate()

    net.getNodeByName('h1').pexec("/bin/netstat -s > %s/netstat.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/ifconfig > %s/ifconfig.txt" %
	    args.dir, shell=True)
    net.getNodeByName('h1').pexec("/sbin/tc -s qdisc > %s/tc-stats-h1.txt" %
    	    args.dir, shell=True)

    net.getNodeByName('s1').pexec("/sbin/tc -s qdisc > %s/tc-stats-s1.txt" %
    	    args.dir, shell=True)
    net.stop()
    Popen("killall -9 cat ping top bwm-ng netserver &> /dev/null", shell=True).wait()

    enable_cubic()
    disable_dctcp()
    disable_inigo()

if __name__ == '__main__':
    main()
