# Iventoy

iPXE boot CDROM images.

When running from lxc, it is possible to run with an unpriviledged container. As long as the container
has read rights on /sys/devices/virtual/dmi/id/product_uuid. This is possible by running as priviledged,
but an alternative is to start the container and in the lxc.hook.pre-start run a script to change the permissions:

chgrp 100000 /sys/devices/virtual/dmi/id/product_uuid
chmod 440 /sys/devices/virtual/dmi/id/product_uuid

Keep in mind that this change will be for all containers running on the same system.
