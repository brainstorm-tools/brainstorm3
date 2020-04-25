function varargout = panel_headmodel(varargin)
% PANEL_HEADMODEL: Computation of forward model (GUI).
% 
% USAGE:     bstPanel = panel_headmodel('CreatePanel',      isMeg, isEeg, isEcog, isSeeg, isMixed)
%         OutputFiles = panel_headmodel('ComputeHeadModel', iStudies, sMethod)

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
% Authors: Francois Tadel, 2008-2020

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(isMeg, isEeg, isEcog, isSeeg, isMixed)  %#ok<DEFNU>
    panelName = 'HeadmodelOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    % Compatible call with older versions: 2 params only
    if (nargin == 2)
        isEcog = 0;
        isSeeg = 0;
        isMixed = 0;
    end
    % Create main main panel
    jPanelNew = gui_river([8,10], [0,15,20,15]);
   
    % ===== TITLE =====
    gui_component('label', jPanelNew, 'br', 'Comment:');
    jTextComment = gui_component('text', jPanelNew, 'hfill', ' ');
    
    % ===== Head model type =====
    jPanelSourceSpace = gui_river([2,4], [0,6,12,6], 'Source space');
    % Source grid type
    jButtonGroupGridType = ButtonGroup();
    jRadioGridSurface = gui_component('Radio', jPanelSourceSpace, 'br', 'Cortex surface', jButtonGroupGridType, 'Estimates sources at the cortex surface only', @UpdateComment);
    jRadioGridVolume  = gui_component('Radio', jPanelSourceSpace, 'br hfill', 'MRI volume', jButtonGroupGridType,  'Estimates sources in the full head volume', @UpdateComment);
    jRadioGridMixed   = gui_component('Radio', jPanelSourceSpace, 'br hfill', 'Custom source model', jButtonGroupGridType,  'Estimates sources based on the atlas "Source model"', @UpdateComment);
    if ~isMixed
        jRadioGridMixed.setEnabled(0);
    end
    % Default: surface
    jRadioGridSurface.setSelected(1);
    % Attach sub panel to NewPanel
    jPanelNew.add('br hfill', jPanelSourceSpace);
    
    % ===== Head model method =====
    jPanelMethod = gui_river([2,6], [0,6,12,6], 'Forward modeling methods');
    % === MEG ===
    if isMeg
        % Checkbox
        jCheckMethodMEG = gui_component('CheckBox', jPanelMethod, [], 'MEG: ', [], [], @UpdateComment);
        jCheckMethodMEG.setSelected(1);
        % Combobox
        jComboMethodMEG = gui_component('ComboBox', jPanelMethod, 'tab hfill', [], [], [], @UpdateComment, []);
        jComboMethodMEG.addItem(BstListItem('meg_sphere', '', 'Single sphere', []));
        jComboMethodMEG.addItem(BstListItem('os_meg', '', 'Overlapping spheres', []));
        jComboMethodMEG.addItem(BstListItem('openmeeg', '', 'OpenMEEG BEM', []));
        jComboMethodMEG.addItem(BstListItem('duneuro', '', 'DUNEuro FEM', []));
        jComboMethodMEG.setSelectedIndex(1);
    else
        jCheckMethodMEG = [];
        jComboMethodMEG = [];
    end
    % === EEG ===
    if isEeg
        % Checkbox
        jCheckMethodEEG = gui_component('CheckBox', jPanelMethod, 'br', 'EEG: ', [], [], @UpdateComment);
        jCheckMethodEEG.setSelected(1);
        % Combobox
        jComboMethodEEG = gui_component('ComboBox', jPanelMethod, 'tab hfill', [], [], [], @UpdateComment, []);
        jComboMethodEEG.addItem(BstListItem('eeg_3sphereberg', '', '3-shell sphere', []));
        jComboMethodEEG.addItem(BstListItem('openmeeg', '', 'OpenMEEG BEM', []));
        jComboMethodEEG.addItem(BstListItem('duneuro', '', 'DUNEuro FEM', []));
        jComboMethodEEG.setSelectedIndex(1);
    else
        jCheckMethodEEG = [];
        jComboMethodEEG = [];
    end
    % === ECOG ===
    if isEcog
        % Checkbox
        jCheckMethodECOG = gui_component('CheckBox', jPanelMethod, 'br', 'ECOG: ', [], [], @UpdateComment);
        jCheckMethodECOG.setSelected(1);
        % Combobox
        jComboMethodECOG = gui_component('ComboBox', jPanelMethod, 'tab hfill', [], [], [], @UpdateComment, []);
        jComboMethodECOG.addItem(BstListItem('openmeeg', '', 'OpenMEEG BEM', []));
        jComboMethodECOG.setSelectedIndex(0);
    else
        jCheckMethodECOG = [];
        jComboMethodECOG = [];
    end
    % === SEEG ===
    if isSeeg
        % Checkbox
        jCheckMethodSEEG = gui_component('CheckBox', jPanelMethod, 'br', 'SEEG: ', [], [], @UpdateComment);
        jCheckMethodSEEG.setSelected(1);
        % Combobox
        jComboMethodSEEG = gui_component('ComboBox', jPanelMethod, 'tab hfill', [], [], [], @UpdateComment, []);
        jComboMethodSEEG.addItem(BstListItem('openmeeg', '', 'OpenMEEG BEM', []));
        jComboMethodSEEG.setSelectedIndex(0);
    else
        jCheckMethodSEEG = [];
        jComboMethodSEEG = [];
    end
    % Attach sub panel to NewPanel
    jPanelNew.add('br hfill', jPanelMethod);

    % ===== VALIDATION BUTTON =====
    gui_component('Button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback);
    gui_component('Button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback);
        
    % ===== PANEL CREATION =====
    % Update comments
    UpdateComment();
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct('jTextComment',        jTextComment, ...
                  'jRadioGridSurface',   jRadioGridSurface, ...
                  'jRadioGridVolume',    jRadioGridVolume, ...
                  'jRadioGridMixed',     jRadioGridMixed, ...
                  'jCheckMethodMEG',     jCheckMethodMEG, ...
                  'jComboMethodMEG',     jComboMethodMEG, ...
                  'jCheckMethodEEG',     jCheckMethodEEG, ...
                  'jComboMethodEEG',     jComboMethodEEG, ...
                  'jCheckMethodECOG',    jCheckMethodECOG, ...
                  'jComboMethodECOG',    jComboMethodECOG, ...
                  'jCheckMethodSEEG',    jCheckMethodSEEG, ...
                  'jComboMethodSEEG',    jComboMethodSEEG ...
                 );
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);

    
%% =================================================================================
%  === LOCAL CALLBACKS =============================================================
%  =================================================================================
    %% ===== BUTTON: CANCEL =====
    function ButtonCancel_Callback(varargin)
        % Close panel
        gui_hide(panelName);
    end

    %% ===== BUTTON: OK =====
    function ButtonOk_Callback(varargin)
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

    %% ===== UPDATE COMMENT =====
    function UpdateComment(varargin)
        % Force to have at least one modality selected
        if isMeg && ~isEeg && ~isEcog && ~isSeeg
            jCheckMethodMEG.setSelected(1);
        elseif ~isMeg && isEeg && ~isEcog && ~isSeeg
            jCheckMethodEEG.setSelected(1);
        end
        % MEG/EEG Checkbox
        isMegSel  = isMeg && jCheckMethodMEG.isSelected();
        isEegSel  = isEeg && jCheckMethodEEG.isSelected();
        isEcogSel = isEcog && jCheckMethodECOG.isSelected();
        isSeegSel = isSeeg && jCheckMethodSEEG.isSelected();
        % MEG/EEG Combobox
        if isMeg
            jComboMethodMEG.setEnabled(isMegSel);
        end
        if isEeg
            jComboMethodEEG.setEnabled(isEegSel);
        end
        if isEcog
            jComboMethodECOG.setEnabled(isEcogSel);
        end
        if isSeeg
            jComboMethodSEEG.setEnabled(isSeegSel);
        end
        % Get current methods for EEG and MEG
        allMethods = {};
        if isMegSel
            allMethods{end+1} = char(jComboMethodMEG.getSelectedItem.getName());
        end
        if isEegSel
            allMethods{end+1} = char(jComboMethodEEG.getSelectedItem.getName());
        end
        if isEcogSel
            allMethods{end+1} = char(jComboMethodECOG.getSelectedItem.getName());
        end
        if isSeegSel
            allMethods{end+1} = char(jComboMethodSEEG.getSelectedItem.getName());
        end
        allMethods = unique(allMethods);
        allMethods(cellfun(@isempty,allMethods)) = [];
        % Build comment
        Comment = '';
        for im = 1:length(allMethods)
            if (im >= 2)
                Comment = [Comment, ' | '];
            end
            Comment = [Comment, allMethods{im}];
        end
        % Grid type
        if jRadioGridVolume.isSelected()
            Comment = [Comment ' (volume)'];
        elseif jRadioGridMixed.isSelected()
            Comment = [Comment ' (mixed)'];
        else
            %Comment = [Comment ' (cortex)'];
        end
        % Update control
        jTextComment.setText(Comment);
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================

%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'HeadmodelOptions');
    if isempty(ctrl)
        s = [];
        return; 
    end
    % Comment
    s.Comment = char(ctrl.jTextComment.getText());
    % Get source space
    if ctrl.jRadioGridSurface.isSelected()
        s.HeadModelType = 'surface';
    elseif ctrl.jRadioGridVolume.isSelected()
        s.HeadModelType = 'volume';
    elseif ctrl.jRadioGridMixed.isSelected()
        s.HeadModelType = 'mixed';
    end
    % Get methods for MEG, EEG, ECOG, SEEG
    if ~isempty(ctrl.jCheckMethodMEG) && ctrl.jCheckMethodMEG.isSelected()
        s.MEGMethod = char(ctrl.jComboMethodMEG.getSelectedItem.getType());
    else
        s.MEGMethod = '';
    end
    if ~isempty(ctrl.jCheckMethodEEG) && ctrl.jCheckMethodEEG.isSelected()
        s.EEGMethod = char(ctrl.jComboMethodEEG.getSelectedItem.getType());
    else
        s.EEGMethod = '';
    end
    if ~isempty(ctrl.jCheckMethodECOG) && ctrl.jCheckMethodECOG.isSelected()
        s.ECOGMethod = char(ctrl.jComboMethodECOG.getSelectedItem.getType());
    else
        s.ECOGMethod = '';
    end
    if ~isempty(ctrl.jCheckMethodSEEG) && ctrl.jCheckMethodSEEG.isSelected()
        s.SEEGMethod = char(ctrl.jComboMethodSEEG.getSelectedItem.getType());
    else
        s.SEEGMethod = '';
    end
    s.SaveFile = 1;
