# ssd-smart
Display SMART data for SSDs, with support for NVMe drives.

## Basics
Basically this [this](https://www.dropbox.com/s/gf3ceksqjyodzuv/ssd-endurance.sh?raw=1) shell script found [here](https://forums.linuxmint.com/viewtopic.php?f=49&t=238686). Modified to support the *MyDigitalSSD SBX* SSD.

## Details

Smartmotools doesn't like the *MyDigitalSSD SBX* drive when accessed as `/dev/nvme0n1`, but likes it when accessed as `/dev/nvme0`. This script is thus modified to replace the former by the latter. In the future, if this modification breaks compatibility with other drives, it might do the replacement only if the drive is detected as the *SBX*.
