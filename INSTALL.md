## installation

### openwrt 

https://openwrt.org/docs/guide-user/installation/generic.flashing

### requirements

install 'rtl_433' and 'mosquitto'  
see: https://openwrt.org/faq/how_to_install_packages

### OpenDew


```
git clone https://github.com/womoak75/OpenDew
cd OpenDew
scp *.sh root@{openwrt-ip/hostname}:/usr/bin/
scp -r openwrt/etc/opendew/ root@{openwrt-ip/hostname}:/etc/
scp -r openwrt/etc/config/* root@{openwrt-ip/hostname}:/etc/config/
scp -r openwrt/etc/init.d/* root@{openwrt-ip/hostname}:/etc/init.d/
```
