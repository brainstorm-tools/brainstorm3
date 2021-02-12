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
    [isOk, errMsg] = bst_plugin('InstallInteractive', 'simmeeg', 1);
    if ~isOk
        return;
    end
    % Load anatomy + sensors + headmodel
    bst = LoadInputs(iStudy);
    % Progress bar
    bst_progress('start', 'SimMEEG', 'Initializing...');
    bst_progress('setimage', 'logo_simmeeg.gif');
    % Call SimMEEG
    try
        SimMEEG_GUI_v21a(bst);
        isStarted = 1;
    catch
        bst_error();
        isStarted = 0;
    end
    % Close progress bar
    bst_progress('stop');
    bst_progress('removeimage');
    % SimMEEG global variable: h
    global h;
    % If the main figure was created
    if isfield(h, 'main_fig') && ~isempty(h.main_fig) && ishandle(h.main_fig)
        % Initialization successful: Wait for it to be closed
        if isStarted
            waitfor(h.main_fig);
        % Initialization failed: Close it
        else
            close(h.main_fig);
        end
    end
    % 
    disp('Closed');
end


%% ===== LOAD INPUTS =====
function bst = LoadInputs(iStudy)
    % Get study and subject info
    ProtocolInfo = bst_get('ProtocolInfo');
    sStudy = bst_get('Study', iStudy);
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Set all fields requested in sm_bst2ft_anatomy_from_bst_files
    % Folders
    bst.FieldTrip_dir = bst_get('FieldTripDir');  % (only "fieldtrip-20200911" tested)
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

