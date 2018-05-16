function varargout = process_extract_maxfreq( varargin )
% PROCESS_EXTRACT_MAXFREQ: Find the maximum value in time (returns the latency or the peak values).

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2016; Martin Cousineau, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Find maximum in frequency';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 355;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % Definition of the options
    % === SELECT: FREQUENCY RANGE
    sProcess.options.freqrange.Comment  = 'Frequency range: ';
    sProcess.options.freqrange.Type     = 'freqrange';
    sProcess.options.freqrange.Value    = [];
    % === METHOD
    sProcess.options.labelmethod.Comment = '<BR>What to detect:';
    sProcess.options.labelmethod.Type    = 'label';
    sProcess.options.method.Comment = {'Maximum amplitude  (positive or negative peak)', 'Maximum value  (positive peak)', 'Minimum value  (negative peak)'; ...
                                       'absmax', 'max', 'min'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'absmax';
    % === OUTPUT
    sProcess.options.labelout.Comment = '<BR>Value to save in the output file:';
    sProcess.options.labelout.Type    = 'label';
    sProcess.options.output.Comment = {'Peak amplitude  (for each signal separately)', 'Frequency of the peak  (for each signal separately)'; ...
                                       'amplitude', 'frequency'};
    sProcess.options.output.Type    = 'radio_label';
    sProcess.options.output.Value   = 'amplitude';
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Preprocess values to detect the correct peaks
    switch (sProcess.options.method.Value)
        case 'absmax',  Comment = 'Find maximum amplitude: ';
        case 'max',     Comment = 'Find maximum value: ';
        case 'min',     Comment = 'Find minimum value: ';
    end
    % Freq indices
    if isfield(sProcess.options, 'freqrange') && isfield(sProcess.options.freqrange, 'Value') && iscell(sProcess.options.freqrange.Value) && (length(sProcess.options.freqrange.Value) == 3) && (length(sProcess.options.freqrange.Value{1}) == 2)
        FreqRange = sProcess.options.freqrange.Value{1};
        if (FreqRange(1) == FreqRange(2))
            Comment = [Comment, ' Invalid frequency selection'];
            return;
        else
            Comment = [Comment, ' ' num2str(FreqRange(1)) '-' num2str(FreqRange(2)) 'Hz'];
        end
    end
    % Output
    if isequal(sProcess.options.output.Value, 'frequency')
        Comment = [Comment, ', frequency'];
    end
end

%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.method.Value;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    
    % ===== GET OPTIONS =====
    Output = sProcess.options.output.Value;
    Method = sProcess.options.method.Value;
    isOverwrite = sProcess.options.overwrite.Value;
    % Freq indices
    if isfield(sProcess.options, 'freqrange') && isfield(sProcess.options.freqrange, 'Value') && iscell(sProcess.options.freqrange.Value) && (length(sProcess.options.freqrange.Value) == 3) && (length(sProcess.options.freqrange.Value{1}) == 2)
        FreqRange = sProcess.options.freqrange.Value{1};
    else
        FreqRange = [];
    end
    OutputFile = [];
    
    % ===== LOAD FILE =====
    % Load TF file
    TimefreqMat = in_bst_timefreq(sInput.FileName, 0);
    % Check for measure
    if strcmpi(TimefreqMat.Measure, 'none')
        bst_report('Error', sProcess, sInput, 'Cannot process complex values. Please apply a measure to the values before calling this function.');
        return;
    end
    % Get file frequency vector
    if iscell(TimefreqMat.Freqs)
        BandBounds = process_tf_bands('GetBounds', TimefreqMat.Freqs);
        FreqVector = mean(BandBounds,2);
        FreqBounds = [BandBounds(1,1), BandBounds(end,2)];
    else
        FreqVector = TimefreqMat.Freqs;
        FreqBounds = [FreqVector(1), FreqVector(end)];
    end
    % Rounds the frequency vector, to have the same level of precision as the process (3 significant digits)
    FreqVector = round(FreqVector * 1000) / 1000;
    % Keep only selected frequencies
    if ~isempty(FreqRange)
        % Find the selected frequencies
        iFreqs = find((FreqVector >= FreqRange(1)) & (FreqVector <= FreqRange(2)));
        if isempty(iFreqs)
            bst_report('Error', sProcess, sInput, 'Invalid frequency range.');
            return;
        end
        TimefreqMat.TF = TimefreqMat.TF(:,:,iFreqs);
        % Keep only the selected frequencies
        if iscell(TimefreqMat.Freqs)
            TimefreqMat.Freqs = TimefreqMat.Freqs(iFreqs,:);
        else
            TimefreqMat.Freqs = TimefreqMat.Freqs(iFreqs);
        end
        FreqVector = FreqVector(iFreqs);
    end
    
    % ===== FIND MAXIMUM =====
    % Preprocess values to detect the correct peaks
    minmaxFunc = @max;
    switch (Method)
        case 'absmax'
            TimefreqMat.TF = abs(TimefreqMat.TF);
        case 'max'
            % nothing to change
        case 'min'
            minmaxFunc = @min;
    end
    % Find maximum in frequency
    [MinMax, iMinMax] = minmaxFunc(TimefreqMat.TF, [], 3);
    % Save the expected value
    switch (Output)
        case 'amplitude'
            TimefreqMat.TF = MinMax;
            strMethod = '';
        case 'frequency'
            TimefreqMat.TF = reshape(FreqVector(iMinMax), size(iMinMax));
            strMethod = ', frequency';
            TimefreqMat.DisplayUnits = 'Hz';
            TimefreqMat.Measure = 'frequency';
    end

    % ===== SAVE FILE =====   
    % Save as frequency band
    FreqBounds = round(FreqBounds * 10) / 10;
    TimefreqMat.Freqs = {Method, [num2str(FreqBounds(1)) ', ' num2str(FreqBounds(2))], Method};
    % Add file tag
    TimefreqMat.Comment = [TimefreqMat.Comment, ' | ' Method strMethod];
    % Do not keep the Std/TFmask fields in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
    if isfield(sInput, 'TFmask') && ~isempty(sInput.TFmask)
        sInput.TFmask = [];
    end
    % Add history entry
    TimefreqMat = bst_history('add', TimefreqMat, 'maxfreq', ['Find the ' Method ' across frequencies.']);

    % Overwrite the input file
    if isOverwrite
        OutputFile = file_fullpath(sInput.FileName);
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Reload study
        db_reload_studies(sInput.iStudy);
    % Save new file
    else
        % Output filename: add file tag
        OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', '_maxfreq.mat');
        OutputFile = file_unique(OutputFile);
        % Save file
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Add file to database structure
        db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
    end
end




