function varargout = process_report_email( varargin )
% PROCESS_REPORT_EMAIL: Send current process report by email.
% 
% For calling this function from a script, use directly bst_report.m:
% bst_report('Email', ReportFile, to, subject, isFullReport=1)

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
% Authors: Francois Tadel, 2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Send report by email';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 983;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Definition of the options
    % === TO
    sProcess.options.to.Comment = 'To: ';
    sProcess.options.to.Type    = 'text';
    sProcess.options.to.Value   = 'you@server.com';
    % === SUBJECT 
    sProcess.options.subject.Comment = 'Subject: ';
    sProcess.options.subject.Type    = 'text';
    sProcess.options.subject.Value   = 'Process completed';
    % === FULL REPORT
    sProcess.options.full.Comment = 'Send full report';
    sProcess.options.full.Type    = 'checkbox';
    sProcess.options.full.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = ['Snapshot: ' sProcess.options.target.Value{2}{sProcess.options.target.Value{1}}];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
    % Destination email
    to = sProcess.options.to.Value;
    if isempty(to) || ~any(to == '@')
        bst_report('error', sProcess, [], 'Invalid email address.');
        return;
    end
    % Email subject
    subject = sProcess.options.subject.Value;
    if isempty(subject)
        subject = 'Brainstorm report';
    end
    % Full report
    isFullReport = sProcess.options.full.Value;
    % Send email
    isOk = bst_report('Email', 'current', to, subject, isFullReport);
    % Error handling
    if ~isOk
        bst_report('error', sProcess, [], 'Email could not be sent.');
    end
end



