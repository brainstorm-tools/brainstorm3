function varargout = process_mni_normalize( varargin )
% PROCESS_MNI_NORMALIZE: Compute deformation fields to the MNI ICBM152 space.
%
% USAGE:     OutputFiles = process_mni_normalize('Run', sProcess, sInputs)
%         [isOk, errMsg] = process_mni_normalize('Compute',            MriFile, Method)
%                          process_mni_normalize('ComputeInteractive', MriFile, Method=[ask], isUnload=1)

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
    
    % ===== COMPUTE MNI TRANSFORMATION =====
    % Get default MRI
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    % Call normalize function
    [sMri, errMsg] = Compute(MriFile, Method);
    % Error handling
    if ~isempty(errMsg)
        bst_report('Error', sProcess, [], errMsg);
    end

    OutputFiles = {'import'};
end


%% ===== COMPUTE =====
function [sMri, errMsg] = Compute(MriFile, Method)
    [sMri, errMsg] = bst_normalize_mni(MriFile, Method);
end


%% ===== COMPUTE/INTERACTIVE =====
function sMri = ComputeInteractive(MriFile, Method, isUnload)
    % Parse inputs
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
        % Compiled: only MAFF8 available
        if exist('isdeployed', 'builtin') && isdeployed
            Method = 'maff8';
        else
            sProcess = GetDescription();
            Method = java_dialog('question', ['<HTML>' sprintf('%s<BR><BR>', sProcess.options.method.Comment{1,:})], ...
                'MNI normalization method', [], {sProcess.options.method.Comment{2,:}, 'Cancel'}, sProcess.options.method.Comment{2,1});
            % Cancel
            if isempty(Method) || strcmpi(Method, 'Cancel')
                sMri = [];
                return;
            end
        end
    end
    % Open progress bar
    bst_progress('start', 'MNI normalization', 'Initialization...');
    % Call non-interactive function
    [sMri, errMsg] = Compute(MriFile, Method);
    % Error handling
    if ~isempty(errMsg)
        sMri = [];
        bst_error(errMsg, 'MNI normalization', 0);
    end
    % Close progress bar
    bst_progress('stop');
end

