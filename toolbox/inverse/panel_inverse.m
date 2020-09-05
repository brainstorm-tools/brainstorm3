function varargout = panel_inverse(varargin)
% PANEL_INVERSE: Inverse modeling GUI.
%
% USAGE:  bstPanelNew = panel_inverse('CreatePanel')

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
% Authors: Francois Tadel, 2008-2015

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(Modalities, isShared, HeadModelType) %#ok<DEFNU>
    panelName = 'InverseOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    HFILLED_WIDTH  = 10;
    DEFAULT_HEIGHT = 20;
    % Initializations
    isFirstCombinationWarning = 1;
    
    % Create tool panel
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.Y_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));
    
    % ==== COMMENT ====
    jPanelTitle = gui_river([1,1], [0,6,6,6]);
        jPanelTitle.add('br', JLabel('Comment:'));
        jTextComment = JTextField('');
        jTextComment.setPreferredSize(java_scaled('dimension', HFILLED_WIDTH, DEFAULT_HEIGHT));
        jPanelTitle.add('hfill', jTextComment);
    jPanelNew.add(jPanelTitle);
    
    % ==== PANEL: METHOD ====
    jPanelMethod = gui_river([1,1], [0,6,6,6], 'Method');
        jButtonGroupMethod = ButtonGroup();
        % All MNE methods        
        jRadioWMNE   = gui_component('Radio', jPanelMethod, [], 'Minimum norm (wMNE)', jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioDSPM   = gui_component('Radio', jPanelMethod, 'br', 'dSPM',                       jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioLoreta = gui_component('Radio', jPanelMethod, 'br', 'sLORETA',                    jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioWMNE.setSelected(1);
        % EXPERT MODE
        jRadioMosherGls   = gui_component('Radio', [], [], '[Test] Mosher GLS',      jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMosherGlsr  = gui_component('Radio', [], [], '[Test] Mosher GLS(Reg)', jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMosherMNE   = gui_component('Radio', [], [], '[Test] Mosher MNE',      jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMosherGlsp  = gui_component('Radio', [], [], 'Performance',      jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMosherGlsrp = gui_component('Radio', [], [], 'Performance',      jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMosherMNEp  = gui_component('Radio', [], [], 'Performance',      jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        jRadioMEM         = gui_component('Radio', [], [], 'BrainEntropy MEM', jButtonGroupMethod, '', @(h,ev)UpdatePanel(), []);
        if ~strcmpi(HeadModelType, 'surface') || isShared || (exist('isdeployed', 'builtin') && isdeployed)
            jRadioMEM.setEnabled(0);
        end
    % Add 'Method' panel to main panel
    jPanelNew.add(jPanelMethod);

    % ===== PANEL: DATA TYPE =====
    jPanelDataType = gui_river([1,1], [0,6,6,6], 'Sensors type');
        jCheckDataMeg = [];
        jCheckDataMegGradio = [];
        jCheckDataMegMagneto = [];
        jCheckDataEeg = [];
        jCheckDataEcog = [];
        jCheckDataSeeg = [];
        % === MEG ===
        if ismember('MEG', Modalities)
            jCheckDataMeg = JCheckBox('MEG');
            java_setcb(jCheckDataMeg, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataMeg);
        end
        % === MEG GRAD ===
        if ismember('MEG GRAD', Modalities)
            jCheckDataMegGradio = JCheckBox('MEG Gradiometers');
            java_setcb(jCheckDataMegGradio, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataMegGradio);
        end
        % === MEG GRAD ===
        if ismember('MEG MAG', Modalities)
            jCheckDataMegMagneto = JCheckBox('MEG Magnetometers');
            java_setcb(jCheckDataMegMagneto, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataMegMagneto);
        end
        % === EEG ===
        if ismember('EEG', Modalities)
            jCheckDataEeg = JCheckBox('EEG');
            java_setcb(jCheckDataEeg, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataEeg);
        end
        % === ECOG ===
        if ismember('ECOG', Modalities)
            jCheckDataEcog = JCheckBox('ECOG');
            java_setcb(jCheckDataEcog, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataEcog);
        end
        % === SEEG ===
        if ismember('SEEG', Modalities)
            jCheckDataSeeg = JCheckBox('SEEG');
            java_setcb(jCheckDataSeeg, 'ActionPerformedCallback', @Modality_Callback);
            jPanelDataType.add('br', jCheckDataSeeg);
        end
        % === SELECT DEFAULT ===
        isDefaultSelected = 0;
        if ismember('MEG', Modalities)
            jCheckDataMeg.setSelected(1);
            isDefaultSelected = 1;
        end
        if ismember('MEG GRAD', Modalities)
            jCheckDataMegGradio.setSelected(1);
            isDefaultSelected = 1;
        end
        if ismember('MEG MAG', Modalities)
            jCheckDataMegMagneto.setSelected(1);
            isDefaultSelected = 1;
        end
        if ismember('EEG', Modalities) && ~isDefaultSelected
            jCheckDataEeg.setSelected(1);
            isDefaultSelected = 1;
        end
        if ismember('ECOG', Modalities) && ~isDefaultSelected
            jCheckDataEcog.setSelected(1);
            isDefaultSelected = 1;
        end
        if ismember('SEEG', Modalities) && ~isDefaultSelected
            jCheckDataSeeg.setSelected(1);
            isDefaultSelected = 1;
        end
    % Add 'Data type' panel to main panel
    jPanelNew.add(jPanelDataType);
    
    
    % ===== PANEL: OUTPUT MODE =====
    jPanelOutputMode = gui_river([1,1], [0,6,6,6], 'Output mode');
        % Output format
        jButtonGroupOutput = ButtonGroup();
        % Kernel only
        jRadioOutputKernel = JRadioButton('Kernel only', 1);
        jRadioOutputKernel.setToolTipText('<HTML>Time independant computation.<BR>To get the sources estimations for a time frame, <BR> the kernel is applied to the recordings (matrix product).');
        jButtonGroupOutput.add(jRadioOutputKernel);
        jPanelOutputMode.add('tab', jRadioOutputKernel);
        % Full results
        jRadioOutputFull = JRadioButton('Full results (Kernel*Recordings)');
        jRadioOutputFull.setToolTipText('Compute sources for all the time samples.');
        jButtonGroupOutput.add(jRadioOutputFull);
        jPanelOutputMode.add('br tab', jRadioOutputFull);
    % Add 'Output mode' panel to main panel
    jPanelNew.add(jPanelOutputMode);

    % ===== VALIDATION BUTTONS =====
    jPanelValid = gui_river([1,1], [0,6,6,6]);
    % Expert/normal mode
    jButtonExpert = gui_component('Button', jPanelValid, [], 'Expert mode', [], [], @SwitchExpertMode_Callback, []);
    gui_component('label', jPanelValid, 'hfill', ' ');
    % Ok/Cancel
    gui_component('Button', jPanelValid, 'right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('Button', jPanelValid, [], 'OK', [], [], @ButtonOk_Callback, []);
    jPanelNew.add(jPanelValid);


    % ===== PANEL CREATION =====
    % Update comments
    UpdatePanel(1);
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct(...
            'jPanelTop',           jPanelNew, ...
            'jTextComment', jTextComment, ...
            ... ==== METHOD PANEL ====
            'jRadioWMNE',          jRadioWMNE, ...
            'jRadioMosherGls',     jRadioMosherGls, ...
            'jRadioMosherGlsr',    jRadioMosherGlsr, ...
            'jRadioMosherMNE',     jRadioMosherMNE, ...
            'jRadioMosherGlsp',    jRadioMosherGlsp, ...
            'jRadioMosherGlsrp',   jRadioMosherGlsrp, ...
            'jRadioMosherMNEp',    jRadioMosherMNEp, ...
            'jRadioLoreta',        jRadioLoreta, ...
            'jRadioDSPM',          jRadioDSPM, ...
            'jRadioMEM',           jRadioMEM, ...
            ... ==== DATA TYPE PANEL ====
            'jPanelDataType',      jPanelDataType, ...
            'jCheckDataEeg',       jCheckDataEeg, ...
            'jCheckDataMeg',       jCheckDataMeg, ...
            'jCheckDataMegGradio', jCheckDataMegGradio, ...
            'jCheckDataMegMagneto',jCheckDataMegMagneto, ...
            'jCheckDataEcog',      jCheckDataEcog, ...
            'jCheckDataSeeg',      jCheckDataSeeg, ...
            ... ==== OUTPUT MODE PANEL =====
            'jPanelOutputMode',    jPanelOutputMode, ...
            'jRadioOutputFull',    jRadioOutputFull, ...
            'jRadioOutputKernel',  jRadioOutputKernel);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    


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

    %% ===== MODALITY CALLBACK =====
    function Modality_Callback(hObject, event)
        % If only one checkbox: can't deselect it
        if (length(Modalities) == 1)
            event.getSource().setSelected(1);
        % Warning if both MEG and EEG are selected
        elseif isFirstCombinationWarning && ~isempty(jCheckDataEeg) && jCheckDataEeg.isSelected() && (...
                (~isempty(jCheckDataMeg) && jCheckDataMeg.isSelected()) || ...
                (~isempty(jCheckDataMegGradio) && jCheckDataMegGradio.isSelected()) || ...
                (~isempty(jCheckDataMegMagneto) && jCheckDataMegMagneto.isSelected()))
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
        % Set value 
        jRadioWMNE.setSelected(1);
        % Update comment
        UpdatePanel(1);
        % Get old panel
        [bstPanelOld, iPanel] = bst_get('Panel', 'InverseOptions');
        container = get(bstPanelOld, 'container');
        jFrame = container.handle{1};
        % Re-pack frame
        jFrame.pack();
    end
    

    %% ===== UPDATE PANEL ======
    % USAGE:  UpdatePanel(isForced = 0)
    function UpdatePanel(isForced)
        % Default values
        if (nargin < 1) || isempty(isForced)
            isForced = 0;
        end
        % Expert mode / Normal mode
        if isForced
            ExpertMode = bst_get('ExpertMode');
            jPanelOutputMode.setVisible(ExpertMode);
            if ExpertMode
                jButtonExpert.setText('Normal mode');
                jPanelMethod.add('br', jRadioMosherGls);
                jPanelMethod.add('tab', jRadioMosherGlsp);
                jPanelMethod.add('br', jRadioMosherGlsr);
                jPanelMethod.add('tab', jRadioMosherGlsrp);
                jPanelMethod.add('br', jRadioMosherMNE);
                jPanelMethod.add('tab', jRadioMosherMNEp);
            else
                jButtonExpert.setText('Expert mode');
                jPanelMethod.remove(jRadioMosherGls);
                jPanelMethod.remove(jRadioMosherGlsr);
                jPanelMethod.remove(jRadioMosherMNE);
                jPanelMethod.remove(jRadioMosherGlsp);
                jPanelMethod.remove(jRadioMosherGlsrp);
                jPanelMethod.remove(jRadioMosherMNEp);
            end
            if ~isempty(jRadioMEM)
                if ~ExpertMode
                    jPanelMethod.remove(jRadioMEM);
                else
                    jPanelMethod.add('br', jRadioMEM);
                end
            end
        end
        
        % Selected modalities
        selModalities = {};
        if ~isempty(jCheckDataMeg) && jCheckDataMeg.isSelected()
            selModalities{end+1} = 'MEG';
        end
        if ~isempty(jCheckDataMegGradio) && jCheckDataMegGradio.isSelected()
            selModalities{end+1} = 'MEG GRAD';
        end
        if ~isempty(jCheckDataMegMagneto) && jCheckDataMegMagneto.isSelected()
            selModalities{end+1} = 'MEG MAG';
        end
        if ~isempty(jCheckDataEeg) && jCheckDataEeg.isSelected()
            selModalities{end+1} = 'EEG';
        end
        if ~isempty(jCheckDataEcog) && jCheckDataEcog.isSelected()
            selModalities{end+1} = 'ECOG';
        end
        if ~isempty(jCheckDataSeeg) && jCheckDataSeeg.isSelected()
            selModalities{end+1} = 'SEEG';
        end
        % Method name
        if jRadioWMNE.isSelected()
            Comment = 'MN: ';
            allowKernel = 1;
        elseif jRadioDSPM.isSelected()
            Comment = 'dSPM: ';
            allowKernel = 1;
        elseif jRadioLoreta.isSelected()
            Comment = 'sLORETA: ';
            allowKernel = 1;
        elseif jRadioMosherGls.isSelected() 
            Comment = 'GLS: ';
            allowKernel = 1;
        elseif jRadioMosherGlsp.isSelected() 
            Comment = 'GLS_P: ';
            allowKernel = 1;
        elseif jRadioMosherGlsr.isSelected() 
            Comment = 'GLS(Reg): ';
            allowKernel = 1;
        elseif jRadioMosherGlsrp.isSelected() 
            Comment = 'GLS_P(Reg): ';
            allowKernel = 1;
        elseif jRadioMosherMNE.isSelected() 
            Comment = 'MNE(JCM): ';
            allowKernel = 1;
        elseif jRadioMosherMNEp.isSelected() 
            Comment = 'MNE_P(JCM): ';
            allowKernel = 1;
        elseif ~isempty(jRadioMEM) && jRadioMEM.isSelected()
            Comment = 'MEM: ';
            allowKernel = 0;
            jRadioMEM.setEnabled(~isShared);
        else
            return
        end
        % Add modality comment
        Comment = [Comment, process_inverse('GetModalityComment', selModalities)];
        % Update comment field
        jTextComment.setText(Comment);

        % ===== OUTPUT MODE =====
        % If the user can select output type
        if ~isempty(jRadioOutputFull)
            % If no data defined: Only Kernel
            jRadioOutputFull.setEnabled(~isShared);
            % If method does not allow kernel: Full only
            jRadioOutputKernel.setEnabled(allowKernel);
            % Select the best available option
            if allowKernel
                jRadioOutputKernel.setSelected(1);
            elseif ~isShared
                jRadioOutputFull.setSelected(1);
            end
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
    % Get selected method
    if ctrl.jRadioWMNE.isSelected()
        s.InverseMethod = 'wmne';
    elseif ctrl.jRadioDSPM.isSelected()
        s.InverseMethod = 'dspm';
    elseif ctrl.jRadioLoreta.isSelected()
        s.InverseMethod = 'sloreta';
    elseif ctrl.jRadioMosherGls.isSelected()
        s.InverseMethod = 'gls';
    elseif ctrl.jRadioMosherGlsp.isSelected()
        s.InverseMethod = 'gls_p';
    elseif ctrl.jRadioMosherGlsr.isSelected()
        s.InverseMethod = 'glsr';
    elseif ctrl.jRadioMosherGlsrp.isSelected()
        s.InverseMethod = 'glsr_p';
    elseif ctrl.jRadioMosherMNE.isSelected()
        s.InverseMethod = 'mnej';
    elseif ctrl.jRadioMosherMNEp.isSelected()
        s.InverseMethod = 'mnej_p';
    elseif ~isempty(ctrl.jRadioMEM) && ctrl.jRadioMEM.isSelected()
        s.InverseMethod = 'mem';
    end
    % Selected modalities
    s.DataTypes = {};
    if ~isempty(ctrl.jCheckDataMeg) && ctrl.jCheckDataMeg.isSelected()
        s.DataTypes{end+1} = 'MEG';
    end
    if ~isempty(ctrl.jCheckDataMegGradio) && ctrl.jCheckDataMegGradio.isSelected()
        s.DataTypes{end+1} = 'MEG GRAD';
    end
    if ~isempty(ctrl.jCheckDataMegMagneto) && ctrl.jCheckDataMegMagneto.isSelected()
        s.DataTypes{end+1} = 'MEG MAG';
    end
    if ~isempty(ctrl.jCheckDataEeg) && ctrl.jCheckDataEeg.isSelected()
        s.DataTypes{end+1} = 'EEG';
    end
    if ~isempty(ctrl.jCheckDataEcog) && ctrl.jCheckDataEcog.isSelected()
        s.DataTypes{end+1} = 'ECOG';
    end
    if ~isempty(ctrl.jCheckDataSeeg) && ctrl.jCheckDataSeeg.isSelected()
        s.DataTypes{end+1} = 'SEEG';
    end
    % Output mode
    if ctrl.jPanelOutputMode.isVisible() && ctrl.jRadioOutputFull.isSelected()
        s.ComputeKernel = 0;
    else
        s.ComputeKernel = 1;
    end
end






