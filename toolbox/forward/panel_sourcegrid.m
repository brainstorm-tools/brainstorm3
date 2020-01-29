function varargout = panel_sourcegrid(varargin)
% PANEL_SOURCEGRID: Options for the construction of volume source grid.
% 
% USAGE:     bstPanel = panel_sourcegrid('CreatePanel', sProcess, sFiles)   : Called from the pipeline editor
%            bstPanel = panel_sourcegrid('CreatePanel', CortexFile)         : Called from the interactive interface
%                grid = panel_sourcegrid('GetPanelContents')                : When called from the interactive interface
%         GridOptions = panel_sourcegrid('GetPanelContents')                : When called from the pipeline editor
%                grid = panel_sourcegrid('GetGrid', GridOptions)

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
% Authors: Francois Tadel, 2011-2016

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'SourceGrid';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % CALL: From GUI
    if (nargin == 1)
        isPreview = 1;
        CortexFile = sProcess;
        sProcess = [];
    % CALL: From Process
    elseif (nargin == 2)
        isPreview = 0;
        CortexFile = [];
    end
    TemplateFile = [];
    isShowGroup = 1;
    % Create main main panel
    jPanelNew = gui_river();

    % Prepare online computation of the grid and preview
    if isPreview
        GridOptions_name = 'GridOptions_headmodel';
        % Default options
        GridOptions = bst_get(GridOptions_name);
        % Create an envelope of the cortex surface
        [sEnvelope, sCortex] = tess_envelope(CortexFile, 'convhull', GridOptions.nVerticesInit, .001, []);
        if isempty(sEnvelope)
            bstPanelNew = [];
            return;
        end
        % Find subject 
        [sSubject, iSubject] = bst_get('SurfaceFile', CortexFile);
        % Load head surface
        if ~isempty(sSubject.iScalp)
            HeadFile = sSubject.Surface(sSubject.iScalp).FileName;
            sHead = bst_memory('LoadSurface', HeadFile);
        else
            HeadFile = CortexFile;
            sHead = sEnvelope;
        end
        % If this is the default subject: do not show the option "use group grid"
        if (iSubject == 0)
            isShowGroup = 0;
        % Else
        else
            % Get the default headmodel file from the group analysis subject
            [sSubjectGroup, iSubjectGroup] = bst_get('Subject', bst_get('NormalizedSubjectName'));
            if ~isempty(sSubjectGroup)
                sStudy = bst_get('DefaultStudy', iSubjectGroup);
                if ~isempty(sStudy.HeadModel) && ~isempty(sStudy.iHeadModel)
                    TemplateFile = sStudy.HeadModel(sStudy.iHeadModel).FileName;
                    GridOptions.FileName = TemplateFile;
                end
            end
        end
    % Calling non-interactive option panel from the pipeline editor
    else
        % Get type of process
        if strcmpi(func2str(sProcess.Function), 'process_ft_dipolefitting')
            GridOptions_name = 'GridOptions_dipfit';
        else
            GridOptions_name = 'GridOptions_headmodel';
        end
        % Get options from the process
        GridOptions = sProcess.options.volumegrid.Value;
        % Get default values if not defined yet
        if isempty(GridOptions)
            GridOptions = bst_get(GridOptions_name);
        end
        % No surfaces
        sEnvelope = [];
        sCortex = [];
        sHead = [];
        HeadFile = [];
    end

    % ===== GRID OPTIONS =====
    jPanelOpt = gui_river([4,5], [0,15,20,10], 'Grid options');
        jButtonGroup = ButtonGroup();
        jButtonGroupSurf = ButtonGroup();
        % RADIO: Generate grid
        jRadioGenerate = gui_component('radio', jPanelOpt, '', 'Generate from cortex surface (adaptive):', jButtonGroup, [], @(h,ev)UpdatePanel, []);
        % nLayers
        gui_component('label', jPanelOpt, 'br', '     ');
        jLabelLayers = gui_component('label', jPanelOpt, '', 'Number of layers: ', [], [], [], []);
        jTextLayers = gui_component('texttime', jPanelOpt, 'tab', num2str(GridOptions.nLayers, '%d'), [], [], [], []);
        java_setcb(jTextLayers, 'ActionPerformedCallback', @(h,ev)OptionsChanged_Callback, ...
                                'FocusLostCallback',       @(h,ev)OptionsChanged_Callback);
        jLabelLayersDef = gui_component('label', jPanelOpt, '', '  (default: 17)', [], [], [], []);
        % Reduction
        gui_component('label', jPanelOpt, 'br', '     ');
        jLabelReduction = gui_component('label', jPanelOpt, '', 'Downsampling factor: ', [], [], [], []);
        jTextReduction = gui_component('texttime', jPanelOpt, 'tab', num2str(GridOptions.Reduction, '%d'), [], [], [], []);
        java_setcb(jTextReduction, 'ActionPerformedCallback', @(h,ev)OptionsChanged_Callback, ...
                                   'FocusLostCallback',       @(h,ev)OptionsChanged_Callback);
        jLabelReductionDef = gui_component('label', jPanelOpt, '', '  (default: 3)', [], [], [], []);
        % nVerticesInit
        gui_component('label', jPanelOpt, 'br', '     ');
        jLabelVertInit = gui_component('label', jPanelOpt, '', 'Initial number of vertices: ', [], [], [], []);
        jTextVertInit = gui_component('texttime', jPanelOpt, 'tab', num2str(GridOptions.nVerticesInit, '%d'), [], [], [], []);
        java_setcb(jTextVertInit, 'ActionPerformedCallback', @(h,ev)OptionsChanged_Callback, ...
                                  'FocusLostCallback',       @(h,ev)OptionsChanged_Callback);
        jLabelVertInitDef = gui_component('label', jPanelOpt, '', '  (default: 4000)', [], [], [], []);
        gui_component('label', jPanelOpt, 'br', ' ');
        
        % RADIO: Isotropic
        jRadioIsotropic = gui_component('radio', jPanelOpt, 'br', 'Regular grid (isotropic):', jButtonGroup, [], @(h,ev)UpdatePanel, []);
        jRadioBrain = gui_component('radio', jPanelOpt, [], 'Brain', jButtonGroupSurf, [], @(h,ev)UpdatePanel, []);
        jRadioHead  = gui_component('radio', jPanelOpt, [], 'Head', jButtonGroupSurf, [], @(h,ev)UpdatePanel, []);
        % Grid resolution
        gui_component('label', jPanelOpt, 'br', '     ');
        jLabelResolution = gui_component('label', jPanelOpt, '', 'Grid resolution: ', [], [], [], []);
        jTextResolution = gui_component('texttime', jPanelOpt, 'tab', num2str(GridOptions.Resolution * 1000), [], [], [], []);
        java_setcb(jTextResolution, 'ActionPerformedCallback', @(h,ev)OptionsChanged_Callback, ...
                                    'FocusLostCallback',       @(h,ev)OptionsChanged_Callback);
        jLabelResUnits = gui_component('label', jPanelOpt, '', ' mm');
        
        % RADIO: Load from file
        jRadioFile = gui_component('radio', jPanelOpt, 'br', 'Load from file [Nx3 double]', jButtonGroup, [], @(h,ev)UpdatePanel, []);
        % Filename
        gui_component('label', jPanelOpt, 'br', '     ');
        jTextFile = gui_component('text', jPanelOpt, 'hfill', '', [], [], [], []);
        jTextFile.setEditable(0);
        jButtonFile = gui_component('button', jPanelOpt, '', '...', [], [], @(h,ev)SelectFileVar, []);
         
        % RADIO: Load from variable
        jRadioVar = gui_component('radio', jPanelOpt, 'br', 'Load from Matlab variable [Nx3 double]', jButtonGroup, [], @(h,ev)UpdatePanel, []);
        gui_component('label', jPanelOpt, 'br', '     ');
        jTextVar = gui_component('text', jPanelOpt, 'hfill', '', [], [], [], []);
        java_setcb(jTextVar, 'ActionPerformedCallback', @(h,ev)UpdatePanel);
        java_setcb(jTextVar, 'FocusLostCallback', @(h,ev)UpdatePanel);
        
        % RADIO: Use template grid for group analysis
        if isShowGroup
            jRadioGroup = gui_component('radio', jPanelOpt, 'br', 'Use template grid for group analysis', jButtonGroup, [], @(h,ev)UpdatePanel, []);
            if ~isempty(TemplateFile) || ~isPreview
                gui_component('label', jPanelOpt, 'br', '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT COLOR="#777777"><I>Loads the grid from the default head model in "Group analysis"</I></FONT>');
            else
                gui_component('label', jPanelOpt, 'br', '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT COLOR="#777777"><I>No head model available in "Group analysis"</I></FONT>');
                jRadioGroup.setEnabled(0);
            end
        else
            jRadioGroup = [];
        end
        
        % Estimated number of vertices
        if isPreview
            gui_component('label', jPanelOpt, 'br', '     ');
            gui_component('label', jPanelOpt, 'br', 'Estimated number of grid points: ', [], [], [], []);
            jLabelPoints = gui_component('label', jPanelOpt, '', '2000', [], [], [], []);
        end
    jPanelNew.add('br hfill', jPanelOpt);
    % Select the appropriate radio button
    switch (GridOptions.Method) 
        case 'adaptive'
            jRadioGenerate.setSelected(1);
            jRadioBrain.setSelected(1);
        case 'isotropic'
            jRadioIsotropic.setSelected(1);
            jRadioBrain.setSelected(1);
        case 'isohead'
            jRadioIsotropic.setSelected(1);
            jRadioHead.setSelected(1);
        case 'file'
            jRadioFile.setSelected(1);
            jTextFile.setText(GridOptions.FileName);
            jRadioBrain.setSelected(1);
        case 'var'
            jRadioVar.setSelected(1);
            jTextVar.setText(GridOptions.FileName);
            jRadioBrain.setSelected(1);
        case 'group'
            if ~isempty(jRadioGroup) && jRadioGroup.isEnabled()
                jRadioGroup.setSelected(1);
            else
                jRadioGenerate.setSelected(1);
            end
            jRadioBrain.setSelected(1);
        otherwise
            jRadioGenerate.setSelected(1);
    end
    
    % ===== VALIDATION BUTTONS =====
    if isPreview
        gui_component('button', jPanelNew, 'br right', 'Preview', [], [], @(h,ev)ShowGrid, []);
        constrNext = [];
    else
        constrNext = 'br right';
    end
    gui_component('button', jPanelNew, constrNext, 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('CortexFile',       CortexFile, ...
                  'HeadFile',         HeadFile, ...
                  'isPreview',        isPreview, ...
                  'GridOptions_name', GridOptions_name, ...
                  'sEnvelope',        sEnvelope, ...
                  'sCortex',          sCortex, ...
                  'sHead',            sHead, ...
                  'jRadioGenerate',   jRadioGenerate, ...
                  'jRadioIsotropic',  jRadioIsotropic, ...
                  'jRadioBrain',      jRadioBrain, ...
                  'jRadioHead',       jRadioHead, ...
                  'jRadioFile',       jRadioFile, ...
                  'jRadioVar',        jRadioVar, ...
                  'jRadioGroup',      jRadioGroup, ...
                  'jTextLayers',      jTextLayers, ...
                  'jTextReduction',   jTextReduction, ...
                  'jTextVertInit',    jTextVertInit, ...
                  'jTextResolution',  jTextResolution, ...
                  'jTextFile',        jTextFile, ...
                  'jTextVar',         jTextVar);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    % Update panel
    UpdatePanel();
    

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close preview window
        hFig = findobj(0, 'type', 'figure', 'tag', 'FigCheckGrid');
        if ~isempty(hFig)
            close(hFig);
        end
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Close preview window
        hFig = findobj(0, 'type', 'figure', 'tag', 'FigCheckGrid');
        if ~isempty(hFig)
            close(hFig);
        end
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== OPTION CHANGED =====
    function OptionsChanged_Callback(varargin)
        % Get new options
        NewOptions.nLayers       = str2double(char(ctrl.jTextLayers.getText()));
        NewOptions.Reduction     = str2double(char(ctrl.jTextReduction.getText()));
        NewOptions.nVerticesInit = str2double(char(ctrl.jTextVertInit.getText()));
        NewOptions.Resolution    = str2double(char(ctrl.jTextResolution.getText())) / 1000;
        % If options changed: update panel
        if ~isequal(NewOptions.nLayers, GridOptions.nLayers) || ~isequal(NewOptions.Reduction, GridOptions.Reduction) || ~isequal(NewOptions.nVerticesInit, GridOptions.nVerticesInit) || ~isequal(NewOptions.Resolution, GridOptions.Resolution)
            GridOptions = NewOptions;
            UpdatePanel();
        end
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        global gGridLoc;
        % RADIO: Generate
        isGenerate = jRadioGenerate.isSelected();
        jTextLayers.setEnabled(isGenerate);
        jLabelLayers.setEnabled(isGenerate);
        jLabelLayersDef.setEnabled(isGenerate);
        jTextReduction.setEnabled(isGenerate);
        jLabelReduction.setEnabled(isGenerate);
        jLabelReductionDef.setEnabled(isGenerate);
        jTextVertInit.setEnabled(isGenerate);
        jLabelVertInit.setEnabled(isGenerate);
        jLabelVertInitDef.setEnabled(isGenerate);
        % RADIO: Isotropic
        isIsotropic = jRadioIsotropic.isSelected();
        jLabelResolution.setEnabled(isIsotropic);
        jTextResolution.setEnabled(isIsotropic);
        jRadioBrain.setEnabled(isIsotropic);
        jRadioHead.setEnabled(isIsotropic);
        jLabelResUnits.setEnabled(isIsotropic);
        % RADIO: File
        isFile = jRadioFile.isSelected();
        jTextFile.setEnabled(isFile);
        jButtonFile.setEnabled(isFile);
        % RADIO: Variable
        isVar = jRadioVar.isSelected();
        jTextVar.setEnabled(isVar);
        % Preview grid
        if isPreview
            % Get the options
            GridOptions = GetOptions(ctrl);
            % Get grid of source points
            if strcmpi(GridOptions.Method, 'isohead')
                [gGridLoc, ctrl.sEnvelope] = GetGrid(GridOptions, ctrl.HeadFile, ctrl.sHead, ctrl.sHead);
            else
                [gGridLoc, ctrl.sEnvelope] = GetGrid(GridOptions, ctrl.CortexFile, ctrl.sCortex, ctrl.sEnvelope);
            end
            % Variable not found
            if strcmpi(GridOptions.Method, 'var') && isempty(gGridLoc)
                ctrl.jTextVar.setText('');
            end
            % Count number of points
            if ~isempty(gGridLoc)
                nTotal = length(gGridLoc);
            else
                nTotal = 0;
            end
            % Display new estimation
            jLabelPoints.setText(num2str(nTotal));
            % Get previous window: If it exists, update it
            if (nTotal ~= 0)
                hFig = findobj(0, 'type', 'figure', 'tag', 'FigCheckGrid');
                if ~isempty(hFig)
                    ShowGrid();
                end
            end
        end
    end

%% ===== SELECT FILE =====
    function SelectFileVar()
        % Get file
        filename = java_getfile( 'open', 'Import grid of points', '', 'single', 'files', ...
                                {{'*'}, 'Matlab or ASCII files (*.mat;*.*)', 'ALL'}, 1);
        % Update panel
        if ~isempty(filename)
            jTextFile.setText(filename);
        end
        UpdatePanel();
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
    global gGridLoc;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'SourceGrid');
    if isempty(ctrl)
        return;
    end
    % Get grid options
    GridOptions = GetOptions(ctrl);
    % Save the new options
    bst_set(ctrl.GridOptions_name, GridOptions);
    % For "group" option: Get the default template grid
    if isequal(GridOptions.Method, 'group') && isempty(GridOptions.FileName)
        GridOptions.FileName = GetDefaultGridFile();
    end
    % GUI: Return previewed grid
    if ctrl.isPreview
        s.GridLoc = gGridLoc;
        s.GridOptions = GridOptions;
        gGridLoc = [];
        clear gGridLoc;
    % Process: Return selected options
    else
        s = GridOptions;
    end