end


%% ===== COMPUTE HEADMODEL =====
% USAGE:  OutputFiles = ComputeHeadModel(iStudies, sMethod);
%         OutputFiles = ComputeHeadModel(iStudies);
%
% INPUT: 
%     - iStudies  : Indices of the studies for which we need to estimate a head model
%     - sMethod   : struct
%         |- MEGMethod     : {'meg_sphere', 'os_meg', 'openmeeg', ''}
%         |- EEGMethod     : {'eeg_3sphereberg', 'openmeeg', ''}
%         |- ECOGMethod    : {'openmeeg', ''}
%         |- SEEGMethod    : {'openmeeg', ''}
%         |- HeadModelType : {'volume', 'surface'}
%         |- Comment       : String [optional]
%         |- Interactive   : {0,1}, if 0, does everything by default and does not shoe any message
%         |- SaveFile      : {0,1}, if 0, return a the headmodel structure instead of saving the file in the database
%        [for sphere models]
%         |- HeadCenter   : [x;y;z], 3D coordinates of the head center
%         |- Conductivity : [cScalp, cSkull, cBrain], condictivity for each layer (useful only for 3-sphere models)
%         |- Radii        : [rScalp, rSkull, rBrain], radius for each layer (useful only for sphere models)
%        [for OpenMEEG]
%         |- OpenMEEG     : Options required by OpenMEEG
%        [optional]
%         |- GridLoc      : [Nx3] Grid of source points, to override what is defined in bst_headmodeler
%         |- GridOrient   : [Nx3] Normal vectors for the points in GridLoc (constrained orientation at those source points)
%         |- GridOptions  : Necessary information to compute the grid if the above fields are not available (see bst_sourcegrid.m)
function [OutputFiles, errMessage] = ComputeHeadModel(iStudies, sMethod) %#ok<DEFNU>
    global GlobalData;
    OutputFiles = {};
    errMessage = [];
        
    % ===== GET INPUT INFORMATION =====
    % Get all the study structures
    sStudies = bst_get('Study', iStudies);
    % Check that there are channel files available
    if all(cellfun(@isempty, {sStudies.Channel}))
        errMessage = 'No channel files available for the selected studies.';
        return;
    end
    % Loop through all the channel files to find the available modalities
    isMeg = 0;
    isEeg = 0;
    isEcog = 0;
    isSeeg = 0;
    for i = 1:length(sStudies)
        if ~isempty(sStudies(i).Channel)
            isMeg  = any(strcmpi(sStudies(i).Channel.DisplayableSensorTypes, 'MEG'));
            isEeg  = any(strcmpi(sStudies(i).Channel.DisplayableSensorTypes, 'EEG'));
            isEcog = any(strcmpi(sStudies(i).Channel.DisplayableSensorTypes, 'ECOG'));
            isSeeg = any(strcmpi(sStudies(i).Channel.DisplayableSensorTypes, 'SEEG'));
        end
    end
    % Check that at least one modality is available
    if ~isMeg && ~isEeg && ~isEcog && ~isSeeg
        errMessage = 'No valid sensor types to estimate a head model.';
        return;
    end
    % Check if the first subject has a "Source model" atlas
    sSubjectFirst = bst_get('Subject', sStudies(1).BrainStormSubject);
    if ~isempty(sSubjectFirst) && ~isempty(sSubjectFirst.iCortex)
        SurfaceFile = sSubjectFirst.Surface(sSubjectFirst.iCortex).FileName;
        SurfaceMat = load(file_fullpath(SurfaceFile), 'Atlas');
        if isfield(SurfaceMat, 'Atlas') && ~isempty(SurfaceMat.Atlas)
            iInverse = find(strcmpi('Source model', {SurfaceMat.Atlas.Name}));
            isMixed = ~isempty(iInverse);
        else
            isMixed = 0;
        end
    else
        isMixed = 0;
    end
    % Display options panel
    if (nargin < 2) || isempty(sMethod)
        sMethod = gui_show_dialog('Compute head model', @panel_headmodel, 1, [], isMeg, isEeg, isEcog, isSeeg, isMixed);
        if isempty(sMethod)
            return;
        end
    end
    % Recompute missing comment field
    if ~isMeg || ~isfield(sMethod, 'MEGMethod')
        sMethod.MEGMethod = '';
    end
    if ~isEeg || ~isfield(sMethod, 'EEGMethod')
        sMethod.EEGMethod = '';
    end
    if ~isEcog || ~isfield(sMethod, 'ECOGMethod')
        sMethod.ECOGMethod = '';
    end
    if ~isSeeg || ~isfield(sMethod, 'SEEGMethod')
        sMethod.SEEGMethod = '';
    end
    % List all methods
    allMethods = unique({sMethod.MEGMethod, sMethod.EEGMethod, sMethod.ECOGMethod, sMethod.SEEGMethod});
    allMethods(cellfun(@isempty,allMethods)) = [];
    % Build default comment
    if ~isfield(sMethod, 'Comment') || isempty(sMethod.Comment)
        sMethod.Comment = '';
        for im = 1:length(allMethods)
            if (im >= 2)
                sMethod.Comment = [sMethod.Comment, ' | '];
            end
            sMethod.Comment = [sMethod.Comment, allMethods{im}];
        end
        % Replace codes with comments
        sMethod.Comment = strrep(sMethod.Comment, 'os_meg',          'Overlapping spheres');
        sMethod.Comment = strrep(sMethod.Comment, 'meg_sphere',      'Single sphere');
        sMethod.Comment = strrep(sMethod.Comment, 'eeg_3sphereberg', '3-shell sphere');
        sMethod.Comment = strrep(sMethod.Comment, 'openmeeg',        'OpenMEEG BEM');
        sMethod.Comment = strrep(sMethod.Comment, 'duneuro',         'DUNEuro FEM');
        % Grid type
        if strcmpi(sMethod.HeadModelType, 'volume')
            sMethod.Comment = [sMethod.Comment ' (volume)'];
        elseif strcmpi(sMethod.HeadModelType, 'mixed')
            sMethod.Comment = [sMethod.Comment ' (mixed)'];
        end
    end
    isOpenMEEG = any(strcmpi(allMethods, 'openmeeg'));
    isDuneuro = any(strcmpi(allMethods, 'duneuro'));
    % Get protocol description
    ProtocolInfo = bst_get('ProtocolInfo');

    % ===== LOOP STUDY BY STUDY =====
    % Initialize loop variables
    BfsSubjects = {};
    BfsList = repmat(struct('HeadCenter',   [], ...
                            'Conductivity', [], ...
                            'Radii',        []), 0);
    for iStudy = iStudies(:)'
        % ===== Get subject/study information =====
        % Get study
        sStudy = bst_get('Study', iStudy);
        if isempty(sStudy.Channel) || isempty(sStudy.Channel.FileName)
            errMessage = 'No channel file available.';
            continue;
        end
        % Get current subject
        [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
        if isempty(sSubject) || isempty(sSubject.iCortex)
            errMessage = 'No cortex surface available for this subject.';
            continue;
        end
        % Load channel description
        ChannelFile = file_fullpath(sStudy.Channel.FileName);
        ChannelMat = in_bst_channel(ChannelFile);
        % Get default OPTIONS structure for bst_headmodeler
        OPTIONS = bst_headmodeler();
        % Override fields with input structure
        OPTIONS = struct_copy_fields(OPTIONS, sMethod, 1);
        % Output folder: folder of the channel file
        if sMethod.SaveFile
            OPTIONS.HeadModelFile = bst_fileparts(ChannelFile);
        else
            OPTIONS.HeadModelFile = '';
        end
        
        % ===== Fields Related to Sensor Information =====
        OPTIONS.Channel = ChannelMat.Channel;
        if isfield(ChannelMat, 'MegRefCoef')
            OPTIONS.MegRefCoef = ChannelMat.MegRefCoef;
        end
%         if isfield(ChannelMat, 'Projector')
%             OPTIONS.Projector = ChannelMat.Projector;
%         end
        % List of sensors
        OPTIONS.iMeg  = [good_channel(OPTIONS.Channel, [], 'MEG'), good_channel(OPTIONS.Channel, [], 'MEG REF')];
        OPTIONS.iEeg  = good_channel(OPTIONS.Channel, [], 'EEG');
        OPTIONS.iEcog = good_channel(OPTIONS.Channel, [], 'ECOG');
        OPTIONS.iSeeg = good_channel(OPTIONS.Channel, [], 'SEEG');

        % ===== BEST FITTING SPHERE =====
        % BestFittingSphere : .HeadCenter, .Radii, .Conductivity
        % ONLY FOR methods : meg_sphere, eeg_3sphereberg
        isBFS = strcmpi(OPTIONS.MEGMethod, 'meg_sphere') || strcmpi(OPTIONS.EEGMethod, 'eeg_3sphereberg');
        if isBFS && ~isfield(sMethod, 'HeadCenter')
            % Is the BFS already defined for this anatomy ?
            iBfs = find(strcmpi(sSubject.FileName, BfsSubjects));
            % If yes, use it
            if ~isempty(iBfs)
                BFS = BfsList(iBfs);
            else
                % Get possible estimations of the best fitting sphere
                estimList = GetBfsEstimations(sSubject, ChannelMat, isMeg, isEeg);
                if isempty(estimList)
                    errMessage = 'Could not estimate the best fitting sphere.';
                    return
                end
                % Interactive interface to set the BFS
                if OPTIONS.Interactive
                    % Display message (only if more than one computation)
                    if (length(iStudies) > 1)
                        java_dialog('msgbox', ['Editing best fitting sphere for subject "' sSubject.Name '".'], 'Compute head model');
                    end
                    % Number of spheres
                    if strcmpi(OPTIONS.EEGMethod, 'eeg_3sphereberg')
                        GlobalData.HeadModeler.nbSpheres = 3;
                    else
                        GlobalData.HeadModeler.nbSpheres = 1;
                    end
                    % Reference surface for GUI: Scalp or Cortex
                    if ~isempty(sSubject.iScalp)
                        RefSurface = sSubject.Surface(sSubject.iScalp).FileName;
                    elseif ~isempty(sSubject.iCortex)
                        RefSurface = sSubject.Surface(sSubject.iCortex).FileName;
                    end
                    % Start BFS editor
                    hFig = gui_edit_bfs(RefSurface, estimList);
                    % Display help message
                    jHelp = bst_help('BfsEstimation.html', 0);
                    % Wait for user to close this figure
                    waitfor(hFig);
                    % Close help message if not done yet
                    jHelp.close();
                    % If cancelled: stop
                    HeadCenter = GlobalData.HeadModeler.BFS.HeadCenter;
                    Radius     = GlobalData.HeadModeler.BFS.Radius;
                    if isempty(HeadCenter) || isempty(Radius)
                        return 
                    end
                % Non-interactive: get the first estimation
                else
                    HeadCenter = estimList(1).HeadCenter;
                    Radius     = estimList(1).Radius;
                end
                
                % Get BFS values
                BFSProperties = bst_get('BFSProperties');
                BFS.HeadCenter   = HeadCenter;
                BFS.Conductivity = BFSProperties(1:3);
                if strcmpi(OPTIONS.MEGMethod, 'meg_sphere')
                    BFS.Radii = Radius;
                elseif strcmpi(OPTIONS.EEGMethod, 'eeg_3sphereberg')
                    BFS.Radii = Radius .* [BFSProperties(4:5), 1];
                else
                    error('Invalid method...');
                end
                % Add this BFS to the existing BFS list
                BfsSubjects{end + 1} = sSubject.FileName;
                BfsList(end + 1) = BFS;
            end
            % Add BFS properties to bst_headmodeler options
            OPTIONS.HeadCenter   = BFS.HeadCenter;
            OPTIONS.Conductivity = BFS.Conductivity;
            OPTIONS.Radii        = BFS.Radii;
        end
        
        % ===== Fields Related to Source Localization =====
        % Overlapping spheres and no inner skull: warning
%         if isempty(sSubject.iInnerSkull) && strcmpi(OPTIONS.MEGMethod, 'os_meg')
%             errMessage = ['Overlapping sphere model would be more accurate based on an inner skull surface.' 10 ...
%                           'Please consider importing one, or computing the BEM surfaces for this subject.'];
%             disp(['HEADMODEL> ' errMessage]);
%         end
        % OpenMEEG and no inner skull: Generate BEM surfaces
        if isempty(sSubject.iInnerSkull) && isOpenMEEG
            % Ask confirmation
            if OPTIONS.Interactive
                isOk = java_dialog('confirm', ...
                    ['You need at least the inner skull surface for this head model.' 10 10 ...
                     'Generate BEM surfaces now?'], 'Subject definition');
                if ~isOk
                    return;
                end
            else
                errMessage = ['OpenMEEG: Inner skull surface not available for this subject.' 10 ...
                              'You should generate the BEM surfaces first.'];
                return;
            end
            % Generate BEM surfaces
            if ~tess_bem(iSubject)
                return
            end
            % Get subject definition again
            sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        end
        % Get all the layers available
        if ~isempty(sSubject.iInnerSkull)
            OPTIONS.InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull(1)).FileName;
        end
        if ~isempty(sSubject.iScalp)
            OPTIONS.HeadFile = sSubject.Surface(sSubject.iScalp(1)).FileName;
        end
        if ~isempty(sSubject.iCortex)
            OPTIONS.CortexFile = sSubject.Surface(sSubject.iCortex(1)).FileName;
        else
            bst_error('Please import a cortex surface for this subject.', 'Head model', 0);
            return
        end
                
        % ===== OPENMEEG =====
        if isOpenMEEG
            % Interactive interface to set the OpenMEEG options
            if OPTIONS.Interactive
                OPTIONS.BemFiles = {};
                OPTIONS.BemNames = {};
                OPTIONS.BemCond  = [];
                % Add the BEM layers definition to the OPTIONS structure
                % Get all the available layers: out -> in
                if ~isempty(sSubject.iScalp)
                    OPTIONS.BemFiles{end+1} = file_fullpath(sSubject.Surface(sSubject.iScalp(1)).FileName);
                    OPTIONS.BemNames{end+1} = 'Scalp';
                    OPTIONS.BemCond(end+1)  = 1;
                end
                if ~isempty(sSubject.iOuterSkull)
                    OPTIONS.BemFiles{end+1} = file_fullpath(sSubject.Surface(sSubject.iOuterSkull(1)).FileName);
                    OPTIONS.BemNames{end+1} = 'Skull';
                    OPTIONS.BemCond(end+1)  = 0.0125;
                end
                if ~isempty(sSubject.iInnerSkull)
                    OPTIONS.BemFiles{end+1} = file_fullpath(sSubject.Surface(sSubject.iInnerSkull(1)).FileName);
                    OPTIONS.BemNames{end+1} = 'Brain';
                    OPTIONS.BemCond(end+1)  = 1;
                end
                % EEG: Select all layers; MEG: Select only the innermost layer
                if ismember('openmeeg', {OPTIONS.EEGMethod, OPTIONS.ECOGMethod, OPTIONS.SEEGMethod})
                    OPTIONS.BemSelect = ones(size(OPTIONS.BemCond));
                else
                    OPTIONS.BemSelect = zeros(size(OPTIONS.BemCond));
                    OPTIONS.BemSelect(end) = 1;
                end
                % Let user edit OpenMEEG options
                OpenmeegOptions = gui_show_dialog('OpenMEEG options', @panel_openmeeg, 1, [], OPTIONS);
                if isempty(OpenmeegOptions)
                    bst_progress('stop');
                    return;
                end
                % Copy the selected options to the OPTIONS structure
                OPTIONS = struct_copy_fields(OPTIONS, OpenmeegOptions, 1);
            end

            % Get files names, if not defined yet
            if ~isfield(OPTIONS, 'BemFiles') || isempty(OPTIONS.BemFiles)
                OPTIONS.BemFiles = {};
                for iLayer = 1:length(OPTIONS.BemNames)
                    switch (OPTIONS.BemNames{iLayer})
                        case 'Scalp'
                            if ~isempty(sSubject.iScalp)
                                OPTIONS.BemFiles{iLayer} = file_fullpath(sSubject.Surface(sSubject.iScalp(1)).FileName);
                            else
                                errMessage = 'No scalp surface for this subject.';
                                return;
                            end
                        case 'Skull'
                            if ~isempty(sSubject.iOuterSkull)
                                OPTIONS.BemFiles{iLayer} = file_fullpath(sSubject.Surface(sSubject.iOuterSkull(1)).FileName);
                            else
                                errMessage = 'No outer skull surface for this subject.';
                                return;
                            end
                        case 'Brain'
                            if ~isempty(sSubject.iInnerSkull)
                                OPTIONS.BemFiles{iLayer} = file_fullpath(sSubject.Surface(sSubject.iInnerSkull(1)).FileName);
                            else
                                errMessage = 'No inner skull surface for this subject.';
                                return;
                            end
                    end
                end
            end
            % Use only the selected layers
            OPTIONS.BemSelect = logical(OPTIONS.BemSelect);
            if ~isempty(OPTIONS.BemFiles)
                OPTIONS.BemFiles = OPTIONS.BemFiles(OPTIONS.BemSelect);
            else
                OPTIONS.BemFiles = {};
            end
            OPTIONS.BemNames = OPTIONS.BemNames(OPTIONS.BemSelect);
            OPTIONS.BemCond  = OPTIONS.BemCond(OPTIONS.BemSelect);
        end
        
        % ===== DUNEURO =====
        if isDuneuro
            % Get default FEM head model
            if isempty(sSubject.iFEM)
                errMessage = 'No FEM head model available for this subject.';
                return;
            end
            OPTIONS.FemFile = file_fullpath(sSubject.Surface(sSubject.iFEM(1)).FileName);
            % Let user edit DUNEuro options
            DuneuroOptions = gui_show_dialog('DUNEuro options', @panel_duneuro, 1, [], OPTIONS);
            if isempty(DuneuroOptions)
                bst_progress('stop');
                return;
            end
            % Copy the selected options to the OPTIONS structure
            OPTIONS = struct_copy_fields(OPTIONS, DuneuroOptions, 1);
        end
        
        % ===== COMPUTE HEADMODEL =====
        % Start process
        [OPTIONS, errMessage] = bst_headmodeler(OPTIONS);
        if isempty(OPTIONS)
            return
        end

