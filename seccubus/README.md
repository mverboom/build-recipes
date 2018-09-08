# Seccubus

Seccubus is a security scanner manager.

## About recipe

Recommended extra packages:
* nmap
* nikto
* testssl

Recipe features:
* No database installation
* Creates seccubus user
* Sets up base certificate
* Adjusts defaults in configuration

## Installation

To get a working seccubus installation, do the following:

* Create a database on the local system or remote.
* Edit the seccubus configuration (/etc/seccubus/config.xml) and set database 
and (optionally) mailserver configuration.
* Populate the database and set the administartor account pasword

su - seccubus
loaddb.sh
exit

* Start seccubus

systemctl start seccubus

* Connect to the webinterface

https://<hostname>:8443

In order for seccubus to be able to run specific scans that require root provileges,
setup sudo for the seccubus user.

In order to run scans on an external server, create a keypair for the seccubus user
and exchange it with the user on the remote system.

## Application configuration example

* Go to: Manage Workspaces -> New workspace
  * Name: Example
* Choose Create

Example local nmap scan

* Go to: Manage scans
* Under Workspace, Select Example
* Select New scan
  * Name: nmap scan
  * Scanner: Nmap
  * Parameters: -o "-sS -sV -sC -T4 -p 1-65535" --sudo --hosts @HOSTS
  * Hosts: 192.168.1.0/24
* Choose: Create scan
* Choose: Edit scan
* Choose: New notification
  * Subject: $WORKSPACE-$SCAN
  * Trigger: On Open
  * Recipients: email
  * Message: $SUMMARY
* Choose: Create Notification
* Choose: Update

Running a scan

su - seccubus
do-scan -w Example -s "nmap scan" -v

Viewing scan result

* Go to: Findings
* Under Workplace, Select Example
* Under Scans, Select nmap scan
