function DataMat = in_data_neuroscan_dat(DataFile)
% IN_DATA_NEUROSCAN_DAT: Read Neuroscan .dat EEG files (ASCII export).
%
% USAGE:  DataMat = in_data_neuroscan_dat( DataFile )
%
% INPUT:
%     - DataFile : Full path to a recordings file.
% OUTPUT: 
%     - DataMat : Brainstorm data (recordings) structure

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009

%% ===== INITIALIZATION =====
% Get short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.Comment  = fBase;
DataMat.DataType = 'recordings';
DataMat.Device   = 'Neuroscan';           

%% ===== READ FILE =====
% Open file
fid = fopen(DataFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iTime = 1;
blockName = '';
nChannels = 0;
smpRate = 1000;
nTime = 0;

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line: go to next line
    if isempty(read_line)
        continue
    end
    % End of file: stop reading
    if (read_line(1) == -1)
        break
    end
    
    % Start of block
    if (read_line(1) == '[')
        % Get name of block
        iEndBlock = strfind(read_line, ']');
        if ~isempty(iEndBlock)
            blockName = deblank(strtrim(read_line(2:iEndBlock-1)));
        else
            blockName = '';
        end
        % Read block parameter
        if (length(read_line) > iEndBlock + 1)
            blockParam = str2double(read_line(iEndBlock+1:end));
            if isempty(blockParam) || isnan(blockParam)
                blockParam = 0;
            end
        else
            blockParam = 0;
        end
    
        % Interpret block
        switch lower(blockName)
            case 'channels'
                nChannels = blockParam;
            case 'rate'
                smpRate = blockParam;
            case 'points'
                nTime = blockParam;
            case 'continuous data'
                % Initialize data matrix
                if (nChannels ~= 0) && (nTime ~= 0)
                    DataMat.F = zeros(nChannels, nTime);
                end
        end
    % Else: read data
    else
        if strcmpi(blockName, 'continuous data')
            % Interpret line as a list of values
            val = str2num(read_line);
            if ~isempty(val) 
                if (nChannels == 0)
                    nChannels = length(val);
                elseif (nChannels ~= length(val))
                    error('Inconsistent file.');
                end
                DataMat.F(:,iTime) = val';
                iTime = iTime + 1;
            end
        end
    end
end

% Check if something was read
if isempty(DataMat.F)
    DataMat = [];
    warning('This file is not a valid Neuroscan .DAT recordings file.');
    return;
end
% Convert values to Volts
DataMat.F = DataMat.F .* 1e-6;
% Build time vector
DataMat.Time = (0:size(DataMat.F,2)-1) / smpRate;
% Build bad channels list
DataMat.ChannelFlag = ones(size(DataMat.F,1), 1);
% Number of trials
DataMat.nAvg = 1;
             







