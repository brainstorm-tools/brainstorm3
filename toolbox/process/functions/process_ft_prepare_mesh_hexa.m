function varargout = process_ft_prepare_mesh_hexa( varargin )
% PROCESS_FT_PREPARE_MESH_HEXA: Call FieldTrip function ft_prepare_mesh to generate hexahedral meshes.

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
% Authors: Francois Tadel, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    OPTIONS = GetDefaultOptions();
    % Description the process
    sProcess.Comment     = 'Generate hexa mesh (ft_prepare_mesh)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 33;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/tutorial/headmodel_eeg_fem';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment    = 'Subject name:';
    sProcess.options.subjectname.Type       = 'subjectname';
    sProcess.options.subjectname.Value      = 'NewSubject';
    sProcess.options.subjectname.InputTypes = {'import'};
    % FieldTrip: Downsample volume
    sProcess.options.downsample.Comment = 'Downsample volume (1=no downsampling): ';
    sProcess.options.downsample.Type    = 'value';
    sProcess.options.downsample.Value   = {OPTIONS.Downsample, '', 0};
    % FieldTrip: Node shift
    sProcess.options.nodeshift.Comment = 'Node shift [0 - 0.49]: ';
    sProcess.options.nodeshift.Type    = 'value';
    sProcess.options.nodeshift.Value   = {OPTIONS.NodeShift, '', 2};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = [];
    OPTIONS = struct();
    % Not supported in compiled version
    if exist('isdeployed', 'builtin') && isdeployed
        error('Not supported in compiled version yet. Post a message on the forum if you need this feature.');
    end
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
    % Get subject
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Node shift
    OPTIONS.NodeShift = sProcess.options.nodeshift.Value{1};
    if isempty(OPTIONS.NodeShift) || (OPTIONS.NodeShift < 0) || (OPTIONS.NodeShift >= 0.5)
        bst_report('Error', sProcess, [], 'Invalid node shift.');
        return
    end
    % Downsample volume 
    OPTIONS.Downsample = sProcess.options.downsample.Value{1};
    if isempty(OPTIONS.Downsample) || (OPTIONS.Downsample < 1) || (OPTIONS.Downsample - round(OPTIONS.Downsample) ~= 0)
        bst_report('Error', sProcess, [], 'Invalid downsampling factor.');
        return
    end
    
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], OPTIONS);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== DEFAULT OPTIONS =====
function OPTIONS = GetDefaultOptions()
    OPTIONS = struct(...
        'NodeShift',      0.3, ...   % [0 - 0.49] Improves the geometrical properties of the mesh
        'Downsample',     3);        % Integer, Downsampling factor to apply to the volumes before meshing
end


%% ===== COMPUTE =====
function [isOk, errMsg, FemFile] = Compute(iSubject, iMri, OPTIONS)
    isOk = 0;
    errMsg = '';
    FemFile = [];

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
        iMri = find(strcmpi({sSubject.Anatomy.Comment}, 'tissues'), 1);
        if isempty(iMri)
            iMri = find(~cellfun(@(c)isempty(strfind(lower(c), 'tissue')), {sSubject.Anatomy.Comment}), 1);
            if isempty(iMri)
                errMsg = 'Tissue segmentation not available...';
                return;
            end
        end
    end

    % ===== LOAD INPUT =====
    % Load Brainstorm MRI
    MriFile = sSubject.Anatomy(iMri).FileName;
    disp(['BST> Using tissue segmentation: ' MriFile]);
    sMri = in_mri_bst(MriFile);
    % Convert to FieldTrip structure
    ftMri = out_fieldtrip_mri(sMri, 'anatomy');
    % Recreate FieldTrip segmented MRI
    TissueLabels = {'white', 'gray', 'csf', 'skull', 'scalp'};
    indTissues = [1 2 3 4 5];
    for i = 1:length(TissueLabels)
        if (nnz(ftMri.anatomy == indTissues(i)) > 0)
            ftMri.(TissueLabels{i}) = (ftMri.anatomy == indTissues(i));
        end
    end
    ftMri = rmfield(ftMri, 'anatomy');
        
    % ===== CALL FIELDTRIP =====
    cfg = [];
    cfg.method = 'hexahedral';
    cfg.spmversion = 'spm12';
    cfg.downsample = OPTIONS.Downsample;
    cfg.shift = OPTIONS.NodeShift;
    mesh = ft_prepare_mesh(cfg, ftMri);
    % Reorder labels based on requested order
    iRelabel = cellfun(@(c)find(strcmpi(c,TissueLabels)), mesh.tissuelabel)';
    mesh.tissue = iRelabel(mesh.tissue);

    % ===== SAVE FEM MESH =====
    bst_progress('text', 'Saving FEM mesh...');
    % Create output structure
    FemMat = db_template('femmat');
    FemMat.TissueLabels = TissueLabels;
    FemMat.Comment  = sprintf('FEM %dV (fieldtrip, %d layers)', length(mesh.pos), length(FemMat.TissueLabels));
    FemMat.Vertices = mesh.pos;
    FemMat.Elements = mesh.hex;
    FemMat.Tissue   = mesh.tissue;
    % Add history
    FemMat = bst_history('add', FemMat, 'preparemesh', OPTIONS);
    % Save to database
    FemFile = file_unique(bst_fullfile(bst_fileparts(file_fullpath(MriFile)), sprintf('tess_fem_fieldtrip_%dV.mat', length(FemMat.Vertices))));
    bst_save(FemFile, FemMat, 'v7');
    db_add_surface(iSubject, FemFile, FemMat.Comment);

    % Return success
    isOk = 1;
end


%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iMri) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iMri)
        iMri = [];
    end
    % Get default options
    OPTIONS = GetDefaultOptions();
    % Ask user for the downsampling factor
    [res, isCancel]  = java_dialog('input', ['Downsample volume before meshing:' 10 '(integer, 1=no downsampling)'], ...
        'FieldTrip FEM mesh', [], num2str(OPTIONS.Downsample));
    if isCancel || isempty(str2double(res))
        return
    end
    OPTIONS.Downsample = str2double(res);
    % Ask user for the node shifting
    [res, isCancel]  = java_dialog('input', 'Shift the nodes to fit geometry [0-0.49]:', ...
        'FieldTrip FEM mesh', [], num2str(OPTIONS.NodeShift));
    if isCancel || isempty(str2double(res))
        return
    end
    OPTIONS.NodeShift = str2double(res);
    
    % Open progress bar
    bst_progress('start', 'Generate FEM mesh', 'Generating hexa FEM mesh (FieldTrip)...');
    % Generate FEM mesh
    try
        [isOk, errMsg] = Compute(iSubject, iMri, OPTIONS);
        % Error handling
        if ~isOk
            bst_error(errMsg, 'Generate FEM mesh', 0);
        elseif ~isempty(errMsg)
            java_dialog('msgbox', ['Warning: ' errMsg]);
        end
    catch
        bst_error();
        bst_error(['The FEM mesh generation failed.' 10 'Check the Matlab command window for additional information.' 10], 'Generate FEM mesh', 0);
    end
    % Close progress bar
    bst_progress('stop');
end


