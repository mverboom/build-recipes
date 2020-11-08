# HomeAssistant

This is a placeholder build recipe for HomeAssistant. As HomeAssistant installs
any addons in its install directory, it looks like it is impossible to create a
real package with the software itself.

This package helps with:
* Making sure the required software is available to run HomeAssistant
* Create a homeassistant user and group
* Provide an install script that installs homeassistant in a virtual environment

All is dependand on a seperate python installation, as HomeAssistant seems to
regularly needs a newer version of python than is supplied with the OS. In order
for HomeAssistant to install, the custom python package should be build first and
made available.
