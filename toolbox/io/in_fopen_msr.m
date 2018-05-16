function [sFile, ChannelMat] = in_fopen_msr(DataFile)
% IN_FOPEN_MSR: Open a ANT ASA .msr/.msm file

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
% Authors:  Cristian Donos, 2015
%           Francois Tadel, 2017, adaptation for Brainstorm


%% ===== GET FILES =====
% MSR File (header)
MsrFile = [DataFile(1:end-4) '.msr'];
if ~exist(MsrFile, 'file')
    error('Could not find MSR header file.');
end
% MSM File (data)
MsmFile = [DataFile(1:end-4) '.msm'];
if ~exist(MsmFile, 'file')
    error('Could not find MSM data file.');
end


%% ===== READ HEADER =====
% Open file
fid = fopen(MsrFile, 'r');
if (fid == -1)
    error('Could not MSR open file.');
end
% Reading header info
str = fgetl(fid);
header.record_length = str2num(str(strfind(str,'=')+1:end));

str = fgetl(fid);
header.numchannels = str2num(str(strfind(str,'=')+1:end));

str = fgetl(fid);
header.unitmeas =  strtrim(str(max(find(isspace(str))):end));

str = fgetl(fid);
header.unittime = strtrim(str(max(find(isspace(str))):end));

str = fgetl(fid);
str = str(max(find(isspace(str))):end);
if strcmp(header.unittime,'ms')
     header.samplingrate = 1000 / str2num(str(strfind(str,'(')+1:end-1)) - str2num(str(1:strfind(str,'(')-1));
else
     disp(' MSM file import not available for other units than "ms"');
     return
end

% Contact labels
fgetl(fid); % Labels lines start with the next fgetl
header.channels = [];
ix = 1;
str = fgetl(fid);
[tok remaining] = strtok(str);
header.channels{ix} = tok;
ix = ix+1;
while ~isempty(remaining)
    [tok remaining] = strtok(remaining);
    header.channels{ix} = tok;
    ix = ix+1;      
end
header.channels(end) = []; % delete last cell as it has been created by the last ix = ix+1

% Close file
fclose(fid);    


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = 'l';
sFile.filename     = MsmFile;
sFile.format       = 'EEG-ANT-MSR';
sFile.prop.sfreq   = double(header.samplingrate);
sFile.prop.samples = [0, header.record_length - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(header.numchannels,1);
sFile.device       = 'ASA';
sFile.header       = header;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, header.numchannels]);
% For each channel
for iChan = 1:header.numchannels
    ChannelMat.Channel(iChan).Type = 'EEG';
    ChannelMat.Channel(iChan).Name = header.channels{iChan};
end



