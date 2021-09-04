# Mosquitto

Mosquitto MQTT

One recipe for the complete server and client, and one recipe for clients only.

# Management Center

Web frontend to manage mosquitto's authentication and authorization for the
Dynamic Security module.

## Connecting

Default this listens on 127.0.0.1:8088 with login admin, password admin.
A lighttpd reverse proxy example is included in the configuration directory
for https. See configuration file for example installation.

## Authentication

See mosquitto documentation:

https://mosquitto.org/documentation/dynamic-security/

TL;DR

This replaces any password file based authentication!

* Generate initial configuration file and create admin account
'''
mosquitto_ctrl dynsec init /etc/mosquitto/dynamic-security.json admin
chown mosquitto:mosquitto /etc/mosquitto/dynamic-security.json
'''

* Enable in configuration file
'''
vi /etc/mosquitto/mosquitto.conf
plugin /opt/mosquitto/lib/mosquitto_dynamic_security.so
plugin_opt_config_file /etc/mosquitto/dynamic-security.json
per_listener_settings false
'''
* Restart mosquitto to activate
'''
systemctl restart mosquitto
'''
