function [Output, ChannelFile, FileFormat] = import_channel(iStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign)
% IMPORT_CHANNEL: Imports a channel file (definition of the sensors).
% 
% USAGE:  BstChannelFile = import_channel(iStudies=none, ChannelFile='ask', FileFormat)
%
% INPUT:
%    - iStudies    : Indices of the studies where to import the ChannelFile
%    - ChannelFile : Full filename of the channels list to import (default: asked to the user)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2014

%% ===== PARSE INPUTS =====
Output = [];
if (nargin < 5) || isempty(ChannelAlign)
    ChannelAlign = [];
end
if (nargin < 4) || isempty(ChannelReplace)
    ChannelReplace = 1;
end
if (nargin < 3) || isempty(ChannelFile) || isempty(FileFormat)
    ChannelFile = [];
end
if (nargin < 1) || isempty(iStudies)
    iStudies = [];
end

%% ===== SELECT CHANNEL FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(ChannelFile)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get MRI file
    [ChannelFile, FileFormat] = java_getfile('open', ...
            'Import Channels...', ...              % Window title
            LastUsedDirs.ImportChannel, ...        % Last used directory
            'single', 'files_and_dirs', ...        % Selection mode
            bst_get('FileFilters', 'channel'), ... % File filters
            DefaultFormats.ChannelIn);             % Default ASCII XYZ
    % If no file was selected: exit
    if isempty(ChannelFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportChannel = bst_fileparts(ChannelFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.ChannelIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


%% ===== LOAD CHANNEL FILE =====
ChannelMat = [];
FileUnits = 1;
% Progress bar
isProgressBar = bst_progress('isVisible');
if ~isProgressBar
    bst_progress('start', 'Import channel file', ['Loading file "' ChannelFile '"...']);
end
% Get the file extenstion
[fPath, fBase, fExt] = bst_fileparts(ChannelFile);
if ~isempty(fExt)
    fExt = lower(fExt(2:end));
end
% Import options
ImportOptions = db_template('ImportOptions');
ImportOptions.EventsMode = 'ignore';
ImportOptions.DisplayMessages = 0;
% Load file
switch FileFormat
    % ===== MEG/EEG =====
    case 'CTF'
        ChannelMat = in_channel_ctf(ChannelFile);
        FileUnits = 'm';
    case {'FIF', '4D', 'KIT', 'BST-BIN', 'KDF'}
        [sFile, ChannelMat] = in_fopen(ChannelFile, FileFormat, ImportOptions);
        if isempty(ChannelMat)
            return;
        end
        FileUnits = 'm';
    case 'BST'
        ChannelMat = in_bst_channel(ChannelFile);
        FileUnits = 'm';
        
    % ===== EEG ONLY =====
    case 'BESA' % (*.sfp;*.elp;*.eps/*.ela)
        switch (fExt)
            case 'sfp'
                ChannelMat = in_channel_ascii(ChannelFile, {'Name','-Y','X','Z'}, 0, .01);
                ChannelMat.Comment = 'BESA channels';
            case 'elp'
                ChannelMat = in_channel_ascii(ChannelFile, {'Name','Y','X','Z'}, 0, .01);
                ChannelMat.Comment = 'BESA channels';
            case {'eps','ela'}
                ChannelMat = in_channel_besa_eps(ChannelFile);
        end
        FileUnits = 'cm';
        
    case 'BRAINVISION'
        ChannelMat = in_channel_brainvision(ChannelFile);
        FileUnits = 'm';
        
    case 'CARTOOL' % (*.els;*.xyz)
        switch (fExt)
            case 'els'
                ChannelMat = in_channel_cartool_els(ChannelFile);
                FileUnits = 'mm';
            case 'xyz'
                ChannelMat = in_channel_ascii(ChannelFile, {'-Y','X','Z','Name'}, 1, .001);
                ChannelMat.Comment = 'Cartool channels';
                FileUnits = 'cm';
        end

    case 'MEGDRAW'
        ChannelMat = in_channel_megdraw(ChannelFile);
        FileUnits = 'cm';
        
    case 'CURRY' % (*.res;*.rs3)
        switch (fExt)
            case 'res'
                ChannelMat = in_channel_ascii(ChannelFile, {'%d','-Y','X','Z','%d','Name'}, 0, .001);
                ChannelMat.Comment = 'Curry channels';
            case 'rs3'
                ChannelMat = in_channel_curry_rs3(ChannelFile);
        end
        FileUnits = 'mm';
        
    case 'XENSOR' % ANT Xensor (*.elc)
        ChannelMat = in_channel_ant_xensor(ChannelFile);
        FileUnits = 'mm';

    case 'EEGLAB' % (*.ced;*.xyz)
        switch (fExt)
            case 'ced'
                ChannelMat = in_channel_ascii(ChannelFile, {'indice','Name','%f','%f','X','Y','Z','%f','%f','%f'}, 1, .0875); % Convert normalized coord => average head radius
                ChannelMat.Comment = 'EEGLAB channels';
            case 'xyz'
                ChannelMat = in_channel_ascii(ChannelFile, {'indice','-Y','X','Z','Name'}, 0, .01);
                ChannelMat.Comment = 'EEGLAB channels';
            case 'set'
                ChannelMat = in_channel_eeglab_set(ChannelFile);
        end
        FileUnits = 'cm';
        
    case 'EETRAK' % (*.elc)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z'}, 3, .001);
        ChannelMat.Comment = 'EETRAK channels';
        FileUnits = 'mm';
        
    case 'EGI'  % (*.sfp)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','-Y','X','Z'}, 0, .01);
        ChannelMat.Comment = 'EGI channels';
        FileUnits = 'cm';
        
    case 'EMSE'  % (*.elp)
        ChannelMat = in_channel_emse_elp(ChannelFile);
        FileUnits = 'm';
        
    case 'NEUROSCAN'  % (*.dat;*.tri;*.txt;*.asc)
        switch (fExt)
            case {'dat', 'txt'}
                ChannelMat = in_channel_neuroscan_dat(ChannelFile);
                FileUnits = 'cm';
            case 'tri'
                ChannelMat = in_channel_neuroscan_tri(ChannelFile);
                FileUnits = 'cm';
            case 'asc'
                ChannelMat = in_channel_neuroscan_asc(ChannelFile);
                FileUnits = 'mm';
        end
        
    case 'POLHEMUS'  % (*.pos;*.elp)
        switch (fExt)
            case 'pos'
                ChannelMat = in_channel_pos(ChannelFile);
                FileUnits = 'cm';
            case {'pol','txt'}
                ChannelMat = in_channel_ascii(ChannelFile, {'name','X','Y','Z'}, 1, .01);
                ChannelMat.Comment = 'Polhemus';
                FileUnits = 'cm';
            case 'elp'
                ChannelMat = in_channel_emse_elp(ChannelFile);
                FileUnits = 'mm';
        end

    case 'ASCII_XYZ'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z'}, 0, .01);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = 'cm';
    case 'ASCII_NXYZ'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','X','Y','Z'}, 0, .01);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = 'cm';
    case 'ASCII_XYZN'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z','Name'}, 0, .01);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = 'cm';
    case 'ASCII_NXY'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','X','Y'}, 0, .000875);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = 'mm';
    case 'ASCII_XY'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y'}, 0, .000875);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = '';
    case 'ASCII_NTP'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','TH','PHI'}, 0, .0875);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = '';
    case 'ASCII_TP'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'TH','PHI'}, 0, .0875);
        ChannelMat.Comment = 'ASCII channels';
        FileUnits = '';
end
% No data imported
isHeadPoints = isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints.Loc);
if isempty(ChannelMat) || ((~isfield(ChannelMat, 'Channel') || isempty(ChannelMat.Channel)) && ~isHeadPoints)
    disp('BST> Warning: No channel information was read from the file.');
    bst_progress('stop');
    return
end


%% ===== CHECK DISTANCE UNITS =====
iEEG = good_channel(ChannelMat.Channel, [], {'EEG','SEEG','ECOG','Fiducial'});
iMEG = good_channel(ChannelMat.Channel, [], 'MEG');
if (length(iEEG) > 8)
    % Compute mean distance from head center
    meanNorm = 0;
    for k=1:length(iEEG)
        if ~isempty(ChannelMat.Channel(iEEG(k)).Loc)
            meanNorm = meanNorm + norm(ChannelMat.Channel(iEEG(k)).Loc(:,1)) ./ length(iEEG);
        end
    end
    % If distances units do not seem to be in meters (if head mean radius > 200mm or < 30mm)
    if ~isempty(FileUnits) && (meanNorm > 0) && ((meanNorm > 0.200) || (meanNorm < 0.030))            
        % Detect the best factor possible
        FactorTest = [0.001, 0.01, 0.1, 1, 10, 100, 1000];
        iFactor = bst_closest(0.15, FactorTest .* meanNorm);
        strFactor = num2str(FactorTest(iFactor));
        % Ask user if we should scale the distances
        strFactor = java_dialog('question', ...
            ['Warning: The EEG electrodes locations do not seem to be in the expected units (' FileUnits ').' 10 ...
             'Please select a scaling factor for the units (suggested: ' strFactor '):' 10 10], 'Import channel file', ...
            [], {'0.001', '0.01', '0.1', '1', '10', '100' '1000'}, strFactor);
        % If user accepted to scale
        if ~isempty(strFactor) && ~isequal(strFactor, '1')
            Factor = str2num(strFactor);
            % Apply correction to location values
            for k = 1:length(iEEG)
                ChannelMat.Channel(iEEG(k)).Loc = ChannelMat.Channel(iEEG(k)).Loc .* Factor;
            end
        end
    end
end
% Remove fiducials only from polhemus and ascii files
%isRemoveFid = ismember(FileFormat, {'MEGDRAW', 'POLHEMUS', 'ASCII_XYZ', 'ASCII_NXYZ', 'ASCII_XYZN', 'ASCII_NXY', 'ASCII_XY', 'ASCII_NTP', 'ASCII_TP'});
isRemoveFid = 1;
% Detect auxiliary EEG channels + align channel
ChannelMat = channel_detect_type(ChannelMat, 1, isRemoveFid);


%% ===== APPLY NEW CHANNEL FILE =====
% If some studies were defined
if ~isempty(iStudies)
    if isempty(ChannelAlign)
        ChannelAlign = ~isempty(iMEG);
    end
    % History: Import channel file
    ChannelMat = bst_history('add', ChannelMat, 'import', ['Import from: ' ChannelFile ' (Format: ' FileFormat ')']);
    % Add channel file to all the target studies
    for i = 1:length(iStudies)
        ChannelFile = db_set_channel(iStudies(i), ChannelMat, ChannelReplace, ChannelAlign);
    end
    % Returned value
    Output = ChannelFile;
else
    Output = ChannelMat;
end


% Progress bar
if ~isProgressBar
    bst_progress('stop');
end


