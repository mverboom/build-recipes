# iucode

Intel microcode package

This recipe downloads versions of the intel microcode and make it available in a
local directory. After installing the files, it checks the current CPU's microcode
and the available microcode. If a newer version of the microcode is available, it is
copied to the standard microcode directory and the initramfs is regenerated.

The package does not attempt to do a runtime update of the microcode.
