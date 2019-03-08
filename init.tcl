connect
targets -filter { name =~ "ARM*#0" } -set
rst -sys
source VivadoWorkspace/DSO100Hardware-SDK/ps7_init.tcl
ps7_init
targets -filter { name =~ "xc7z*" } -set
fpga VivadoWorkspace/DSO100Hardware-SDK/dso100_wrapper.bit
targets -filter { name =~ "ARM*#0" } -set
ps7_post_config
ps7_debug
targets -filter { name =~ "ARM*#1" } -set
con
targets -filter { name =~ "ARM*#0" } -set
dow TargetOutputs/dso100.elf
con