end


%% ===== GET OPTIONS =====
function GridOptions = GetOptions(ctrl)
    % Get default structure
    GridOptions = bst_get(ctrl.GridOptions_name);
    % Get computation mode
    if ctrl.jRadioGenerate.isSelected()
        GridOptions.Method = 'adaptive';
    elseif ctrl.jRadioIsotropic.isSelected()
        if ctrl.jRadioBrain.isSelected()
            GridOptions.Method = 'isotropic';
        elseif ctrl.jRadioHead.isSelected()
            GridOptions.Method = 'isohead';
        end
    elseif ctrl.jRadioFile.isSelected()
        GridOptions.Method = 'file';
    elseif ctrl.jRadioVar.isSelected()
        GridOptions.Method = 'var';
    elseif isfield(ctrl, 'jRadioGroup') && ~isempty(ctrl.jRadioGroup) && ctrl.jRadioGroup.isSelected()
        GridOptions.Method = 'group';
    else
        GridOptions.Method = 'adaptive';
    end
    % Adaptive options
    GridOptions.nLayers       = str2double(char(ctrl.jTextLayers.getText()));
    GridOptions.Reduction     = str2double(char(ctrl.jTextReduction.getText()));
    GridOptions.nVerticesInit = str2double(char(ctrl.jTextVertInit.getText()));
    % Check for errors
    if isnan(GridOptions.nLayers) || isnan(GridOptions.Reduction) || isnan(GridOptions.nVerticesInit)
        bst_error('Invalid values.', 'Generate grid', 0);
        GridOptions = [];
        return
    end
    % Isotropic options
    GridOptions.Resolution = str2double(char(ctrl.jTextResolution.getText())) / 1000;
    % External inputs
    if strcmpi(GridOptions.Method, 'file')
        GridOptions.FileName = char(ctrl.jTextFile.getText());
    elseif strcmpi(GridOptions.Method, 'var')
        GridOptions.FileName = char(ctrl.jTextVar.getText());
    else
        GridOptions.FileName = [];
    end
