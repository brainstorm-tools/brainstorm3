function [sFile, ChannelMat] = in_fopen_gtec(DataFile)
% IN_FOPEN_GTEC: Open a g.tec/g.Recorder .mat/.hdf5 file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_gtec(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

% Get format
[fPath,fBase,fExt] = bst_fileparts(DataFile);
% MATLAB .mat
if strcmpi(fExt, '.mat')
    warning('off', 'MATLAB:unknownObjectNowStruct');
    FileMat = load(DataFile, '-mat');
    warning('on', 'MATLAB:unknownObjectNowStruct');
    % Check file contents
    if isempty(FileMat) || ~isfield(FileMat, 'P_C_S') || isempty(FileMat.P_C_S)
        error('Invalid g.tec Matlab export: Missing field "P_C_S".');
    end
% HDF5
elseif strcmpi(fExt, '.hdf5')
    error('Not supported yet');
%     h5disp(DataFile) 
%     info = hdf5info(DataFile)
%     ChannelXml=hdf5read(DataFile,'RawData/AcquisitionTaskDescription');
%     Data=hdf5read(DataFile,'RawData/Samples');
else
    error('Invalid g.tec file.');
end


% ===== FILL STRUCTURE =====
% Initialize returned file structure                    
sFile = db_template('sfile');                     
% Add information read from header
sFile.filename   = DataFile;
sFile.fid        = [];  
sFile.format     = 'EEG-GTEC';
sFile.device     = FileMat.P_C_S.amplifiername;
sFile.byteorder  = 'l';
% Properties of the recordings
sFile.prop.samples = [0, size(FileMat.P_C_S.data,2)-1] - FileMat.P_C_S.pretrigger;
sFile.prop.sfreq   = double(FileMat.P_C_S.samplingfrequency);
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(FileMat.P_C_S.numberchannels,1); % GOOD=1; BAD=-1;
% Epochs, if any
if (size(FileMat.P_C_S.data,1) > 1)
    for i = 1:size(FileMat.P_C_S.data,1)
        sFile.epochs(i).label   = sprintf('Trial #%d', i);
        sFile.epochs(i).samples = sFile.prop.samples;
        sFile.epochs(i).times   = sFile.prop.times;
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
end

% ===== EVENTS =====
for iEvt = 1:length(FileMat.P_C_S.markername)
    % Get all the occurrences
    iOcc = find(FileMat.P_C_S.marker(:,3) == iEvt);
    % Create event structure
    sFile.events(iEvt).label   = FileMat.P_C_S.markername{iEvt};
    sFile.events(iEvt).samples = FileMat.P_C_S.marker(iOcc,1)';
    sFile.events(iEvt).epochs  = FileMat.P_C_S.marker(iOcc,2)';
    if ~isempty(sFile.epochs)
        for i = 1:length(sFile.events(iEvt).samples)
            iEpoch =  sFile.events(iEvt).epochs(i);
            sFile.events(iEvt).samples(i) = sFile.events(iEvt).samples(i) + sFile.epochs(iEpoch).samples(1) - 1;
        end
    end
    sFile.events(iEvt).times   = sFile.events(iEvt).samples ./ sFile.prop.sfreq;
    sFile.events(iEvt).select  = 1;
end






%% ===== CHANNEL FILE =====
% Initialize structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'g.tec channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, FileMat.P_C_S.numberchannels);
% Channels information
for iChan = 1:FileMat.P_C_S.numberchannels
    ChannelMat.Channel(iChan).Name    = FileMat.P_C_S.channelname{iChan};
    ChannelMat.Channel(iChan).Type    = 'EEG';
    ChannelMat.Channel(iChan).Loc     = [0; 0; 0];
    ChannelMat.Channel(iChan).Orient  = [];
    ChannelMat.Channel(iChan).Weight  = 1;
    ChannelMat.Channel(iChan).Comment = [];  
end









