%% Neurodata Without Borders (NWB) advanced write using DataPipe
% How to utilize HDF5 compression using dataPipe
%
%  author: Ivan Smalianchuk and Ben Dichter
%  contact: smalianchuk.ivan@gmail.com, ben.dichter@catalystneuro.com
%  last edited: May 06, 2020
%%
% Neurophysiology data can be quite large, often in the 10s of GB per
% session and sometimes much larger. Here, we demonstrate methods in 
% MatNWB that allow you to deal with large datasets. These methods are 
% compression and iterative write. Both of these techniques use the
% |types.untyped.DataPipe| object, which sends specific instructions to the
% HDF5 backend about how to store data.
%% Compression - basic implementation
% To compress experimental data (in this case a 3D matrix with dimensions 
% [250 250 70]) one must assign it as a |DataPipe| type:

DataToCompress = randi(100,250,250,70);
DataPipe=types.untyped.DataPipe('data', DataToCompress);

%%
% This is the most basic way to acheive compression, and all of the
% optimization decisions are automatically determined by MatNWB.
%% Background
% HDF5 has built-in ability to compress and decompress individual datasets.
% If applied intelligently, this can dramatically reduce the amount of space
% used on the hard drive to represent the data. The end user does not need 
% to worry about the compression status of the dataset- HDF5 will 
% automatically decompress the dataset on read.
%
% The above example uses default chunk size and compression level (3). To 
% optimize compression, |compressionLevel| and |chunkSize| must be considered.
% compressionLevel ranges from 0 - 9 where 9 is the highest level of
% compression and 0 is the lowest. |chunkSize| is less intuitive to adjust;
% to implement compression, chunk size must be less than data size. 
%% |DataPipe| Arguments
%
% <html>
% <table border=1>
% <tr><td><em>maxSize</em></td><td>Sets the maximum size of the HDF5 Dataset. Unless using iterative writing, this should match the size of Data. To append data later, use the maxSize for the full dataset. You can use Inf for a value of a dimension if you do not know its final size.</td></tr>
% <tr><td><em>data</em></td><td>The data to compress. Must be numerical data.</td></tr>
% <tr><td><em>axis</em></td><td>Set which axis to increment when appending more data.</td></tr>
% <tr><td><em>dataType</em></td><td>Sets the type of the experimental data. This must be a numeric data type. Useful to include when using iterative write to append data as the appended data must be the same data type. If data is provided and dataType is not, the dataType is inferred from the provided data.</td></tr>
% <tr><td><em>chunkSize</em></td><td>Sets chunk size for the compression. Must be less than maxSize.</td></tr>
% <tr><td><em>compressionLevel</em></td><td>Level of compression ranging from 0-9 where 9 is the highest level of compression. The default is level 3.</td></tr>
% <tr><td><em>offset</em></td><td>Axis offset of dataset to append. May be used to overwrite data.</td></tr></table>
% </html>

%% Chunking
% HDF5 Datasets can be either stored in continuous or chunked mode.
% Continuous means that all of the data is written to one continuous block
% on the hard drive, and chunked means that the dataset is automatically
% split into chunks that are distributed across the hard drive. The user
% does not need to know the mode used- HDF5 handles the gathering of chunks
% automatically. However, it is worth understanding these chunks because
% they can have a big impact on space used and read and write speed. When
% using compression, the dataset MUST be chunked. HDF5 is not able to apply
% compression to continuous datasets.
%
% If chunkSize is not explicitly specified, dataPipe will determine an
% appropriate chunk size. However, you can optimize the performance of the
% compression by manually specifying the chunk size using _chunkSize_ argument.
%
% We can demonstrate the benefit of chunking by exploring the following
% scenario. The following code utilizes DataPipe’s default chunk size:
%

fData=randi(250,1000,1000); % Create fake data

