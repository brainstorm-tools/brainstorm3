function varargout = panel_femname(varargin)
% PANEL_FEMNAME  Rename and/or merge layers in FEM tetrahedral mesh.
%
% USAGE:  bstPanel = panel_femname('CreatePanel', OPTIONS)           : Call from the interactive interface
%         bstPanel = panel_femname('CreatePanel', sProcess, sFiles)  : Call from the process editor
%                s = panel_femname('GetPanelContents')
%                    panel_femname('Edit', FemFile, NewLabels)       : Rename the tissues and merge the ones with the same labels
%                    panel_femname('Edit', FemFile)                  : Edit FEM mesh interactively

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
% Authors: Francois Tadel, 2023

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)
    panelName = 'FemNameOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % GUI CALL:  panel_femcname('CreatePanel', OPTIONS)
    if (nargin == 1)
        OPTIONS = sProcess;
    % PROCESS CALL:  panel_femname('CreatePanel', sProcess, sFiles)
    else
        OPTIONS = sProcess.options.femname.Value;
        % Get FEM files
        sSubject = bst_get('Subject', sProcess.options.subjectname.Value);
        if isempty(sSubject.iFEM)
            error('No available FEM mesh file for this subject.');
        end
        OPTIONS.FemFile = file_fullpath(sSubject.Surface(sSubject.iFEM).FileName);
    end
    
    % ==== GET MESH INFO ====
    % Load tissue labels
    FemMat = load(OPTIONS.FemFile, 'TissueLabels');
    OldLabels = FemMat.TissueLabels;

    % ==== FRAME STRUCTURE ====
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));

    % ===== FEM LAYERS =====
    jPanelLayers = gui_river([25,6], [0,6,15,6]);
        nLayers = length(OldLabels);
        jTextLabel = javaArray('javax.swing.JTextField', nLayers);
        % Title
        gui_component('label', jPanelLayers, '', '<HTML><B>Old label</B>', [], [], [], []);
        gui_component('label', jPanelLayers, 'tab', '<HTML><B>New label</B>', [], [], [], []);
        % Loop on each layer
        for i = 1:nLayers
            gui_component('label', jPanelLayers, 'br', [OldLabels{i} ''], [], [], [], []);
            jTextLabel(i) = gui_component('text', jPanelLayers, 'tab hfill', OldLabels{i}, [], [], [], []);
        end
    jPanelNew.add(jPanelLayers);

    % ===== INFO PANEL =====
    jPanelInfo = gui_river([2,2], [6,6,6,6]);
        gui_component('label', jPanelInfo, '', '<HTML>- Tissues with the same label will be merged<BR>- Tissues with an empty name will be removed', [], [], [], []);
    jPanelNew.add(jPanelInfo);
    
    % ===== VALIDATION BUTTONS =====
    jPanelValidation = gui_river([10 0], [6 10 0 10]);
        gui_component('Button', jPanelValidation, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
        gui_component('Button', jPanelValidation, [], 'OK', [], [], @ButtonOk_Callback, []);
    jPanelNew.add(jPanelValidation);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct('jTextLabel', jTextLabel);
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
end


%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'FemNameOptions');
    if isempty(ctrl)
        s = [];
        return; 
    end
    % FEM layers
    s.NewLabels = cell(1, length(ctrl.jTextLabel));
    for i = 1:length(ctrl.jTextLabel)
        s.NewLabels{i} = strtrim(lower(char(ctrl.jTextLabel(i).getText())));
    end
end


%% ===== EDIT FEM MESH =====
function NewFile = Edit(FemFile, NewLabels)
    NewFile = [];
    % Parse inputs
    if (nargin < 2)
        NewLabels = [];
    end
    % If new labels are not defined, ask user interactively
    if isempty(NewLabels)
        OPTIONS.FemFile = FemFile;
        LabelOptions = gui_show_dialog('Edit tissue labels', @panel_femname, 1, [], OPTIONS);
        if isempty(LabelOptions)
            return;
        end
        NewLabels = LabelOptions.NewLabels;
    end
    
    % Load FEM mesh
    bst_progress('start', 'Convert FEM mesh', ['Loading file: "' FemFile '"...']);
    FemFile = file_fullpath(FemFile);
    FemMat = load(FemFile);

    % If labels did not change
    if isequal(NewLabels, FemMat.TissueLabels) || all(cellfun(@isempty, NewLabels))
        bst_progress('stop');
        return;
    end

    % Delete tissues marked for removal
    iTissueDel = find(cellfun(@isempty, NewLabels));
    if ~isempty(iTissueDel)
        NewLabels(iTissueDel) = [];
        FemMat.TissueLabels(iTissueDel) = [];
        % Find elements from these tissues
        iElemDel = find(ismember(FemMat.Tissue, iTissueDel));
        if ~isempty(iElemDel)
            FemMat.Tissue(iElemDel) = [];
            FemMat.Elements(iElemDel,:) = [];
        end
    end

    % Relabel all tissues
    FemMat.TissueLabels = unique(NewLabels, 'stable');
    iRelabel = cellfun(@(c)find(strcmp(c, FemMat.TissueLabels)), NewLabels);
    FemMat.Tissue = reshape(iRelabel(FemMat.Tissue), [], 1);

    % Edit file comment: number of layers
    oldNlayers = regexp(FemMat.Comment, '\d+ layers', 'match');
    if ~isempty(oldNlayers)
        FemMat.Comment = strrep(FemMat.Comment, oldNlayers{1}, sprintf('%d layers', length(FemMat.TissueLabels)));
    else
        FemMat.Comment = sprintf('%s (%d layers)', str_remove_parenth(FemMat.Comment), length(FemMat.TissueLabels));
    end
    % Edit file comment: number of nodes
    oldNvert = regexp(FemMat.Comment, '\d+V', 'match');
    if ~isempty(oldNvert)
        FemMat.Comment = strrep(FemMat.Comment, oldNvert{1}, sprintf('%dV', size(FemMat.Vertices, 1)));
    end

    % Output filename
    [fPath, fBase, fExt] = bst_fileparts(FemFile);
    NewFile = file_unique(bst_fullfile(fPath, [fBase, '_merge', fExt]));
    % Save new surface in Brainstorm format
    bst_progress('text', 'Saving new mesh...');    
    bst_save(NewFile, FemMat, 'v7');
    % Add to database
    [sSubject, iSubject] = bst_get('SurfaceFile', FemFile);
    db_add_surface(iSubject, NewFile, FemMat.Comment);

    % Close progress bar
    bst_progress('stop');
end


