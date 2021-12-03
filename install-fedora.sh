#!/bin/bash
# 
set -eu -o pipefail

function pre-reqs() {
    sudo dnf install git redhat-lsb-core glibc-devel glibc-common glibc-static gcc make cmake gcc-c++ -y || true
}

if [[ ! -f /lib/lsb/init-functions ]]; then
    pre-reqs
fi

. /lib/lsb/init-functions

daemonname="deskpi"
deskpidaemon=$daemonname.service
safeshutdaemon=$daemonname-safeshut.service
systemdsrvc_d=/lib/systemd/system
workspace=$(mktemp -d)
deskpi_src_d=$workspace/$daemonname
userland_src_d=$workspace/userland
dest_bin_dir=/usr/local/bin

pushd $workspace >/dev/null

echo "Install Raspberry Pi userland tools ..."
git clone ${RPI_USERLAND_GIT_URL:-https://github.com/raspberrypi/userland.git}  $userland_src_d

pushd $userland_src_d >/dev/null

if [[ -n ${RPI_USERLAND_GIT_BRANCH:-} ]]; then
    git checkout $RPI_USERLAND_GIT_BRANCH
fi

./buildme --aarch64

sudo tee /etc/ld.so.conf.d/vc.conf <<EOF
/opt/vc/lib
EOF

sudo ldconfig

sudo tee /etc/profile.d/raspberrypi.sh <<EOF
# Add raspberry pi userland tools to PATH

export PATH=$PATH:/opt/vc/bin/
EOF

popd >/dev/null

sudo tee /lib/modules-load.d/vchiq.conf <<EOF
# This entry ensures that the kernel module bcm2835-mmal-vchiq.ko is loaded at boot time.
bcm2835-mmal-vchiq
EOF

echo "Install udev permissions for vchiq ..."
curl -O https://raw.githubusercontent.com/sakaki-/genpi64-overlay/master/media-libs/raspberrypi-userland/files/92-local-vchiq-permissions.rules
sudo install -o root -g root -m 0644 92-local-vchiq-permissions.rules /usr/lib/udev/rules.d/
sudo usermod -aG video $USER

echo "Install deskpi software ..."
git clone ${DESKPI_GIT_URL:-https://github.com/DeskPi-Team/deskpi.git} $deskpi_src_d

pushd $deskpi_src_d >/dev/null

if [[ -n ${DESKPI_GIT_BRANCH:-} ]]; then
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

pushd $deskpi_src_d/drivers/c/ >/dev/null
make clean
make
sudo make install
popd >/dev/null

sudo install --mode 0755 --context=system_u:object_r:bin_t:s0 -t $dest_bin_dir \
    $deskpi_src_d/deskpi-config \
    $deskpi_src_d/Deskpi-uninstall
sudo restorecon -vr $dest_bin_dir

# Build Fan Daemon
tee $deskpidaemon <<EOF
[Unit]
Description=DeskPi PWM Control Fan Service
After=multi-user.target

[Service]
Type=simple
RemainAfterExit=no
ExecStart=$dest_bin_dir/pwmFanControl

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
ExecStart=$dest_bin_dir/fanStop
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

popd >/dev/null # deskpi_src_d

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
