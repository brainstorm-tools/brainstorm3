function [ExportFile, sFileOut] = export_data(DataFile, ChannelMat, ExportFile, FileFormat)
% EXPORT_DATA: Exports a recordings file to one of the supported file formats.
%
% USAGE:  [ExportFile, sFileOut] = export_data( DataFile,        [], ExportFile=[ask], FileFormat=[detect] ) 
%         [ExportFile, sFileOut] = export_data( DataMat, ChannelMat, ExportFile=[ask], FileFormat=[detect] ) : Save a data structure
%                                  export_data( DataFiles{}, ... )                      : Batch process over multiple files
%         
% INPUT: 
%     - DataFile   : Brainstorm data file name to be exported
%     - DataMat    : Brainstorm data structure to be exported
%     - ExportFile : Full path to target file (extension will determine the format)
%                    If not specified: asked to the user

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2008-2019

% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 3) || isempty(ExportFile)
    ExportFile = [];
end
if (nargin < 2) || isempty(ChannelMat)
    ChannelMat = [];
end
% Initialize returned variables
sFileOut = [];


% ===== RECURSIVE CALLS =====
% CALL: export_data( DataFiles, ... )
if iscell(DataFile) 
    % Single file
    if (length(DataFile) == 1)
        DataFile = DataFile{1};
    % Multiple files
    else
        AllOutputs = cell(1,length(DataFile));
        % Call function once to get the output path
        AllOutputs{1} = export_data(DataFile{1}, ChannelMat, ExportFile);
        if isempty(AllOutputs{1})
            ExportFile = [];
            return;
        end
        % Get output path
        [outPath, outBase, outExt] = bst_fileparts(AllOutputs{1});
        % Loop on the other files
        for i = 2:length(DataFile)
            % Build output file name
            [dataPath, dataBase, dataExt] = bst_fileparts(DataFile{i});
            newFile = bst_fullfile(outPath, [dataBase, outExt]);
            newFile = strrep(newFile, '_data', '');
            newFile = strrep(newFile, 'data_', '');
            newFile = strrep(newFile, '0raw_', '');
            AllOutputs{i} = newFile;
            % Export file
            export_data(DataFile{i}, ChannelMat, AllOutputs{i});
        end
        ExportFile = AllOutputs;
        return;
    end
end

% ===== LOAD DATA =====
% CALL: export_data( DataFile, [], ExportFile )
if ischar(DataFile) 
    isRawIn = ~isempty(strfind(DataFile, '_0raw'));
    % Load initial file
    DataMat = in_bst_data(DataFile);
    % Get raw file structure
    if isRawIn
        sFileIn = DataMat.F;
        if (length(sFileIn.epochs) > 1)
            error('Cannot export epoched files.');
        end
    else
        sFileIn = in_fopen(DataFile, 'BST-DATA');
    end
    % Load channel file
    ChannelFile = bst_get('ChannelFileForStudy', DataFile);
    ChannelMat = in_bst_channel(ChannelFile);
% CALL: export_data( DataMat, ChannelMat, ExportFile ) 
elseif isstruct(DataFile)
    DataMat = DataFile;
    DataFile = [];
    isRawIn = 0;
    % Create a fake sFile structure
    sFileIn = in_fopen(DataMat, 'BST-DATA');
else
    error('Invalid call.');
end
    

