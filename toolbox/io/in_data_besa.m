function [DataMat, ChannelMat] = in_data_besa(DataFile)
% IN_DATA_BESA: Read BESA EEG files.
%
% USAGE:  OutputData = in_data_besa( DataFile )
%
% INPUT:
%     - DataFile : Full path to a recordings file.
% OUTPUT: 
%     - DataMat : Brainstorm data (recordings) structure

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2015

% Get format
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.Comment  = fBase;
DataMat.Device   = 'BESA';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;
ChanNames = {};

% Open file
fid = fopen(DataFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end

% Switch according to file format
switch lower(fExt)
    case {'.avr', '.mul'}
        % Read header (first line)
        hdr = fgetl(fid);
        % Split to get all the parameters
        hdr = str_split(hdr, ' =');
        % Multiplexed/averaged files
        if strcmpi(fExt, '.mul')
            nTime     = str2num(hdr{2});
            nChannels = str2num(hdr{4});
            timeStart = str2num(hdr{6}) / 1000;  % Convert to seconds
            timeStep  = str2num(hdr{8}) / 1000;  % Convert to seconds
        else
            nTime     = str2num(hdr{2});
            timeStart = str2num(hdr{4}) / 1000;  % Convert to seconds
            timeStep  = str2num(hdr{6}) / 1000;  % Convert to seconds
            nChannels = 0;
        end
        % Read second line: Either the channel names or the first sensor
        hdr = fgetl(fid);
        % If there are alphabetical characters in the line: sensor names
        if any(ismember(double(hdr), double('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz()[]/\_@')))
            % Replace spaces in channel names with _ (eg. "TP 1" to "TP_1")
            for iDig = 0:9
                hdr = strrep(hdr, sprintf(' %d', iDig), sprintf('_%d', iDig));
            end
            % Try to get the channel names
            ChanNames = str_split(hdr, ' ');
        % Else: It was the first sensor
        else
            % Restart reading the file at the beginning
            fseek(fid, 0, 'bof');
            hdr = fgetl(fid);
        end
        % Read the recordings in multiplexed/averaged mode
        if strcmpi(fExt, '.mul')
            DataMat.F = fscanf(fid, '%f', [nChannels, nTime]);
        else
            DataMat.F = fscanf(fid, '%f', [nTime, Inf])';
        end
        
    case {'.mux'}
        % Skip three lines
        hdr = fgetl(fid);
        hdr = fgetl(fid);
        hdr = fgetl(fid);
        % Read the recordings, line by line
        allLines = {};
        while 1
            newLine = fgetl(fid);
            if ~ischar(newLine)
                break;
            end
            allLines{end+1} = str2num(newLine);
        end
        % Concatenate everything
        DataMat.F = cat(1, allLines{:})';
        
        % Ask for time window
        res = java_dialog('input', {'Start time (in miliseconds):', 'Sampling frequency'}, ...
                                    'Time definition (in Hz)', [], {'0','1000'});
        if isempty(res) || (length(str2num(res{1})) ~= 1) || (length(str2num(res{2})) ~= 1)
            DataMat = [];
        else
            timeStart = str2num(res{1}) / 1000;
            timeStep  = 1 / str2num(res{2});
        end
    otherwise
        error(['Unsupported file extension: ' fExt]);
end
% Close file
fclose(fid);

% Rebuild time vector
DataMat.Time = timeStart + (0:size(DataMat.F,2)-1) .* timeStep;
% No bad channels defined in those files: all good
nChannels = size(DataMat.F,1);
DataMat.ChannelFlag = ones(nChannels, 1);

% Try to build a channel file
if ~isempty(ChanNames) && (length(ChanNames) == nChannels)
    % Default channel structure
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'BESA channels';
    ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
    % For each channel
    for i = 1:nChannels
        if ~isempty(ChanNames{i})
            ChannelMat.Channel(i).Name = ChanNames{i};
        elseif (length(ChannelMat.Channel) > 99)
            ChannelMat.Channel(i).Name = sprintf('E%03d', i);
        else
            ChannelMat.Channel(i).Name = sprintf('E%02d', i);
        end
        ChannelMat.Channel(i).Type    = 'EEG';
        ChannelMat.Channel(i).Loc     = [0; 0; 0];
        ChannelMat.Channel(i).Orient  = [];
        ChannelMat.Channel(i).Weight  = 1;
        ChannelMat.Channel(i).Comment = [];
    end
else
    ChannelMat = [];
end





