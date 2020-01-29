function varargout = process_generate_head( varargin )
% PROCESS_GENERATE_HEAD: Generate s head surface from an MRI.

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
% Authors: Francois Tadel, 2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Generate head surface';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 20;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer#The_head_surface_looks_bad';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices [integer]: ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {10000, '', 0};
    % Option: Erode factor
    sProcess.options.erodefactor.Comment = 'Erode factor [0,1,2,3]: ';
    sProcess.options.erodefactor.Type    = 'value';
    sProcess.options.erodefactor.Value   = {0, '', 0};
    % Option: Fill factor
    sProcess.options.fillfactor.Comment = 'Fill holes factor [0,1,2,3]: ';
    sProcess.options.fillfactor.Type    = 'value';
    sProcess.options.fillfactor.Value   = {2, '', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
    % Number of vertices
    nVertices   = sProcess.options.nvertices.Value{1};
    erodeFactor = sProcess.options.erodefactor.Value{1};
    fillFactor  = sProcess.options.fillfactor.Value{1};
    if isempty(nVertices) || isempty(erodeFactor) || isempty(fillFactor)
        bst_report('Error', sProcess, [], 'Invalid values.');
        return;
    end
      
    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectName '".']);
        return
    end
    
    % ===== GENERATE HEAD =====
    % Generate head surface
    HeadFile = tess_isohead(iSubject, nVertices, erodeFactor, fillFactor);
    % Error handling
    if isempty(HeadFile)
        bst_report('Error', sProcess, [], 'An error occurred in tess_isohead function.');
        return;
    end

    OutputFiles = {'import'};
end



