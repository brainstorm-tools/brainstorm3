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
    sProcess.Comment     = 'Segment MRI with FieldTrip (ft_volumesegment)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 32;
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
    sProcess.options.label1.Comment = '<BR><B>Tissues to segment</B>:';
    sProcess.options.label1.Type    = 'label';
    % Option: White
    sProcess.options.iswhite.Comment = 'White matter';
    sProcess.options.iswhite.Type    = 'checkbox';
    sProcess.options.iswhite.Value   = 0;
    % Option: Gray
    sProcess.options.isgray.Comment = 'Gray matter';
    sProcess.options.isgray.Type    = 'checkbox';
    sProcess.options.isgray.Value   = 0;
    % Option: Brain
    sProcess.options.iscsf.Comment = 'Brain/CSF';
    sProcess.options.iscsf.Type    = 'checkbox';
    sProcess.options.iscsf.Value   = 1;
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
    % Save surface
    sProcess.options.istess.Comment = 'Surface <FONT color="#999999">&nbsp;&nbsp;&nbsp;&nbsp;(for OpenMEEG BEM)</FONT>';
    sProcess.options.istess.Type    = 'checkbox';
    sProcess.options.istess.Value   = 1;
    % Number of vertices
    sProcess.options.nvertwhite.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (white matter): ';
    sProcess.options.nvertwhite.Type    = 'value';
    sProcess.options.nvertwhite.Value   = {15000, '', 0};
    sProcess.options.nvertgray.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (gray matter): ';
    sProcess.options.nvertgray.Type    = 'value';
    sProcess.options.nvertgray.Value   = {15000, '', 0};
    sProcess.options.nvertcsf.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Number of vertices (inner skull): ';
    sProcess.options.nvertcsf.Type    = 'value';
    sProcess.options.nvertcsf.Value   = {1922, '', 0};
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
    if sProcess.options.iscsf.Value
        OPTIONS.layers{end+1} = 'csf';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertcsf.Value{1};
    end
    if sProcess.options.isgray.Value
        OPTIONS.layers{end+1} = 'gray';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertgray.Value{1};
    end
    if sProcess.options.iswhite.Value
        OPTIONS.layers{end+1} = 'white';
        OPTIONS.nVertices(end+1) = sProcess.options.nvertwhite.Value{1};
    end
    if isempty(OPTIONS.layers)
        bst_report('Error', sProcess, [], 'Nothing to extract.');
        return;
    end
    % Get output 
    OPTIONS.isSaveTess = sProcess.options.istess.Value;
    
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
    OPTIONS.layers      = {'scalp', 'skull', 'csf', 'gray', 'white'};
    OPTIONS.nVertices   = [1922, 1922, 1922, 15000, 15000];
    OPTIONS.isSaveTess  = 1;
end


%% ===== COMPUTE =====
function [isOk, errMsg, TissueFile] = Compute(iSubject, iMri, OPTIONS)
    isOk = 0;
    errMsg = '';
    TissueFile = [];
    
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
    % Replace CSF with BRAIN if white/grey not needed
    if ~any(ismember({'white','gray'}, OPTIONS.layers)) && ismember('csf', OPTIONS.layers)
        OPTIONS.layers{ismember(OPTIONS.layers, {'csf'})} = 'brain';
    end
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
        bst_progress('text', 'Calling FieldTrip function: ft_prepare_mesh...');
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
    sMriTissue = [];
    % Save each layer as a volume and a surface
    for i = 1:length(OPTIONS.layers)
        % If layer was not computed
        if ~isfield(ftSegmented, OPTIONS.layers{i}) || isempty(ftSegmented.(OPTIONS.layers{i}))
            continue;
        end
        % Get layer name
        switch (OPTIONS.layers{i})
            case 'white', bemName = 'white';       SurfaceType = 'Cortex';     iTissue = 1;
            case 'gray',  bemName = 'cortex';      SurfaceType = 'Cortex';     iTissue = 2;
            case 'csf',   bemName = 'innerskull';  SurfaceType = 'InnerSkull'; iTissue = 3;
            case 'brain', bemName = 'innerskull';  SurfaceType = 'InnerSkull'; iTissue = 3;
            case 'skull', bemName = 'outerskull';  SurfaceType = 'OuterSkull'; iTissue = 4;
            case 'scalp', bemName = 'scalp';       SurfaceType = 'Scalp';      iTissue = 5;
        end

        % === SAVE AS MRI ===
        bst_progress('text', ['Saving volume: ' OPTIONS.layers{i}]);
        % Convert to Brainstorm MRI structure
        bstSegmented = in_mri_fieldtrip(ftSegmented, OPTIONS.layers{i});
        % Create structure once
        if isempty(sMriTissue)
            sMriTissue = bstSegmented;
        end
        % Copy binary mask to atlas of tissues
        sMriTissue.Cube(bstSegmented.Cube ~= 0) = iTissue;

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
            NewTessFile = file_unique(bst_fullfile(bst_fileparts(file_fullpath(MriFile)), ['tess_' bemName 'bem_ft' fileTag '.mat']));
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

    % ===== SAVE TISSUE ATLAS =====
    % Set comment
    sMriTissue.Comment = file_unique('tissues', {sSubject.Surface.Comment});
    % Copy some fields from the original MRI
    if isfield(sMri, 'SCS') 
        sMriTissue.SCS = sMri.SCS;
    end
    if isfield(sMri, 'NCS') 
        sMriTissue.NCS = sMri.NCS;
    end
    if isfield(sMri, 'History') 
        sMriTissue.History = sMri.History;
    end
    % Add history tag
    sMriTissue = bst_history('add', sMriTissue, 'segment', 'Tissues segmentation generated with ft_volumesegment.');
    % Output file name
    TissueFile = file_unique(strrep(file_fullpath(MriFile), '.mat', '_tissues.mat'));
    % Save new MRI in Brainstorm format
    sMriTissue = out_mri_bst(sMriTissue, TissueFile);
    % Add to subject
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy).Comment  = sMriTissue.Comment;
    sSubject.Anatomy(iAnatomy).FileName = file_short(TissueFile);
    
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
    % Select layers to segment
    isSelect = ismember(OPTIONS.layers, {'scalp', 'skull', 'csf'});
    isSelect = logical(java_dialog('checkbox', 'Select tissues to segment:', 'FieldTrip: ft_volumesegment', [], OPTIONS.layers, isSelect));
    if isempty(isSelect) || all(~isSelect)
        return;
    end
    OPTIONS.layers = OPTIONS.layers(isSelect);
    % Save surfaces
    OPTIONS.isSaveTess = java_dialog('confirm', ['Generate surface meshes?', 10, ...
        'This would be useful for computing OpenMEEG BEM forward models.']);
    % Ask BEM meshing options
    if OPTIONS.isSaveTess
        res = java_dialog('input', OPTIONS.layers, 'Number of vertices', [], cellfun(@num2str, num2cell(OPTIONS.nVertices(isSelect), 1), 'UniformOutput', 0));
        if isempty(res)
            return
        end
        % Get new values
        OPTIONS.nVertices = cellfun(@str2num, res);
        if (length(OPTIONS.nVertices) ~= nnz(isSelect))
            bst_error('Invalid options.', 'FieldTrip BEM mesh', 0);
            return;
        end
    else
        OPTIONS.nVertices = OPTIONS.nVertices(isSelect);
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