end


%% ===== GET GRID =====
% USAGE:  [grid, sEnvelope] = GetGrid(GridOptions, CortexFile, sCortex, sEnvelope)
%                      grid = GetGrid(GridOptions, CortexFile)
function [grid, sEnvelope] = GetGrid(GridOptions, CortexFile, sCortex, sEnvelope)
    grid = [];
    % Progress bar
    bst_progress('start', 'Volume grid', 'Creating grid...');
    % Surfaces are not loaded yet
    if (nargin < 4) || isempty(sCortex) || isempty(sEnvelope)
        % Create an envelope of the cortex surface
        [sEnvelope, sCortex] = tess_envelope(CortexFile, 'convhull', GridOptions.nVerticesInit, .001, []);
        if isempty(sEnvelope)
            return;
        end
    end
    % Switch between methods
    switch (GridOptions.Method)
        case 'adaptive'
            % If default number of points changed, remesh envelope
            if (GridOptions.nVerticesInit ~= 4000)
                center = mean(sEnvelope.Vertices);
                sEnvelope.Vertices = bst_bsxfun(@minus, sEnvelope.Vertices, center);
                [sEnvelope.Vertices, sEnvelope.Faces] = tess_remesh(sEnvelope.Vertices, GridOptions.nVerticesInit);
                sEnvelope.Vertices = bst_bsxfun(@plus, sEnvelope.Vertices, center);
            end
            % Compute grid
            grid = bst_sourcegrid(GridOptions, CortexFile, sCortex, sEnvelope);
        case {'isotropic', 'isohead'}
            % Compute grid
            grid = bst_sourcegrid(GridOptions, CortexFile, sCortex, sEnvelope);
        case {'file', 'var'}
            % Read grid
            if ~isempty(GridOptions.FileName)
                grid = ReadGrid(GridOptions.FileName, GridOptions.Method);
            end
        case 'group'
            % === GET SUBJECT ===
            % Get subject using cortex surface
            [sSubject, iSubject] = bst_get('SurfaceFile', CortexFile);
            if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
                return;
            end
            % Load subject MRI
            SubjectMriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            sMriSubject = in_mri_bst(SubjectMriFile);

            % === GET TEMPLATE SUBJECT ===
            % For "group" option: Get the default template grid
            if isempty(GridOptions.FileName)
                GridOptions.FileName = GetDefaultGridFile();
                if isempty(GridOptions.FileName)
                    return;
                end
            end
            % Get template study using the grid file
            [sStudyGroup, iStudyGroup] = bst_get('HeadModelFile', GridOptions.FileName);
            if isempty(sStudyGroup)
                return;
            end
            % Get template subject
            [sSubjectGroup, iSubjectGroup] = bst_get('Subject', sStudyGroup.BrainStormSubject);
            if isempty(sSubjectGroup) || isempty(sSubjectGroup.Anatomy) || isempty(sSubjectGroup.iAnatomy)
                return;
            end
            % Load template MRI
            GroupMriFile = sSubjectGroup.Anatomy(sSubjectGroup.iAnatomy).FileName;
            sMriGroup = in_mri_bst(GroupMriFile);
            
            % === CONVERT TEMPLATE GRID TO SUBJECT SPACE ===
            % Load grid file             
            HeadModelMat = in_bst_headmodel(GridOptions.FileName, 0, 'GridLoc');
            gridGroup = HeadModelMat.GridLoc;
            if isempty(gridGroup)
                return;
            end
            % Convert grid coordinates: Template SCS => MNI
            gridMni = cs_convert(sMriGroup, 'scs', 'mni', gridGroup);
            if isempty(gridMni)
                return;
            end
            % Display warning when transformation is not available
            if ~isfield(sMriSubject, 'NCS') || isempty(sMriSubject.NCS) || ~isfield(sMriSubject.NCS, 'R') ||  isempty(sMriSubject.NCS.R)
                disp('PROJECT> Error: The MNI transformation is not available for this subject.');
            end
            % Convert grid coordinates: MNI => Subject SCS
            grid = cs_convert(sMriSubject, 'mni', 'scs', gridMni);
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== GET DEFAULT GRID FILE =====
function HeadModelFile = GetDefaultGridFile()
    HeadModelFile = [];
    % Get the group analysis subject
    [sSubjectGroup, iSubjectGroup] = bst_get('Subject', bst_get('NormalizedSubjectName'));
    if isempty(sSubjectGroup) || isempty(sSubjectGroup.Anatomy) || isempty(sSubjectGroup.iAnatomy)
        return;
    end
    % Get default study of group analysis subject
    sStudy = bst_get('DefaultStudy', iSubjectGroup);
    % Exit if there is no head model in this subject
    if isempty(sStudy.HeadModel) || isempty(sStudy.iHeadModel)
        return;
    end
    % Return default headmodel file            
    HeadModelFile = sStudy.HeadModel(sStudy.iHeadModel).FileName;