% create an nwb structure with required fields
nwb=NwbFile(...
    'session_start_time','2020-01-01 00:00:00',...
    'identifier','ident1',...
    'session_description','DataPipeTutorial');

fData_compressed=types.untyped.DataPipe('data', fData);

fdataNWB=types.core.TimeSeries(...
    'data', fData_compressed,...
    'data_unit', 'mV');

nwb.acquisition.set('data', fdataNWB);

nwbExport(nwb, 'DefaultChunks.nwb');
%%
% This results in a file size of 47MB (too large), and the process takes
% 11 seconds (far too long). Setting the chunk size manually as in the
% example code below resolves these issues:

fData_compressed=types.untyped.DataPipe(...
    'data', fData,...
    'chunkSize', [1,1000],...
    'axis', 1);
%%
% This change results in the operation completing in 0.7 seconds and
% resulting file size of 1.1MB. The chunk size was chosen such that it
% spans each individual row of the matrix.
%
% Use the combination of arugments that fit your need. 
% When dealing with large datasets, you may want to use iterative write to
% ensure that you stay within the bounds of your system memory and use
% chunking and compression to optimize storage, read and write of the data.

%% Iterative Writing
% If experimental data is close to, or exceeds the available system memory,
% performance issues may arise. To combat this effect of large data,
% |DataPipe| can utilize iterative writing, where only a portion of the data
% is first compressed and saved, and then additional portions are appended.
%
% To demonstrate, we can create a nwb file with a compressed time series data:
%%

dataPart1=randi(250,10000,1); % "load" 1/4 of the entire dataset
fullDataSize=[40000 1]; % this is the size of the TOTAL dataset

% create an nwb structure with required fields
nwb=NwbFile(...
    'session_start_time','2020-01-01 00:00:00',...
    'identifier','ident1',...
    'session_description','DataPipeTutorial');

% compress the data
fData_use=types.untyped.DataPipe(...
    'data', dataPart1,...
    'maxShape', fullDataSize,...
    'axis', 1);

%Set the compressed data as a time series
fdataNWB=types.core.TimeSeries(...
    'data', fData_use,...
    'data_unit','mV');

nwb.acquisition.set('time_series', fdataNWB);

nwbExport(nwb, 'DataPipeTutorial_iterate.nwb');
%%
% To append the rest of the data, simply load the NWB file and use the
% append method:

nwb=nwbRead('DataPipeTutorial_iterate.nwb'); %load the nwb file with partial data

% "load" each of the remaining 1/4ths of the large dataset
for i=2:4 % iterating through parts of data
    dataPart_i=randi(250,10000,1); % faked data chunk as if it was loaded
    nwb.acquisition.get('time_series').data.append(dataPart_i) % append the loaded data
end
%%
% The axis property defines the dimension in which additional data will be
% appended. In the above example, the resulting dataset will be 4000x1.
% However, if we set axis to 2 (and change fullDataSize appropriately),
% then the resulting dataset will be 1000x4.
%

%% Timeseries example
% Following is an example of how to compress and add a timeseries
% to an NWB file:

fData=randi(250,10000,1); % create fake data;

%assign data without compression
nwb=NwbFile(...
    'session_start_time','2020-01-01 00:00:00',...
    'identifier','ident1',...
    'session_description','DataPipeTutorial');

ephys_module = types.core.ProcessingModule(...
    'description', 'holds processed ephys data');

nwb.processing.set('ephys', ephys_module);

% compress the data
fData_compressed=types.untyped.DataPipe( ...
    'data', fData,...
    'compressionLevel', 3,...
    'chunkSize', [100 1],...
    'axis', 1);

% Assign the data to appropriate module and write the NWB file
fdataNWB=types.core.TimeSeries(...
    'data', fData_compressed,...
    'data_unit','mV');

ephys_module.nwbdatainterface.set('data', fdataNWB);
nwb.processing.set('ephys', ephys_module);

%write the file
nwbExport(nwb, 'Compressed.nwb');