%         % ===== VERIFICATION FOR OVERLAP.SPHERES =====
%         if strcmpi(OPTIONS.MEGMethod, 'os_meg')
%             % Display all the spheres
%             view_spheres(OPTIONS.HeadModelFile, ChannelFile, sSubject);
%         end
        
%         % ===== VERIFICATION FOR OPENMEEG =====
%         % Calculate the overlapping sphere / 3-shell sphere models for the same sensors, to validate values
%         if isOpenMEEG
%             % Same base options, different methods
%             sMethodValid = sMethod;
%             sMethodValid.Interactive = 0;
%             sMethodValid.SaveFile = 0;
%             iRowValid = [];
%             % MEG: openmeeg => overlapping spheres
%             if isequal(sMethod.MEGMethod, 'openmeeg')
%                 sMethodValid.MEGMethod = 'os_meg';
%                 iRowValid = [iRowValid, OPTIONS.iMeg];
%             end
%             % EEG: openmeeg => overlapping spheres
%             if isequal(sMethod.EEGMethod, 'openmeeg')
%                 sMethodValid.EEGMethod = 'eeg_3sphereberg';
%                 iRowValid = [iRowValid, OPTIONS.iEeg];
%             end
%             % Call computation function
%             ValidMats = ComputeHeadModel(iStudy, sMethodValid);
%             % Load openmeeg gain matrix
%             OpenmeegMat = load(OPTIONS.HeadModelFile, 'Gain');
%             % Get both gain matrices for the sensors computed by OpenMEEG
%             Gsph = ValidMats{1}.Gain(iRowValid,:);
%             Gbem = OpenmeegMat.Gain(iRowValid,:);
%             % Compare them
%             corr = sum(bst_bsxfun(@rdivide, Gsph, sqrt(sum(Gsph.^2,1))) .* bst_bsxfun(@rdivide, Gbem, sqrt(sum(Gbem.^2,1))), 1);
%         end
        
        % ===== Add new HeadModel in Brainstorm Database =====
        % If a file was saved
        if ~isempty(OPTIONS.HeadModelFile)
            % If a new head model is available
            newHeadModel = db_template('HeadModel');
            newHeadModel.FileName      = file_win2unix(strrep(OPTIONS.HeadModelFile, ProtocolInfo.STUDIES, ''));
            newHeadModel.Comment       = OPTIONS.Comment;
            newHeadModel.HeadModelType = OPTIONS.HeadModelType;
            newHeadModel.MEGMethod     = OPTIONS.MEGMethod;
            newHeadModel.EEGMethod     = OPTIONS.EEGMethod;
            newHeadModel.ECOGMethod    = OPTIONS.ECOGMethod;
            newHeadModel.SEEGMethod    = OPTIONS.SEEGMethod;
            % Update Study structure
            iHeadModel = length(sStudy.HeadModel) + 1;
            sStudy.HeadModel(iHeadModel) = newHeadModel;
            sStudy.iHeadModel = iHeadModel;
            % Update DataBase
            bst_set('Study', iStudy, sStudy);
            panel_protocols('UpdateNode', 'Study', iStudy);
            % Return saved file
            OutputFiles{end+1} = OPTIONS.HeadModelFile;
        % Else: return the matrix
        else
            OutputFiles{end+1} = OPTIONS.HeadModelMat;
        end
    end
    % Save database
    db_save();
