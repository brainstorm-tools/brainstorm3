function varargout = process_select_files_timefreq( varargin )
% PROCESS_SELECT_FILES_TIMEFREQ: Select files from the database, based on the subject name and the condition.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: Time-freq';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1012;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Definition of the options
    % SUBJECT NAME
    sProcess.options.subjectname.Comment = 'Subject name (empty=all):';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'All';
    % CONDITION
    sProcess.options.condition.Comment = 'Condition name (empty=all):';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = '';
    % COMMENT TAG
    sProcess.options.tag.Comment = 'File comment contains tag: ';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '';
    % INCLUDE BAD TRIALS
    sProcess.options.includebad.Comment = 'Include the bad trials';
    sProcess.options.includebad.Type    = 'checkbox';
    sProcess.options.includebad.Value   = 0;
    % INCLUDE INTRA-SUBJECT
    sProcess.options.includeintra.Comment = 'Include the folder "Intra-subject"';
    sProcess.options.includeintra.Type    = 'checkbox';
    sProcess.options.includeintra.Value   = 0;
    % INCLUDE INTRA-SUBJECT
    sProcess.options.includecommon.Comment = 'Include the folder "Common files"';
    sProcess.options.includecommon.Type    = 'checkbox';
    sProcess.options.includecommon.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Define file type
    sProcess.options.filetype.Value = 'timefreq';
    % Call common process
    Comment = process_select_files_data('FormatComment', sProcess);
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Define file type
    sProcess.options.filetype.Value = 'timefreq';
    % Call common process
    OutputFiles = process_select_files_data('Run', sProcess, sInputs);
end



