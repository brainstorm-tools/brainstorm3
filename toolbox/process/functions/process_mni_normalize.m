function varargout = process_mni_normalize( varargin )
% PROCESS_MNI_NORMALIZE: Compute deformation fields to the MNI ICBM152 space.
%
% USAGE:     OutputFiles = process_mni_normalize('Run', sProcess, sInputs)
%         [isOk, errMsg] = process_mni_normalize('Compute',            T1File, Method)
%                          process_mni_normalize('ComputeInteractive', T1File, Method=[ask], isUnload=1)

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
% Authors: Francois Tadel, 2020-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'MNI normalization';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 10;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ImportAnatomy#MNI_transformation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Method
    sProcess.options.method.Comment = {...
         '<B>maff8</B>:<BR>Affine registration using SPM mutual information algorithm.<BR>Estimates a simple 4x4 linear transformation to the MNI space.<BR><FONT color="#707070"><I>Included in Brainstorm.</I></FONT>', ...
         '<B>segment</B>:<BR>Non-linear normalization and tissue classification with SPM12.<BR>Estimates forward and inverse deformation fields to MNI space (IXI549).<BR><FONT color="#707070"><I>Requires the installation of SPM12.</I></FONT>'; ...
         'maff8', 'segment'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'maff8';
    % Use T2 when available
    sProcess.options.uset2.Comment = 'Use T2 when available ("segment" only)';
    sProcess.options.uset2.Type    = 'checkbox';
    sProcess.options.uset2.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
    % Get method
    Method = sProcess.options.method.Value;
    % Use T2
    UseT2 = sProcess.options.uset2.Value;
      
    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
        bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectName '".']);
        return
    end
    % Get default MRI as T1
    T1File = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    % Look for T2 MRI
    T2File = [];
    if UseT2 && (length(sSubject.Anatomy) > 1)
        iT2 = find(~cellfun(@(c)isempty(strfind(c,'t2')), lower({sSubject.Anatomy.Comment})));
        % Warning when multiple T2 images
        if (length(iT2) > 1)
            bst_report('Warning', sProcess, [], ['Subject "' sSubject.Name '" has multiple anatomy volumes with tag "T2": not using T2 to avoid confusion.' 10 ...
                'To use a T2 MRI for better volume segmentation, rename or delete the extra T2-labelled files from the subject anatomy.']);
            iT2 = [];
        end
        % Get T2 filename
        if ~isempty(iT2)
            T2File = sSubject.Anatomy(iT2).FileName;
        end
    end

    % ===== COMPUTE MNI TRANSFORMATION =====
    % Call normalize function
    [sMriT1, errMsg] = Compute(T1File, Method, T2File);
    % Error handling
    if ~isempty(errMsg)
        bst_report('Error', sProcess, [], errMsg);
    end

    OutputFiles = {'import'};
end


%% ===== COMPUTE =====
function [sMriT1, errMsg] = Compute(T1File, Method, T2File)
    % Parse inputs
    if (nargin < 3) || isempty(T2File)
        T2File = [];
    end
    % Compute normalization
    [sMriT1, errMsg] = bst_normalize_mni(T1File, Method, T2File);
end


%% ===== COMPUTE/INTERACTIVE =====
function sMriT1 = ComputeInteractive(T1File, Method, isUnload, T2File)
    % Parse inputs
    if (nargin < 4) || isempty(T2File)
        T2File = [];
    end
    if (nargin < 3) || isempty(isUnload)
        isUnload = 1;
    end
    if (nargin < 2) || isempty(Method)
        Method = [];
    end
    % Unloading everything
    if isUnload
        bst_memory('UnloadAll', 'Forced');
    end
    % Ask method
    if isempty(Method)
        sProcess = GetDescription();
        Method = java_dialog('question', ['<HTML>' sprintf('%s<BR><BR>', sProcess.options.method.Comment{1,:})], ...
            'MNI normalization method', [], {sProcess.options.method.Comment{2,:}, 'Cancel'}, sProcess.options.method.Comment{2,1});
        % Cancel
        if isempty(Method) || strcmpi(Method, 'Cancel')
            sMriT1 = [];
            return;
        end
    end
    % For Segment method: look for T2 MRI in the subject
    if strcmpi(Method, 'segment') && isempty(T2File)
        % Get subject info
        sSubject = bst_get('MriFile', T1File);
        % Find any possible T2
        iT2 = [];
        if (length(sSubject.Anatomy) > 1)
            iT2 = find(~cellfun(@(c)isempty(strfind(c,'t2')), lower({sSubject.Anatomy.Comment})));
            % Warning when multiple T2 images
            if (length(iT2) > 1)
                res = java_dialog('question', ...
                    ['Subject "' sSubject.Name '" has multiple anatomy volumes with tag "T2".' 10 10 ...
                     'If you want to use a T2 MRI for better volume segmentation, ' 10 ...
                     'rename or delete the extra T2-labelled files from the subject anatomy.' 10 10 ...
                     'If you click OK, no T2 image will be used in the segmentation.' 10 10], 'MNI normalization', [], {'OK', 'Cancel'}, 'OK');
                if isempty(res) || isequal(res, 'Cancel')
                    return;
                end
                iT2 = [];
            % Confirmation for using T2 image
            elseif (length(iT2) == 1)
                isT2 = java_dialog('confirm', ...
                    ['Subject "' sSubject.Name '" seems to include one T2 MRI, named "' sSubject.Anatomy(iT2).Comment '".' 10 10 ...
                     'Use this T2 image to refine the volume segmentation?' 10 10], 'MNI normalization');
                if ~isT2
                    iT2 = [];
                end
            end
        end
        % Get T2 filename
        if ~isempty(iT2)
            T2File = sSubject.Anatomy(iT2).FileName;
        end
    end
    % Open progress bar
    bst_progress('start', 'MNI normalization', 'Initialization...');
    % Call non-interactive function
    [sMriT1, errMsg] = Compute(T1File, Method, T2File);
    % Error handling
    if ~isempty(errMsg)
        sMriT1 = [];
        bst_error(errMsg, 'MNI normalization', 0);
    end
    % Close progress bar
    bst_progress('stop');
end