% ===== SELECT OUTPUT FILE =====
if isempty(ExportFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.DataOut)
        case {'', 'BST-BIN'},   DefaultExt = '.bst';
        case 'FT-TIMELOCK',     DefaultExt = '.mat';
        case 'SPM-DAT',         DefaultExt = '.mat';
        case 'EEG-BRAINAMP',    DefaultExt = '.eeg';
        case 'EEG-CARTOOL-EPH', DefaultExt = '.eph';
        case 'EEG-EGI-RAW',     DefaultExt = '.raw';
        case 'EEG-EDF',         DefaultExt = '.edf';
        case 'ASCII-CSV',       DefaultExt = '.csv';
        case 'ASCII-CSV-HDR',   DefaultExt = '.csv';
        case 'ASCII-SPC',       DefaultExt = '.txt';  
        case 'ASCII-SPC-HDR',   DefaultExt = '.txt';        
        case 'EXCEL',           DefaultExt = '.xlsx';
        case 'BST',             DefaultExt = '_timeseries.mat';
        otherwise,              DefaultExt = '_timeseries.mat';
    end
    % Build default output filename
    if ~isempty(DataFile)
        [BstPath, BstBase, BstExt] = bst_fileparts(DataFile);
    else
        BstBase = file_standardize(DataMat.Comment);
    end
    DefaultExportFile = bst_fullfile(LastUsedDirs.ExportData, [BstBase, DefaultExt]);
    DefaultExportFile = strrep(DefaultExportFile, '_data', '');
    DefaultExportFile = strrep(DefaultExportFile, 'data_', '');
    DefaultExportFile = strrep(DefaultExportFile, '0raw_', '');

    % === Ask user filename ===
    % RAW file or imported
    if isRawIn
        FileFilters = bst_get('FileFilters', 'rawout');
    else
        FileFilters = bst_get('FileFilters', 'dataout');
    end
    % Put file
    [ExportFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export MEG/EEG recordings...', ... % Window title
        DefaultExportFile, ...              % Default directory
        'single', 'files', ...              % Selection mode
        FileFilters, ...
        DefaultFormats.DataOut);
    % If no file was selected: exit
    if isempty(ExportFile)
        return;
    end    
    % Save new default export path
    LastUsedDirs.ExportData = bst_fileparts(ExportFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.DataOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    
% Guess file format based on its extension
elseif isempty(FileFormat)
    [BstPath, BstBase, BstExt] = bst_fileparts(ExportFile);
    switch lower(BstExt)
        case '.bst',   FileFormat = 'BST-BIN';
        case '.eeg',   FileFormat = 'EEG-BRAINAMP';
        case '.eph',   FileFormat = 'EEG-CARTOOL-EPH';
        case '.raw',   FileFormat = 'EEG-EGI-RAW';
        case '.edf',   FileFormat = 'EEG-EDF';
        case '.txt',   FileFormat = 'ASCII-CSV';
        case '.csv',   FileFormat = 'ASCII-SPC';
        case '.xlsx',  FileFormat = 'EXCEL';
        case '.mat',   FileFormat = 'BST';
        otherwise,     error('Unsupported file extension.');
    end
end
% Show progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Export EEG/MEG recordings', 'Exporting file...');
end
% Option for input raw file
if isRawIn
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode      = 'Time';
    ImportOptions.DisplayMessages = 0;
    ImportOptions.UseCtfComp      = 0;
    ImportOptions.UseSsp          = 0;
    ImportOptions.RemoveBaseline  = 'no';
end

% ===== REMOVE ANNOTATION CHANNELS =====
% Detect annotation channels (exclude BST-BIN output, because we want to keep everything)
if ~strcmpi(FileFormat, 'BST-BIN')
    iAnnot = channel_find(ChannelMat.Channel, {'EDF', 'BDF', 'KDF'});
else
    iAnnot = [];
end
% List of input and output channels
iChannelsIn = setdiff(1:length(ChannelMat.Channel), iAnnot);
iChannelsOut = 1:length(iChannelsIn);
% Selected channel mats
ChannelMatIn = ChannelMat;
ChannelMatOut = ChannelMat;
% Remove unwanted channels from channel file
if ~isempty(iAnnot)
    ChannelMatOut.Channel = ChannelMatOut.Channel(iChannelsIn);
    for iProj = 1:length(ChannelMatOut.Projector)
        if isequal(ChannelMatOut.Projector(iProj).SingVal, 'REF')
            ChannelMatOut.Projector(iProj).Components = ChannelMatOut.Projector(iProj).Components(iChannelsIn, iChannelsIn);
        else
            ChannelMatOut.Projector(iProj).Components = ChannelMatOut.Projector(iProj).Components(iChannelsIn, :);
        end
    end
end
% Remove unwanted channels from input data file
if ~isRawIn
    if isfield(DataMat, 'F') && ~isempty(DataMat.F)
        DataMat.F = DataMat.F(iChannelsIn,:);
    end
    if isfield(DataMat, 'ChannelFlag') && ~isempty(DataMat.ChannelFlag)
        DataMat.ChannelFlag = DataMat.ChannelFlag(iChannelsIn);
    end
end

% ===== CREATE OUTPUT RAW FILE =====
% Output data as raw file (continuous writers routines)
isRawOut = ismember(FileFormat, {'BST-BIN', 'EEG-EGI-RAW', 'SPM-DAT', 'EEG-EDF', 'EEG-BRAINAMP'});
% Open output file 
if isRawOut
    [sFileOut, errMsg] = out_fopen(ExportFile, FileFormat, sFileIn, ChannelMatOut, iChannelsIn);
    % Error management
    if isempty(sFileOut) && ~isempty(errMsg)
        error(errMsg);
    elseif ~isempty(errMsg)
        disp(['BST> Warning: ' errMsg]);
    end
end

% ===== RAW IN / RAW OUT =====
if isRawIn && isRawOut
    % Check that in!=out
    if file_compare(sFileIn.filename, sFileOut.filename)
        error('Input and output files are the same.');
    end
    % Get default epoch size
    EpochSize = bst_process('GetDefaultEpochSize', sFileOut);
    % Process by sample blocks
    nSamples = round((sFileOut.prop.times(2) - sFileOut.prop.times(1)) * sFileOut.prop.sfreq) + 1;
    nBlocks = ceil(nSamples / EpochSize);
    % Show progress bar
    if ~isProgress
        bst_progress('start', 'Export EEG/MEG recordings', 'Exporting file...', 0, nBlocks);
    end
    % Copy files by block
    for iBlock = 1:nBlocks
        % Get sample indices
        SamplesBounds = sFileOut.prop.times(1) * sFileOut.prop.sfreq + [(iBlock-1) * EpochSize, min(iBlock*EpochSize-1, nSamples-1)];
        % Read from input file
        F = in_fread(sFileIn, ChannelMatIn, 1, SamplesBounds, iChannelsIn, ImportOptions);
        % Save to output file
        sFileOut = out_fwrite(sFileOut, ChannelMatOut, 1, SamplesBounds, iChannelsOut, F);
        % Increase progress bar
        if ~isProgress
            bst_progress('inc', 1);
        end
    end

% ===== SAVE FULL FILES =====
else
    % Load full file
    if isRawIn
        F = in_fread(sFileIn, ChannelMatIn, 1, [], iChannelsIn, ImportOptions);
    else
        if isfield(DataMat, 'F') && ~isempty(DataMat.F)
            F = DataMat.F;
        elseif isfield(DataMat, 'ImageGridAmp') && ~isempty(DataMat.ImageGridAmp)
            F = DataMat.ImageGridAmp;
        else
            error('No relevant data to save found in structure.');
        end
    end

    % Save full file
    if isRawOut
        out_fwrite(sFileOut, ChannelMatOut, 1, [], iChannelsOut, F);
    else
        % Switch between file formats
        switch FileFormat
            case 'BST'
                DataMat.F = F;
                bst_save(ExportFile, DataMat, 'v6');
            case 'FT-TIMELOCK'
                ftData = out_fieldtrip_data(DataMat, ChannelMatOut, [], 1);
                bst_save(ExportFile, ftData, 'v6');
            case 'EEG-CARTOOL-EPH'
                % Get sampling rate
                samplingFreq = round(1/(DataMat.Time(2) - DataMat.Time(1)));
                % Write header : nb_electrodes, nb_time, sampling_freq
                dlmwrite(ExportFile, [size(F,1), size(F,2), samplingFreq], 'newline', 'unix', 'precision', '%d', 'delimiter', ' ');
                % Write data
                dlmwrite(ExportFile, F' * 1000, 'newline', 'unix', 'precision', '%0.7f', 'delimiter', '\t', '-append');
            case {'ASCII-SPC', 'ASCII-CSV', 'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'EXCEL'}
                out_matrix_ascii(ExportFile, F, FileFormat, {ChannelMatOut.Channel.Name}, DataMat.Time, []);
            otherwise
                error('Unsupported format.');
        end
    end
end
    
% Hide progress bar
if ~isProgress
    bst_progress('stop');
end

end

