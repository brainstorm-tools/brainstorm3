function varargout = process_ft_volumesegment( varargin )
% PROCESS_FT_VOLUMESEGMENT: Call FieldTrip function ft_volumesegment.
%
% REFERENCES: 
%     - http://www.fieldtriptoolbox.org/faq/how_is_the_segmentation_defined

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
% Authors: Francois Tadel, 2016-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_volumesegment';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 31;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/faq/how_is_the_segmentation_defined';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import', 'data'};
    sProcess.OutputTypes = {'import', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment    = 'Subject name:';
    sProcess.options.subjectname.Type       = 'subjectname';
    sProcess.options.subjectname.Value      = 'NewSubject';
    sProcess.options.subjectname.InputTypes = {'import'};
    % Label
    sProcess.options.label1.Comment = '<BR><B>Layers to extract</B>:';
    sProcess.options.label1.Type    = 'label';
    % Option: Brain
    sProcess.options.isbrain.Comment = 'Brain';
    sProcess.options.isbrain.Type    = 'checkbox';
    sProcess.options.isbrain.Value   = 1;
    % Option: Skull
    sProcess.options.isskull.Comment = 'Skull <FONT color="#999999">&nbsp;&nbsp;&nbsp;&nbsp;(requires the Image Processing toolbox)</FONT>';
    sProcess.options.isskull.Type    = 'checkbox';
    sProcess.options.isskull.Value   = 1;
    % Option: Scalp
    sProcess.options.isscalp.Comment = 'Scalp <FONT color="#999999">&nbsp;&nbsp;&nbsp;&nbsp;(requires the Image Processing toolbox)</FONT>';
    sProcess.options.isscalp.Type    = 'checkbox';
    sProcess.options.isscalp.Value   = 1;
    % Label
    sProcess.options.label2.Comment = '<BR><B>Files to save for each layer</B>:';
    sProcess.options.label2.Type    = 'label';
    % Save MRI
    sProcess.options.ismri.Comment = 'MRI mask <FONT color="#999999">&nbsp;&nbsp;&nbsp;&nbsp;(for FieldTrip headmodels)</FONT>';
    sProcess.options.ismri.Type    = 'checkbox';
    sProcess.options.ismri.Value   = 1;
    % Save surface
    sProcess.options.istess.Comment = 'Surface <FONT color="#999999">&nbsp;&nbsp;&nbsp;&nbsp;(for OpenMEEG BEM)</FONT>';
    sProcess.options.istess.Type    = 'checkbox';
    sProcess.options.istess.Value   = 1;
    % Number of vertices 
    sProcess.options.nvertbrain.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (inner skull): ';
    sProcess.options.nvertbrain.Type    = 'value';
    sProcess.options.nvertbrain.Value   = {1922, '', 0};
    sProcess.options.nvertskull.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (outer skull): ';
    sProcess.options.nvertskull.Type    = 'value';
    sProcess.options.nvertskull.Value   = {1922, '', 0};
    sProcess.options.nvertscalp.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (head): ';
    sProcess.options.nvertscalp.Type    = 'value';
    sProcess.options.nvertscalp.Value   = {1922, '', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = [];
    % Not supported in compiled version
    if exist('isdeployed', 'builtin') && isdeployed
        error('Not supported in compiled version yet. Post a message on the forum if you need this feature.');
    end

    % ===== GET OPTIONS =====
    % If data file in input: get the subject from the input
    if strcmpi(sInputs(1).FileType, 'data')
        SubjectNames = unique({sInputs.SubjectName});
    % Otherwise, the subject name should be specified in input
    else
        % Get subject name
        SubjectNames = file_standardize(sProcess.options.subjectname.Value);
        if isempty(SubjectNames)
            bst_report('Error', sProcess, [], 'Subject name is empty.');
            return;
        end
        SubjectNames = {SubjectNames};
    end
    % Get selections
    OPTIONS.layers = {};
    OPTIONS.nVertices = [];
    if sProcess.options.isscalp.Value
        OPTIONS.layers{end+1} = 'scalp';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertscalp.Value{1};
        if ~exist('imfill','file')
            bst_report('Error', sProcess, [], 'Extracting the scalp requires the Image Processing toolbox.');
            return;
        end
    end
    if sProcess.options.isskull.Value
        OPTIONS.layers{end+1} = 'skull';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertskull.Value{1};
        if ~exist('imdilate','file')
            bst_report('Error', sProcess, [], 'Extracting the skull requires the Image Processing toolbox.');
            return;
        end
    end
    if sProcess.options.isbrain.Value
        OPTIONS.layers{end+1} = 'brain';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertbrain.Value{1};
    end
    if isempty(OPTIONS.layers)
        bst_report('Error', sProcess, [], 'Nothing to extract.');
        return;
    end
    % Get output 
    OPTIONS.isSaveTess = sProcess.options.istess.Value;
    OPTIONS.isSaveMri  = sProcess.options.ismri.Value;
    
    % ===== LOOP ON SUBJECTS =====
    for isub = 1:length(SubjectNames)
        % Get subject 
        [sSubject, iSubject] = bst_get('Subject', SubjectNames{isub});
        if isempty(iSubject)
            bst_report('Error', sProcess, [], ['Subject "' SubjectNames{isub} '" does not exist.']);
            return
        end
        % Check if a MRI is available for the subject
        if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
            bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectNames{isub} '".']);
            return
        end
        
        % Initialize progress bar
        bst_progress('start', 'ft_volumesegment', 'Initializing...');
        % Call processing function
        [isOk, errMsg] = Compute(iSubject, sSubject.iAnatomy, OPTIONS);
        % Handling errors
        if ~isOk
            bst_report('Error', sProcess, [], errMsg);
        elseif ~isempty(errMsg)
            bst_report('Warning', sProcess, [], errMsg);
        end
    end

    % Return nothing
    OutputFiles = {sInputs.FileName};
