# MatNWB

A Matlab interface for reading and writing Neurodata Without Borders (NWB) 2.0 files.

## How does it work

NWB files are HDF5 files with data stored according to the Neurodata Without Borders: Neurophysiology (NWB:N) [schema](https://github.com/NeurodataWithoutBorders/nwb-schema/tree/dev/core). The schema is described in a set of yaml documents. These define the various types and their attributes.

This package provides two functions `generateCore` and `generateExtension` that transform the yaml files that describe the schema into Matlab m-files. The generated code defines classes that reflect the types defined in the schema.  Object attributes, relationships, and documentation are automatically generated to reflect the schema where possible.

Once the code generation step is done, NWB objects can be read, constructed and written from Matlab.

PyNWB's cached schemas are also supported, bypassing the need to run `generateCore` or `generateExtension` if present.

## Sources

MatNWB is available online at https://github.com/NeurodataWithoutBorders/matnwb

## Caveats

The NWB:N schema is in a state of some evolution.  This package assumes a certain set of rules are used to define the schema.  As the schema is updated, some of the rules may be changed and these will break this package.

For those planning on using matnwb alongside pynwb, please keep the following in mind:
 - The ordering of dimensions in MATLAB are reversed compared to numpy (and pynwb).  Thus, a 3-D ```SpikeEventSeries```, which in pynwb would normally be indexed in order ```(num_samples, num_channels, num_events)```, would be indexed in form ```(num_events, num_channels, num_samples)``` in MatNWB.
 - MatNWB is dependent on the schema, which may not necessary correspond with your PyNWB schema version.  Please consider overwriting the contents within MatNWB's **~/schema/core** directory with the generating PyNWB's **src/pynwb/data directory** and running generateCore to ensure compatibilty between systems.
 
The `master` branch in this repository is considered perpetually unstable.  If you desire matnwb's full functionality (full round-trip with nwb data), please consider downloading the more stable releases in the Releases tab.  Keep in mind that the Releases are generally only compatible with older versions of pynwb and may not supported newer data types supported by pynwb (such as data references or compound types).  Most releases will coincide with nwb-schema releases and contain compatibility with those features.

This package reads and writes NWB:N 2.0 files and does not support older formats.

## Setup

#### Step 1: Download MatNWB
[![View NeurodataWithoutBorders/matnwb on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/67741-neurodatawithoutborders-matnwb)

Download the current release of MatNWB from https://github.com/NeurodataWithoutBorders/matnwb/releases or check out the latest development version via 

```bash
git clone https://github.com/NeurodataWithoutBorders/matnwb.git
```

#### Step 2: Download the NWB Schema

Download the current release of the NWB format schema from https://github.com/NeurodataWithoutBorders/nwb-schema/releases or check out the latest development via 

```bash
git clone --recursive https://github.com/NeurodataWithoutBorders/nwb-schema.git
```

#### Step 3: Generate the API

From the Matlab command line, generate code from the copy of the NWB schema.  The command also takes variable arguments from any extensions.

```matlab
generateCore(); % generate core namespace located in the repository.
```

The command also takes variable arguments from any extensions.

```matlab
generateCore('schema/core/nwb.namespace.yaml', '.../my_extensions1.namespace.yaml',...);
```

You can also generate extensions without generating the core classes in this way:

```matlab
generateExtension('my_extension.namespace.yaml');
```

Generated Matlab code will be put a `+types` subdirectory.  This is a Matlab package.  When the `+types` folder is accessible to the Matlab path, the generated code will be used for reading NWBFiles.

```matlab
nwb=nwbRead('data.nwb');
```

## API Documentation

For more information regarding the MatNWB API or any of the NWB Core types in MatNWB, visit the [MatNWB API Documentation pages](https://neurodatawithoutborders.github.io/matnwb/doc/index.html).

## Tutorials

[Extracellular Electrophysiology](https://neurodatawithoutborders.github.io/matnwb/tutorials/html/ecephys.html)

[Calcium Imaging](https://neurodatawithoutborders.github.io/matnwb/tutorials/html/ophys.html)

[Intracellular Electrophysiology](https://neurodatawithoutborders.github.io/matnwb/tutorials/html/icephys.html)

## Examples

[Basic Data Retrieval](https://neurodatawithoutborders.github.io/matnwb/tutorials/html/basicUsage.html)
| showcases how one would read and process converted NWB file data to display a raster diagram.

[Conversion of Real Electrophysiology/Optophysiology Data](https://neurodatawithoutborders.github.io/matnwb/tutorials/html/convertTrials.html)
| converts Electrophysiology/Optophysiology Data recorded from:
>Li, Daie, Svoboda, Druckman (2016); Data and simulations related to: Robust neuronal dynamics in premotor cortex during motor planning. Li, Daie, Svoboda, Druckman, Nature. CRCNS.org
http://dx.doi.org/10.6080/K0RB72JW

## Third-party Support
The `+contrib` folder contains tools for converting from other common data formats/specifications to NWB. Currently supported data types are TDT, MWorks, and Blackrock. We are interested in expanding this section to other data specifications and would greatly value your contribution!

## Testing

Run the test suite with `nwbtest`.

## FAQ

1. "A class definition must be in an "@" directory."

Make sure that there are no "@" signs **anywhere** in your *full* file path.  This includes even directories that are not part of the matnwb root path and any "@" signs that are not at the beginning of the directory path.

Alternatively, this issue disappears after MATLAB version 2017b.  Installing this version may also resolve these issues.  Note that the updates provided with 2017b should also be installed.
