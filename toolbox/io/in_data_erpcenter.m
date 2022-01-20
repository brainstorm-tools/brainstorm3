function DataMat = in_data_erpcenter(DataFile)
% IN_DATA_ERPCENTER: Imports an ERPCenter file.
%
% USAGE: DataMat = in_data_erpcenter(DataFile);
%
% INPUT:
%    - DataFile : Full path to a recordings file. This file can be:
%         1) .hdr filename => load all the .erp files in this directory
%         2) .erp filename => else load only target .erp data file
%         3) directory with a .hdr file and at least one .erp file
%
% OUTPUT:
%    - DataMat : Brainstorm standard recordings ('data') structure
%
% FORMAT:
%     An ERPCenter document is a directory with : 
%        - One ASCII header file (erp.hdr), which has the following format:
%           "data format"        RETURN
%           "number of channels" RETURN
%           "number of samples"  RETURN
%           "time step"          RETURN
%           "baseline stop"      RETURN
%        - Many .erp files, that can either in ASCII or in binary format
%           => Raw matrices [NbTime x NbElectrodes]
%           => A column with only zero-values is a BAD channel

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2016

targetFileNames = [];
DataMat = repmat(db_template('DataMat'), 0);

% Get DataFile format
if ~isdir(DataFile)
    [filepath, filebase, fileext] = bst_fileparts(DataFile);
    switch lower(fileext)
        % Target file is a HEADER file
        case '.hdr'
            HdrFile  = DataFile;
            % List .erp files in header directory
            dirErp = dir(bst_fullfile(filepath, '*.erp'));
            ErpFiles = cellfun(@(f)fullfile(filepath,f), {dirErp.name}', 'UniformOutput',0);
        case '.erp'
            ErpFiles = {DataFile};
            % List .hdr files in header directory
            dirHdr = dir(bst_fullfile(filepath, '*.hdr'));
            % Keep it if there is only one header
            if (length(dirHdr) ~= 1)
                HdrFile = '';
            else
                HdrFile = bst_fullfile(filepath, dirHdr(1).name);
            end
        otherwise
            error('File is not a ERPCenter file : %s', DataFile);
    end
% Directory : look for .hdr and .erp files
else
    filepath = DataFile;
    % List .hdr files in header directory
    dirHdr = dir(bst_fullfile(filepath, '*.hdr'));
    % Keep it if there is only one header
    if (length(dirHdr) ~= 1)
        HdrFile = '';
    else
        HdrFile = bst_fullfile(filepath, dirHdr(1).name);
    end
    % List .erp files in header directory
    dirErp = dir(bst_fullfile(filepath, '*.erp'));
    ErpFiles = cellfun(@(f)bst_fullfile(filepath,f), {dirErp.name}', 'UniformOutput',0);
end
% Check that Data and Header are accessible
if isempty(HdrFile)
    error('Cannot find ERPCenter header file in directory : %s', filepath);
elseif isempty(ErpFiles)
    error('Cannot find any ERPCenter data file in directory : %s', filepath);
end
% Get base name
[tmp__, baseName] = bst_fileparts(filepath);
    
%% ===== LOAD HEADER FILE (.hdr) =====
% Open file
fid = fopen( HdrFile, 'r' );
if (fid == -1)
    error('Cannot open header file : %s', HdrFile);
end
try
    % Read file
    format     = fgetl(fid);
    nbChannels = str2num(fgetl(fid));  % Integer
    nbSamples  = str2num(fgetl(fid));  % Integer
    timestep   = str2num(fgetl(fid));  % Float (ms)
    baseline   = str2num(fgetl(fid));  % Float (ms)
    % Close file
    fclose(fid);
catch
    bst_error(['Header file is corrupted : ', HdrFile]);
end
% Check read values
if isempty(format) || isempty(nbChannels) || isempty(nbSamples) || isempty(timestep) || isempty(baseline) 
    bst_error(['Header file is corrupted : %s', HdrFile]);
end
% Build Time vector
TimeVector = ((1:nbSamples)*timestep - baseline)/1000;



%% ===== LOAD DATA FILES (.erp) =====
for iFile = 1:length(ErpFiles)
    % Read data matrix
    % ASCII format
    if strcmpi(format, 'ascii')
        read_data = dlmread(ErpFiles{iFile});
        
    % Binary format ('ieee-le', 'ieee-be', ...)
    else
        % Open file
        fid = fopen(ErpFiles{iFile}, 'rb', format);
        % Read matrix
        [read_data, read_count] = fread( fid, [nbSamples, nbChannels], '*float32' );
        % Close file
        fclose(fid);
        % If could not as many values values as needed : ignore this file
        if (read_count ~= nbChannels*nbSamples)
            warning('BST:InvalidFile', ['Corrupted data file : ' ErpFiles{iFile}]);
            continue
        end
    end
    if isempty(read_data)
        warning('BST:InvalidFile', ['Data file is empty : ' ErpFiles{iFile}]);
        continue
    end
    % Transposing data matix
    read_data = read_data';
    % Get file comment
    [tmp___, Comment] = bst_fileparts(ErpFiles{iFile});
    
    % === DETECT BAD CHANNELS ===
    % Detect the rows that are full of zeros
    % iBadChannels = find(sum(double(read_data < 1e-10), 2) == size(read_data,2));
    iBadChannels = find(all(abs(read_data) < 1e-10, 2));
    % Build good/bad channels vector
    ChannelFlag = ones(nbChannels, 1);
    ChannelFlag(iBadChannels) = -1;
    % Display bad channels list in message window
    if ~isempty(iBadChannels)
        strBadChan = ['BST> Bad channels for "' Comment '": ' sprintf('%d ', iBadChannels)];
        disp(strBadChan);
    end
    
    % === SCALING DATA ===
    % WARNING : ERP Center data is in microV, while Brainstorm considers data in V.
    read_data = read_data .* 1e-6;
    
    % === SAVE FILE ===
    % Build DataMat structure
    nbData = length(DataMat) + 1;
    DataMat(nbData).F           = double(read_data);    % DATA STORED IN microV  % FT 11-Jan-10: Remove "single"
    DataMat(nbData).ChannelFlag = ChannelFlag;
    DataMat(nbData).Time        = TimeVector;
    DataMat(nbData).Comment     = Comment;
    DataMat(nbData).DataType    = 'recordings';
    DataMat(nbData).Device      = 'Unknown';
    DataMat(nbData).nAvg        = 1;
    % Build file name
    [DataMat(nbData).SubjectName, DataMat(nbData).Condition] = ParseErpFilename(ErpFiles{iFile});
end

end


%% ===== HELPERS ====================================================
% Parse filename to detect subject/condition/run
function [SubjectName, ConditionName] = ParseErpFilename(filename)
    SubjectName   = '';
    ConditionName = '';
    % Get only short filename without extension
    [fPath, fName, fExt] = bst_fileparts(filename);
    
    % ERP CENTER filename format : 
    %     "cell<i>_<conditionName>_obs<j>": subject #j, condition #i, conditionName
    iTag_cell = strfind(fName, 'cell');
    iTag_obs  = strfind(fName, '_obs');
    if ~isempty(iTag_cell) && ~isempty(iTag_obs)
        iCell = sscanf(fName(iTag_cell(1):end), 'cell%d');
        iObs  = sscanf(fName(iTag_obs(1):end),  '_obs%d');
        if ~isempty(iCell) && ~isempty(iObs)
            iUnderscore = strfind(fName(iTag_cell(1):end), '_');
            ConditionName = fName(iUnderscore(1)+iTag_cell(1):iTag_obs(1)-1);
            SubjectName = sprintf('%03d', iObs);
        end
    end
end






