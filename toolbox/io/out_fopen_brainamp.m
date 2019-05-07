function sFileOut = out_fopen_brainamp(OutputFile, sFileIn, ChannelMat)
% OUT_FOPEN_BRAINAMP: Saves the header of a new empty BrainVision file (.vhdr/.vmrk)

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
% Authors: Francois Tadel, 2018


%% ===== PARSE INPUTS =====
% Reject files with epochs
if (length(sFileIn.epochs) > 1)
    error('Cannot export epoched files to continuous BrainVision .eeg file.');
end

%% ===== CREATE HEADER =====
% Get file comment
[fPath, fBase, fExt] = bst_fileparts(OutputFile);
% VHDR and VMRK header files
VhdrFile = bst_fullfile(fPath, [fBase, '.vhdr']);
if ~isempty(sFileIn.events)
    VmrkFile = bst_fullfile(fPath, [fBase, '.vmrk']);
else
    VmrkFile = [];
end

% Initialize output file
sFileOut = sFileIn;
sFileOut.filename  = OutputFile;
sFileOut.condition = '';
sFileOut.format    = 'EEG-BRAINAMP';
sFileOut.byteorder = 'l';
sFileOut.comment   = fBase;

% Get channel positions
nChannels = length(ChannelMat.Channel);
allLoc = cellfun(@(c)mean(c,2), {ChannelMat.Channel.Loc}, 'UniformOutput', 0);

% Create a new header structure
header = struct();
header.chnames          = {ChannelMat.Channel.Name};
header.chgain           = 1e-6 * ones(1, nChannels);   % Save values in microVolts
header.chloc            = cat(2, allLoc{:})';
header.Codepage         = 'UTF-8';
header.DataFile         = [fBase, fExt];
header.MarkerFile       = [fBase, '.vmrk'];
header.DataFormat       = 'BINARY';
header.DataOrientation  = 'MULTIPLEXED';
header.NumberOfChannels = nChannels;
header.SamplingInterval = 1e6 ./ sFileOut.prop.sfreq;
header.BinaryFormat     = 'IEEE_FLOAT_32';
header.bytesize         = 4;
header.byteformat       = 'float32';
header.nsamples         = round((sFileOut.prop.times(2) - sFileOut.prop.times(1)) .* sFileOut.prop.sfreq) + 1;
sFileOut.header = header;

% ===== WRITE VHDR =====
% Open file
fid = fopen(VhdrFile, 'w');
if (fid == -1)
    error(['Could not open header file: ' VhdrFile]);
end
% Print header
fprintf(fid, [...
    'Brain Vision Data Exchange Header File Version 1.0', 10, ...
    '; Data created by Brainstorm', 10, ...
    '', 10, ...
    '[Common Infos]', 10, ...
    'Codepage=', header.Codepage, 10, ...
    'DataFile=', header.DataFile, 10, ...
    'MarkerFile=', header.MarkerFile, 10, ...
    'DataFormat=', header.DataFormat, 10, ...
    '; Data orientation: MULTIPLEXED=ch1,pt1, ch2,pt1 ...', 10, ...
    'DataOrientation=', header.DataOrientation, 10, ...
    'NumberOfChannels=', num2str(header.NumberOfChannels), 10, ...
    '; Sampling interval in microseconds', 10, ...
    'SamplingInterval=', num2str(header.SamplingInterval), 10, ...
    '', 10, ...
    '[Binary Infos]', 10, ...
    'BinaryFormat=', num2str(header.BinaryFormat), 10, ...
    '', 10, ...
    '[Channel Infos]', 10, ...
    '; Each entry: Ch<Channel number>=<Name>,<Reference channel name>,', 10, ...
    '; <Resolution in "Unit">,<Unit>, Future extensions..', 10, ...
    '; Fields are delimited by commas, some fields might be omitted (empty).', 10, ...
    '; Commas in channel names are coded as "\\1".', 10]);
% Replace comas with \1 in channel names
chNames = strrep({ChannelMat.Channel.Name}, ',', char(1));
% Print channel names
for i = 1:nChannels
    fprintf(fid, 'Ch%d=%s,,1,µV\n', i, chNames{i});
end
% If there are 
if any(~cellfun(@isempty, allLoc)) && any(~cellfun(@(c)isequal(c,[0;0;0]), allLoc))
    % Print positions header
    fprintf(fid, [...
        '', 10, ...
        '[Coordinates]', 10, ...
        '; Each entry: Ch<Channel number>=<Name>,<Radius in mm>,<Theta in degrees>,<Phi in degrees>', 10, ...
        '; Commas in channel names are coded as "\\1".', 10]);
    % Print positions for each channel
    for i = 1:nChannels
        if ~isempty(allLoc{i}) && ~isequal(allLoc{i}, [0;0;0])
            % Convert Cartesian (m) => Spherical(radians) => Spherical(degrees)
            [PHI, TH, R] = cart2sph(-allLoc{i}(1), -allLoc{i}(2), allLoc{i}(3));
            R = R .* 1000;
            TH = 90 - TH * 180 / pi;
            PHI = PHI * 180 / pi - 90;
            % Print location
            fprintf(fid, 'Ch%d=%f,%f,%f\n', i, R, TH, PHI);
        end
    end
end
% Close file
fclose(fid);


% ===== WRITE VMRK =====
if ~isempty(VmrkFile) 
    out_events_brainamp(sFileOut, VmrkFile);
end



