function varargout = panel_inverse_2018(varargin)
% PANEL_INVERSE_2018: Inverse modeling GUI
%
% USAGE:  bstPanel = panel_inverse_2018('CreatePanel', sProcess, sFiles)                                                 : Called from the pipeline editor
%         bstPanel = panel_inverse_2018('CreatePanel', Modalities, isShared, HeadModelType, nSamplesNoise, nSamplesData) : Called from the interactive interface

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2021

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(Modalities, isShared, HeadModelType, nSamplesNoise, nSamplesData) %#ok<DEFNU>
    panelName = 'InverseOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Initializations
    strDiagRecommNoise = '';
    strDiagRecommData = '';
    NoiseMethod = [];
    DataMethod = [];

    % GUI CALL:  panel_inverse_2018('CreatePanel', Modalities, isShared, HeadModelType, nSamplesNoise, nSamplesData)
    if iscell(Modalities)
        isProcess = 0;
        isFull = 0;
        % Get default inverse options
        OPTIONS = bst_inverse_linear_2018();
        
        % Recommendations for noise covariance
        NoiseMethod = OPTIONS.NoiseMethod;
        if ~isempty(nSamplesNoise)
            nChannels = nnz(any(~isnan(nSamplesNoise) & (nSamplesNoise > 2)));
            nSamples  = max(nSamplesNoise(~isnan(nSamplesNoise)));
            % Check if we should force the diagonal selection
            if (nSamples < nChannels*(nChannels+1)/2)
                strDiagRecommNoise = '  (recommended)';
                NoiseMethod = 'diag';
                OPTIONS.NoiseMethod = 'diag';
            end
        end
        % Recommendations for data covariance
        DataMethod = OPTIONS.NoiseMethod;
        if ~isempty(nSamplesData)
            nChannels = nnz(any(~isnan(nSamplesData) & (nSamplesData > 2)));
            nSamples  = max(nSamplesData(~isnan(nSamplesData)));
            % Check if we should force the diagonal selection
            if (nSamples < nChannels*(nChannels+1)/2)
                strDiagRecommData = '  (recommended)';
                DataMethod = 'diag';
            end
        end
        
    % PROCESS CALL:  panel_inverse_2018('CreatePanel', sProcess, sFiles)
    else
        isProcess = 1;
        % Get inputs
        sProcess = Modalities;
        sFiles   = isShared;
        % Get inverse options
        OPTIONS = sProcess.options.inverse.Value;
        % List of sensors
        Modalities = {'MEG MAG', 'MEG GRAD', 'MEG', 'EEG', 'ECOG', 'SEEG'};
        if ~isempty(sFiles(1).ChannelTypes)
            Modalities = intersect(sFiles(1).ChannelTypes, Modalities);
            if any(ismember({'MEG MAG','MEG GRAD'}, Modalities))
                Modalities = setdiff(Modalities, 'MEG');
            end
        end
        % Shared kernel
        isShared = (sProcess.options.output.Value == 1);
        isFull   = (sProcess.options.output.Value == 3);
        % Head model type: Get from head model
        sStudyChan = bst_get('ChannelFile', sFiles(1).ChannelFile);
        if ~isempty(sStudyChan) && ~isempty(sStudyChan.HeadModel)
            HeadModelFile = sStudyChan.HeadModel(sStudyChan.iHeadModel).FileName;
            HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'HeadModelType');
            HeadModelType = HeadModelMat.HeadModelType;
        else
            HeadModelType = 'surface';
        end
    end
    % Initializations
    isFirstCombinationWarning = 1;
    
    % ==== FRAME STRUCTURE ====
    % Create main panel: split in top (interface) / left(standard options) / right (details)
    jPanelNew = gui_component('panel');
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));
    % Create top panel
    jPanelTop = gui_river([1,1], [0,6,6,6]);
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    % Create left panel
    jPanelLeft = java_create('javax.swing.JPanel');
    jPanelLeft.setLayout(GridBagLayout());
    jPanelNew.add(jPanelLeft, BorderLayout.WEST);
    % Create right panel
    jPanelRight = java_create('javax.swing.JPanel');
    %jPanelRight.setLayout(BoxLayout(jPanelRight, BoxLayout.Y_AXIS));
    jPanelRight.setLayout(GridBagLayout());
    jPanelRight.setBorder(BorderFactory.createEmptyBorder(0,12,0,0));
    jPanelNew.add(jPanelRight, BorderLayout.EAST);
    % Default constrains
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.HORIZONTAL;
    c.weightx = 1;
    c.weighty = 0;
    
    % ==== TOP PANEL ====
    % Comment
    gui_component('label', jPanelTop, 'br', 'Comment:  ', [], [], [], []);
    jTextComment = gui_component('text', jPanelTop, 'hfill', '', [], '', [], []);
    if isProcess && isfield(OPTIONS, 'Comment') && ~isempty(OPTIONS.Comment)
        jTextComment.setText(OPTIONS.Comment);
    end

    % ==== PANEL: METHOD ====
    jPanelMethod = gui_river([1,1], [0,6,6,6], 'Method');
        jGroupMethod  = ButtonGroup();
        jRadioMethodMn  = gui_component('radio', jPanelMethod, [],   'Minimum norm imaging', jGroupMethod, '', @Method_Callback, []);
        jRadioMethodBf  = gui_component('radio', jPanelMethod, 'br', 'LCMV beamformer',      jGroupMethod, '', @Method_Callback, []);
        jRadioMethodDip = gui_component('radio', jPanelMethod, 'br', 'Dipole modeling',      jGroupMethod, '', @Method_Callback, []);
        if ~isProcess
            jRadioMethodMem = gui_component('radio', jPanelMethod, 'br', 'MEM: Max entropy on the mean', jGroupMethod, '', @Method_Callback, []);
        else
            jRadioMethodMem = [];
        end
        % Default selection
        switch lower(OPTIONS.InverseMethod)
            case 'minnorm',  jRadioMethodMn.setSelected(1);
            case 'gls',      jRadioMethodDip.setSelected(1);
            case 'lcmv',     jRadioMethodBf.setSelected(1);
            case 'mem',      disp('BST> Warning: Running MEM from a script is not handled yet.');
        end
        % Disable Beamformer if no data covariance
        if ~isProcess && isempty(nSamplesData)
            jRadioMethodBf.setEnabled(0);
        end
        % Disable Dipoles/Beamformer if mixed head models
        if ~isProcess && strcmpi(HeadModelType, 'mixed')
            jRadioMethodBf.setEnabled(0);
            jRadioMethodDip.setEnabled(0);
        end
        % Disable MEM for shared/volume
        if ~isempty(jRadioMethodMem) && ~isProcess && (~strcmpi(HeadModelType, 'surface') || isShared)
            jRadioMethodMem.setEnabled(0);
        end
        
    c.gridy = 1;
    jPanelLeft.add(jPanelMethod, c);
    
    % ==== PANEL: MEASURE MIN NORM ====
    jPanelMeasureMN = gui_river([1,1], [0,6,6,6], 'Measure');
        jGroupMnMeasure = ButtonGroup();
        jRadioMnCurrent = gui_component('radio', jPanelMeasureMN, [],   'Current density map',  jGroupMnMeasure, '', @(h,ev)UpdatePanel(1), []);
        jRadioMnDspm    = gui_component('radio', jPanelMeasureMN, 'br', 'dSPM',                 jGroupMnMeasure, '', @(h,ev)UpdatePanel(1), []);
        jButtonDspmWarning = gui_component('label', jPanelMeasureMN, 'hfill', '<HTML><FONT color="#428bca">&nbsp;<U>Warning: unscaled values</U></FONT>', '', '', @(h,ev)WarningDspm(), []);
        jButtonDspmWarning.setHorizontalAlignment(jButtonDspmWarning.RIGHT);
        jRadioMnSloreta = gui_component('radio', jPanelMeasureMN, 'br', 'sLORETA',              jGroupMnMeasure, '', @(h,ev)UpdatePanel(1), []);
        % Default selection
        switch lower(OPTIONS.InverseMeasure)
            case 'amplitude',    jRadioMnCurrent.setSelected(1);
            case 'dspm2018',     jRadioMnDspm.setSelected(1);
            case 'sloreta',      jRadioMnSloreta.setSelected(1);
            otherwise,           jRadioMnCurrent.setSelected(1);
        end
    c.gridy = 2;
    jPanelLeft.add(jPanelMeasureMN, c);
    
    % ==== PANEL: MEASURE BEAMFORMER ====
    jPanelMeasureBf = gui_river([1,1], [0,6,6,6], 'Measure');
        jGroupBfMeasure = ButtonGroup();
        jRadioMethodBfNai = gui_component('radio', jPanelMeasureBf, 'br', 'Pseudo Neural Activity Index',  jGroupBfMeasure, '', @(h,ev)UpdatePanel(), []);
        % Default selection
        jRadioMethodBfNai.setSelected(1);
    c.gridy = 2;
    jPanelLeft.add(jPanelMeasureBf, c);
    
    % ==== PANEL: SOURCE MODEL ====
    jPanelModel = gui_river([1,1], [0,6,6,6], 'Source model: Dipole orientations');
        jGroupModel    = ButtonGroup(); 
        jRadioConstr   = gui_component('radio', jPanelModel, [],   'Constrained:  Normal to cortex',    jGroupModel, '', @(h,ev)UpdatePanel(), []);
        jRadioLoose    = gui_component('radio', jPanelModel, 'br', 'Loose constraints',                jGroupModel, '', @(h,ev)UpdatePanel(), []);
        jTextLoose     = gui_component('texttime', jPanelModel, [], '', [], '', [], []);
        gui_validate_text(jTextLoose, [], [], 0:0.1:1, '', 1, OPTIONS.Loose, []);
        jRadioUnconstr = gui_component('radio', jPanelModel, 'br', 'Unconstrained', jGroupModel, '', @(h,ev)UpdatePanel(), []);
        % Default selection
        if strcmpi(HeadModelType, 'surface')
            switch lower(OPTIONS.SourceOrient{1})
                case 'fixed',    jRadioConstr.setSelected(1);
                case 'loose',    jRadioLoose.setSelected(1);
                case 'free',     jRadioUnconstr.setSelected(1);
            end
        elseif strcmpi(HeadModelType, 'volume')
            jRadioConstr.setEnabled(0);
            jRadioLoose.setEnabled(0);
            jRadioUnconstr.setSelected(1);
        elseif strcmpi(HeadModelType, 'mixed')
            jRadioConstr.setEnabled(0);
            jRadioLoose.setEnabled(0);
            jRadioUnconstr.setEnabled(0);
        end
    c.gridy = 3;
    jPanelLeft.add(jPanelModel, c);
    
    % ==== PANEL: DATA TYPE ====
    jPanelSensors = gui_river([1,1], [0,6,6,6], 'Sensors');
        jCheckMeg = [];
        jCheckMegGrad = [];
        jCheckMegMag = [];
        jCheckEeg = [];
        jCheckEcog = [];
        jCheckSeeg = [];
        if ismember('MEG', Modalities)
            jCheckMeg = gui_component('checkbox', jPanelSensors, '', 'MEG', [], '', @Modality_Callback, []);
            jCheckMeg.setSelected(1);
        end
        if ismember('MEG GRAD', Modalities)
            jCheckMegGrad = gui_component('checkbox', jPanelSensors, '', 'MEG GRAD', [], '', @Modality_Callback, []);
            jCheckMegGrad.setSelected(1);
        end
        if ismember('MEG MAG', Modalities)
            jCheckMegMag = gui_component('checkbox', jPanelSensors, '', 'MEG MAG', [], '', @Modality_Callback, []);
            jCheckMegMag.setSelected(1);
        end
        if ismember('EEG', Modalities)
            jCheckEeg = gui_component('checkbox', jPanelSensors, '', 'EEG', [], '', @Modality_Callback, []);
            if (length(Modalities) == 1)
                jCheckEeg.setSelected(1);
            end
        end
        if ismember('ECOG', Modalities)
            jCheckEcog = gui_component('checkbox', jPanelSensors, '', 'ECOG', [], '', @Modality_Callback, []);
            if (length(Modalities) == 1)
                jCheckEcog.setSelected(1);
            end
        end
        if ismember('SEEG', Modalities)
            jCheckSeeg = gui_component('checkbox', jPanelSensors, '', 'SEEG', [], '', @Modality_Callback, []);
            if (length(Modalities) == 1)
                jCheckSeeg.setSelected(1);
            end
        end
    c.gridy = 4;
    jPanelLeft.add(jPanelSensors, c);
    
    % ==== PANEL: MEM INFO ====
    jPanelMemInfo = gui_river([1,1], [0,6,6,6], 'MEM');
        gui_component('label', jPanelMemInfo, '', '<HTML><FONT color="#707070"><I>Requires the BrainEntropy plugin.<BR>Options defined in a separate panel.</I></FONT>', [], '', [], []);
    c.gridy = 2;
    jPanelLeft.add(jPanelMemInfo, c);
    % ======================================================================================================
    
    % ==== DEPTH WEIGHTING =====
    jPanelDepth = gui_river([1,1], [0,6,6,6], 'Depth weighting');
        % Use depth weighting
        jCheckDepth = gui_component('checkbox', jPanelDepth, 'br', 'Use depth weighting', [], '', @(h,ev)UpdatePanel(), []);
        jCheckDepth.setSelected(OPTIONS.UseDepth);
        % Weightexp
        jLabelWeightExp = gui_component('label', jPanelDepth, 'br', '       Order [0,1]: ', [], '', [], []);
        jTextWeightExp  = gui_component('texttime', jPanelDepth, 'tab', num2str(OPTIONS.WeightExp), [], '', [], []);
        % Weightlimit
        jLabelWeightLimit = gui_component('label', jPanelDepth, 'br', '       Maximal amount: ', [], '', [], []);
        jTextWeightLimit  = gui_component('texttime', jPanelDepth, 'tab', num2str(OPTIONS.WeightLimit), [], '', [], []);
    c.gridy = 1;
    jPanelRight.add(jPanelDepth, c);
    
    % ==== PANEL: NOISE COVARIANCE ====
    jPanelNoiseCov = gui_river([1,1], [0,6,6,6], 'Title');
        jGroupReg    = ButtonGroup();
        jRadioReg    = gui_component('radio',    jPanelNoiseCov, [], 'Text:', jGroupReg, '', @(h,ev)UpdatePanel(), []);
            jTextReg = gui_component('texttime', jPanelNoiseCov, [], '', [], '', [], []);
            gui_validate_text(jTextReg, [], [], 0:0.1:1, '', 1, OPTIONS.NoiseReg, []);
        jRadioMedian = gui_component('radio',    jPanelNoiseCov, 'br', 'Median eigenvalue', jGroupReg, '', @(h,ev)UpdatePanel(), []);
        jRadioDiag   = gui_component('radio',    jPanelNoiseCov, 'br', 'Text', jGroupReg, '', @(h,ev)UpdatePanel(), []);
        jRadioNoReg  = gui_component('radio',    jPanelNoiseCov, 'br', 'No covariance regularization', jGroupReg, '', @(h,ev)UpdatePanel(), []);
        jRadioShrink = gui_component('radio',    jPanelNoiseCov, 'br', 'Automatic shrinkage', jGroupReg, '', @(h,ev)UpdatePanel(), []);
        % Default selection
        switch lower(OPTIONS.NoiseMethod)
            case 'reg',    jRadioReg.setSelected(1);
            case 'diag',   jRadioDiag.setSelected(1);
            case 'none',   jRadioNoReg.setSelected(1);
            case 'shrink', jRadioShrink.setSelected(1);
            case 'median', jRadioMedian.setSelected(1);
        end
    c.gridy = 2;
    jPanelRight.add(jPanelNoiseCov, c);
    
    % ==== PANEL: SNR ====
    jPanelSnr = gui_river([1,1], [0,6,6,6], '<HTML>Regularization parameter: 1 / &lambda;');
        jGroupSnr  = ButtonGroup();
        % Fixed SNR
        jRadioSnrFix = gui_component('radio', jPanelSnr, [], 'Signal-to-noise ratio: ', jGroupSnr, '', @(h,ev)UpdatePanel(), []);
        jTextSnrFix  = gui_component('texttime', jPanelSnr, [], '', [], '', [], []);
        gui_validate_text(jTextSnrFix, [], [], {0, 10000, 100}, '', 2, OPTIONS.SnrFixed, []);
        % Maximum source amplitude
        jRadioSnrRms = gui_component('radio', jPanelSnr, 'br', 'RMS source amplitude: ', jGroupSnr, '', @(h,ev)UpdatePanel(), []);
        jTextSnrRms  = gui_component('texttime', jPanelSnr, [], '', [], '', [], []);
        gui_validate_text(jTextSnrRms, [], [], {0, 1000000, 100}, 'scalar', 2, OPTIONS.SnrRms, []);
        gui_component('label', jPanelSnr, [], 'nAm', [], '', [], []);
        % Default selection
        switch lower(OPTIONS.SnrMethod)
            case 'rms',    jRadioSnrRms.setSelected(1);
            case 'fixed',  jRadioSnrFix.setSelected(1);
        end
    c.gridy = 3;
    jPanelRight.add(jPanelSnr, c);
    
    % ===== PANEL: OUTPUT MODE =====
    jPanelOutput = gui_river([1,1], [0,6,6,6], 'Output mode');
        jGroupOutput = ButtonGroup();
        jRadioKernel = gui_component('radio', jPanelOutput, [],   'Inverse kernel only', jGroupOutput, '<HTML>Time independant computation.<BR>To get the sources estimations for a time frame, <BR> the kernel is applied to the recordings (matrix product).', @(h,ev)UpdatePanel(), []);
        jRadioFull   = gui_component('radio', jPanelOutput, 'br', 'Full results (Kernel*Recordings)', jGroupOutput, 'Compute sources for all the time samples.', @(h,ev)UpdatePanel(), []);
        if isShared
            jRadioFull.setEnabled(0);
            jRadioKernel.setSelected(1);
        elseif isFull
            jRadioFull.setSelected(1);
        else
            jRadioKernel.setSelected(1);
        end
    c.gridy = 4;
    jPanelRight.add(jPanelOutput, c);
    
    % ===== VALIDATION BUTTONS =====
    jPanelValid = gui_river([1,1], [0,6,6,6]);
    % Add a glue at the bottom of the right panel (for appropriate scaling with the left)
    c.gridy   = 5;
    c.weighty = 1;
    jPanelRight.add(Box.createVerticalGlue(), c);
    % Add a glue at the bottom of the left panel (for appropriate scaling with the right)
    c.gridy   = 5;
    c.weighty = 1;
    jPanelLeft.add(Box.createVerticalGlue(), c);
    % Expert/normal mode
    jButtonExpert = gui_component('button', jPanelValid, [], 'Show details', [], [], @SwitchExpertMode_Callback, []);
    gui_component('label', jPanelValid, 'hfill', ' ');
    % Ok/Cancel
    gui_component('Button', jPanelValid, 'right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('Button', jPanelValid, [],      'OK',     [], [], @ButtonOk_Callback,     []);
    c.gridy = 6;
    c.weighty = 0;
    jPanelLeft.add(jPanelValid, c);

    
    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct(...
            'HeadModelType',  HeadModelType, ...
            'jTextComment',   jTextComment, ...
            ... % ==== PANEL: METHOD ====
            'jRadioMethodMn',  jRadioMethodMn, ...
            'jRadioMethodBf',  jRadioMethodBf, ...
            'jRadioMethodDip', jRadioMethodDip, ...
            ... % ==== PANEL: MEASURE ====
            'jRadioMnCurrent',   jRadioMnCurrent, ...
            'jRadioMnDspm',      jRadioMnDspm, ...
            'jRadioMnSloreta',   jRadioMnSloreta, ...
            'jRadioMethodBfNai', jRadioMethodBfNai, ...
            ... % ==== PANEL: SOURCE MODEL ====
            'jRadioConstr',   jRadioConstr, ...
            'jRadioUnconstr', jRadioUnconstr, ...
            'jRadioLoose',    jRadioLoose, ...
            'jTextLoose',     jTextLoose, ...
            ... % ==== PANEL: DEPTH WEIGHTING ====
            'jCheckDepth',      jCheckDepth, ...
            'jTextWeightExp',   jTextWeightExp, ...
            'jTextWeightLimit', jTextWeightLimit, ...
            ... % ==== PANEL: SNR ====
            'jRadioSnrRms',  jRadioSnrRms, ...
            'jTextSnrRms',   jTextSnrRms, ...
            'jRadioSnrFix',  jRadioSnrFix, ...
            'jTextSnrFix',   jTextSnrFix, ...
            ... % ==== PANEL: NOISE COVARIANCE ====
            'jRadioShrink',  jRadioShrink, ...
            'jRadioMedian',  jRadioMedian, ...
            'jRadioReg',     jRadioReg, ...
            'jTextReg',      jTextReg, ...
            'jRadioDiag',    jRadioDiag, ...
            'jRadioNoReg',   jRadioNoReg, ...
            ... % ==== PANEL: NON-LINEAR ====
            'jRadioMethodMem',     jRadioMethodMem, ...
            ... % ==== PANEL: DATA TYPE ====
            'jCheckMeg',     jCheckMeg, ...
            'jCheckMegGrad', jCheckMegGrad, ...
            'jCheckMegMag',  jCheckMegMag, ...
            'jCheckEeg',     jCheckEeg, ...
            'jCheckEcog',    jCheckEcog, ...
            'jCheckSeeg',    jCheckSeeg, ...
            ... % ===== PANEL: OUTPUT MODE =====
            'jRadioFull',    jRadioFull, ...
            'jRadioKernel',  jRadioKernel);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    % Update comments
    UpdatePanel(1, 1);
    


%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
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

    %% ===== METHOD CALLBACK =====
    function Method_Callback(hObject, event)
        % Change the default for source orientation
        if jRadioMethodMn.isSelected() && jRadioConstr.isEnabled()
            jRadioConstr.setSelected(1);
        elseif jRadioMethodDip.isSelected()
            jRadioUnconstr.setSelected(1);
        end
        % Update the panel
        UpdatePanel(1);
    end

    %% ===== MODALITY CALLBACK =====
    function Modality_Callback(hObject, event)
        isMEM = ~isempty(ctrl.jRadioMethodMem) && ctrl.jRadioMethodMem.isSelected();
        
        % If only one checkbox: can't deselect it
        if (length(Modalities) == 1)
            event.getSource().setSelected(1);
        % Warning if both MEG and EEG are selected
        elseif isFirstCombinationWarning && ~isMEM && ...
                ~isempty(jCheckEeg) && jCheckEeg.isSelected() && (...
                (~isempty(jCheckMeg) && jCheckMeg.isSelected()) || ...
                (~isempty(jCheckMegGrad) && jCheckMegGrad.isSelected()) || ...
                (~isempty(jCheckMegMag) && jCheckMegMag.isSelected()))
            java_dialog('warning', ['Warning: Brainstorm inverse models do not properly handle the combination of MEG and EEG yet.' 10 10 ...
                                    'For now, we recommend to compute separatly the sources for MEG and EEG.'], 'EEG/MEG combination');
            isFirstCombinationWarning = 0;
        end
        % Update comment
        UpdatePanel();
    end


    %% ===== SWITCH EXPERT MODE =====
    function SwitchExpertMode_Callback(varargin)
        % Toggle expert mode
        ExpertMode = bst_get('ExpertMode');
        bst_set('ExpertMode', ~ExpertMode);
        % Update comment
        UpdatePanel(1);
    end
    

    %% ===== UPDATE PANEL ======
    % USAGE:  UpdatePanel(isForced = 0)
    function UpdatePanel(isForced, isFirstCall)
        % Default values
        if (nargin < 2) || isempty(isFirstCall)
            isFirstCall = 0;
        end
        if (nargin < 1) || isempty(isForced)
            isForced = 0;
        end
        % Get the main categories of options
        isLinear = isempty(jRadioMethodMem) || ~jRadioMethodMem.isSelected();
        % Expert mode / Normal mode
        if isForced
            ExpertMode = bst_get('ExpertMode');
            % Left panels
            jPanelModel.setVisible(isLinear);
            jPanelMeasureMN.setVisible(isLinear && jRadioMethodMn.isSelected());
            jPanelMeasureBf.setVisible(isLinear && jRadioMethodBf.isSelected());
            jPanelMemInfo.setVisible(~isLinear);
            % Right panels (expert)
            jPanelRight.setVisible(ExpertMode);
            jPanelNoiseCov.setVisible(isLinear);
            jPanelSnr.setVisible(isLinear && ~jRadioMethodDip.isSelected() && ~jRadioMethodBf.isSelected());
            jPanelDepth.setVisible(isLinear && jRadioMethodMn.isSelected() && ~jRadioMnSloreta.isSelected());
            jPanelOutput.setVisible(isLinear && ~isProcess);
            % Update expert button 
            if ExpertMode
                jButtonExpert.setText('Hide details');
            else
                jButtonExpert.setText('Show details');
            end
            % Matrix to regularize
            regMethod = '';
            if jRadioMethodBf.isSelected()
                jPanelNoiseCov.getBorder().setTitle('Data covariance regularization');
                jRadioReg.setText('Regularize data covariance:');
                jRadioDiag.setText(['Diagonal data covariance' strDiagRecommData]);
                if ~isempty(DataMethod)
                    regMethod = DataMethod;
                else
                    regMethod = 'median';
                end
            else
                jPanelNoiseCov.getBorder().setTitle('Noise covariance regularization');
                jRadioReg.setText('Regularize noise covariance:');
                jRadioDiag.setText(['Diagonal noise covariance' strDiagRecommNoise]);
                if jRadioMethodDip.isSelected() && ~isequal(NoiseMethod, 'diag')
                    regMethod = 'median';
                elseif ~isempty(NoiseMethod)
                    regMethod = NoiseMethod;
                end
            end
            jPanelNoiseCov.repaint();
            % Force selection for the covariance reg
            switch lower(regMethod)
                case 'reg',    jRadioReg.setSelected(1);
                case 'diag',   jRadioDiag.setSelected(1);
                case 'none',   jRadioNoReg.setSelected(1);
                case 'shrink', jRadioShrink.setSelected(1);
                case 'median', jRadioMedian.setSelected(1);
            end
            % Select default regularization method
            if jRadioMethodMn.isSelected()
                jRadioSnrFix.setSelected(1);
                jRadioSnrRms.setEnabled(0);
                if strcmpi(HeadModelType, 'surface')
                    jRadioLoose.setEnabled(1);
                end
            else
                jRadioSnrRms.setSelected(1);
                jRadioSnrRms.setEnabled(1);
                jRadioLoose.setEnabled(0);
                if jRadioLoose.isSelected()
                    jRadioUnconstr.setSelected(1);
                end
            end
            
            % Get old panel
            [bstPanelOld, iPanel] = bst_get('Panel', 'InverseOptions');
            container = get(bstPanelOld, 'container');
            % Re-pack frame
            if ~isempty(container)
                jFrame = container.handle{1};
                if ~isempty(jFrame)
                    jFrame.pack();
                end
            end
        end
        % Enable/disable text boxes
        % jTextLoose.setEnabled(jRadioLoose.isSelected()); % For mixed models with loose
        jLabelWeightExp.setEnabled(jCheckDepth.isSelected());
        jTextWeightExp.setEnabled(jCheckDepth.isSelected());
        jLabelWeightLimit.setEnabled(jCheckDepth.isSelected());
        jTextWeightLimit.setEnabled(jCheckDepth.isSelected());
        jTextSnrRms.setEnabled(jRadioSnrRms.isSelected());
        jTextSnrFix.setEnabled(jRadioSnrFix.isSelected());
        jTextReg.setEnabled(jRadioReg.isSelected());
        
        % Selected modalities
        selModalities = {};
        if ~isempty(jCheckMeg) && jCheckMeg.isSelected()
            selModalities{end+1} = 'MEG';
        end
        if ~isempty(jCheckMegGrad) && jCheckMegGrad.isSelected()
            selModalities{end+1} = 'MEG GRAD';
        end
        if ~isempty(jCheckMegMag) && jCheckMegMag.isSelected()
            selModalities{end+1} = 'MEG MAG';
        end
        if ~isempty(jCheckEeg) && jCheckEeg.isSelected()
            selModalities{end+1} = 'EEG';
        end
        if ~isempty(jCheckEcog) && jCheckEcog.isSelected()
            selModalities{end+1} = 'ECOG';
        end
        if ~isempty(jCheckSeeg) && jCheckSeeg.isSelected()
            selModalities{end+1} = 'SEEG';
        end
        
        % Linear methods
        if isLinear
            % Get selected method
            [InverseMethod, InverseMeasure] = GetSelectedMethod(ctrl);
            % Get comment for this method
            Comment = GetMethodComment(InverseMethod, InverseMeasure);
        else
            if ~isempty(jRadioMethodMem) && jRadioMethodMem.isSelected()
                Comment = 'MEM: ';
            end
        end
        % Add modality comment
        Comment = [Comment, ': ', process_inverse_2018('GetModalityComment', selModalities)];
        % Update comment field
        if ~isProcess || ~isFirstCall || ~isfield(OPTIONS, 'Comment') || isempty(OPTIONS.Comment)
            jTextComment.setText(Comment);
        end
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'InverseOptions');
    if isempty(ctrl)
        s = [];
        return; 
    end
    % Comment
    s.Comment = char(ctrl.jTextComment.getText());
    % Linear models
    isLinear = isempty(ctrl.jRadioMethodMem) || ~ctrl.jRadioMethodMem.isSelected();
    if isLinear
        % Get selected method
        [s.InverseMethod, s.InverseMeasure] = GetSelectedMethod(ctrl);
        % Source model
        if strcmpi(ctrl.HeadModelType, 'mixed')
            s.SourceOrient = [];
        else
            if ctrl.jRadioConstr.isSelected()
                s.SourceOrient = {'fixed'};
            elseif ctrl.jRadioUnconstr.isSelected()
                s.SourceOrient = {'free'};
            elseif ctrl.jRadioLoose.isSelected()
                s.SourceOrient = {'loose'};
            end
        end
        s.Loose = str2num(char(ctrl.jTextLoose.getText()));
        % Depth weighting
        s.UseDepth    = ctrl.jCheckDepth.isSelected() && ~strcmpi(s.InverseMeasure, 'sloreta');
        s.WeightExp   = str2num(char(ctrl.jTextWeightExp.getText()));
        s.WeightLimit = str2num(char(ctrl.jTextWeightLimit.getText()));
        % Noise covariance
        if ctrl.jRadioShrink.isSelected()
            s.NoiseMethod = 'shrink';
        elseif ctrl.jRadioMedian.isSelected()
            s.NoiseMethod = 'median';
        elseif ctrl.jRadioReg.isSelected()
            s.NoiseMethod = 'reg';
        elseif ctrl.jRadioDiag.isSelected()
            s.NoiseMethod = 'diag';
        elseif ctrl.jRadioNoReg.isSelected()
            s.NoiseMethod = 'none';
        end
        s.NoiseReg = str2num(char(ctrl.jTextReg.getText()));
        % Signal to noise
        if ctrl.jRadioSnrRms.isSelected()
            s.SnrMethod = 'rms';
        elseif ctrl.jRadioSnrFix.isSelected()
            s.SnrMethod = 'fixed';
        end
        s.SnrRms   = str2num(char(ctrl.jTextSnrRms.getText())) * 1e-9;  % Convert to Amper.mter
        s.SnrFixed = str2num(char(ctrl.jTextSnrFix.getText()));
        % Output mode
        if ctrl.jRadioFull.isSelected()
            s.ComputeKernel = 0;
        else
            s.ComputeKernel = 1;
        end
    % Non-linear models
    else
        % Get selected method
        if ctrl.jRadioMethodMem.isSelected()
            s.InverseMethod = 'mem';
        end
        % Other fields that are not defined
        s.InverseMeasure = [];
        s.SourceOrient   = [];
        s.Loose          = [];
        s.UseDepth       = [];
        s.WeightExp      = [];
        s.WeightLimit    = [];
        s.NoiseMethod    = [];
        s.NoiseReg       = [];
        s.SnrMethod      = [];
        s.SnrRms         = [];
        s.SnrFixed       = [];
        s.ComputeKernel  = 0;
    end
    % Selected modalities
    s.DataTypes = {};
    if ~isempty(ctrl.jCheckMeg) && ctrl.jCheckMeg.isSelected()
        s.DataTypes{end+1} = 'MEG';
    end
    if ~isempty(ctrl.jCheckMegGrad) && ctrl.jCheckMegGrad.isSelected()
        s.DataTypes{end+1} = 'MEG GRAD';
    end
    if ~isempty(ctrl.jCheckMegMag) && ctrl.jCheckMegMag.isSelected()
        s.DataTypes{end+1} = 'MEG MAG';
    end
    if ~isempty(ctrl.jCheckEeg) && ctrl.jCheckEeg.isSelected()
        s.DataTypes{end+1} = 'EEG';
    end
    if ~isempty(ctrl.jCheckEcog) && ctrl.jCheckEcog.isSelected()
        s.DataTypes{end+1} = 'ECOG';
    end
    if ~isempty(ctrl.jCheckSeeg) && ctrl.jCheckSeeg.isSelected()
        s.DataTypes{end+1} = 'SEEG';
    end
