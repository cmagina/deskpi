#!/bin/bash
# 
echo "DeskPi Driver Installing..."
if [ -d /tmp/deskpi ]; then
	rm -rf /tmp/deskpi 2&>/dev/null
fi
echo "Download the latest DeskPi Driver from GitHub..."
cd /tmp && git clone https://github.com/DeskPi-Team/deskpi.git 

echo "DeskPi Driver Installation Start."
deskpiv1=/lib/systemd/system/systemd-deskpi-safecutoffpower.service
driverfolder=/tmp/deskpi

# delete deskpi-safecutoffpower.service file.
if [ -e $deskpi ]; then
	sh -c "rm -f $deskpi"
fi

# adding dtoverlay to enable dwc2 on host mode.
echo "Configure /boot/config.txt file and enable front USB2.0"
sed -i '/dtoverlay=dwc2*/d' /boot/config.txt
sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/config.txt 
sh -c "echo dwc2 > /etc/modules-load.d/raspberry.conf" 

cp -rf $driverfolder/drivers/c/safecutoffpower64 /usr/bin/safecutoffpower64
cp -rf $driverfolder/drivers/python/safecutoffpower.py /usr/bin/safecutoffpower.py
chmod 644 /usr/bin/safecutoffpower64
chmod 644 /usr/bin/safecutoffpower.py

# send cut off power signal to MCU before system shuting down.
echo "[Unit]" > $deskpi
echo "Description=DeskPi Safe Cut-off Power Service" >> $deskpi
echo "Conflicts=reboot.target" >> $deskpi
echo "DefaultDependencies=no" >> $deskpi
echo "" >> $deskpi
echo "[Service]" >> $deskpi
echo "Type=oneshot" >> $deskpi
echo "ExecStart=/usr/bin//usr/bin/safecutoffpower64" >> $deskpi
echo "# ExecStart=/usr/bin/python3 /usr/bin/safecutoffpower.py" >> $deskpi
echo "RemainAfterExit=yes" >> $deskpi
echo "TimeoutStartSec=15" >> $deskpi
echo "" >> $deskpi
echo "[Install]" >> $deskpi
echo "WantedBy=halt.target shutdown.target poweroff.target final.target" >> $deskpi

chown root:root $deskpi
chmod 644 $deskpi

systemctl daemon-reload
systemctl enable systemd-deskpiv1-safecutoffpower.service
# install rpi.gpio for fan control
yes |pacman -S python-pip
pip3 install pyserial
# pacman -S python python-pip base-devel
# env CFLAGS="-fcommon" pip install rpi.gpio

sync
rm -rf /tmp/deskpi
echo "DeskPi Driver installation successful, system will reboot in 5 seconds to take effect!"
sleep 5 && reboot
