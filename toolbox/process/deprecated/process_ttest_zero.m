function varargout = process_ttest_zero( varargin )
% PROCESS_TTEST_ZERO: Student''s t-test against zero.

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2015

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric t-test against zero [DEPRECATED]';
    sProcess.Category    = 'Stat1';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 720;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    sProcess.options.label1.Comment   = ['<B>Test formula:</B><BR>' ...
                                         't = avg(X) ./ std(X) .* sqrt(n)<BR>' ...
                                         'Where X represents of all the input files.<BR>'];
    sProcess.options.label1.Type       = 'label';
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
    % === UNCONSTRAINED SOURCES
    sProcess.options.label_norm.Comment    = '<BR><B>Warning</B>: This test is not adapted for unconstrained sources.<BR><BR>';
    sProcess.options.label_norm.Type       = 'label';
    sProcess.options.label_norm.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = 't-test vs zero';
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputs) %#ok<DEFNU>
    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        isMatchRows = sProcess.options.matchrows.Value;
    else
        isMatchRows = 1;
    end
    
    % Compute the mean and variance of input foiles
    isVariance = 1;
    isWeighted = 0;
    [Stat, Messages] = bst_avg_files({sInputs.FileName}, [], 'mean', isVariance, isWeighted, isMatchRows);

    % Add messages to report
    if ~isempty(Messages)
        bst_report('Error', sProcess, sInputs, Messages);
        sOutput = [];
        return;
    end
    % Display progress bar
    bst_progress('start', 'Processes', 'Computing t-test...');

    % Initialize output structure
    sOutput = db_template('statmat');
    % Bad channels and other properties
    switch lower(sInputs(1).FileType)
        case 'data'
            ChannelFlag = Stat.ChannelFlag;
            isGood = (ChannelFlag == 1);
        case {'results', 'timefreq', 'matrix'}
            ChannelFlag = [];
            isGood = true(size(Stat.mean, 1), 1);
    end
    sizeOutput = size(Stat.mean);
    % Get results
    mean_zero = Stat.mean(isGood,:,:);
    std_zero = sqrt(Stat.var(isGood,:,:));
    % Remove null variances
    iNull = find(std_zero == 0);
    std_zero(iNull) = eps;

    % Number of input samples
    n = length(sInputs);
    % Compute t-test
    t_tmp = mean_zero ./ std_zero .* sqrt(n);
    df = n - 1;
    clear mean_zero std_zero
    % Remove values with null variances
    if ~isempty(iNull)
        t_tmp(iNull) = 0;
    end

    % === OUTPUT STRUCTURE ===
    % Initialize p and t matrices
    if (nnz(isGood) == length(ChannelFlag))
        sOutput.tmap = t_tmp;
    else
        sOutput.tmap = zeros(sizeOutput);
        sOutput.tmap(isGood,:,:) = t_tmp;
    end
    %sOutput.pmap = betainc( df ./ (df + sOutput.tmap .^ 2), df/2, 0.5);
    sOutput.Time         = Stat.Time;
    sOutput.df           = df;
    sOutput.Correction   = 'no';
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = 't';
    % Row names
    if isfield(Stat, 'RowNames') && ~isempty(Stat.RowNames)
        if strcmpi(sInputs(1).FileType, 'matrix')
            sOutput.Description = Stat.RowNames;
        else
            sOutput.RowNames = Stat.RowNames;
        end
    end
end


