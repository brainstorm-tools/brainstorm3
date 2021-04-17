# EasyH5 Toolbox - An easy-to-use HDF5 data interface (loadh5 and saveh5)

* Copyright (C) 2019  Qianqian Fang <q.fang at neu.edu>
* License: GNU General Public License version 3 (GPL v3) or 3-clause BSD license, see LICENSE*.txt
* Version: 0.8 (code name: Go - Japanese 5)
* URL: http://github.com/fangq/easyh5

## Overview

EasyH5 is a fully automated, fast, compact and portable MATLAB object to HDF5
exporter/importer. It contains two easy-to-use functions - `loadh5.m` and
`saveh5.m`. The `saveh5.m` can handle almost all MATLAB data types, including 
structs, struct arrays, cells, cell arrays, real and complex arrays, strings, 
and `containers.Map` objects. All other data classes (such as a table, digraph, 
etc) can also be stored/loaded seemlessly using an undocumented data serialization 
interface (MATLAB only).

EasyH5 stores complex numerical arrays using a special compound data type in an
HDF5 dataset. The real-part of the data are stored as `Real` and the imaginary
part is stored as the `Imag` component. The `loadh5.m` automatically converts
such data structure to a complex array. Starting from v0.8, EasyH5 also supports
saving and loading sparse arrays using a compound dataset with 2 or 3
specialized subfields: `SparseArray`, `Real`, and, in the case of a sparse
complex array, `Imag`. The sparse array dimension is stored as an attribute
named `SparseArraySize`, attached with the dataset. Using the `deflate` filter
to save compressed arrays is supported in v0.8 and later.

Because HDF5 does not directly support 1-D/N-D cell arrays or struct arrays,
EasyH5 converts these data structures into data groups with names in the 
following format
```
    ['/hdf5/path/.../varname',num2str(idx1d)]
```
where `varname` is the variable/field name to the cell/struct array object, 
and `idx1d` is the 1-D integer index of the cell/struct array. We also provide
a function, `regrouph5.m` to automatically collapse these group/dataset names
into 1-D cell/struct arrays after loading the data using `loadh5.m`. See examples
below.

## Installation

The EasyH5 toolbox can be installed using a single command
```
    addpath('/path/to/easyh5');
```
where the `/path/to/easyh5` should be replaced by the unzipped folder
of the toolbox (i.e. the folder containing `loadh5.m/saveh5.m`).

## Usage

### `saveh5` - Save a MATLAB struct (array) or cell (array) into an HDF5 file
Save a MATLAB struct (array) or cell (array) into an HDF5 file.

Example:
```
  a=struct('a',rand(5),'c','string','b',true,'d',2+3i,'e',{'test',[],1:5});
  saveh5(a,'test.h5');
  saveh5(a(1),'test2.h5','rootname','');
  saveh5(a(1),'test2.h5','compression','deflate','compressarraysize',1);
```
### `loadh5` - Load data in an HDF5 file to a MATLAB structure.
Load data in an HDF5 file to a MATLAB structure.

Example:
```
  a={rand(2), struct('va',1,'vb','string'), 1+2i};
  saveh5(a,'test.h5');
  a2=loadh5('test.h5')
  a3=loadh5('test.h5','regroup',1)
  isequaln(a,a3.a)
  a4=loadh5('test.h5','/a1')
```
### `regrouph5` - Processing an HDF5 based data and group indexed datasets into a cell array
Processing a loadh5 restored data and merge "indexed datasets", whose
names start with an ASCII string followed by a contiguous integer
sequence number starting from 1, into a cell array. For example,
datasets {data.a1, data.a2, data.a3} will be merged into a cell/struct
array data.a with 3 elements.

Example:
```
  a=struct('a1',rand(5),'a2','string','a3',true,'d',2+3i,'e',{'test',[],1:5});
  a(1).a1=0; a(2).a2='test';
  data=regrouph5(a)
  saveh5(a,'test.h5');
  rawdata=loadh5('test.h5')
  data=regrouph5(rawdata)
```

## Known problems
- EasyH5 currently does not support 2D cell and struct arrays
- If a cell name ends with a number, such as `a10={...}`; `regrouph5` can not group the cell correctly
- If a database/group name is longer than 63 characters, it may have the risk of being truncated

## Contribute to EasyH5

Please submit your bug reports, feature requests and questions to the Github Issues page at

https://github.com/fangq/easyh5/issues

Please feel free to fork our software, making changes, and submit your revision back
to us via "Pull Requests". EasyH5 is open-source and welcome to your contributions!

