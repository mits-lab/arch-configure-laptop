#!/usr/bin/bash

## Monocle IT Solutions Labs ##
## Server Baseline - Arch Linux Configuration Script ##
## server-postinstall-configuration-archlinux2022.sh
## Rev. 2022041317 ##

# Tested on Archlinux 2022 x86_64
#
# !!! CONNECT TO THE INTERNET BEFORE EXECUTING THIS SCRIPT !!!
#
# Script should be executed from Arch Linux terminal as the root user.
# 
# Script updates system and installs and configures apps for a business environment. Meant to be run after the bootstrap app completes.
#
# The MIT License (MIT)
# 
# Copyright (c) 2022 Monocle IT Solutions/configure.sh
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# hostname format is host.example.com
# standard alpha numeric user name
# password should include letter numbers and special character

red='\e[0;31m'
cyan='\e[0;36m'
green='\e[0;32'
yellow='\e[1;33'
normal='\e[0m' # No Color

bold=`tput bold`
normal=`tput sgr0`

# run as root user check.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

clear

echo -n -e "\nMITS - Arch System Configuration Utility\n"
echo -n -e "$cyan------------------------------------------ $normal\n\n"

echo -n -e "Enter an employee's username to create.\n"
echo -n -e "user: "
read _user
echo -n -e "\n"

echo -n -e "Enter a password for your user.\n"
echo -n -e "password: "
read -s _password
echo -n -e "\n\n"

# ensure a user is specified, otherwise exit script.

if [ -z "$_user" ]; then
    echo -n -e "\nMissing USER variable...exiting\n"
    exit 69
fi
if [ -z "$_password" ]; then
    echo -n -e "\nMissing PASSWORD variable...exiting\n"
    exit 69
fi

### Static Vars

_urltest=google.ca
_localscriptdir=/home/${_user}/Scripts/
_gitrepo=https://github.com/mits-lab/Arch-Tools.git

### Internet connection test

echo -n -e "\nTesting Internet Connectivity.."

yes | pacman -S nmap >/dev/null 2>&1

if ncat -zw1 $_urltest 443 && echo |openssl s_client -connect $_urltest:443 2>&1 |awk '
  handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 }
  $1 $2 == "SSLhandshake" { handshake = 1 }'
then
  echo -n -e ".$cyan Complete$normal \n"
else
  echo -n -e "\n\nNo internet connectivity detected.\n\nCheck you internet connection and re-run the script.\n"
  exit 69
fi

### Prevent Script from running a second time.

if [ -e /root/.stop_run ]
then
    echo -n -e "\nScript has already completed system configuration.  Stopping..\n\n"
	exit 69
else
    echo -n -e ""
fi

touch /root/.stop_run

### Updates the packages on the system from the distribution repositories. 
##  The script finishes with a reboot.

# create employee account.

echo -n -e "\nCreating Employee user account.."

useradd -G wheel -m ${_user}
echo "${_user}:${_password}" | chpasswd

echo -n -e ".$cyan Complete$normal \n"

# configure visudo preferred editor - this is a security risk as a user can seek security elevation through vim EXEC.

echo -n -e "\nSetting default visudo text editor.."

echo 'Defaults editor=/usr/bin/vim' >> /etc/sudoers

echo -n -e ".$cyan Complete$normal \n"

# Set repo locality with 'reflector'

echo -n -e "\nAdjusting Repo Locality.."

yes | pacman -S reflector >/dev/null 2>&1
reflector -c Canada -a 6 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1

echo -n -e ".$cyan Complete$normal \n"

#Update Pacman mirror list with the following.

echo -n -e "\nUpdating Base System.."

yes | pacman -Syu >/dev/null 2>&1

echo -n -e ".$cyan Complete$normal \n"

# optional package installation

echo -n -e "\nEnabling Core Systems Apps.."

# enable Network Manager.
systemctl enable NetworkManager.service
# enable Bluetooth.
systemctl enable bluetooth.service
# enable cups
systemctl enable cups.service

echo -n -e ".$cyan Complete$normal \n"

# install ntp client chrony

echo -n -e "\nInstall and Configure ntp client Chrony on System.."

yes | pacman -S chrony >/dev/null 2>&1

