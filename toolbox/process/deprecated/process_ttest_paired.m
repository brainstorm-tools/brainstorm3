function varargout = process_ttest_paired( varargin )
% PROCESS_TTEST_PAIRED: Paired Student''s t-test: Compare means between conditions (across trials or across sujects).

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2008-2015

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Parametric t-test (Paired) [DEPRECATED]';
    sProcess.Category    = 'Stat2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 121;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isPaired    = 1;
    sProcess.isSeparator = 1;
    
    % Definition of the options
    % === SCOUTS SELECTION ===
    sProcess.options.scoutsel.Comment    = 'Use scouts';
    sProcess.options.scoutsel.Type       = 'scout_confirm';
    sProcess.options.scoutsel.Value      = {};
    sProcess.options.scoutsel.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment   = {'Mean', 'PCA', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type      = 'radio_line';
    sProcess.options.scoutfunc.Value     = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    
    % === T-TEST: title
    sProcess.options.ttest_title.Comment    = '<BR>';
    sProcess.options.ttest_title.Type       = 'label';
    sProcess.options.ttest_title.InputTypes = {'results'};
    % === Absolue values: legend:
    % 'Warning: This test may not be adapted for processing sources.<BR><BR>' ...
    sProcess.options.abs_label.Comment    = 'Test:  t = mean(D) ./ std(D) .* sqrt(n)';
    sProcess.options.abs_label.Type       = 'label';
    % === Absolue values: type
    sProcess.options.abs_type.Comment = {'D = abs(A)-abs(B)', ...
                                         'D = A-B'};
    sProcess.options.abs_type.Type    = 'radio';
    sProcess.options.abs_type.Value   = 1;
    sProcess.options.abs_type.InputTypes = {'data', 'results', 'matrix'};
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
    % === WEIGHTED AVERAGE
    sProcess.options.label_wavg.Comment    = ['<FONT color="#777777">Note: When processing averages, "mean" refers to a weighted average:<BR>' ...
                                              'mean(F) = sum(nAvgA(i) * F(i)) / sum(nAvgA(i))</FONT>'];
    sProcess.options.label_wavg.Type       = 'label';
    % === UNCONSTRAINED SOURCES
    sProcess.options.label_norm.Comment    = ['<FONT color="#777777">Note: For unconstrained sources, "absolute value" refers to the norm<BR>' ...
                                              'of the three orientations: abs(F) = sqrt(Fx^2 + Fy^2 + Fz^2).</FONT>'];
    sProcess.options.label_norm.Type       = 'label';
    sProcess.options.label_norm.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Absolute type
    if ~isfield(sProcess.options, 'abs_type') || isempty(sProcess.options.abs_type.Value) || (sProcess.options.abs_type.Value == 2)
        strAbsType = '';
    elseif (sProcess.options.abs_type.Value == 1)
        strAbsType = ', abs';
    end 
    % Comment
    Comment = ['t-test [paired' strAbsType ']'];
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % ===== PARSE INPUTS =====
    % Scouts
    if isfield(sProcess.options, 'scoutsel') && isfield(sProcess.options.scoutsel, 'Value') && isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value')
        ScoutSel = sProcess.options.scoutsel.Value;
        switch (sProcess.options.scoutfunc.Value)
            case 1, ScoutFunc = 'mean';
            case 2, ScoutFunc = 'pca';
            case 3, ScoutFunc = 'all';
        end
    else
        ScoutSel = [];
        ScoutFunc = [];
    end
    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        isMatchRows = sProcess.options.matchrows.Value;
    else
        isMatchRows = 1;
    end
    % Absolute values for sources
    if isfield(sProcess.options, 'abs_type') 
        switch(sProcess.options.abs_type.Value)
            case 1,  Function = 'norm';
            case 2,  Function = 'mean';
        end
    else
        Function = 'mean';
    end
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        sOutput = [];
        return;
    end
    % Dimensions
    n1 = length(sInputsA);
    n2 = length(sInputsB);
    % Paired test: Number of samples must be equal
    if (n1 ~= n2)
        bst_report('Error', sProcess, [sInputsA(:)',sInputsB(:)'], 'For a paired t-test, the number of files must be the same in the two groups.');
        sOutput = [];
        return;
    end
    % Results?
    isResults = strcmpi(sInputsA(1).FileType, 'results');
    isScouts  = ~isempty(ScoutSel);
    % Initialize output structure
    sOutput = db_template('statmat');

    
    % === PAIRED T-TEST ===
    % Scouts: Need to load them here
    if isScouts
        InputSetA = bst_process('LoadScouts', {sInputsA.FileName}, ScoutSel, ScoutFunc, []);
        InputSetB = bst_process('LoadScouts', {sInputsB.FileName}, ScoutSel, ScoutFunc, []);
        sOutput.Type = 'matrix';
    % Other types of data: can be handled directly by bst_avg_files
    else
        InputSetA = {sInputsA.FileName};
        InputSetB = {sInputsB.FileName};
    end
    % Compute the mean and variance of (samples A - samples B)
    [Stat, Messages] = bst_avg_files(InputSetA, InputSetB, Function, 1, 0, isMatchRows);
    % Add messages to report
    if ~isempty(Messages)
        bst_report('Error', sProcess, [sInputsA(:)',sInputsB(:)'], Messages);
        sOutput = [];
        return;
    end
    % Display progress bar
    bst_progress('start', 'Processes', 'Computing t-test...');
    
    % Bad channels and other properties
    switch lower(sInputsA(1).FileType)
        case 'data'
            ChannelFlag = Stat.ChannelFlag;
            isGood = (ChannelFlag == 1);
        case {'results', 'timefreq', 'matrix'}
            ChannelFlag = [];
            isGood = true(size(Stat.mean, 1), 1);
    end
    sizeOutput = size(Stat.mean);
    % Get results
    mean_diff = Stat.mean(isGood,:,:);
    std_diff = sqrt(Stat.var(isGood,:,:));
    % Remove null variances
    iNull = find(std_diff == 0);
    std_diff(iNull) = eps;

    % Compute t-test
    t_tmp = mean_diff ./ std_diff .* sqrt(n1);
    sOutput.df = n1 - 1;
    clear mean_diff std_diff
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
    sOutput.Correction   = 'no';
    sOutput.ChannelFlag  = ChannelFlag;
    sOutput.Time         = Stat.Time;
    sOutput.ColormapType = 'stat2';
    sOutput.DisplayUnits = 't';
    
    % If the number of components may have changed outside of this function
    if isResults && strcmpi(Function, 'norm') && ~isScouts
        ResultsMat = in_bst(sInputsA(1).FileName);
        % Unconstrained or mixed sources: source maps have been flattened by bst_avg_files
        if (ResultsMat.nComponents ~= 1)
            % Flatten the first file to get the modified variables
            ResultsMat = process_source_flat('Compute', ResultsMat, 'rms');
            sOutput.nComponents = ResultsMat.nComponents;
            sOutput.GridAtlas   = ResultsMat.GridAtlas;
        end
    end
    % Row names
    if isfield(Stat, 'RowNames') && ~isempty(Stat.RowNames)
        if strcmpi(sInputsA(1).FileType, 'matrix') || isScouts
            sOutput.Description = Stat.RowNames;
        else
            sOutput.RowNames = Stat.RowNames;
        end
    end
end


