function varargout = process_stat_parametric1( varargin )
% PROCESS_STAT_PARAMETRIC1: Compute parametric one-sample statistics (NO TEST).

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compute t-statistic (no test)';
    sProcess.Category    = 'Stat1';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 710;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
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
    sProcess.options.test_type.Comment = {['<B>One-sample Student''s t-test</B> &nbsp;&nbsp;&nbsp;<FONT color="#777777">X~N(m,s)</FONT><BR>' ...
                                           't = mean(X) ./ std(X) .* sqrt(n) &nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777">df=n-1</FONT>'], ...
                                          ['<B>One-sample Chi-square test</B> &nbsp;&nbsp;&nbsp;<FONT color="#777777">Zi~N(0,1), i=1..n</FONT><BR>' ...
                                           'Q = sum(|Zi|^2) &nbsp;&nbsp;&nbsp;<FONT color="#777777">Q~Chi2(n)</FONT>']; ...
                                          'ttest_onesample', 'chi2_onesample'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_onesample';
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
function sOutput = Run(sProcess, sInputs) %#ok<DEFNU>
    sOutput = process_test_parametric2('Run', sProcess, sInputs, []);
end