end


%% ===== GET SELECTED METHOD =====
function [Method, Measure] = GetSelectedMethod(ctrl)
    if ctrl.jRadioMethodMn.isSelected()
        Method = 'minnorm';
        if ctrl.jRadioMnCurrent.isSelected()
            Measure = 'amplitude';
        elseif ctrl.jRadioMnDspm.isSelected()
            Measure = 'dspm2018';
        elseif ctrl.jRadioMnSloreta.isSelected()
            Measure = 'sloreta';
        end
    elseif ctrl.jRadioMethodDip.isSelected()
        Method = 'gls';
        Measure = 'performance';
    elseif ctrl.jRadioMethodBf.isSelected()
        Method = 'lcmv';
        if ctrl.jRadioMethodBfNai.isSelected()
            Measure = 'nai';
        end
    end
end

%% ===== GET METHOD COMMENT =====
function Comment = GetMethodComment(Method, Measure)
    Comment = 'UKNOWN';
    switch (lower(Method))
        case 'minnorm'
            switch (lower(Measure))
                case 'amplitude', Comment = 'MN';
                case 'dspm2018',  Comment = 'dSPM-unscaled';
                case 'sloreta',   Comment = 'sLORETA';
            end
        case 'gls'
            Comment = 'Dipoles';
        case 'lcmv'
            switch (lower(Measure))
                case 'nai',       Comment = 'PNAI';
            end
        case 'mem'
            Comment = 'MEM';
    end
end


%% ===== WARNING DSPM 2018 =====
function WarningDspm()
    java_dialog('msgbox', [...
        'The dSPM implementation in "Compute sources [2018]" changed in July 2018:' 10 ...
        'The values are not scaled by the effective number of trials any more.' 10 ...
        'To get proper dSPM values for averages, run process "Sources > Scale averaged dSPM".' 10 10 ...
        'You will be directed to the Brainstorm website for additional information.' 10 10], 'Warning: dSPM update.');
    web('https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Averaging_normalized_values', '-browser');
end


