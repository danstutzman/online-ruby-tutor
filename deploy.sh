#!/bin/bash
cd `dirname $0`
ORIGINAL_DIR=`pwd`
cd `dirname $0`/../ansible
source hacking/env-setup
ansible-playbook -v $ORIGINAL_DIR/playbook.yml -i $ORIGINAL_DIR/hosts --private-key=~/.ec2/gsg-keypair