cp /etc/chrony.conf /root/chrony.conf.bak && cat > /etc/chrony.conf <<EOL
#
# Monocle IT Solutions - Chrony NTP Client/Server configuration
# Rev. 2021100605
#
# Public NTP Servers
server ptbtime1.ptb.de iburst maxdelay 0.4 nts
server ptbtime2.ptb.de iburst maxdelay 0.4 nts
server ptbtime3.ptb.de iburst maxdelay 0.4 nts
server nts1.time.nl iburst maxdelay 0.4 nts
server nts.ntp.se iburst maxdelay 0.4 nts
server nts.sth1.ntp.se iburst maxdelay 0.4 nts
server nts.sth2.ntp.se iburst maxdelay 0.4 nts
server time.cloudflare.com iburst maxdelay 0.4 nts

minsources 3
maxchange 100 0 0
makestep 0.001 1
maxdrift 100
maxslewrate 100

driftfile /var/lib/chrony/drift

rtconutc
rtcsync

keyfile /etc/chrony.keys

leapsectz right/UTC

logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
EOL

systemctl -q restart chronyd
systemctl -q enable chronyd.service

echo -n -e ".$cyan Complete$normal \n"

# Install and Configure SSH server

echo -n -e "\nInstall and Configure SSH server on System.."

yes | pacman -S openssh >/dev/null 2>&1

cp /etc/ssh/sshd_config /root/sshd_config.bak && cat > /etc/ssh/sshd_config <<EOL
# modified sshd_config; test config with $ sudo /usr/sbin/sshd -t
#
# Monocle IT Solutions SSHD config for Arch Linux Workstation
#
# Revision 2022041003

Port 22
AddressFamily inet
ListenAddress 0.0.0.0
Protocol 2

PubkeyAuthentication no
PasswordAuthentication yes
#KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes

#AuthenticationMethods publickey,keyboard-interactive:pam
AuthenticationMethods password

AllowUsers ${_user}
PermitRootLogin no

UsePAM yes

# Ensure /bin/login is not used so that it cannot bypass PAM settings for sshd.

# HostKeys for protocol version 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

AuthorizedKeysFile      %h/.ssh/authorized_keys

AllowTcpForwarding yes
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no

# Disable X11 Forwarding unless you need it
X11Forwarding no

# Disable TCPKeepAlive and use ClientAliveInterval instead to prevent TCP Spoofing attacks
TCPKeepAlive no
ClientAliveInterval 600
ClientAliveCountMax 3

# Logging
SyslogFacility AUTH
LogLevel VERBOSE
PrintLastLog yes

# Display login banner
Banner /etc/issue.net
EOL

systemctl -q enable sshd.service

echo -n -e ".$cyan Complete$normal \n"

# install simple utilities

echo -n -e "\nInstall simple utilities on System.."

yes | pacman -S man-db nmap mtr rsync neofetch picocom iperf tcpdump firewalld cronie >/dev/null 2>&1

systemctl -q enable --now cronie.service
systemctl -q enable firewalld.service

echo -n -e ".$cyan Complete$normal \n"

# Create utility scripts and place them in the user's 'Scripts' directory.

echo -n -e "\nPulling utility scripts.."

git clone "$_gitrepo" "$_localscriptdir" >/dev/null 2>&1
chown -R  ${_user}:${_user} /home/${_user}/Scripts
find /home/${_user}/Scripts/ -iname '*.sh' -exec chmod 744 {} \;
amixer set Master 35%+ >/dev/null 2>&1

# scripts added to cronie
echo "*/5 * * * * /home/${_user}/Scripts/lowbattery/lowbattcheck.sh" >> /root/cron_tmp
crontab -u ${_user} /root/cron_tmp

echo -n -e ".$cyan Complete$normal \n"

# add aliases and tweaks to .bashrc file.

echo -n -e "\nAdding aliases and tweaks to .bashrc file.."

cat <<EOF >> /home/${_user}/.bashrc
alias ll='ls -l'
alias la='ls -la'
alias vi='vim'
alias batt='bash /home/${_user}/Scripts/batt/batt.sh'
neofetch
EOF

echo -n -e ".$cyan Complete$normal \n\n"

# Install KDE Plasma desktop environment?

read -p "Do you wish to Install KDE Plasma desktop environment? (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -n -e "\n"
else
	echo -n -e "\n\nInstalling KDE Plasma.."
	pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications packagekit packagekit-qt5 >/dev/null 2>&1
	systemctl -q enable sddm.service
	systemctl -q enable NetworkManager.service
	echo -n -e ".$cyan Complete$normal \n"
fi

# Reload your shell to apply the changes.

echo -n -e "\n"
read -p "Your system will require a reboot to complete the installation.  Reboot now?(y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -n -e "\n"
else
	echo -n -e "\n\nRebooting.. \n"
	reboot
	exit 0
fi

exit 0
