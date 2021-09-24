function varargout = process_test_parametric2p( varargin )
% PROCESS_TEST_PARAMETRIC2P: Parametric two-sample tests (dependent=paired).

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2008-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric test: Paired';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 102;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isPaired    = 1;
    sProcess.isSeparator = 1;
    
    % === GENERIC EXTRACT OPTIONS
    % Label
    sProcess.options.extract_title.Comment    = '<B><U>Select data to test</U></B>:';
    sProcess.options.extract_title.Type       = 'label';
    % Options
    sProcess = process_extract_values('DefineExtractOptions', sProcess);
    % DISABLE ABSOLUTE VALUE
    sProcess.options.isabs.Value = 0;
    sProcess.options.isnorm.Value = 0;
    sProcess.options.isabs.Hidden = 1;
    sProcess.options.isnorm.Hidden = 1;
    
    % === OUTPUT COMMENT
    sProcess.options.Comment.Comment = 'Comment (empty=default): ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    
    % === TEST: title
    sProcess.options.test_title.Comment    = '<BR><B><U>Test statistic</U></B>:';
    sProcess.options.test_title.Type       = 'label';
    % === TEST: type
    sProcess.options.test_type.Comment = {['<B>Paired Student''s t-test</B> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777"><I>(A-B)~N(m,v)</I></FONT><BR>' ...
                                           't = mean(A-B) / std(A-B) * sqrt(n) &nbsp;&nbsp;&nbsp;&nbsp; <FONT COLOR="#777777">df=n-1</FONT>']; ...
                                          'ttest_paired'};
    sProcess.options.test_type.Type    = 'radio_label';
    sProcess.options.test_type.Value   = 'ttest_paired';
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
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    sOutput = process_test_parametric2('Run', sProcess, sInputsA, sInputsB);
end





