function varargout = process_project_sources( varargin )
% PROCESS_PROJECT_SOURCES: Project source files on a different surface.

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
% Authors: Francois Tadel, 2012-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Project on default anatomy';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 334;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/CoregisterSubjects';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'results', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Head model type
    sProcess.options.label.Comment = 'Type of source space:';
    sProcess.options.label.Type    = 'label';
    sProcess.options.headmodeltype.Comment = {'Cortex surface', 'MRI volume'; 'surface', 'volume'};
    sProcess.options.headmodeltype.Type    = 'radio_label';
    sProcess.options.headmodeltype.Value   = 'surface';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
    if isfield(sProcess.options, 'headmodeltype') && isfield(sProcess.options.headmodeltype, 'Value') && ~isempty(sProcess.options.headmodeltype.Value)
        Comment = [Comment, ': ', sProcess.options.headmodeltype.Value];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    if isfield(sProcess.options, 'headmodeltype') && isfield(sProcess.options.headmodeltype, 'Value') && ~isempty(sProcess.options.headmodeltype.Value)
        HeadModelType = sProcess.options.headmodeltype.Value;
    else
        HeadModelType = 'surface';
    end
    isAbsoluteValues = 0;
    % List all the input files
    ResultsFile = {sInputs.FileName};
    % Get default anatomy
    sDefSubject = bst_get('Subject', 0);
    if isempty(sDefSubject.iCortex)
        bst_report('Error', sProcess, [], 'No cortex available for the default anatomy.');
        return;
    end
    % Get default cortex of default anatomy
    destSurfFile = sDefSubject.Surface(sDefSubject.iCortex).FileName;
    % Project sources
    switch (HeadModelType)
        case 'surface'
            OutputFiles = bst_project_sources(ResultsFile, destSurfFile, isAbsoluteValues, 0);
        case 'volume'
            OutputFiles = bst_project_grid(ResultsFile, [], 0);
    end
end




