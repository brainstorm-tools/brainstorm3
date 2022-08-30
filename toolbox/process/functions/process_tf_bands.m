function varargout = process_tf_bands( varargin )
% PROCESS_TF_FREQBANDS: Group TF values in frequency bands.
%
% USAGE:  TimefreqMat = process_tf_bands('Compute', TimefreqMat, FreqBands, TimeBands)
%            strBands = process_tf_bands('FormatBands', FreqBands)
%               Bands = process_tf_bands('ParseBands', strBands)
%           FreqBands = process_tf_bands('Eval', FreqBands)
%          BandBounds = process_tf_bands('GetBounds', FreqBands)

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
% Authors: Francois Tadel, 2012-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Group in time or frequency bands';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 520;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TimeFrequency#Process_options';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % === IS FREQ BANDS
    sProcess.options.isfreqbands.Comment = 'Group by frequency bands (name/freqs/function):';
    sProcess.options.isfreqbands.Type    = 'checkbox';
    sProcess.options.isfreqbands.Value   = 1;
    % === FREQ BANDS
    sProcess.options.freqbands.Comment = '';
    sProcess.options.freqbands.Type    = 'groupbands';
    sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
    % === IS TIME BANDS
    sProcess.options.istimebands.Comment = 'Group by time bands (name/time/function):';
    sProcess.options.istimebands.Type    = 'checkbox';
    sProcess.options.istimebands.Value   = 0;
    % === TIME BANDS
    sProcess.options.timebands.Comment = '';
    sProcess.options.timebands.Type    = 'groupbands';
    sProcess.options.timebands.Value   = '';
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    % Get options
    isFreqBands = sProcess.options.isfreqbands.Value;
    isTimeBands = sProcess.options.istimebands.Value;
    if isFreqBands
        FreqBands = sProcess.options.freqbands.Value;
    else
        FreqBands = [];
    end
    if isTimeBands
        TimeBands = sProcess.options.timebands.Value;
    else
        TimeBands = [];
    end
    isOverwrite = sProcess.options.overwrite.Value;
    % If no input
    if isempty(FreqBands) && isempty(TimeBands)
        bst_report('Error', sProcess, sInput, 'No time or frequency bands selected.');
        return;
    end
    
    % Load TF file
    TimefreqMat = in_bst_timefreq(sInput.FileName, 0);
    % Call function to group by frequency bands
    [TimefreqMat, Messages] = Compute(TimefreqMat, FreqBands, TimeBands);
    % Error
    if isempty(TimefreqMat)
        bst_report('Error', sProcess, sInput, Messages);
        return;
    end
    
    % Comment
    TimefreqMat.Comment = [TimefreqMat.Comment, ' | tfbands'];
    % Overwrite the input file
    if isOverwrite
        OutputFile = file_fullpath(sInput.FileName);
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Reload study
        db_reload_studies(sInput.iStudy);
    % Save new file
    else
        % Output filename: add file tag
        OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', '_tfbands.mat');
        OutputFile = file_unique(OutputFile);
        % Save file
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Add file to database structure
        db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
    end
end


