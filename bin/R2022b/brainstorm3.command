#!/bin/bash
# USAGE:  brainstorm3.command <MATLABROOT>
#         brainstorm3.command
#         brainstorm3.command <MATLABROOT> <script.m> <arguments>
#
# If MATLABROOT argument is specified, the Matlab root path is saved
# in the file ~/.brainstorm/MATLABROOTXX.txt.
# Else, MATLABROOT is read from this file
#
# AUTHOR: Francois Tadel, 2011-2022

# Configuration
VER_NAME="2022b"
VER_NUMBER="9.13"
VER_DIR="913"
MDIR="$HOME/.brainstorm"
MFILE="$MDIR/MATLABROOT$VER_DIR.txt"

#########################################################################
# Detect system type
if [ $(uname -s) == "Linux" ]; then
    if [ $(getconf LONG_BIT) == "32" ]; then
        SYST=glnx86
    else
        SYST=glnxa64
    fi
elif [ $(uname -s) == "Darwin" ]; then
    SYST=maci64
else
    echo "ERROR: Unsupported operating system"
    uname -a
    exit 1
fi 

##########################################################################
# Detect in which directory is this script
SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# JAR is in the same folder (Linux)
if [ -f "$SH_DIR/brainstorm3.jar" ]; then
    JAR_FILE=$SH_DIR/brainstorm3.jar
# JAR is 3 levels up (on MacOSX: brainstorm3.app/Contents/MacOS/brainstorm3.command)
elif [ -f "$SH_DIR/../../../brainstorm3.jar" ]; then
    JAR_FILE=$SH_DIR/../../../brainstorm3.jar
else
    echo "ERROR: brainstorm3.jar not found"
fi

#########################################################################
# Read the Matlab root folder from the command line
if [ "$1" ]; then
    MATLABROOT=$1 
# Read the folder from the file
elif [ -f $MFILE ]; then
    MATLABROOT=$(<$MFILE)
# MacOS: Try the default installation folders for Matlab or the MCR
elif [ $SYST == "maci64" ] && [ -d "/Applications/MATLAB/MATLAB_Runtime/v$VER_DIR" ]; then
    MATLABROOT="/Applications/MATLAB/MATLAB_Runtime/v$VER_DIR"
    echo "MATLAB Runtime library was found in folder:"
    echo "$MATLABROOT"
# Run the java file selector
else
    java -classpath "$JAR_FILE" org.brainstorm.file.SelectMcr$VER_NAME
    # Read again the folder from the file
    if [ -f $MFILE ]; then
        MATLABROOT=$(<$MFILE)
    fi
fi

#########################################################################
# If folder not specified: error
if [ -z "$MATLABROOT" ]; then
    echo " "
    echo "USAGE: brainstorm3.command <MATLABROOT>"
	echo "       brainstorm3.command <MATLABROOT> <script.m> <arguments>"
    echo " "
    echo "MATLABROOT is the installation folder of the Runtime $VER_NUMBER (R$VER_NAME)"
    echo "The Matlab Runtime $VER_NUMBER is the library needed to"
    echo "run executables compiled with Matlab $VER_NAME."
    echo " "
    echo "Examples:"
    echo "    Linux:  /usr/local/MATLAB_Runtime/v$VER_DIR"
    echo "    Linux:  $HOME/MATLAB_Runtime_$VER_NAME"
    echo "    MacOSX: /Applications/MATLAB/MATLAB_Runtime/v$VER_DIR"
    echo " "
    echo "MATLABROOT has to be specified only at the first call,"
    echo "then it is saved in the file ~/.brainstorm/MATLABROOT$VER_DIR.txt"
    echo " "
    exit 1
# If folder not a valid Matlab root path
else
    if [ $SYST == "maci64" ]; then
        LIBNAT=$MATLABROOT/bin/$SYST/libnativedl.dylib
    else
        LIBNAT=$MATLABROOT/bin/$SYST/libnativedl.so
    fi
    if [ ! -f "$LIBNAT" ]; then
		echo " "
        echo "Error: $MATLABROOT"
        echo "Not a valid MATLAB root path."
		echo " "
		echo "USAGE: brainstorm3.command <MATLABROOT>"
		echo "       brainstorm3.command <MATLABROOT> <script.m> <arguments>"
		echo " "
        exit 1
    fi
fi

#########################################################################
# Create .brainstorm folder is necessary
if [ ! -d "$MDIR" ]; then
    mkdir $MDIR
fi
# Save Matlab path in user folder
echo "$MATLABROOT" > $MFILE

#########################################################################
# Get JVM folder
export JVM_DIR=$MATLABROOT/sys/java/jre/$SYST/jre
export JAVA_EXE=$JVM_DIR/bin/java

##########################################################################
# Setting library path for MACOSX
if [ $SYST == "maci64" ]; then
    export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:$MATLABROOT/runtime/maci64:$MATLABROOT/sys/os/maci64:$MATLABROOT/bin/maci64
# Setting library path for LINUX
else
    export PATH=$PATH:$MATLABROOT/runtime/$SYST
    JAVA_SUBDIR=$(find $MATLABROOT/sys/java/jre -type d | tr '\n' ':') 
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$JAVA_SUBDIR$MATLABROOT/runtime/$SYST:$MATLABROOT/bin/$SYST:$MATLABROOT/sys/os/$SYST
fi

export XAPPLRESDIR=$MATLABROOT/X11/app-defaults

##########################################################################
# Start message
echo " "
echo "Please wait..."
echo " "
echo "If it hangs for more than a few minutes: try pressing ENTER."
echo "Alternatively, download Brainstorm for a different version of the Matlab Runtime."
echo "(See the installation instructions on the Brainstorm website)"
echo " "

# Run Brainstorm
"$JAVA_EXE" -jar "$JAR_FILE" "${@:2}"

# Force shell death on MacOSX
if [ $SYST == "maci64" ]; then
    exit 0
fi



