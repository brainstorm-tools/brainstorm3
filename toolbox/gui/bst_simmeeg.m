function [varargout] = bst_simmeeg(varargin)
% BST_SIMMEEG:  Calls SimMEEG GUI to simulate signals and imports results in database
%
% USAGE:  NewFiles = bst_simmeeg('GUI', iStudy)

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
% Authors: Francois Tadel 2021

eval(macro_method);
end


%% ===== SIMMEEG GUI =====
function NewFiles = GUI(iStudy)
    NewFiles = {};
    % Install/load SimMEEG plugin
    [isOk, errMsg] = bst_plugin('InstallInteractive', 'simmeeg');
    if ~isOk
        return;
    end
    % Progress bar
    bst_progress('start', 'SimMEEG', 'Initializing...');
    bst_plugin('SetProgressLogo', 'simmeeg');
    % Load anatomy + sensors + headmodel
    bst = LoadInputs(iStudy);
    % Reset SimMEEG global variable h
    global h;
    h = [];
    % Call SimMEEG
    try
        SimMEEG_GUI(bst);
        isStarted = 1;
    catch
        bst_error();
        isStarted = 0;
    end
    % Close progress bar
    bst_progress('stop');
    bst_plugin('SetProgressLogo', []);
    % If the main figure was created
    if isfield(h, 'main_fig') && ~isempty(h.main_fig) && ishandle(h.main_fig)
        % Initialization successful: Wait for it to be closed
        if isStarted
            waitfor(h.main_fig);
        % Initialization failed: Close it
        else
            close(h.main_fig);
            return;
        end
    end
    % Import simulated signals
    NewFiles = ImportSimulations(iStudy);
    % Clear memory
    h = [];
end


%% ===== LOAD INPUTS =====
% Set all fields requested in sm_bst2ft_anatomy_from_bst_files
function bst = LoadInputs(iStudy)
    % Get study and subject info
    ProtocolInfo = bst_get('ProtocolInfo');
    sStudy = bst_get('Study', iStudy);
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Initialize FieldTrip
    [isInstalled, errMsg, PlugFt] = bst_plugin('Install', 'fieldtrip', 1, '20200911');
    if ~isInstalled
        bst_error(errMsg, 'Plugin manager', 0);
        return;
    end
    % Folders
    bst.FieldTrip_dir = bst_fileparts(which(PlugFt.TestFile));  % (only "fieldtrip-20200911" tested)
    bst.subj_anat_dir = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(sStudy.BrainStormSubject));
    bst.subj_data_dir = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName));
    % MRI file
    if ~isempty(sSubject.iAnatomy)
        bst.subj_MriFile = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    else
        bst.subj_MriFile = [];
    end
    % Scalp
    if ~isempty(sSubject.iScalp)
        bst.subj_scalpFile = file_fullpath(sSubject.Surface(sSubject.iScalp).FileName);
    else
        bst.subj_scalpFile = [];
    end
    % Outer skull
    if ~isempty(sSubject.iOuterSkull)
        bst.subj_skullFile = file_fullpath(sSubject.Surface(sSubject.iOuterSkull).FileName);
    else
        bst.subj_skullFile = [];
    end
    % Inner skull
    if ~isempty(sSubject.iInnerSkull)
        bst.subj_brainFile = file_fullpath(sSubject.Surface(sSubject.iInnerSkull).FileName);
    else
        bst.subj_brainFile = [];
    end
    % Cortex => The one used for the computation of the selected forward model
    if ~isempty(sSubject.iCortex)
        bst.subj_cortexFile = file_fullpath(sSubject.Surface(sSubject.iCortex).FileName);
    else
        bst.subj_cortexFile = [];
    end

    bst.subj_wmFile = bst.subj_cortexFile;
    bst.subj_pialFile = bst.subj_cortexFile;
    
    % Get channel files
    bst.subj_sens_meg_file = [];
    bst.subj_sens_eeg_file = [];
    if ~isempty(sStudy.Channel)
        if ismember('MEG', sStudy.Channel.Modalities)
            bst.subj_sens_meg_file = file_fullpath(sStudy.Channel.FileName);
        end
        if ismember('EEG', sStudy.Channel.Modalities)
            bst.subj_sens_eeg_file = file_fullpath(sStudy.Channel.FileName);
        end
    end
    
    % Get head model
    bst.subj_hdm_meg_vol_file = [];
    bst.subj_hdm_meg_cortex_file = [];
    bst.subj_hdm_eeg_vol_file = [];
    bst.subj_hdm_eeg_cortex_file = [];
    if ~isempty(sStudy.iHeadModel)
        hm = sStudy.HeadModel(sStudy.iHeadModel);
        % Surface
        if strcmpi(hm.HeadModelType, 'surface')
            % MEG
            if ~isempty(hm.MEGMethod)
                bst.subj_hdm_meg_cortex_file = file_fullpath(hm.FileName);
            end
            % EEG
            if ~isempty(hm.EEGMethod)
                bst.subj_hdm_eeg_cortex_file = file_fullpath(hm.FileName);
            end
        % Volume
        elseif strcmpi(hm.HeadModelType, 'volume')
            % MEG
            if ~isempty(hm.MEGMethod)
                bst.subj_hdm_meg_vol_file = file_fullpath(hm.FileName);
            end
            % EEG
            if ~isempty(hm.EEGMethod)
                bst.subj_hdm_eeg_vol_file = file_fullpath(hm.FileName);
            end
        end
        % If a reference cortex surface is defined in the file: overwrite the default cortex
        hmMat = in_bst_headmodel(hm.FileName, 0, 'SurfaceFile');
        if ~isempty(hmMat.SurfaceFile) && file_exist(file_fullpath(hmMat.SurfaceFile))
            bst.subj_cortexFile = file_fullpath(hmMat.SurfaceFile);
        end
    end
