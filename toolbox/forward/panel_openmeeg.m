function varargout = panel_openmeeg(varargin)
% PANEL_OPENMEEG: Options for OpenMEEG BEM (GUI).
% 
% USAGE:  bstPanelNew = panel_openmeeg('CreatePanel', OPTIONS)           : Call from the interactive interface
%         bstPanelNew = panel_openmeeg('CreatePanel', sProcess, sFiles)  : Call from the process editor
%                   s = panel_openmeeg('GetPanelContents')

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
% Authors: Francois Tadel, 2011-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'OpenmeegOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % CALL: From GUI
    if (nargin == 1)
        OPTIONS = sProcess;
    % CALL: From Process
    else
        OPTIONS = sProcess.options.openmeeg.Value;
    end
    % Default options
    if isempty(OPTIONS)
        OPTIONS = struct();
    end
    defOPTIONS = bst_get('OpenMEEGOptions');
    OPTIONS = struct_copy_fields(OPTIONS, defOPTIONS, 0);
    
    % Create main main panel
    jPanelNew = gui_river();
    
    % ===== BEM LAYERS =====
    jPanelLayers = gui_river([4,4], [3,15,10,10], 'BEM Layers & conductivities');
        nVertices = [];
        nFaces = [];
        nLayers = length(OPTIONS.BemNames);
        jCheckLayer = javaArray('javax.swing.JCheckBox', nLayers);
        jLabelLayer = javaArray('javax.swing.JLabel', nLayers);
        jTextCond   = javaArray('javax.swing.JTextField', nLayers);
        % Loop on each layer
        for i = 1:nLayers
            % Read fields descriptions in surface file (if available)
            if isfield(OPTIONS, 'BemFiles') && ~isempty(OPTIONS.BemFiles)
                fields = whos('-file', OPTIONS.BemFiles{i});
                % Get number of vertices/faces in layer #i
                ivar = find(strcmpi({fields.name}, 'Vertices'));
                nVertices(i) = max(fields(ivar).size);
                ivar = find(strcmpi({fields.name}, 'Faces'));
                nFaces(i) = max(fields(ivar).size);
                strVert = sprintf('| %d vertices: ', nVertices(i));
            else
                OPTIONS.BemFiles = {};
                strVert = '';
            end
            % Add components
            jCheckLayer(i) = gui_component('checkbox', jPanelLayers, 'br',  OPTIONS.BemNames{i}, [], [], @UpdatePanel, []);
            jLabelLayer(i) = gui_component('label', jPanelLayers, 'tab', strVert, [], [], [], []);
            jTextCond(i) = gui_component('texttime', jPanelLayers, 'tab', num2str(OPTIONS.BemCond(i), '%g'), [], [], [], []);
            % EEG: Select all layers; MEG: Select only the innermost layer
            jCheckLayer(i).setSelected(OPTIONS.BemSelect(i));
        end
    jPanelNew.add('br hfill', jPanelLayers);

    % ===== OPENMEEG OPTIONS ======
    isSeeg = isfield(OPTIONS, 'SEEGMethod') && strcmpi(OPTIONS.SEEGMethod, 'openmeeg') && ~isempty(OPTIONS.iSeeg);
    jPanelOpenmeeg = gui_river([3,3], [3,15,10,10], 'OpenMEEG options');
        % Adjoint
        jCheckAdjoint = gui_component('checkbox', jPanelOpenmeeg, [], '<HTML>Use adjoint formulation  <FONT COLOR="#808080"><I>(less memory, longer)</I></FONT>', [], [], @UpdatePanel, []);
        jCheckAdjoint.setSelected(OPTIONS.isAdjoint && ~isSeeg);
        jCheckAdjoint.setEnabled(~isSeeg);
        % Adaptive
        jCheckAdaptative = gui_component('checkbox', jPanelOpenmeeg, 'br', '<HTML>Use adaptive integration  <FONT COLOR="#808080"><I>(more accurate, 3x longer)</I></FONT>', [], [], @UpdatePanel, []);
        jCheckAdaptative.setSelected(OPTIONS.isAdaptative);
        % Split in blocks
        jCheckSplit = gui_component('checkbox', jPanelOpenmeeg, 'br', 'Process dipoles by blocks of: ', [], [], @UpdatePanel, []);
        jCheckSplit.setSelected(OPTIONS.isSplit);
        jTextSplit  = gui_component('texttime', jPanelOpenmeeg, ' ', num2str(OPTIONS.SplitLength), [], [], @UpdatePanel, []);
    jPanelNew.add('br hfill', jPanelOpenmeeg);
        
    % ===== ESTIMATED RESOURCES =====
    jPanelEstimate = gui_river([4 4], [3,15,10,10], 'Estimated resources');
                    gui_component('label', jPanelEstimate, '',    'Memory: ', [], [], [], []);
        jLabelRam = gui_component('label', jPanelEstimate, 'tab', '500 Mb', [], [], [], []);
                    gui_component('label', jPanelEstimate, 'br',  'Hard drive: ', [], [], [], []);
        jLabelHd  = gui_component('label', jPanelEstimate, 'tab', '1500 Mb', [], [], [], []);
    if ~isempty(OPTIONS.BemFiles)
        jPanelNew.add('br hfill', jPanelEstimate);
    end

    % ===== VALIDATION BUTTONS =====
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jCheckLayer',      jCheckLayer, ...
                  'jTextCond',        jTextCond, ...
                  'jCheckAdjoint',    jCheckAdjoint, ...
                  'jCheckAdaptative', jCheckAdaptative, ...
                  'jCheckSplit',      jCheckSplit, ...
                  'jTextSplit',       jTextSplit, ...
                  'jLabelRam',        jLabelRam, ...
                  'jLabelHd',         jLabelHd);
    ctrl.BemFiles = OPTIONS.BemFiles;
    ctrl.BemCond  = OPTIONS.BemCond;
    ctrl.BemNames = OPTIONS.BemNames;
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    % Update panel
    UpdatePanel();
    

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)       
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        % OpenMEEG options
        isAdjoint = jCheckAdjoint.isSelected();
        jCheckAdaptative.setEnabled(~isAdjoint);
        if isAdjoint
            jCheckAdaptative.setSelected(1);
        end
        % Split in blocks
        isSplit = jCheckSplit.isSelected();
        jTextSplit.setEnabled(isSplit);
        % BEM Layers
        if isempty(nVertices)
            return;
        end
        nv = [];
        nf = [];
        for j = 1:nLayers
            isSelLayer(j) = jCheckLayer(j).isSelected();
            jLabelLayer(j).setEnabled(isSelLayer(j));
            jTextCond(j).setEnabled(isSelLayer(j));
            if isSelLayer(j)
                nv(end+1) = nVertices(j);
                nf(end+1) = nFaces(j);
            end
        end

        % === COUNT MEMORY NEEDED ===
        estHd = 0;
        % Get number of dipoles
        if isSplit
            ntmp = str2num(char(ctrl.jTextSplit.getText()));
            if (length(ntmp) == 1)
                P = ntmp;
            end
        elseif ~isempty(OPTIONS.GridLoc)
            P = length(OPTIONS.GridLoc);
        elseif strcmpi(OPTIONS.HeadModelType, 'surface')
            VarInfo = whos('-file', file_fullpath(OPTIONS.CortexFile), 'Vertices');
            P = VarInfo.size(1);
        else
            % We don't know yet the number of dipoles: impossible to estimate
            jLabelRam.setText('?');
            jLabelHd.setText('?');
            return;
        end
        % Number of dipoles * Number of orientations
        P = 3 * P;
        % Number of faces+vertices
        if isempty(nv)
            N = 0;
        elseif (length(nv) == 1)
            N = nv(1);
        else
            N = sum(nv(2:end) + nf(2:end)) + nv(end);
        end
        % Head geometry
        est_HM    = N*(N+1)/2;
        est_HMINV = N*(N+1)/2;
        est_DSM   = N*P + P*3;
        % MEG
        nchan_meg = length(OPTIONS.iMeg);
        if strcmpi(OPTIONS.MEGMethod, 'openmeeg') && (nchan_meg > 0)
            ninteg_meg = size([OPTIONS.Channel(OPTIONS.iMeg).Loc], 2);
            est_H2MM  = ninteg_meg * N;
            est_DS2MM = ninteg_meg * P;
            est_LMEG  = nchan_meg * P;
            est_GainMEG    = est_DSM + est_HMINV + est_DS2MM + est_LMEG;
            est_GainMEGadj = est_HM + est_DS2MM + est_LMEG + 3*P;
            estHd = estHd + est_H2MM + est_DS2MM + est_LMEG;
        else
            est_GainMEG = 0;
            est_GainMEGadj = 0;
        end
        % EEG
        nchan_eeg = 0;
        if strcmpi(OPTIONS.EEGMethod, 'openmeeg')
            nchan_eeg = nchan_eeg + length(OPTIONS.iEeg);
        end
        if strcmpi(OPTIONS.ECOGMethod, 'openmeeg')
            nchan_eeg = nchan_eeg + length(OPTIONS.iEcog);
        end
        if strcmpi(OPTIONS.SEEGMethod, 'openmeeg')
            nchan_eeg = nchan_eeg + length(OPTIONS.iSeeg);
        end
        if (nchan_eeg > 0)
            est_LEEG       = nchan_eeg * P;
            est_GainEEG    = est_DSM + est_HMINV + est_LEEG;
            est_GainEEGadj = est_HM + est_LEEG + 3*P;
            estHd = estHd + est_LEEG;
        else
            est_GainEEG = 0;
            est_GainEEGadj = 0;
        end
        % Maximum RAM required
        if isAdjoint
            estRam = max(est_GainMEGadj, est_GainEEGadj);
            estHd = estHd + est_HM;
        else
            estRam = max(est_GainMEG, est_GainEEG);
            estHd = estHd + est_HM + est_HMINV + est_DSM;
        end        
        % Update estimations labels
        jLabelRam.setText(sprintf('%d Mb', round(estRam*8/1024/1024)));
        jLabelHd.setText(sprintf('%d Mb', round(estHd*8/1024/1024)));
    end
end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'OpenmeegOptions');
    % Bem layers
    for i = 1:length(ctrl.jCheckLayer)
        s.BemSelect(i) = ctrl.jCheckLayer(i).isSelected();
        s.BemCond(i) = str2num(char(ctrl.jTextCond(i).getText()));
    end
    s.BemNames = ctrl.BemNames;
    s.BemFiles = ctrl.BemFiles;
    % OpenMEEG options
    s.isAdjoint    = ctrl.jCheckAdjoint.isSelected();
    s.isAdaptative = ctrl.jCheckAdaptative.isSelected();
    s.isSplit      = ctrl.jCheckSplit.isSelected();
    s.SplitLength  = str2num(char(ctrl.jTextSplit.getText()));
end



