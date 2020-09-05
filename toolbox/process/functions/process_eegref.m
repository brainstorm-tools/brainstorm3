function varargout = process_eegref( varargin )
% PROCESS_EEGREF: Re-reference the EEG recordings.

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
% Authors: Francois Tadel, 2015-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Re-reference EEG';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 306;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle#EEG_reference_and_bad_channels';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Label
    sProcess.options.title.Comment = ['This process creates a linear projector that re-refences the EEG.<BR>' ...
                                      'Enter below the name of one or more electrodes, separated with commas.<BR>' ...
                                      'For average reference, enter "<B>AVERAGE</B>" (EEG).<BR>' ...
                                      'For local average reference, enter "<B>LOCAL AVERAGE</B>" (SEEG/ECOG).<BR><BR>' ...
                                      'To view or delete this operator: open the file, go the Record tab<BR>' ...
                                      'and select the menu "Artifacts > Select active projectors".<BR><BR>'];
    sProcess.options.title.Type    = 'label';
    % EEG references
    sProcess.options.eegref.Comment = 'EEG reference channel(s): ';
    sProcess.options.eegref.Type    = 'text';
    sProcess.options.eegref.Value   = '';
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned values
    OutputFile = {};
    % Get options
    SensorTypes = strtrim(sProcess.options.sensortypes.Value);
    EegRef      = strtrim(sProcess.options.eegref.Value);
    if isempty(EegRef) || isempty(SensorTypes)
        bst_report('Error', sProcess, [], 'You need to specify both the sensors type and the references.');
        return;
    end
    % Get list of channel files
    uniqueChanFiles = unique({sInputs.ChannelFile});
    
    % Process each channel file separately
    for iFile = 1:length(uniqueChanFiles)
        % === GET BAD CHANNELS ===
        % Get data files
        iFilesIn = find(strcmp({sInputs.ChannelFile}, uniqueChanFiles{iFile}));
        DataFiles = {sInputs(iFilesIn).FileName};
        % Get bad channels
        ChannelFlag = [];
        for i = 1:length(DataFiles)
            DataMat = in_bst_data(DataFiles{i}, 'ChannelFlag');
            if isempty(ChannelFlag)
                ChannelFlag = DataMat.ChannelFlag;
            else
                ChannelFlag(DataMat.ChannelFlag == -1) = -1;
            end
        end
        
        % === GET CHANNEL FILE ===
        ChannelFile = uniqueChanFiles{iFile};
        % Load the channel file
        ChannelMat = in_bst_channel(ChannelFile);
        % Get channels to process
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
        if isempty(iChannels)
            bst_report('Error', sProcess, sInputs, 'No channels to process.');
            return;
        end
        % Get electrodes types
        allTypes = unique({ChannelMat.Channel(iChannels).Type});
        Modality = allTypes{1};
        % Error if more than one channel type
        if (length(allTypes) > 1)
            strTypes = cellfun(@(c)cat(2,c,' '), allTypes, 'UniformOutput', 0);
            bst_report('Error', sProcess, sInputs, ...
                ['Mixing different channel types to compute the projector: ' [strTypes{:}], '.' 10 ...
                 'You should reference separately each sensor type.']);
             return;
        % Do not accept references for the MEG
        elseif any(strcmpi(Modality, {'MEG', 'MEG GRAD', 'MEG MAG'}))
            bst_report('Error', sProcess, sInputs, 'References cannot be applied to MEG sensors.');
            return;
        end
        % Find EEG reference channels
        iEegRef = channel_find(ChannelMat.Channel, EegRef);
        % Initialize weight matrix
        W = eye(length(ChannelMat.Channel));
        % AVERAGE: Average reference
        if isempty(iEegRef) && ismember(lower(EegRef), {'average','avg','avgref','all','*'})
            iEegRef = iChannels;
            sMontage = panel_montage('GetMontageAvgRef', [], ChannelMat.Channel(iChannels), ChannelFlag(iChannels), 0);
            W(iChannels,iChannels) = sMontage.Matrix;
        % LOCAL AVERAGE: Local average reference
        elseif isempty(iEegRef) && ismember(lower(EegRef), {'local average'})
            iEegRef = iChannels;
            sMontage = panel_montage('GetMontageAvgRef', [], ChannelMat.Channel(iChannels), ChannelFlag(iChannels), 1);
            W(iChannels,iChannels) = sMontage.Matrix;
        elseif isempty(iEegRef)
            bst_report('Error', sProcess, [], ['EEG reference channels were not found: "' EegRef '".']);
            return;
        % Standard referencing
        else
            W(iChannels,iEegRef) = W(iChannels,iEegRef) - 1./length(iEegRef);
        end

        % === CREATE AVERAGE REF PROJECTOR ===
        % Remove the references that were used (if they are not regular channels)
        iExtRef = setdiff(iEegRef, iChannels);
        if ~isempty(iExtRef)
            W(iExtRef,iExtRef) = 0;
        end
        % Build projector structure
        proj = db_template('projector');
        proj.Comment    = ['EEG reference: ' EegRef];
        proj.Components = W;
        proj.CompMask   = [];
        proj.Status     = 1;
        proj.SingVal    = 'REF';
               
        % === SAVE PROJECTOR ===
        % Check for existing re-referencing projector
        if ~isempty(ChannelMat.Projector) && any(cellfun(@(c)isequal(c,'REF'), {ChannelMat.Projector.SingVal}))
            %bst_report('Warning', sProcess, [], 'There was already a re-referencing projector.');
            disp('BST> EEGREF: There was already a re-referencing projector.');
        end
        % Add projector to channel file
        [newproj, errMsg] = import_ssp(ChannelFile, proj, 1);
        if ~isempty(errMsg)
            bst_report('Error', sProcess, sInputs, errMsg);
            return;
        end
    end
    % Return all the input files
    OutputFile = {sInputs.FileName};
end




