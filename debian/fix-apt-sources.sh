#!/bin/bash
set -e

source common/ui.sh
source common/utils.sh

info 'Fixing apt sources'

SRCLIST=${ROOTFS}/etc/apt/sources.list

sed -i -E 's/cdn\.debian\.net\/debian-security(.+)\update/security\.debian\.org\1updates/' $SRCLIST


