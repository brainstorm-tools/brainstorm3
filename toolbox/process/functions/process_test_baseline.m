function varargout = process_test_baseline( varargin )
% PROCESS_TTEST_BASELINE: Parametric test of a post-stimulus signal vs a baseline.

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
% Authors: Francois Tadel, 2010-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric test against baseline';
    sProcess.Category    = 'Stat1';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 702;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % === GENERIC EXTRACT OPTIONS
    % Label
    sProcess.options.extract_title.Comment    = '<B><U>Select data to test</U></B>:';
    sProcess.options.extract_title.Type       = 'label';
    % Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % Options
    sProcess = process_extract_values('DefineExtractOptions', sProcess);
    % DISABLE ABSOLUTE VALUE
    sProcess.options.isabs.Value = 0;
    sProcess.options.isnorm.Value = 0;
    sProcess.options.isabs.Hidden = 1;
    sProcess.options.isnorm.Hidden = 1;    
    % === TEST: title
    sProcess.options.test_title.Comment    = '<BR><B><U>Test statistic</U></B>:';
    sProcess.options.test_title.Type       = 'label';
    % === TEST: type
    sProcess.options.test_type.Comment = {['<B>Student''s t-test vs baseline</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>X~N(m,v)</I></FONT><BR>' ...
                                           'Y = mean_trials(X) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>Y~N(m,v)</I></FONT><BR>' ...
                                           't = (Y - mean_time(Y(baseline)) / std_time(Y(baseline)))<BR>' ...
                                           '<FONT COLOR="#777777">df = Nbaseline - 1 = length(baseline) - 1</FONT>'], ...
                                          ['<B>Power F-test vs baseline</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>X~N(0,1)</I></FONT><BR>' ...
                                           'Y = sum_trials(X^2) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>Y~Chi2(Ntrials)</I></FONT><BR>' ...
                                           'F = Y / mean_time(Y(baseline)) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>F~F(Ntrials,Ntrials)</I></FONT>'], ...
                                          ['<B>Power F-test vs baseline (unconstrained sources)</B> &nbsp;&nbsp; <FONT COLOR="#777777"><I>Xx,Xy,Xz~N(0,1)</I></FONT><BR>' ...
                                           'Y = sum_trials(Xx^2 + Xy^2 + Xz^2) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>Y~Chi2(3*Ntrials)</I></FONT><BR>' ...
                                           'F = Y / mean_time(Y(baseline)) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>F~F(3*Ntrials,3*Ntrials)</I></FONT>']; ...
                                          'ttest_baseline', 'power_baseline', 'power_baseline_unconstr'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_baseline';
    % === TAIL FOR THE TEST STATISTIC
    sProcess.options.tail.Comment  = {'One-tailed (-)', 'Two-tailed', 'One-tailed (+)', ''; ...
                                      'one-', 'two', 'one+', ''};
    sProcess.options.tail.Type     = 'radio_linelabel';
    sProcess.options.tail.Value    = 'two';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_test_parametric2('FormatComment', sProcess);
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputs) %#ok<DEFNU>
    sOutput = process_test_parametric2('Run', sProcess, sInputs, []);
end