end


%% ===== READ GRID =====
function grid = ReadGrid(varname, Method)
    grid = [];
    % Read matrix from file
    if strcmpi(Method, 'file')
        FileName = varname;
        % File doesn't exist
        if ~file_exist(FileName)
            disp(['Error: File does not exist: ' 10 FileName]);
            return;
        end
        % Get extension
        [tmp, tmp, fExt] = bst_fileparts(FileName);
        % Matlab matrix
        if strcmpi(fExt, '.mat')
            % Other kinds of files
            try
                % Load file
                filemat = load(varname);
                % Get field "GridLoc" if it exists
                if isfield(filemat, 'GridLoc')
                    grid = filemat.GridLoc;
                else
                    allfields = fieldnames(filemat);
                    if (length(allfields) == 1)
                        grid = filemat.(allfields{1});
                    end
                end
                % Return an error if there is more than one matrix
                if isempty(grid)
                    disp('Error: The file must be a valid Brainstorm headmodel file, or a Matlab matrix with only one variable.');
                end
            catch
                disp('Error: Cannot read as .mat file.');
            end
        % ASCII file
        else
            % Other kinds of files
            try
                grid = load(varname, '-ascii');
            catch
                disp('Error: Cannot read as ASCII file.');
            end
        end
    % Read matrix from variable in base workspace
    elseif strcmpi(Method, 'var')
        grid = in_matlab_var(varname, 'numeric');
    else
        error('Unknown method.');
    end
    % Re-orient matrix
    if ~isempty(grid)
        if (size(grid,1) ~= 3) && (size(grid,2) ~= 3)
            disp('BST> Invalid grid format. Matrix must be [Nx3].');
        elseif (size(grid,1) == 3) && (size(grid,2) ~= 3)
            grid = grid';
        end
    end
