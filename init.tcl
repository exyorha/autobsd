connect
targets -filter { name =~ "ARM*#0" } -set
rst -sys
source VivadoWorkspace/DSO100Hardware-SDK/ps7_init.tcl
ps7_init
ps7_post_config
ps7_debug
targets -filter { name =~ "ARM*#1" } -set
bpadd -addr 0xc051c50c
con
targets -filter { name =~ "ARM*#0" } -set
dow TargetOutputs/dso100.elf
bpadd -addr 0xc051c50c
con
