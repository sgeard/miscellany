# miscellany
A collection of unrelated small programs

## make_makefile.sh
This is for the covid-sim application: https://github.com/mrc-ide/covid-sim.git

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