end


%% ===== GENERATE SOURCE GRID =====
% USAGE:  OutputFile = GenerateSourceGrid(iStudy, isInteractive=1)
function OutputFile = GenerateSourceGrid(iStudy, isInteractive) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 2) || isempty(isInteractive)
        isInteractive = 1;
    end
    OutputFile = [];
        
    % ===== GET INPUT INFORMATION =====
    % Get all the study structures
    sStudy = bst_get('Study', iStudy);
    % Get current subject
    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
    if isempty(sSubject) || isempty(sSubject.iCortex)
        return;
    end
    % Get cortex surface
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    HeadFile = sSubject.Surface(sSubject.iScalp).FileName;
    OutSurfaceFile = CortexFile;
    
    % ===== GET GRID ====
    % Compute grid
    if isInteractive
        % Show panel for use to select the options
        sGrid = gui_show_dialog('Volume source grid', @panel_sourcegrid, 0, [], CortexFile);
        if isempty(sGrid)
            return;
        end
        % Get the options the user selected
        GridLoc = sGrid.GridLoc;
        GridOptions = sGrid.GridOptions;
        % If using the full head volume: change the surface file that is used as a reference
        if strcmpi(GridOptions.Method, 'isohead')
            OutSurfaceFile = HeadFile;
        end
    else
        % Get the saved options of the computation of the Grid
        GridOptions = bst_get('GridOptions_headmodel');
        % Compute the grid with these options
        if strcmpi(GridOptions.Method, 'isohead')
            GridLoc = panel_sourcegrid('GetGrid', GridOptions, HeadFile);
            OutSurfaceFile = HeadFile;
        else
            GridLoc = panel_sourcegrid('GetGrid', GridOptions, CortexFile);
        end
    end
    if isempty(GridLoc)
        return;
    end

    % ===== SAVE FILE =====
    % File structure
    HeadModelMat = db_template('headmodelmat');
    HeadModelMat.Comment       = sprintf('Source grid (%d)', length(GridLoc));
    HeadModelMat.HeadModelType = 'volume';
    HeadModelMat.GridLoc       = GridLoc;
    HeadModelMat.GridOptions   = GridOptions;
    HeadModelMat.SurfaceFile   = OutSurfaceFile;
    % New file name
    HeadModelFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'headmodel_grid');
    % Save file 
    bst_save(HeadModelFile, HeadModelMat, 'v7');
    % If a new head model is available
    sHeadModel = db_template('headmodel');
    sHeadModel.FileName      = file_short(HeadModelFile);
    sHeadModel.Comment       = HeadModelMat.Comment;
    sHeadModel.HeadModelType = HeadModelMat.HeadModelType;
    % Update Study structure
    iHeadModel = length(sStudy.HeadModel) + 1;
    sStudy.HeadModel(iHeadModel) = sHeadModel;
    sStudy.iHeadModel = iHeadModel;
    % Update DataBase
    bst_set('Study', iStudy, sStudy);
    panel_protocols('UpdateNode', 'Study', iStudy);
    panel_protocols('SelectNode', [], HeadModelFile);
    % Save database
    db_save();
