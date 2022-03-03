function varargout = process_report_email( varargin )
% PROCESS_REPORT_EMAIL: Send current process report by email.
% 
% For calling this function from a script, use directly bst_report.m:
% bst_report('Email', ReportFile, to, subject, isFullReport=1)

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
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting#Send_report_by_email';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix', 'import'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'dipoles', 'pdata', 'presults', 'ptimefreq', 'pmatrix', 'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Definition of the options
    % === USERNAME
    sProcess.options.username.Comment = 'Brainstorm username: ';
    sProcess.options.username.Type    = 'text';
    sProcess.options.username.Value   = '';
    % === TO
    sProcess.options.cc.Comment = 'Send copy to (email address): ';
    sProcess.options.cc.Type    = 'text';
    sProcess.options.cc.Value   = '';
    % === SUBJECT 
    sProcess.options.subject.Comment = 'Subject: ';
    sProcess.options.subject.Type    = 'text';
    sProcess.options.subject.Value   = 'Process completed';
    % === REPORTFILE
    sProcess.options.reportfile.Comment = 'ReportFile: ';
    sProcess.options.reportfile.Type    = 'text';
    sProcess.options.reportfile.Value   = 'current'; 
    sProcess.options.reportfile.Hidden  = 1; 
    % === FULL REPORT
    sProcess.options.full.Comment = 'Send full report';
    sProcess.options.full.Type    = 'checkbox';
    sProcess.options.full.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
    % Brainstorm username
    username = sProcess.options.username.Value;
    if isempty(username)
        bst_report('error', sProcess, [], 'Invalid Brainstorm username.');
        return;
    end
    % CC address
    cc = sProcess.options.cc.Value;
    if ~isempty(cc) && ~any(cc == '@')
        bst_report('error', sProcess, [], 'Invalid email address.');
        return;
    end
    % Email subject
    subject = sProcess.options.subject.Value;
    if isempty(subject)
        subject = 'Brainstorm report';
    end
    % Report file
    reportfile = sProcess.options.reportfile.Value;        
    % Full report
    isFullReport = sProcess.options.full.Value;
    % Send email
    [isOk, resp] = bst_report('Email', reportfile, username, cc, subject, isFullReport);
    % Error handling
    if ~isOk
        bst_report('Error', sProcess, [], ['Email could not be sent: ' 10 resp]);
    end
end



