function varargout = process_segment_fsl( varargin )
% process_segment_fsl: Run the fsl to estimate skin head
%
% USAGE:     OutputFiles = process_segment_fsl('Run',     sProcess, sInputs)
%                          process_segment_fsl('ComputeInteractive', iSubject, iAnatomy)
%         [isOk, errMsg] = process_segment_fsl('Compute', iSubject, iAnatomy, nVertices,erodeFactor,fillFactor)
%                          
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
% Authors: Edouard Delaire, 2022
%          Francois Tadel, 2022-2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Extract head with FSL';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 39;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';

    sProcess.options.nVertices.Comment = 'Number of vertices [integer]';
    sProcess.options.nVertices.Type    = 'value';
    sProcess.options.nVertices.Value   = {10000,'',0};

    sProcess.options.erodeFactor.Comment = 'Erode factor [0,1,2,3]';
    sProcess.options.erodeFactor.Type    = 'value';
    sProcess.options.erodeFactor.Value   = {0,'',0};

    sProcess.options.fillFactor.Comment = 'Fill holes factor [0,1,2,3]';
    sProcess.options.fillFactor.Type    = 'value';
    sProcess.options.fillFactor.Value   = {2,'',0};

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {}; 
    
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
    nVertices       = sProcess.options.nVertices.Value{1}; 
    erodeFactor     = sProcess.options.erodeFactor.Value{1}; 
    fillFactor      = sProcess.options.fillFactor.Value{1}; 
    
     % Check parameters values
    if isempty(nVertices) || (nVertices < 50) || (nVertices ~= round(nVertices)) || isempty(erodeFactor) || ~ismember(erodeFactor,[0,1,2,3]) || isempty(fillFactor) || ~ismember(fillFactor,[0,1,2,3])
        bst_report('Error', sProcess, [], 'Invalid parameters.');
        return;
    end

    % Call processing function
    [isOk, errMsg] = Compute(iSubject,sSubject.iAnatomy, nVertices, erodeFactor,fillFactor);


    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE FSL SEGMENTATION =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, erodeFactor, fillFactor)
    errMsg  = '';
    isOk    = 0;

    % Check FSL install
    fsl_dir = getenv('FSLDIR');
    if isempty(fsl_dir)
        errMsg = 'FSL was not found (set FSLDIR variable).';
        return
    end
    
    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', iSubject);
    if isempty(sSubject)
        errMsg = 'Subject does not exist.';
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        errMsg = ['No MRI available for subject "' sSubject.Name '".'];
        return
    end
    % Get default MRI if not specified
    if isempty(iAnatomy)
        iAnatomy = sSubject.iAnatomy;
    end
    
    % ===== VERIFY FIDUCIALS IN MRI =====
    % Load MRI file
    T1File = sSubject.Anatomy(iAnatomy).FileName;
    sMri = in_mri_bst(T1File);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3) || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.T)
        % Issue warning
        errMsg = 'Missing NAS/LPA/RPA: Computing the MNI normalization to get default positions.'; 
        % Compute MNI normalization
        [sMri, errNorm] = bst_normalize_mni(T1File);
        % Handle errors
        if ~isempty(errNorm)
            errMsg = [errMsg 10 'Error trying to compute the MNI normalization: ' 10 errNorm 10 ...
                'Missing fiducials: the surfaces cannot be aligned with the MRI.'];
        end
    end

    % ===== SAVE MRI AS NII =====
    bst_progress('text', 'Saving temporary files...');
    % Temporay folder for FSL output
    TmpDir = bst_get('BrainstormTmpDir', 0, 'fsl');
    % Save MRI in .nii format
    subjid = strrep(sSubject.Name, '@', '');
    NiiFile = bst_fullfile(TmpDir, [subjid, '.nii']);
    out_mri_nii(sMri, NiiFile);
    % If a "world transformation" was not available in the MRI in the database, it was set to a default when saving to .nii
    % Let's reload this file to get the transformation matrix, it will be used when importing the results
    if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf) || isempty(find(strcmpi(sMri.InitTransf(:,1), 'vox2ras')))
        % Load again the file, with the default vox2ras transformation
        [tmp, vox2ras] = in_mri_nii(NiiFile, 0, 0, 0);
        % Prepare the history of transformations
        if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf)
            sMri.InitTransf = cell(0,2);
        end
        % Add this transformation in the MRI
        sMri.InitTransf(end+1,[1 2]) = {'vox2ras', vox2ras};
        % Save modification on hard drive
        bst_save(file_fullpath(T1File), sMri, 'v7');
    end

    % ===== RUN FSL/BET =====
    bst_progress('text', 'Executing FSL/BET...');
    % FSL command line
    cmd = sprintf('%s %s %s -A -f 0.5 -g 0 -o -m -s', fullfile(fsl_dir,'bin/bet'), fullfile(TmpDir,subjid), fullfile(TmpDir,[subjid '_brain']));
    disp(['BST> System call: ' cmd]);
    % Run execution
    status = system(cmd);
    % Error handling
    MaskFile = fullfile(TmpDir, [subjid '_brain_outskin_mask.nii.gz']);
    if (status ~= 0) || ~exist(MaskFile, 'file')
        errMsg = ['FSL was not able to create the head mask.', 10, 'Check the Matlab command window for more information.'];
        return
    end
    
    % ===== IMPORT RESULTS =====
    bst_progress('text', 'Importing MRI...');
    % Read mask
    sMask = in_mri(MaskFile);
    sMriMasked = sMri;
    % Convert sMask.Cube to the same type as sMRI.Cube and mask the MRI
    sMask.Cube          = eval(sprintf('%s(%s)',class(sMri.Cube), 'sMask.Cube')); 
    sMriMasked.Cube     = sMri.Cube .* sMask.Cube;
    sMriMasked.Comment  = [sMri.Comment ' | fsl'];
    sMriMasked.Histogram.bgLevel = 0; % Might not be needed 
    sMriMasked = bst_history('add', sMriMasked, 'import', 'Head extraction with FSL/BET');
    % Output file name
    [fPath,fName,fExt] = bst_fileparts(file_fullpath(T1File));
    OutputFile = file_unique(fullfile(fPath, [fName '_masked' fExt]));
    % Save new MRI in Brainstorm format
    sMriMasked = out_mri_bst(sMriMasked, OutputFile);
    % Add file to database
    [sSubject, iSubject] = bst_get('MriFile', T1File);
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy).FileName = file_short(OutputFile);
    sSubject.Anatomy(iAnatomy).Comment = sMriMasked.Comment;
    bst_set('Subject', iSubject, sSubject);
    % Refresh database tree
    panel_protocols('UpdateNode', 'Subject', iSubject);

    % Create head surface
    tess_isohead(sSubject.Anatomy(iAnatomy).FileName, nVertices, erodeFactor, fillFactor);
    
    % Delete temporary folder
    file_delete(TmpDir, 1, 1);
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end

   res = java_dialog('input', {'Number of vertices [integer]:', 'Erode factor [0,1,2,3]:', 'Fill holes factor [0,1,2,3]:'}, 'Generate head surface', [], {'10000', '0', '2'});
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    nVertices   = str2num(res{1});
    erodeFactor = str2num(res{2});
    fillFactor  = str2num(res{3});
    
     % Check parameters values
    if isempty(nVertices) || (nVertices < 50) || (nVertices ~= round(nVertices)) || isempty(erodeFactor) || ~ismember(erodeFactor,[0,1,2,3]) || isempty(fillFactor) || ~ismember(fillFactor,[0,1,2,3])
        bst_error('Invalid parameters.', 'FSL head extraction', 0);
        return
    end

    % Open progress bar
    bst_progress('start', 'FSL', 'FSL/BET head extraction...');
    % Run FSL
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, erodeFactor, fillFactor);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FSL head extraction', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    
    % Close progress bar
    bst_progress('stop');
end


