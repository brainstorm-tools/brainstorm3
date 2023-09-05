# JSNIRF Toolbox - A portable MATLAB toolbox for parsing SNIRF (HDF5) and JSNIRF (JSON) files

* Copyright (C) 2019  Qianqian Fang <q.fang at neu.edu>
* License: GNU General Public License version 3 (GPL v3) or Apache License 2.0, see License*.txt
* Version: 0.4 (code name: Amygdala - alpha)
* URL: https://github.com/NeuroJSON/jsnirf/tree/master/lib/matlab

## Overview

JSNIRF is a portable format for storage, interchange and processing data generated 
from functional near-infrared spectroscopy, or fNIRS - an emerging functional neuroimaging 
technique. Built upon the JData and SNIRF specifications, a JSNIRF file has both a 
text-based interface using the JavaScript Object Notation (JSON) [RFC4627] format 
and a binary interface using the Universal Binary JSON (UBJSON, http://ubjson.org) derived 
Binary JData ([BJData](https://github.com/NeuroJSON/bjdata)) serialization format.
It contains a compatibility layer to provide a 1-to-1 mapping to the existing 
HDF5 based SNIRF files. A JSNIRF file can be directly parsed by most existing 
JSON and BJData parsers. Advanced features include optional hierarchical data 
storage, grouping, compression, integration with heterogeneous scientific data 
enabled by JData data serialization framework.

This toolbox also provides a fast/complete reader/writer for the HDF5-based SNIRF
files (along with any HDF5 data) via the EazyH5 toolbox 
(http://github.com/fangq/eazyh5). The toolbox can read/write SNIRF v1.0 data
files specified by the SNIRF specification http://github.com/fNIRS/snirf .

This toolbox is selectively dependent on the below toolboxes
- To read/write SNIRF/HDF5 files, one must install the EazyH5 toolbox at 
  http://github.com/fangq/eazyh5 ; this is only supported on MATLAB, not Octave.
- To create/read/write JSNIRF files, one must install the JSONLab toolbox
  http://github.com/NeuroJSON/jsonlab ; this is supported on both MATLAB and Octave.
- To read/write JSNIRF files with internal data compression, one must install 
  the JSONLab toolbox http://github.com/NeuroJSON/jsonlab as well as ZMat toolbox
  http://github.com/fangq/zmat ; this is supported on both MATLAB and Octave.

## Why JSNIRF?

A SNIRF data file is basically an HDF5 file. HDF5 (Hierarchical Data Format version 5)
is a general purpose file format for storing flexible binary data. However, it has
the below limitations:

- it is binary, not human readable, you must use a parser to load the file
  and understand the content
- it requires a spacial library, although widely and freely available, to load
  or save such file; dependeny to such library requires extra work for deployment
- HDF5 is a very sophisticated format; writing your own parser is quite difficult
- when storing a small dataset, an HDF5 file has an overhead in file size

In comparison, the JSNIRF data format is defined based on the JData specification.
and supports both a text-based interface and a binary interface. The text form
JSNIRF file is a plain JSON file, and has various advantages

- JSNIRF is human readable, you can read the data using an editor
- JSNIRF is very simple (because JSON format is very simple)
- JSNIRF is lightweight, little overhead for storing small datasets
- JSNIRF can be readily parsed by numerous free JSON parsers available
- Programming your own specialized JSNIRF parser is very easy to write

The binary JSNIRF format uses a binary JSON format (BJData) which is also
- quasi-human readable despite it is binary
- free parsers available for [MATLAB](http://github.com/fangq/jsonlab),
  [Python](https://pypi.org/project/bjdata/), [C++](https://github.com/NeuroJSON/json),
  and [C](https://github.com/NeuroJSON/ubj)
- easy to write your own parser because of the simplicity



## SNIRF and JSNIRF format compatibility

The JSNIRF data structure is highly compatible with the SNIRF data structure.
This toolbox provides utilities convert from one form to the other losslessly.

There are only two minor differences:
* A JSNIRF data container renames the SNIRF `/nirs` root object as `SNIRFData`.
  If multiple measurement datasets are provided in the SNIRF data in the forms of
  `/nirs1`, `/nirs2` ..., or `/nirs/data1`. `/nirs/data2` ..., JSNIRF merges these
  data objects into struct/cell arrays, and removes the group indices from the 
  group names. These grouped objects are stored as an JSON/BJData array object
  '[]' when saving to disk.
* The `/formatVersion` object in the SNIRF data are moved from the root level 
  to a subfield of `SNIRFData`, this allows the JSNIRF data files to be easily
  mixed/integrated with other JSON-based data containers, such as `SNIRFData`
  defined in other JData based data formats.

To further illustrate the above data reorganization steps, please find below
an example

An original SNIRF/HDF5 data outline
```
/formatVersion
/nirs1/
   /metaDataTags
   /data1
   /data2
   /aux1
   /aux2
   /probe
   ...
/nirs2/
   /metaDataTags
   /data
   /aux1
   /aux2
   /aux3
   /probe
   ...
```
is converted to the below JSON/JSNIRF data structure
```
{
  "SNIRFData": [
      {
          "formatVersion": '1.0',
          "metaDataTags":{
	      "SubjectID": ...
	  },
	  "data": [
	     {..for data1 ...},
	     {..for data2 ...}
	  ],
	  "aux": [
	     {..for aux1 ...},
	     {..for aux2 ...}
	  ],
	  "probe": ...
      },
      {
          "formatVersion": '1.0',
          "metaDataTags":{
	      "SubjectID": ...
	  },
	  "data": {...},
	  "aux": [
	     {..for aux1 ...},
	     {..for aux2 ...},
	     {..for aux3 ...}
	  ],
	  "probe": ...
      },
      ...
  ]
}
```

## Installation

The JSNIRF toolbox can be installed using a single command
```
    addpath('/path/to/jsnirf');
```
where the `/path/to/jsnirf` should be replaced by the unzipped folder
of the toolbox (i.e. the folder containing `savejsnirf.m/loadjsnirf.m`).

In order for this toolbox to work, one must install the below dependencies
- the `saveh5/loadh5` functions are provided by the EazyH5 toolbox at 
  http://github.com/fangq/eazyh5
- the `savejson` and `savebj` functions are provided by the JSONLab 
  toolbox at http://github.com/NeuroJSON/jsonlab 
- if data compression is specified by `'compression','zlib'` param/value 
  pairs, ZMat toolbox will be needed, http://github.com/fangq/zmat


## Usage

### `snirfcreate/jsnirfcreate` - Create an empty SNIRF or JSNIRF data container (structure)
Example:
```
  data=snirfcreate;              % create an empty SNIRF data structure
  data=snirfcreate('data',realdata,'aux',realauxdata); % setting the default values to user data
  data=jsnirfcreate('format','snirf');                 % specify 'snirf' or 'jsnirf' using 'format' option
  jsn=snirfdecode(loadh5('mydata.snirf'));             % load raw HDF5 data and convert to a JSNIRF struct
```
### `loadsnirf/loadjsnirf` - Loading SNIRF/JSNIRF files as in-memory MATLAB data structures
Example:
```
  data=loadsnirf('mydata.snirf');     % load an HDF5 SNIRF data file, same as loadh5+regrouph5
  jdata=loadjsnirf('mydata.bnirs');   % load a binary JSON/JSNIRF data file
```
### `savesnirf/savejsnirf` - Saving in-memory MATLAB data structure into SNIRF/HDF5 or JSNIRF/JSON files
Example:
```
  data=snirfcreate;
  data.nirs.data.dataTimeSeries=rand(100,5);
  data.nirs.metaDataTags.SubjectID='subj1';
  data.nirs.metaDataTags.MeasurementDate=date;
  data.nirs.metaDataTags.MeasurementTime=datestr(now,'HH:MM:SS');
  savesnirf(data,'test.snirf');
  savejsnirf(data,'test.jnirs');
```

## Contribute to JSNIRF

Please submit your bug reports, feature requests and questions to the Github Issues page at

https://github.com/NeuroJSON/jsnirf/issues

Please feel free to fork our software, making changes, and submit your revision back
to us via "Pull Requests". JSNIRF toolbox is open-source and we welcome your contributions!
