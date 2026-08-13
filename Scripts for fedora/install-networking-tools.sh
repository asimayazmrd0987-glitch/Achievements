#!/bin/bash
set -e

echo "Installing Computer Networks lab tools..."

sudo dnf install -y \
    wireshark wireshark-cli tcpdump \
    nmap netcat socat iperf3 \
    traceroute mtr iproute iputils \
    bind-utils curl wget telnet \
    openssl openssh-clients openssh-server \
    python3 python3-pip gcc-c++ make \
    qemu-kvm libvirt virt-manager

sudo usermod -aG wireshark $USER
sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap

pip3 install scapy requests urllib3

echo "Done. Log out and back in for Wireshark permissions."
