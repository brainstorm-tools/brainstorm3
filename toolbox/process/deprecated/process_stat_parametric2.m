function varargout = process_stat_parametric2( varargin )
% PROCESS_STAT_PARAMETRIC2: Compute parametric two-sample statistics (NO TEST).
% 
% USAGE:  OutputFiles = process_stat_parametric2('Run', sProcess, sInput)

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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compute t-statistic (no test)';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 111;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;

    % === OUTPUT COMMENT
    sProcess.options.Comment.Comment = 'Comment (empty=default): ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    % === NORM XYZ
    sProcess.options.isnorm.Comment    = 'Test absolute values (or norm for unconstrained sources)';
    sProcess.options.isnorm.Type       = 'checkbox';
    sProcess.options.isnorm.Value      = 0;
    sProcess.options.isnorm.InputTypes = {'results'};
    % === ABSOLUTE VALUE
    sProcess.options.isabs.Comment    = 'Test absolute values';
    sProcess.options.isabs.Type       = 'checkbox';
    sProcess.options.isabs.Value      = 0;
    sProcess.options.isabs.InputTypes = {'data', 'timefreq', 'matrix'};
    
    % === TEST: title
    sProcess.options.test_title.Comment    = '<BR><B><U>Test statistic</U></B>:';
    sProcess.options.test_title.Type       = 'label';
    % === TEST: type
    sProcess.options.test_type.Comment = {['<B>Student''s t-statistic &nbsp;&nbsp;(equal variance)</B> <BR>t = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))<BR>' ...
                                           'Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2)) <BR>' ...
                                           '<FONT COLOR="#777777">df = nA + nB - 2</FONT>'], ...
                                          ['<B>Student''s t-statistic &nbsp;&nbsp;(unequal variance)</B> <BR>', ...
                                           't = (mean(A)-mean(B)) / sqrt(var(A)/nA + var(B)/nB)<BR>' ...
                                           '<FONT COLOR="#777777">df=(vA/nA+vB/nB)<SUP>2</SUP> / ((vA/nA)<SUP>2</SUP>/(nA-1)+(vB/nB)<SUP>2</SUP>/(nB-1))</FONT>'], ...
                                          ['<B>Paired Student''s t-test</B> <BR>' ...
                                           't = mean(A-B) ./ std(A-B) .* sqrt(n) &nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777">df=n-1</FONT>']; ...
                                          'ttest_equal', 'ttest_unequal', 'ttest_paired'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_equal';
    % === DEFAULTS: NO TEST
    sProcess.options.tail.Comment = {'One-tailed (-)', 'Two-tailed', 'One-tailed (+)', 'no', ''; ...
                                     'one-', 'two', 'one+', 'no', ''};
    sProcess.options.tail.Type    = 'radio_linelabel';
    sProcess.options.tail.Value   = 'no';
    sProcess.options.tail.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_test_parametric2('FormatComment', sProcess);
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    sOutput = process_test_parametric2('Run', sProcess, sInputsA, sInputsB);
end

    
    