end


%% ===== IMPORT SIMULATIONS =====
% Get the signals simulated by SimMEEG from the global data h, and import them in the Brainstorm DB
function NewFiles = ImportSimulations(iStudy)
    % Global SimMEEG variable
    global h;
    % Returned files
    NewFiles = {};
    % No simulated data
    if isempty(h) || ~isfield(h, 'sim_data') || isempty(h.sim_data)
        return;
    end
    % Get available fields
    allFields = {'sens_final', 'sig_final', 'sig_wav', 'prepost_wav', 'noise_wav', 'prepost_win', 'sig_win', ...
        'sens_noise', 'sens_noise_scaled', 'sens_sig_data', 'sens_noise_final', 'sens_final_org', 'sens_noise_final_org', 'sens_sig_data_org'};
    availFields = {};
    for i = 1:length(allFields)
        if isfield(h.sim_data, allFields{i}) && ~isempty(h.sim_data.(allFields{i}))
            availFields{end+1} = allFields{i};
        end
    end
    if isempty(availFields)
        return;
    end
    % Ask fields to import
    isSelect = strcmpi(availFields, 'sens_final');
    if ~any(isSelect)
        isSelect = strcmpi(availFields, 'sig_final');
    end
    isSelect = java_dialog('checkbox', 'Select variables to import:', 'Import SimMEEG output', [], availFields, isSelect);
    if isempty(isSelect)
        return;
    end
    importGroups = availFields(isSelect == 1);
    % Get study
    sStudy = bst_get('Study', iStudy);
    % Timestamp
    c = clock;
    strTime = sprintf('_%02.0f%02.0f%02.0f_%02.0f%02.0f', c(1)-2000, c(2:5));
    % Progress bar
    nTrials = length(importGroups) * size(h.sim_data.(importGroups{1}),3);
    bst_progress('start', 'SimMEEG', 'Importing simulated files...', 0, nTrials);
    % Detect previous executions of simmeeg in this study
    iRun = 1;
    if ~isempty(sStudy.Matrix)
        while any(cellfun(@(c)and(length(c)>3, strcmpi(c(1:3),sprintf('%02d-',iRun))), {sStudy.Matrix.Comment}))
            iRun = iRun + 1;
        end
    end
    % Load channel file
    if ~isempty(sStudy.Channel)
        ChannelMat = in_bst_channel(sStudy.Channel.FileName);
        nChannels = length(ChannelMat.Channel);
        iChannels = cellfun(@(c)find(strcmpi(c,{ChannelMat.Channel.Name}),1), h.anatomy.sens.label);
    end
    % Loop to import groups of trials
    for iGroup = 1:length(importGroups)
        % List of trials to import
        trials = h.sim_data.(importGroups{iGroup});
        nSources = size(trials,2);
        % Save matrix
        if ismember(importGroups{iGroup}, {'sig_final', 'sig_wav', 'prepost_wav', 'noise_wav', 'prepost_win', 'sig_win'})
            % Create a "matrix" structure
            sMat = db_template('matrixmat');
            sMat.Time        = h.sim_data.cfg.study.lat_sim;
            sMat.Description = cell(nSources,1);
            for iSource = 1:nSources
                sMat.Description{iSource} = sprintf('Source %d', iSource);
            end
            % Add history entry
            sMat = bst_history('add', sMat, 'process', 'Generated with SimMEEG');
            % Add extra cfg structure
            sMat.cfg = h.sim_data.cfg;
            % Loop on each trial
            for iTrial = 1:size(trials,3)
                % Trial values
                sMat.Comment = sprintf('%02d-%s (#%d)', iRun, importGroups{iGroup}, iTrial);
                sMat.Value   = trials(:,:,iTrial)';
                % Output filename
                FileName = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_simmeeg', strTime, '_', strrep(importGroups{iGroup}, '_', '-'), sprintf('_trial%03d', iTrial)], 0);
                % Save on disk
                bst_save(FileName, sMat, 'v6');
                NewFiles{end+1} = FileName;
                % Add structure to database
                sNew = db_template('Matrix');
                sNew.FileName = file_short(FileName);
                sNew.Comment  = sMat.Comment;
                iItem = length(sStudy.Matrix) + 1;
                sStudy.Matrix(iItem) = sNew;
                % Increment progress bar
                bst_progress('inc',1);
            end
        % Save MEG/EEG data 
        else
            % Create a "matrix" structure
            sMat = db_template('datamat');
            sMat.Time = h.sim_data.cfg.study.lat_sim;
            sMat.ChannelFlag = ones(nChannels,1);
            sMat.Device = 'SimMEEG';
            % Add history entry
            sMat = bst_history('add', sMat, 'process', 'Generated with SimMEEG');
            % Add extra cfg structure
            sMat.cfg = h.sim_data.cfg;
            % Loop on each trial
            for iTrial = 1:size(trials,3)
                % Trial values
                sMat.Comment = sprintf('%02d-%s (#%d)', iRun, importGroups{iGroup}, iTrial);
                sMat.F = zeros(nChannels, size(trials,1));
                sMat.F(iChannels,:) = trials(:,:,iTrial)';
                % Output filename
                FileName = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['data_simmeeg', strTime, '_', strrep(importGroups{iGroup}, '_', '-'), sprintf('_trial%03d', iTrial)], 0);
                % Save on disk
                bst_save(FileName, sMat, 'v6');
                NewFiles{end+1} = FileName;
                % Add structure to database
                sNew = db_template('Data');
                sNew.FileName = file_short(FileName);
                sNew.Comment  = sMat.Comment;
                iItem = length(sStudy.Data) + 1;
                sStudy.Data(iItem) = sNew;
                % Increment progress bar
                bst_progress('inc',1);
            end
        end
    end
    % Update database
    bst_set('Study', iStudy, sStudy);
    panel_protocols('UpdateNode', 'Study', iStudy);
    % Close progress bar
    bst_progress('stop');
end