%% ===== COMPUTE =====
function [TimefreqMat, Messages] = Compute(TimefreqMat, FreqBands, TimeBands)
    Messages = '';
    % Error: Cannot average complex values
    if ~isreal(TimefreqMat.TF)
        Messages = 'Cannot average complex values. Please apply a measure first.';
        TimefreqMat = [];
        return;
    end
    % Error: File is already in frequency bands
    if ~isempty(FreqBands) && iscell(TimefreqMat.Freqs)
        Messages = 'File is already averaged in frequency bands.';
        TimefreqMat = [];
        return;
    end
    % Error: File is already in time bands
    if ~isempty(TimeBands) && ~isempty(TimefreqMat.TimeBands)
        Messages = 'File is already averaged in time bands.';
        TimefreqMat = [];
        return;
    end
    
    % ===== FREQUENCY BANDS =====
    if ~isempty(FreqBands)
        % Check format
        if (size(FreqBands,2) ~= 3) || ~all(cellfun(@ischar, FreqBands(:))) || any(cellfun(@(c)isempty(strtrim(c)), FreqBands(:)))
            Messages = 'Invalid frequency band format.';
            TimefreqMat = [];
            return;
        end
        % Frequency bounds
        BandBounds = GetBounds(FreqBands);
        % Number of bands
        nBands = size(FreqBands,1);
        % Initialize the averaged matrix
        TF_bands = zeros(size(TimefreqMat.TF,1), size(TimefreqMat.TF,2), nBands);
        % Process each band
        for iBand = 1:nBands
            % Get frequency indices in this band
            iFreq = find((TimefreqMat.Freqs >= BandBounds(iBand,1)) & (TimefreqMat.Freqs <= BandBounds(iBand,2)));
            % No frequencies in this frequency band
            if isempty(iFreq)
                disp(['BST> Warning: Frequency band "' FreqBands{iBand,1} '" is empty.']);
                continue;
            end
            % Check the band function name
            if ~ismember(FreqBands{iBand,3}, {'mean', 'max', 'median', 'std'})
                Messages = ['Invalid function "' FreqBands{iBand,3} '".'];
                TimefreqMat = [];
                return;
            end
            % Average the values for the band
            switch lower(FreqBands{iBand,3})
                case 'mean',   TF_bands(:,:,iBand) = mean(TimefreqMat.TF(:,:,iFreq),    3);
                case 'median', TF_bands(:,:,iBand) = median(TimefreqMat.TF(:,:,iFreq),  3);
                case 'max',    TF_bands(:,:,iBand) = max(TimefreqMat.TF(:,:,iFreq), [], 3);
                case 'std',    TF_bands(:,:,iBand) = std(TimefreqMat.TF(:,:,iFreq), [], 3);
            end
        end
        % Update input structure
        TimefreqMat.TF    = TF_bands;
        TimefreqMat.Freqs = FreqBands;
    end
    
    % ===== TIME BANDS =====
    if ~isempty(TimeBands)
        dt = .0001;
        % Frequency bounds
        BandBounds = GetBounds(TimeBands);
        % Number of bands
        nBands = size(TimeBands,1);
        % Initialize the averaged matrix
        TF_bands = zeros(size(TimefreqMat.TF,1), nBands, size(TimefreqMat.TF,3));
        % Process each frequency band
        for iBand = 1:nBands
            % Get time indices in this band
            iTime = find((TimefreqMat.Time >= BandBounds(iBand,1) - dt) & (TimefreqMat.Time <= BandBounds(iBand,2) + dt));
            % No time samples in this band
            if isempty(iTime)
                disp(['BST> Warning: Time band "' TimeBands{iBand,1} '" is empty.']);
                continue;
            end
            % Check the band function name
            if ~ismember(TimeBands{iBand,3}, {'mean', 'max', 'median', 'std'})
                Messages = ['Invalid function "' TimeBands{iBand,3} '".'];
                TimefreqMat = [];
                return;
            end
            % Average the values for the band
            switch lower(TimeBands{iBand,3})
                case 'mean',    TF_bands(:,iBand,:) = mean(TimefreqMat.TF(:,iTime,:),    2);
                case 'median',  TF_bands(:,iBand,:) = median(TimefreqMat.TF(:,iTime,:),  2);
                case 'max',     TF_bands(:,iBand,:) = max(TimefreqMat.TF(:,iTime,:), [], 2);
                case 'std',     TF_bands(:,iBand,:) = std(TimefreqMat.TF(:,iTime,:), [], 2);
            end
        end
        % Update input structure
        TimefreqMat.TF = TF_bands;
        TimefreqMat.TimeBands = TimeBands;
    end
    
    % Do not keep the Std/TFmask fields in the output
    if isfield(TimefreqMat, 'Std') && ~isempty(TimefreqMat.Std)
        TimefreqMat.Std = [];
    end
    if isfield(TimefreqMat, 'TFmask') && ~isempty(TimefreqMat.TFmask)
        TimefreqMat.TFmask = [];
    end
end


%% ===== BANDS => STRING =====
function strBands = FormatBands(Bands) %#ok<DEFNU>
    strBands = '';
    for i = 1:size(Bands,1)
        if (size(Bands, 2) == 3)
            strBands = [strBands, sprintf('%s / %s / %s\n', Bands{i,1}, Bands{i,2}, Bands{i,3})];
        elseif (size(Bands, 2) == 2)
            strBands = [strBands, sprintf('%s / %s\n', Bands{i,1}, Bands{i,2})];
        end
    end
end

%% ===== STRING => BANDS =====
function [Bands, errMsg] = ParseBands(strBands) %#ok<DEFNU>
    Bands = {};
    errMsg = '';
    if isempty(strtrim(strBands))
        return
    end
    % Split by lines
    lineBand = str_split(strBands, 10);
    % Process each line
    for iBand = 1:length(lineBand)
        % Split line 
        valBand = str_split(lineBand{iBand}, '/\|');
        if (length(valBand) ~= 3) || any(cellfun(@(c)isempty(strtrim(c)), valBand))
            errMsg = ['Invalid time or frequency band "' lineBand{iBand} '".'];
            disp(['BST> Error: ' errMsg]);
            Bands = {};
            return;
        end
        for i = 1:length(valBand)
            Bands{iBand,i} = strtrim(valBand{i});
        end
    end
end

%% ===== EVALUATE BANDS =====
function Bands = Eval(Bands)
    for iBand = 1:size(Bands,1)
        Bands{iBand,2} = eval(['[', Bands{iBand,2}, ']']);
    end
end

%% ===== GET BAND BOUNDS =====
function BandBounds = GetBounds(Bands)
    Bands = Eval(Bands);
    BandBounds = zeros(size(Bands,1),2);
    for iBand = 1:size(Bands,1)
        BandBounds(iBand,1) = Bands{iBand,2}(1);
        BandBounds(iBand,2) = Bands{iBand,2}(end);
    end
end



