# miscellany
A collection of unrelated small programs

## make_makefile.sh
This is for building the covid-sim application on Linux:

https://github.com/mrc-ide/covid-sim.git

Tested on Mageia7 but should work on any reasonably recent version. It should also work in WSL2 on Windows (with g++) but thats untested. Works with either g++ or icc (from IntelOneApi).
For me the supplied build mechanism (CMake) used in this project doesn't work and I find the arcane nature of CMake
impossible to debug (and why should I need to?). So I've written this bash tool to create a Makefile that (IMHO) is
much easier to use.

### Example ###
Copy this file to the top level of covid-sim then do the following:
<pre>
 mkdir build
 cd build
 ../make_makefile.sh ../src
 make
 </pre>