end

%% ===== SHOW GRID =====
function ShowGrid()
    global gGridLoc;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'SourceGrid');
    if isempty(ctrl)
        return;
    end
    % Get previous window
    hFig = findobj(0, 'type', 'figure', 'tag', 'FigCheckGrid');
    % If there is no grid to show
    if isempty(gGridLoc)
        % Close existing figure
        if ~isempty(hFig)
            close(hFig);
        end
        return;
    end
    % Create figure if it doesnt exist + show surface
    if isempty(hFig)
        hFig = view_surface(ctrl.CortexFile, .9, [.6 .6 .6], 'NewFigure');
        set(hFig, 'Tag', 'FigCheckGrid');
    % Figure exists: remove previous points
    else
        delete(findobj(hFig, 'tag', 'ptCheckGrid'));
        % Focus on figure
        figure(hFig);
    end
    % No points to show: exit
    if isempty(gGridLoc)
        return;
    end
    % Get axes
    hAxes = findobj(hFig, 'Tag', 'Axes3D');
    % Show grid points
    line(gGridLoc(:,1), gGridLoc(:,2), gGridLoc(:,3), 'LineStyle', 'none', ...
         'Color', [0 1 0], 'MarkerSize', 2, 'Marker', '.', ...
         'Tag', 'ptCheckGrid', 'Parent', hAxes);
end

