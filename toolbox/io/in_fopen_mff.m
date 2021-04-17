function [sFile, ChannelMat] = in_fopen_mff(DataFile, ImportOptions, channelsOnly)
% IN_FOPEN_MFF: Open a Philips .MFF file

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
% Authors: Martin Cousineau, Francois Tadel, 2018-2021


%% ===== INSTALL/LOAD MFF LIBRARY =====
[isInstalled, errMsg] = bst_plugin('Install', 'mff', ImportOptions.DisplayMessages);
if ~isInstalled
    error(errMsg);
end

%% ===== EXTRACT MFF DIRECTORY =====
[parentFolder, file, ext] = bst_fileparts(DataFile);
if ismember(lower(ext), {'.bin', '.xml'})
    DataFile = parentFolder;
end

%% ===== READ MFF FILE WITH EEGLAB PLUGIN =====
hdr = struct();
hdr.filename = DataFile;
if channelsOnly
    hdr.EEG = LoadChanlocsOnly(DataFile);
else
    hdr.EEG = mff_import(DataFile);
end

%% ===== IMPORT FILE USING EEGLAB IMPORTER =====
% Convert electrodes positions from cm to mm, to avoid the interactive question about the spatial scaling
if isfield(hdr.EEG, 'chanlocs') && ~isempty(hdr.EEG.chanlocs) && isfield(hdr.EEG.chanlocs(1), 'X')
    for iChan = 1:length(hdr.EEG.chanlocs)
        hdr.EEG.chanlocs(iChan).X = hdr.EEG.chanlocs(iChan).X * 10;
        hdr.EEG.chanlocs(iChan).Y = hdr.EEG.chanlocs(iChan).Y * 10;
        hdr.EEG.chanlocs(iChan).Z = hdr.EEG.chanlocs(iChan).Z * 10;
    end
end
% Convert EEGLAB structure in Brainstorm structures
if channelsOnly
    sFile = [];
    if isempty(hdr.EEG)
        ChannelMat = [];
    else
        ChannelMat = in_channel_eeglab_set(hdr);
    end
else
    [sFile, ChannelMat] = in_fopen_eeglab(hdr, ImportOptions);
    sFile.format       = 'EEG-EGI-MFF';
    sFile.device       = 'MFF';
end

if ~isempty(ChannelMat)
    ChannelMat.Comment = 'MFF channels';
end

% Rectify sensors positions: mff_import saves the orientation with nose a +Y, brainstorm needs the nose as +X axis
if ~isempty(ChannelMat) && ~isempty(ChannelMat.Channel)
    % Define transformation: Rotation(-90deg/Z)  +  Translation(+40mm/Z)
    angleZ = -pi/2;
    Transf90Z = [cos(angleZ), -sin(angleZ), 0, 0; ...
                 sin(angleZ),  cos(angleZ), 0, 0; ...
                           0,            0, 1, 0.040; ...
                           0,            0, 0, 1];
    % Apply transformation
    ChannelMatFix = channel_apply_transf({ChannelMat}, Transf90Z);
    if ~isempty(ChannelMatFix)
        ChannelMat = ChannelMatFix{1};
    end
end

end

%% ===== LOAD CHANNEL LOC =====
function EEG = LoadChanlocsOnly(mffFile)
    % If we're only importing the channel file, create a EEG structure
    % ourselves, just like calling mff_import() without loading the data.
    EEG = struct();
    EEG.data = [];
    EEG.chaninfo = struct();
    EEG.chaninfo.nosedir = '+Y';
    try
        [EEG.chanlocs, EEG.ref] = mff_importcoordinates(mffFile);
    catch
        EEG = [];
        return;
    end
    try
        EEG = eeg_checkchanlocs(EEG);
    catch
    end
    EEG.nbchan = length(EEG.chanlocs);
end


