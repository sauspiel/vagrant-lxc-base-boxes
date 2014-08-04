#!/bin/bash
set -e

source common/ui.sh
source common/utils.sh

info 'Preparing dhcp configuration for two interfaces'

DHCPCONF=${ROOTFS}/etc/dhcp/dhclient.conf

cat << EOF > $DHCPCONF
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name = gethostname();
supersede domain-name "saulabs.io";
request subnet-mask, broadcast-address, time-offset,
        domain-name, host-name,
        dhcp6.name-servers, dhcp6.domain-search,
        netbios-name-servers, netbios-scope, interface-mtu,
        rfc3442-classless-static-routes, ntp-servers;

interface "eth0" {
  request domain-name-servers;
  request domain-search;
  request routers;
}
EOF

ETHCONF=${ROOTFS}/etc/network/interfaces

cat << EOF > $ETHCONF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet dhcp
EOF
