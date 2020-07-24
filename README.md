# autobsd

autobsd is a build system of DSO-100, an abandoned project to create a digital
storage oscilloscope based upon Xilinx Zynq-7000 FPGA. This project was
abandoned due to several reasons, the chief of them were lack of suitable
remote debugging tools for ARM executables running on FreeBSD. However, I have
decided to publish most of this project, as it may still be of certain
interest, or because parts of it may still be useful.

Following repositories were a part of this project:

  * [BSDBootImageBuilder](https://github.com/moon-touched/BSDBootImageBuilder),
    containing a that allows an entire FreeBSD system to compiled into
	standalone ELF file. 

  * [BSDKickstart](https://github.com/moon-touched/BSDKickstart), containing
    the Zynq-side initialization code for BSDBootImageBuilder.

  * [DSO100Drivers](https://github.com/moon-touched/DSO100Drivers),
    containing a set of drivers specific for the DSO-100 hardware. Only 
	the framebuffer driver was ever implemented.
	
  * [FreeBSDKernelOverlay](https://github.com/moon-touched/FreeBSDKernelOverlay),
	containing the FreeBSD kernel configuration file for DSO-100.

  * [DSO100Hardware](https://github.com/moon-touched/DSO100Hardware),
    containing implementation of DSO-100 specific hardware in Verilog, and 
	various DSO-100 specific integration scripts.
	
  * [DSOSystem](https://github.com/moon-touched/DSOSystem), containing the
    DSO-100 software, running as a user mode process under FreeBSD. Several
	implementations of DSO-100 software existed, however, none of them
	progressed beyond skeletal implementation. DSOSystem is included as it is
	easiest to build and run, and none of the others are particularly
	interesting by themselves.
	
  * autobsd itself, implementing a fully automated build process for the whole
    project, capable of producing a functional bitstream with a single command.
	
Build process of DSO-100, while automated, is still somewhat peculiar, as it
requires Windows-based host machine, containing the entirety of the source code
and Xilinx Vivado tools, and a FreeBSD build machine, which is controlled with
SSH during build process in order to cross-compile ARM binaries. However, I
believe that it still should be possible to build it, if required.

Unfortunately, the procedure required in order to create a suitable FreeBSD
build host has been lost, however, it should not require too much of work
aside from taking a basic installation of FreeBSD with compiler included, and
installing CMake on it.

Vivado side of things may be more problematic, unless Vivado version is
matched exactly.

autobsd is written in Ruby, and, as such, requires Ruby interpreter on the host
machine. CMake and a suitable C compiler are also required.

Also note that DSO-100 uses submodules heavily - make sure you have retrieved
them, recursively, before attempting to build.

# Licensing

autobsd, and, indeed, the entire DSO-100 project, as published, is licensed
under the terms of the MIT license (see LICENSE).
