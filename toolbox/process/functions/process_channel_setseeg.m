function varargout = process_channel_setseeg( varargin )
% PROCESS_CHANNEL_SETSEEG: Convert EEG channels to SEEG.

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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Consider as SEEG/ECOG';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 34;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === Channel type
    sProcess.options.newtype.Comment = {'SEEG', 'ECOG', 'Sensor type: ';
                                        'SEEG', 'ECOG', ''};
    sProcess.options.newtype.Type    = 'radio_linelabel';
    sProcess.options.newtype.Value   = 'SEEG';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    Modality = sProcess.options.newtype.Value;   
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Loop on the channel studies
    for iFile = 1:length(iChanStudies)
        % Get channel study
        sStudy = bst_get('Study', iChanStudies(iFile));
        if isempty(sStudy.Channel)
            bst_report('Error', sProcess, [], 'No channel file available.');
            return
        end
        % Read channel file
        ChannelFile = sStudy.Channel(1).FileName;
        % Convert to SEEG/ECOG
        Compute(ChannelFile, Modality);
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end


%% ===== CONVERT =====
function Compute(ChannelFile, Modality)
    % Get channel file
    [sStudy, iStudy] = bst_get('ChannelFile', ChannelFile);
    % Load channel file
    ChannelFile = file_fullpath(ChannelFile);
    ChannelMat = in_bst_channel(ChannelFile);        
    % Get channels classified as EEG
    iEEG = channel_find(ChannelMat.Channel, 'EEG,SEEG,ECOG,ECG,EKG');
    % If there are no channels classified at EEG, take all the channels
    if isempty(iEEG)
        warning('Warning: No EEG channels identified, trying to use all the channels...');
        iEEG = 1:length(ChannelMat.Channel);
    end
    % Detect channels of interest
    [iSelEeg, iEcg] = ImaGIN_select_channels({ChannelMat.Channel(iEEG).Name}, 1);
    % Set channels as SEEG
    if ~isempty(iSelEeg)
        [ChannelMat.Channel(iEEG(iSelEeg)).Type] = deal(Modality);
    end
    if ~isempty(iEcg)
        [ChannelMat.Channel(iEEG(iEcg)).Type] = deal('ECG');
    end
    % Save modified file
    bst_save(ChannelFile, ChannelMat, 'v7');
    % Update database reference
    [sStudy.Channel.Modalities, sStudy.Channel.DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
    bst_set('Study', iStudy, sStudy);
end

