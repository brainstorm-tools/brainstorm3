function varargout = process_ft_volumesegment( varargin )
% PROCESS_FT_DIPOLEFITTING: Call FieldTrip function ft_volumesegment.
%
% REFERENCES: 
%     - http://www.fieldtriptoolbox.org/faq/how_is_the_segmentation_defined

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_volumesegment';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 11;
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
    sProcess.options.nvertices.Comment = 'Number of vertices (default=1922, 0=original): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {1922, '', 0};
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
    % Initialize fieldtrip
    bst_ft_init();

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
    layers = {};
    if sProcess.options.isscalp.Value
        layers{end+1} = 'scalp';
        if ~exist('imfill','file')
            bst_report('Error', sProcess, [], 'Extracting the scalp requires the Image Processing toolbox.');
            return;
        end
    end
    if sProcess.options.isskull.Value
        layers{end+1} = 'skull';
        if ~exist('imdilate','file')
            bst_report('Error', sProcess, [], 'Extracting the skull requires the Image Processing toolbox.');
            return;
        end
    end
    if sProcess.options.isbrain.Value
        layers{end+1} = 'brain';
    end
    if isempty(layers)
        bst_report('Error', sProcess, [], 'Nothing to extract.');
        return;
    end
    % Get output 
    isSaveTess = sProcess.options.istess.Value;
    isSaveMri  = sProcess.options.ismri.Value;
    nVertices  = sProcess.options.nvertices.Value{1};
    
    % ===== LOOP ON SUBJECTS =====
    for isub = 1:length(SubjectNames)

        % ===== GET SUBJECT =====
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

        % ===== CALL FIELDTRIP =====
        % Load Brainstorm MRI
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        sMri = in_mri_bst(MriFile);
        % Convert to FieldTrip structure
        ftMri = out_fieldtrip_mri(sMri);    
        % Initialize progress bar
        bst_progress('start', 'ft_dipolefitting', 'Calling FieldTrip function: ft_volumesegment...');
        % Prepare FieldTrip cfg structure
        cfg        = [];
        cfg.output = layers;
        % Run ft_volumesegment
        ftSegmented  = ft_volumesegment(cfg, ftMri);    
        % Check if something was returned
        if isempty(ftSegmented)
            bst_report('Error', sProcess, sInputs, 'Something went wrong during the execution of the FieldTrip function. Check the command window...');
            return;
        end

        % ===== SAVE OUTPUT IN DATABASE =====
        % Save each layer as a volume and a surface 
        for i = 1:length(layers)
            % If layer was not computed
            if ~isfield(ftSegmented, layers{i}) || isempty(ftSegmented.(layers{i}))
                continue;
            end
            % Get layer name
            switch (layers{i})
                case 'brain', bemName = 'innerskull';  SurfaceType = 'InnerSkull';
                case 'skull', bemName = 'outerskull';  SurfaceType = 'OuterSkull';
                case 'scalp', bemName = 'scalp';       SurfaceType = 'Scalp';
            end
            
            % === SAVE AS MRI ===
            bst_progress('text', ['Saving volume: ' layers{i}]);
            % Convert to Brainstorm MRI structure
            sNewMri = in_mri_fieldtrip(ftSegmented, layers{i});
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
            NewMriFile = file_unique(strrep(file_fullpath(MriFile), '.mat', ['_', layers{i}, '.mat']));
            % If we want the file in the database
            if isSaveMri
                % Save new MRI in Brainstorm format
                sNewMri = out_mri_bst(sNewMri, NewMriFile);
                % Add to subject
                iAnatomy = length(sSubject.Anatomy) + 1;
                sSubject.Anatomy(iAnatomy).Comment  = sNewMri.Comment;
                sSubject.Anatomy(iAnatomy).FileName = file_short(NewMriFile);
            end

            % === SAVE AS SURFACE ===
            % If we want the surface in the database
            if isSaveTess
                bst_progress('text', ['Saving surface: ' layers{i}]);
                % Fill holes
                sNewMri.Cube = (mri_fillholes(sNewMri.Cube, 1) & mri_fillholes(sNewMri.Cube, 2) & mri_fillholes(sNewMri.Cube, 3));
                % Tesselate mask
                sTess = in_tess_mrimask(sNewMri);
                % Convert to SCS coordinates
                if ~isempty(sMri) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
                    sTess.Vertices = cs_convert(sMri, 'mri', 'scs', sTess.Vertices);
                end
                % Remesh surface
                if (nVertices > 0)
                    [sTess.Vertices, sTess.Faces] = tess_remesh(sTess.Vertices, nVertices, 1);
                    fileTag = sprintf('_%dV', nVertices);
                else
                    fileTag = '';
                end
                % Set comment
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
    end
    % Save database
    db_save();
    % Return nothing
    OutputFiles = {sInputs.FileName};
end



