# Greenbone Vulnerability Manager

## General information

This is a collection of recipes to build Greenbone Vulnerability Manager
(https://www.openvas.org/).

The following recipe's are available:

* gvm - meta package
* gsa - https://github.com/greenbone/gsa
* gvmd - https://github.com/greenbone/gvmd
* gvm-libs - https://github.com/greenbone/gvm-libs
* gvm-tools - https://github.com/greenbone/gvm-tools
* openvas - https://github.com/greenbone/openvas
* openvas-smb - https://github.com/greenbone/openvas-smb
* ospd-openvas - https://github.com/greenbone/ospd-openvas
* ospd - https://github.com/greenbone/ospd
* python-gvm - https://github.com/greenbone/python-gvm

## Structure

Log file can be found in:

/var/log/gvm

## Procedures

### Full GVM setup

To install a full GVM setup on a single system, do the following:

`apt install gvm-<local extension>`

After installation compleets, feeds need to be updated. There is a cron-job included
in the package that takes care of this, but it can also be triggered manually:

SCAP and CERT data feed:
`/etc/cron.daily/gvm`

NVT feed:
`/etc/cron.daily/openvas`

The webinterace should be reachable through https on port 443.

### Remote OSPD scanner

There seems to be an issue with remote OSPD scanners, or at least ospd-openvas in
newer OS distributions. From Debian 9 to Debian 10 there was a migration from Python
3.5 to 3.7. It looks like in that transition support was added for TLSv1.3. When
using TLSv1.3 the "normal" way to connect an OSPD scanner over TLS breaks. To work
around this problem the recipe that builds OSPD implements a patch to restrict usage
to TLSv1.2. This is not a fix but a work-around.

To deploy a remote OSPD-OpenVAS scanner the following steps need to be taken.

* Deploy a system with the full GVM install
* Deploy a "remote" system
* Make sure TCP connectivity is allowed from GVM server system to remote on port 9391

`apt install ospd-openvas-<local extension>`

* From your workstation copy over the required certficates and push to the remote

```
CLIENT=remotescanner.example.com
SERVER=gvm.example.com
cd /tmp
scp $SERVER:/var/lib/gvm/private/CA/clientkey.pem .
scp $SERVER:/var/lib/gvm/CA/clientcert.pem .
scp $SERVER:/var/lib/gvm/CA/cacert.pem .
scp clientkey.pem clientcert.pem cacert.pem $CLIENT:/tmp
```

* Install and configure ospd-openvas on the remote

```
ssh $CLIENT
apt install ospd-openvas-lnw
cd /etc/gvm
mv /tmp/cacert.pem /tmp/client*.pem .
chmod 644 cacert.pem client*.pem
sed -i "s/^unix_socket/#unix_socket/" /etc/gvm/ospd-openvas.conf
sed -i "s/^socket_mode/#socket_mode/" /etc/gvm/ospd-openvas.conf
sed -i "/^log_level/d" /etc/gvm/ospd-openvas.conf
sed -i "s/#log_level/log_level/" /etc/gvm/ospd-openvas.conf
cat >> /etc/gvm/ospd-openvas.conf <<EOF
key_file = /etc/gvm/clientkey.pem
cert_file = /etc/gvm/clientcert.pem
ca_file = /etc/gvm/cacert.pem
port = 9391
EOF
systemctl restart ospd-openvas
su - gvm
openvas-feed-update
exit
tail -f /var/log/gvm/ospd-openvas.log
exit
```

* Add the scanner from the GSA webinterface on the server:

* Go to: Configuration -> Credentials
* New credential
** Name: <name of credential>
** Type: Client Certificate
** Allow insecure use: no
** Certificate -> Browse clientcert.pem
** Private key -> Browse clientkey.pem
* Save
* Configuration -> Scanners
* New Scanner
** Name: <name of remote scanner>
** Type: OSP scanner
** Host: <hostname of remote scanner>
** Port: 9391
** CA Certificate: cacert.pem
** Credential: <name of credential>
* Save

* The scanner is now created. However there seems to be something strance in the GVM software that doesn't allow for a OSPD scanner to be used in a new scan profile. But it seems possible to work around this. From the commandline on the GVM server verify the scanner and if this succeeds change the type to OpenVAS:

```
su - gvm
/opt/gvm/sbin/gvmd --get-scanners
/opt/gvm/sbin/gvmd --verify-scanner=<ID>
/usr/sbin/gvmd --modify-scanner=<ID> --scanner-type="OpenVAS"
```

* The scanner should now be usable from the webinterface in tasks.
