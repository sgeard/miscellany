#!/bin/bash

# Compiler and options
cxx=g++
# cxx=icc ; # For the Intel OneAPI compiler
declare -A cxxopts
cxxopts[release]="-fopenmp -Ofast -std=c++14"
cxxopts[debug]="-fopenmp -ggdb -std=c++14 -Wall -Wextra"

mf_name=Makefile

################################################################################

# You shouldn't need to edit anything hereon

function usage()
{
    echo "Generate GNU makefile suitable for the project in the current directory."
    echo "Usage:  $0 ?-h? ?-v? ?sdir?"
    echo "Searches recursively for .cpp files in sdir. If sdir isn't specified the"
    echo "location of this script is used. The generated Makefile will create objects"
    echo "in the current directory so source and objects can be separated if required."
    echo "The created Makefile builds with release options by default, debug=t can be used"
    echo "to get a debug build."
}

# Parse arguments
verbose=0
sdir=$(dirname $0)
while [[ $# > 0 ]]; do
    case $1 in
       -h) usage; exit 0 ;;
       -v) verbose=1 ;;
        *) sdir=$1 ;;
    esac
    shift
done

#---------------------------------------------------------------------------------

incdir=$(dirname $sdir)/include
if [[ $verbose == 1 ]]; then
    echo "sdir = $sdir"
    echo "incdir = $incdir"
fi
if [[ -d $incdir ]]; then
    cxxincs="-I$incdir"
else
    cxxincs="-I."
fi

# Start of the makefile
echo -n "# Created by $0 on "       > $mf_name
date                               >> $mf_name
echo -e "\n.SUFFICIES:"            >> $mf_name
echo ".PHONY: all clean libs"      >> $mf_name
echo ""                            >> $mf_name

# All source except the main program.
# For subdirectories the object file is created in this directory
# rather than the subdirectory itself so we maintain a map to keep
# track of this.
srcline="SRC := "
objline="OBJ := "
declare -A srcfiles
if [[ $verbose == 1 ]]; then
    echo "Source files found:"
fi

for sf in $(find $sdir -type f -name '*.cpp' -print); do
    if [[ $verbose == 1 ]]; then
        echo -e "\t${sf}"
    fi
    grep -q '^ *int  *main' $sf
    if [[ $? == 0 ]]; then
        mp_src=$sf
        continue
    fi
    of="${sf%.cpp}.o"
    of=${of##*/}
    srcfiles[$sf]=$of
    srcline="$srcline $sf"
    objline="$objline ${srcfiles[$sf]}"
done

echo "$srcline"                                                             >> $mf_name
echo "$objline"                                                             >> $mf_name
echo ""                                                                     >> $mf_name
echo "ifdef debug"                                                          >> $mf_name
echo "CXXOPTS := ${cxxopts[debug]}"                                         >> $mf_name
echo "else"                                                                 >> $mf_name
echo "CXXOPTS := ${cxxopts[release]}"                                       >> $mf_name
echo "endif"                                                                >> $mf_name
echo "CXXINCS := $cxxincs"                                                  >> $mf_name
echo ""                                                                     >> $mf_name

if [[ ! -z $mp_src ]]; then
    mainprog=${mp_src##*/}
    mp_name=${mainprog%.cpp}
    mp_obj="${mp_name}.o"
    echo "main program = $mainprog"
    echo -e "all: libs $mp_name\n"                                          >> $mf_name
    echo "$mp_name: $mp_src libs"                                           >> $mf_name
    echo -e "\t $cxx $mp_src -o $mp_name lib${mp_name}.a \$(CXXOPTS) \$(CXXINCS)\n"    >> $mf_name
else
    echo -e "all: libs\n"                                                   >> $mf_name
fi
echo -e "libs: \$(OBJ)"                                                     >> $mf_name
echo -e "	ar cr lib${mp_name}.a \$(OBJ)\n"                                >> $mf_name

if [[ $verbose == 1 ]]; then
    echo "Dependencies:"
fi
for sf in ${!srcfiles[@]}; do
    if [[ $verbose == 1 ]]; then
        echo -e "\t${sf}"
    fi
    $cxx -MM $cxxincs $sf                                                   >> $mf_name
    echo -e "\t $cxx -c $sf -o ${srcfiles[$sf]} \$(CXXOPTS) \$(CXXINCS)\n"  >> $mf_name
done

echo "clean:"                                                               >> $mf_name
echo -e "\t \$(RM) \$(OBJ) CLI"                                             >> $mf_name
if [[ $verbose == 1 ]]; then
    echo "done"
fi
exit 0
