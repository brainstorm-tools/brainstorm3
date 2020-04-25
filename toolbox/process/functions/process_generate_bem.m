function varargout = process_generate_bem( varargin )
% PROCESS_GENERATE_BEM: Generate BEM surfaces.

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
% Authors: Francois Tadel, 2012-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Generate BEM surfaces';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 21;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutBem';
    sProcess.isSeparator = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Scalp
    sProcess.options.label1.Comment = '<BR>Number of vertices per layer:<BR>Best results are obtained with: outer skull = inner skull';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.nscalp.Comment = 'Scalp surface (default=1922): ';
    sProcess.options.nscalp.Type    = 'value';
    sProcess.options.nscalp.Value   = {1922, '', 0};
    % Option: Outer skull
    sProcess.options.nouter.Comment = 'Outer skull (default=1922): ';
    sProcess.options.nouter.Type    = 'value';
    sProcess.options.nouter.Value   = {1922, '', 0};
    % Option: Inner skull
    sProcess.options.ninner.Comment = 'Inner skull (default=1922): ';
    sProcess.options.ninner.Type    = 'value';
    sProcess.options.ninner.Value   = {1922, '', 0};
    % Option: Skull thickness
    sProcess.options.thickness.Comment = 'Skull thickness (default=4): ';
    sProcess.options.thickness.Type    = 'value';
    sProcess.options.thickness.Value   = {4, 'mm', 1};
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
    nScalp = sProcess.options.nscalp.Value{1};
    nOuter = sProcess.options.nouter.Value{1};
    nInner = sProcess.options.ninner.Value{1};
    skullThickness = sProcess.options.thickness.Value{1};
    if isempty(nScalp) || isempty(nOuter) || isempty(nInner) || isempty(skullThickness) || (nScalp == 0) || (nOuter == 0) || (nInner == 0) || (skullThickness == 0)
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
    % Check if a MRI and cortex surface are available for the subject
    if isempty(sSubject.Anatomy) || isempty(sSubject.iCortex)
        bst_report('Error', sProcess, [], ['No MRI or cortex surface available for subject "' SubjectName '".']);
        return
    end
    
    % ===== IMPORT FILES =====
    % BEM options
    BemOptions.nvert     = [nScalp, nOuter, nInner];
    BemOptions.thickness = [7 skullThickness 3]; 
    % Generate BEM layers for Subject01
    isOk = tess_bem(iSubject, BemOptions);
    if ~isOk
        bst_report('Error', sProcess, [], 'An error occurred in tess_bem function.');
        return
    end

    OutputFiles = {'import'};
end


%% ===== COMPUTE/INTERACTIVE =====
function isOk = ComputeInteractive(iSubject, iMri) %#ok<DEFNU>
    isOk = 0;
    % Get inputs
    if (nargin < 2) || isempty(iMri)
        iMri = [];
    end
    % Ask which method to use
    res = java_dialog('question', [...
        '<HTML><B>Brainstorm</B>:<BR>Create BEM surfaces from <B>T1</B> MRI, <B>scalp</B> and <B>cortex</B> surfaces.<BR>' ...
        'Warp MNI template skull surfaces to fit the head shape of the subject.<BR><BR>' ...
        '<B>FieldTrip</B>:<BR>Call ft_volumesegment to segment ft_prepare_mesh to mesh the <B>T1 MRI</B>.<BR>' ...
        'FieldTrip must be installed on the computer first.<BR>' ...
        'Website: http://www.fieldtriptoolbox.org/download<BR><BR>' ...
        ], 'BEM mesh generation method', [], {'Brainstorm','FieldTrip'}, 'Brainstorm');
    if isempty(res)
        return
    end
    Method = lower(res);
    % Call appropriate method
    switch (Method)
        case 'brainstorm'
            % Get subject
            sSubject = bst_get('Subject', iSubject);
            % If there are no scalp and no cortex: Only FieldTrip available
            if isempty(sSubject.iCortex) || isempty(sSubject.iScalp)
                bst_error('The selected method requires the cortex and scalp surfaces.', 'Generate BEM surfaces', 0);
                return;
            end
            % Run computation
            isOk = tess_bem(iSubject);
        case 'fieldtrip'
            process_ft_volumesegment('ComputeInteractive', iSubject, iMri);
    end
end

