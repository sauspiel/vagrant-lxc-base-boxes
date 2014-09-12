#!/bin/bash
set -e

source common/ui.sh
source common/utils.sh

info 'Preparing dhcp configuration for two interfaces'

DHCPCONF=${ROOTFS}/etc/dhcp/dhclient-eth0.conf
cat << EOF > $DHCPCONF
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name = gethostname();
request subnet-mask, broadcast-address, time-offset,
        host-name, domain-name, domain-name-servers,
        domain-search, routers,
        dhcp6.name-servers, dhcp6.domain-search,
        netbios-name-servers, netbios-scope, interface-mtu,
        rfc3442-classless-static-routes, ntp-servers;
EOF

DHCPCONF=${ROOTFS}/etc/dhcp/dhclient-eth1.conf
cat << EOF > $DHCPCONF
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name = gethostname();
request subnet-mask, broadcast-address, time-offset,
        host-name,
        dhcp6.name-servers, dhcp6.domain-search,
        netbios-name-servers, netbios-scope, interface-mtu,
        rfc3442-classless-static-routes, ntp-servers;
EOF

ETHCONF=${ROOTFS}/etc/network/interfaces
cat << EOF > $ETHCONF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual
  up /sbin/dhclient -v -cf /etc/dhcp/dhclient-eth0.conf -pf /run/dhclient.eth0.pid -lf /var/lib/dhcp/dhclient.eth0.leases eth0
  down /sbin/dhclient -v -r -cf /etc/dhcp/dhclient-eth0.conf -pf /run/dhclient.eth0.pid -lf /var/lib/dhcp/dhclient.eth0.leases eth0 && ifconfig eth0 down

auto eth1
iface eth1 inet manual
  up /sbin/dhclient -v -cf /etc/dhcp/dhclient-eth1.conf -pf /run/dhclient.eth1.pid -lf /var/lib/dhcp/dhclient.eth1.leases eth1
  down /sbin/dhclient -v -r -cf /etc/dhcp/dhclient-eth1.conf -pf /run/dhclient.eth1.pid -lf /var/lib/dhcp/dhclient.eth1.leases eth1 && ifconfig eth1 down
EOF

DHCLIENT_ENTER_HOOK=${ROOTFS}/etc/dhcp/dhclient-enter-hooks.d/vpn-route
cat >$DHCLIENT_ENTER_HOOK << 'EOF'
IPADDR=''

NUM=`echo $interface | sed 's/[a-z]//g'`
NUM=`expr $NUM + 1`

if [ `grep $interface /etc/iproute2/rt_tables | wc -l` -eq 0 ]; then
  echo "$NUM $interface" >> /etc/iproute2/rt_tables
fi

case $reason in
  "BOUND"|"REBOOT")  IPADDR=$new_ip_address ;;
  "RELEASE")  IPADDR=$old_ip_address ;;
esac

NET=`echo ${IPADDR} | cut -d "." -f1,2,3`
SUBNET="$NET.0"
GATEWAY="$NET.254"

case $reason in
  "BOUND"|"REBOOT")
    ip rule add from $SUBNET/24 table $interface
    ip rule add to $SUBNET/24 table $interface
    ip route add $SUBNET/24 dev $interface table $interface
    ip route add default via $GATEWAY dev $interface table $interface
    ;;
  "RELEASE")
    ip rule del from $SUBNET/24 table $interface
    ip rule del to $SUBNET/24 table $interface
    ;;
esac
EOF

chmod +x $DHCLIENT_ENTER_HOOK