end


%% ===== DEFAULT OPTIONS =====
function OPTIONS = GetDefaultOptions()
    OPTIONS.layers      = {'scalp', 'skull', 'brain'};
    OPTIONS.nVertices   = [1922, 1922, 1922];
    OPTIONS.isSaveTess  = 1;
    OPTIONS.isSaveMri   = 1;
end


%% ===== COMPUTE =====
function [isOk, errMsg] = Compute(iSubject, iMri, OPTIONS)
    isOk = 0;
    errMsg = '';

    % ===== DEFAULT OPTIONS =====
    Def_OPTIONS = GetDefaultOptions();
    if isempty(OPTIONS)
        OPTIONS = Def_OPTIONS;
    else
        OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
    end
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    % If not specified, use default MRI
    if isempty(iMri)
        iMri = sSubject.iAnatomy;
    end

    % ===== LOAD INPUT =====
    % Load Brainstorm MRI
    MriFile = sSubject.Anatomy(iMri).FileName;
    sMri = in_mri_bst(MriFile);
    % Convert to FieldTrip structure
    ftMri = out_fieldtrip_mri(sMri);

    % ===== CALL FIELDTRIP =====
    % Initialize fieldtrip
    bst_ft_init();
    % Run ft_volumesegment: Tissue segmentation
    bst_progress('text', 'Calling FieldTrip function: ft_volumesegment...');
    cfg = [];
    cfg.output = OPTIONS.layers;
    ftSegmented = ft_volumesegment(cfg, ftMri);    
    % Check if something was returned
    if isempty(ftSegmented)
        errMsg = 'Something went wrong during the execution of the FieldTrip function ft_volumesegment. Check the command window...';
        return;
    end
    % Run ft_prepare_mesh: Mesh the different layers
    if OPTIONS.isSaveTess
        bst_progress('text', 'Calling FieldTrip funciton: ft_prepare_mesh...');
        cfg = [];
        cfg.tissue = OPTIONS.layers;
        cfg.numvertices = OPTIONS.nVertices;
        ftMesh = ft_prepare_mesh(cfg, ftSegmented);
        if isempty(ftMesh)
            errMsg = 'Something went wrong during the execution of the FieldTrip function ft_prepare_mesh. Check the command window...';
            return;
        end
    end

    % ===== SAVE OUTPUT IN DATABASE =====
    % Save each layer as a volume and a surface 
    for i = 1:length(OPTIONS.layers)
        % If layer was not computed
        if ~isfield(ftSegmented, OPTIONS.layers{i}) || isempty(ftSegmented.(OPTIONS.layers{i}))
            continue;
        end
        % Get layer name
        switch (OPTIONS.layers{i})
            case 'brain', bemName = 'innerskull';  SurfaceType = 'InnerSkull';
            case 'skull', bemName = 'outerskull';  SurfaceType = 'OuterSkull';
            case 'scalp', bemName = 'scalp';       SurfaceType = 'Scalp';
        end

        % === SAVE AS MRI ===
        bst_progress('text', ['Saving volume: ' OPTIONS.layers{i}]);
        % Convert to Brainstorm MRI structure
        sNewMri = in_mri_fieldtrip(ftSegmented, OPTIONS.layers{i});
        % Set comment
        sNewMri.Comment = file_unique(['mask_' bemName], {sSubject.Anatomy.Comment});
        % Copy some fields from the original MRI
        if isfield(sMri, 'SCS') 
            sNewMri.SCS = sMri.SCS;
        end
        if isfield(sMri, 'NCS') 
            sNewMri.NCS = sMri.NCS;
        end
        if isfield(sMri, 'History') 
            sNewMri.History = sMri.History;
        end
        % Add history tag
        sNewMri = bst_history('add', sNewMri, 'segment', 'MRI processed with ft_volumesegment.');
        % Output file name
        NewMriFile = file_unique(strrep(file_fullpath(MriFile), '.mat', ['_', OPTIONS.layers{i}, '.mat']));
        % If we want the file in the database
        if OPTIONS.isSaveMri
            % Save new MRI in Brainstorm format
            sNewMri = out_mri_bst(sNewMri, NewMriFile);
            % Add to subject
            iAnatomy = length(sSubject.Anatomy) + 1;
            sSubject.Anatomy(iAnatomy).Comment  = sNewMri.Comment;
            sSubject.Anatomy(iAnatomy).FileName = file_short(NewMriFile);
        end

        % === SAVE AS SURFACE ===
        % If we want the surface in the database
        if OPTIONS.isSaveTess
            bst_progress('text', ['Saving surface: ' OPTIONS.layers{i}]);             
            % Create surface structure
            sTess = db_template('surfacemat');
            sTess.Vertices = ftMesh(i).pos;
            sTess.Faces    = ftMesh(i).tri;
            % Set comment
            fileTag = sprintf('_%dV', OPTIONS.nVertices(i));
            sTess.Comment = file_unique(['bem_' bemName '_ft' fileTag], {sSubject.Surface.Comment});
            % Output file name
            NewTessFile = file_unique(bst_fullfile(bst_fileparts(NewMriFile), ['tess_' bemName 'bem_ft' fileTag '.mat']));
            % Save file
            bst_save(NewTessFile, sTess, 'v7');
            % Add to subject
            iSurface = length(sSubject.Surface) + 1;
            sSubject.Surface(iSurface).Comment     = sTess.Comment;
            sSubject.Surface(iSurface).FileName    = file_short(NewTessFile);
            sSubject.Surface(iSurface).SurfaceType = SurfaceType;
            % Save subject
            bst_set('Subject', iSubject, sSubject);
            % Set surface type
            sSubject = db_surface_default(iSubject, SurfaceType, iSurface, 0);
        end
    end

    % ===== UPDATE GUI =====
    % Save subject
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    % Save database
    db_save();
    isOk = 1;
end


%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iMris) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iMris)
        iMris = [];
    end
    % Get default options
    OPTIONS = GetDefaultOptions();
    if ~isequal(OPTIONS.layers, {'scalp', 'skull', 'brain'})
        error('Fix the default options');
    end
    % Ask BEM meshing options
    res = java_dialog('input', {'Number of vertices (head):', 'Number of vertices (outer skull):', 'Number of vertices (inner skull):'}, ...
        'FieldTrip BEM meshes', [], {num2str(OPTIONS.nVertices(1)), num2str(OPTIONS.nVertices(2)), num2str(OPTIONS.nVertices(3))});
    if isempty(res)
        return
    end
    % Get new values
    OPTIONS.nVertices = [str2num(res{1}), str2num(res{2}), str2num(res{3})];
    if (length(OPTIONS.nVertices) ~= 3)
        bst_error('Invalid options.', 'FieldTrip BEM mesh', 0);
        return
    end
 
    % Open progress bar
    bst_progress('start', 'Generate BEM mesh', 'Initialization...');
    % Generate BEM mesh
    [isOk, errMsg] = Compute(iSubject, iMris, OPTIONS);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FieldTrip BEM mesh', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end