end


%% =================================================================================
%  === LOCAL HELPERS ===============================================================

%% ===== GET AVAILABLE BFS ESTIMATIONS =====
% PRIORITY ORDER : 
%    1) InnerSkull
%    2) Scalp
%    3) Head shape points (Neuromag FIF only)
%    4) EEG
%    5) Cortex
%    6) MEG
function estimList = GetBfsEstimations(sSubject, ChannelMat, isMeg, isEeg)
    % Initializations
    estimList = repmat(struct('HeadCenter',[],'Radius',[],'Name',''),0);
    Vertices = {};
    Names = {};
    Factor = {};
    minZ = [];
    % INNERSKULL
    if ~isempty(sSubject.iInnerSkull)
        Names{end+1} = 'InnerSkull';
        Factor{end+1} = 1.2;
        % Load vertices from the surface
        sSurf = bst_memory('LoadSurface', sSubject.Surface(sSubject.iInnerSkull(1)).FileName);
        Vertices{end+1} = sSurf.Vertices;
    end
    % SCALP
    if ~isempty(sSubject.iScalp)
        Names{end+1} = 'Scalp';
        Factor{end+1} = 1;
        % Load vertices from the surface
        sSurf = bst_memory('LoadSurface', sSubject.Surface(sSubject.iScalp(1)).FileName);
        Vertices{end+1} = sSurf.Vertices;
    end
    % HEAD POINTS
    if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && (length(ChannelMat.HeadPoints.Loc) > 8)
        Names{end+1} = 'Head points';
        Factor{end+1} = 1;
        % Get all the points that were digitized with the Polhemus system
        Vertices{end+1} = ChannelMat.HeadPoints.Loc';
    end
    % EEG
    if isEeg 
        Names{end+1} = 'EEG';
        Factor{end+1} = 1;
        % Get channels locations
        iEEG = good_channel(ChannelMat.Channel, [], 'EEG');
        Vertices{end+1} = cell2mat(cellfun(@(c)c(:,1), {ChannelMat.Channel(iEEG).Loc}, 'UniformOutput', 0))';
    end
    % CORTEX
    if ~isempty(sSubject.iCortex)
        Names{end+1} = 'Cortex';
        Factor{end+1} = 1.45;
        % Load vertices from the surface
        sSurf = bst_memory('LoadSurface', sSubject.Surface(sSubject.iCortex(1)).FileName);
        Vertices{end+1} = sSurf.Vertices;
        % Find the lowest point on the Z axis on the cortex
        minZ = min(sSurf.Vertices(:,3));
    end
    % MEG
    if isMeg
        Names{end+1} = 'MEG';
        Factor{end+1} = .80;
        % Get channels locations
        iMEG = good_channel(ChannelMat.Channel, [], 'MEG');
        Vertices{end+1} = cell2mat(cellfun(@(c)c(:,1), {ChannelMat.Channel(iMEG).Loc}, 'UniformOutput', 0))';
    end

    % Compute best fitting sphere for all lists for vertices
    if ~isempty(Vertices)
        for i = 1:length(Vertices)
            % If a cortex is also available
            if ~isempty(minZ)
                % Remove all scalp points below this limit
                Vertices{i}(Vertices{i}(:,3) < minZ, :) = [];
            end
            % If enough points to estimate the sphere
            if (length(Vertices{i}) >= 9)
                % Get estimator name
                estimList(end+1).Name = Names{i};
                % Compute sphere estimation
                [estimList(end).HeadCenter, estimList(end).Radius] = bst_bfs(Vertices{i});
                % Apply factor to the Radius
                estimList(end).Radius = estimList(end).Radius * Factor{i};
            end
        end
    end
end





