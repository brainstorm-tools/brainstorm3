function [sFile, ChannelMat] = in_fopen_brainamp(DataFile)
% IN_FOPEN_BRAINAMP: Open a BrainVision BrainAmp .eeg/.dat file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_brainamp(DataFile)

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
% Authors: Guillaume Dumas, Francois Tadel, 2012-2014
        
%% ===== GET FILES =====
% Build header and markers files names
% VHDR/AHDR File (header)
VhdrFile = [DataFile(1:end-4) '.vhdr'];
if ~file_exist(VhdrFile)
    VhdrFile = [DataFile(1:end-4) '.ahdr'];
    if ~file_exist(VhdrFile)
        error('Could not open VHDR header file.');
    else
        error(['File is saved in BrainVision V-Amp encrypted format.' 10 ...
               'Please, export it to "binary data format" before trying to read it in Brainstorm.']);
    end
end
% VMRK/AMRK File (markers)
VmrkFile = [DataFile(1:end-4) '.vmrk'];
if ~file_exist(VmrkFile)
    VmrkFile = [DataFile(1:end-4) '.amrk'];
    if ~file_exist(VmrkFile)
        disp('BRAINAMP> Warning: Could not open VMRK markers file.');
        VmrkFile = [];
    end
end


%% ===== READ HEADER =====
hdr.chnames = {};
hdr.chgain = [];
hdr.chloc = [];
% Open and read file
fid = fopen(VhdrFile,'r');
curBlock = '';
% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Empty lines and comment lines: skip
    if isempty(newLine) || ismember(newLine(1), {';', char(10), char(13)})
        continue;
    end
    % Read block names
    if (newLine(1) == '[')
        curBlock = newLine;
        curBlock(ismember(curBlock, '[] ')) = [];
        continue;
    end
    % Skip non-attribution lines
    if ~any(newLine == '=')
        continue;
    end
    % Split around the '='
    argLine = strtrim(str_split(newLine, '='));
    if (length(argLine) ~= 2) || (length(argLine{1}) < 2) || isempty(argLine{2}) || ~isequal(argLine{1}, file_standardize(argLine{1}))
        continue;
    end
    % Parameter
    if (length(argLine{1}) > 2) && strcmpi(argLine{1}(1:2), 'Ch')
        iChan = str2num(argLine{1}(3:end));
        if ~isempty(iChan)
            if strcmpi(curBlock, 'ChannelInfos')
                % Split channel description line
                chInfo = str_split(argLine{2}, ',', 0);
                % Get channel name
                if (length(chInfo) >= 1) && ~isempty(chInfo{1})
                    hdr.chnames{iChan} = strtrim(chInfo{1});
                end
                % Get gain and units
                if (length(chInfo) >= 3) && ~isempty(chInfo{3}) && ~isempty(str2num(chInfo{3}))
                    chFactor = str2num(chInfo{3});
                else
                    chFactor = 1;
                end
                if (length(chInfo) >= 4) && ~isempty(chInfo{4})
                    switch (strtrim(chInfo{4}))
                        case 'V',            chUnit = 1;
                        case 'mV',           chUnit = 1e-3;
                        case {'µV', 'ÂµV'},  chUnit = 1e-6;
                        otherwise,           chUnit = 1e-6;
                    end
                else
                    chUnit = 1e-6;
                end
                hdr.chgain(iChan) = chFactor * chUnit;
                
            elseif strcmpi(curBlock, 'Coordinates')
                tmpLoc = str2num(argLine{2});
                % Spherical (R,TH,PHI)
                if (length(tmpLoc) == 3) && (tmpLoc(1) == 1)
                    % Convert Spherical(degrees) => Spherical(radians) => Cartesian
                    TH  = (90 - tmpLoc(2)) ./ 180 * pi;
                    PHI = (90 + tmpLoc(3)) ./ 180 * pi;
                    [X,Y,Z] = sph2cart(PHI, TH, 1);
                    % Assign location
                    hdr.chloc(iChan,1:3) = [-X, -Y, Z+.5] .* .0875;
                % Realistic (R,TH,PHI)
                elseif (length(tmpLoc) == 3)
                    % Convert Spherical(degrees) => Spherical(radians) => Cartesian
                    R = tmpLoc(1) ./ 1000;
                    TH  = (90 - tmpLoc(2)) ./ 180 * pi;
                    PHI = (90 + tmpLoc(3)) ./ 180 * pi;
                    [X,Y,Z] = sph2cart(PHI, TH, R);
                    % Assign location
                    hdr.chloc(iChan,1:3) = [-X, -Y, Z];
                else
                    hdr.chloc(iChan,1:3) = [0 0 0];
                end
            end
        end
    elseif strcmpi(argLine{1}, 'NumberOfChannels')
        hdr.NumberOfChannels = str2num(argLine{2});
        % Initialize gains when we have the number of channels
        if isempty(hdr.chloc)
            hdr.chgain = 1e-6 .* ones(1, hdr.(argLine{1}));
        end
    elseif strcmpi(argLine{1}, 'SamplingInterval')
        hdr.SamplingInterval = str2num(argLine{2});
    elseif strcmpi(argLine{1}, 'DataPoints')
        hdr.DataPoints = str2num(argLine{2});
    elseif strcmpi(argLine{1}, 'SegmentDataPoints')
        hdr.SegmentDataPoints = str2num(argLine{2});
    else
        hdr.(file_standardize(argLine{1})) = argLine{2};
    end
end
% Close file
fclose(fid);


%% ===== REBUILD ACQ INFO =====
% BINARY files
if strcmpi(hdr.DataFormat, 'BINARY')
    % EEG file: get size
    dirInfo = dir(DataFile);
    % Get number of samples
    switch lower(hdr.BinaryFormat)
        case 'int_16'
            hdr.bytesize   = 2;
            hdr.byteformat = 'int16';
        case 'int_32'
            hdr.bytesize   = 4;
            hdr.byteformat = 'int32';
        case 'ieee_float_32'
            hdr.bytesize   = 4;
            hdr.byteformat = 'float32';
    end
    hdr.nsamples = dirInfo.bytes ./ (hdr.NumberOfChannels * hdr.bytesize);
% ASCII and VECTORIZED files
elseif (strcmpi(hdr.DataFormat, 'ASCII') && strcmpi(hdr.DataOrientation, 'VECTORIZED'))
    hdr.nsamples = hdr.DataPoints;
else
    error(['Only reading binary or vectorized ASCII data format.' 10 'Please contact us if you would like to read other types of files in Brainstorm.']);
end



%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-BRAINAMP';
sFile.device     = 'BRAINAMP';
sFile.header     = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = 1e6 ./ hdr.SamplingInterval;
sFile.prop.times   = [0, hdr.nsamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.NumberOfChannels, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'BrainAmp channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.NumberOfChannels]);
% For each channel
for i = 1:hdr.NumberOfChannels
    if ~isempty(hdr.chnames{i})
        ChannelMat.Channel(i).Name = hdr.chnames{i};
    else
        ChannelMat.Channel(i).Name = sprintf('E%d', i);
    end
    if ~isempty(hdr.chloc) && (i <= size(hdr.chloc,1))
        ChannelMat.Channel(i).Loc = hdr.chloc(i,:)';
    else
        ChannelMat.Channel(i).Loc = [0; 0; 0];
    end
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end
     

%% ===== READ EVENTS =====
if ~isempty(VmrkFile)
    sFile = import_events(sFile, [], VmrkFile, 'BRAINAMP');
end





