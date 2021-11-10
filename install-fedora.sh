#!/bin/bash
# 
set -eu -o pipefail

function pre-reqs() {
    sudo dnf install git redhat-lsb-core glibc-devel glibc-common glibc-static gcc make -y || true
}

if [[ ! -f /lib/lsb/init-functions ]]; then
    pre-reqs
fi

. /lib/lsb/init-functions

daemonname="deskpi"
tempmonscript=/usr/local/bin/pmwFanControl
deskpidaemon=$daemonname.service
safeshutdaemon=$daemonname-safeshut.service
systemdsrvc_d=/lib/systemd/system
workspace=$(mktemp -d)
installationfolder=$workspace/$daemonname

git clone ${DESKPI_GIT_URL:-https://github.com/DeskPi-Team/deskpi.git} $installationfolder

pushd $installationfolder >/dev/null

if [[ -n $DESKPI_GIT_BRANCH ]]; then
    git checkout $DESKPI_GIT_BRANCH
fi

# install DeskPi stuff.
echo "DeskPi Fan control script installation Start." 

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

# adding dtoverlay to enable dwc2 on host mode.
echo "Enable dwc2 on Host Mode"
sudo sed -i '/dtoverlay=dwc2*/d' /boot/efi/config.txt
sudo sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/efi/config.txt 
if [ $? -eq 0 ]; then
   log_success_msg "dwc2 has been setting up successfully"
fi

# install PWM fan control daemon.
echo "DeskPi main control service loaded."

pushd $installationfolder/drivers/c/ >/dev/null
make clean
make
sudo make install
popd >/dev/null

sudo install --mode 0755 --context=system_u:object_r:bin_t:s0 -t /usr/bin \
    $installationfolder/deskpi-config \
    $installationfolder/Deskpi-uninstall
sudo restorecon -vr /usr/bin/

# Build Fan Daemon
tee $deskpidaemon <<EOF
[Unit]
Description=DeskPi PWM Control Fan Service
After=multi-user.target

[Service]
Type=simple
RemainAfterExit=no
ExecStart=/usr/bin/pwmFanControl

[Install]
WantedBy=multi-user.target
EOF

# send signal to MCU before system shuting down.
tee $safeshutdaemon <<EOF
[Unit]
Description=DeskPi Safeshutdown Service
Conflicts=reboot.target
Before=halt.target shutdown.target poweroff.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/fanStop
RemainAfterExit=yes
TimeoutSec=1

[Install]
WantedBy=halt.target shutdown.target poweroff.target
EOF

echo "DeskPi Service configuration finished." 
sudo install -o root -g root -m 0644 --context=system_u:object_r:bin_t:s0 \
    -t $systemdsrvc_d $safeshutdaemon $deskpidaemon

echo "DeskPi Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service &
sudo systemctl enable $daemonname-safeshut.service

# Cleanup
popd >/dev/null
rm -rf $workspace

# Finished 
log_success_msg "DeskPi PWM Fan Control and Safeshut Service installed successfully." 
# greetings and require rebooting system to take effect.
echo "System will reboot in 5 seconds to take effect." 
sudo sync
sleep 5 
sudo reboot
echo "Reboot system for changes to take effect"
