# shadowsocks-libev

Shadowsocks-libev C implementation of shadowsocks protocol. Default setup is for
using the manager system, which allows for multiple port/password combinations.

To start using:

1. Set configuration
vi /etc/shadowsocks/config.json
* Change IP address for server
* Set required ports and set safe passwords

2. Enable service on boot
systemctl enable shadowsocks-libev

3. Start service
systemctl start shadowsocks-libev
