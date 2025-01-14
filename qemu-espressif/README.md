# qemu-espressif

Espressif qemu for esp32

for testing esphome flash:
* generate factory.bin file with esphome
* use esptool.py to create flash image
`esptool.py --chip esp32 merge_bin --fill-flash-size 4MB -o flash.bin 0x0 esphome.factory.bin`
* start qemu
`qemu-system-xtensa -nographic -machine esp32 -drive file=flash.bin,if=mtd,format=raw`
* or with port forwarding:
`qemu-system-xtensa -net nic -net user,hostfwd=tcp:127.0.0.1:3232-10.0.2.15:3232  -nographic -machine esp32 -drive file=flash.bin,if=mtd,format=raw`
