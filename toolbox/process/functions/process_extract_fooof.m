function varargout = process_extract_fooof( varargin )
% PROCESS_EXTRACT_FOOOF Extract FOOOF meausure from a TimeFrequency file.
%
% USAGE: OutputFiles = process_extract_fooof('Run', sProcess, sInput)
%             Values = process_extract_fooof('Compute', TimeFreqMat, FooofDisp, iRow)
%                    = process_extract_fooof('Compute', TimeFreqMat, FooofDisp)  

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
% Authors: Raymundo Cassani, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'specparam: Extract measure';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 492;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Fooof#Convert_FOOOF_model_parameters_to_regular_PSD_files';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Define options
    sProcess = DefineOptions(sProcess);
end


%% ===== DEFINE OPTIONS =====
function sProcess = DefineOptions(sProcess)
    % === LABEL
    sProcess.options.label1.Comment = ['<FONT color="#707070">Extract a measure computed with the specparam process,<BR>' ... 
                                       'and save it as a regular PSD file for further processing.</FONT><BR><BR>' ...
                                       'specparam measure:'];
    sProcess.options.label1.Type    = 'label';
    % === FOOOF measures
    sProcess.options.fooof.Comment = {'Spectrum', 'specparam model', 'Aperiodic only', 'Peaks only', 'Frequency-wise error', 'Exponent', 'Offset'};
    sProcess.options.fooof.Type    = 'radio';
    sProcess.options.fooof.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get options
    fooofDisp = GetOptions(sProcess);
    % Final process string
    Comment = [sProcess.Comment ': ' fooofDisp];
end


%% ===== GET OPTIONS =====
function strFooofDisp = GetOptions(sProcess)
    % FOOOF measures
    switch sProcess.options.fooof.Value                         
        case 1, strFooofDisp = 'spectrum';
        case 2, strFooofDisp = 'model';
        case 3, strFooofDisp = 'aperiodic';
        case 4, strFooofDisp = 'peaks';
        case 5, strFooofDisp = 'error';
        case 6, strFooofDisp = 'exponent';
        case 7, strFooofDisp = 'offset';
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    strFooofDisp = GetOptions(sProcess);
    % Load input stat file
    TimeFreqMat = in_bst_timefreq(sInput.FileName);
    % Check for FOOOF file
    if ~(isfield(TimeFreqMat.Options, 'FOOOF') && all(ismember({'options', 'freqs', 'data', 'peaks', 'aperiodics', 'stats'}, fieldnames(TimeFreqMat.Options.FOOOF))))
        error('TimeFreq file does not contain specparam information.');
    end
    % Extract FOOOF measure and frequencies
    Values  = Compute(TimeFreqMat, strFooofDisp);
    ixFooofFreq = ismember(TimeFreqMat.Freqs, TimeFreqMat.Options.FOOOF.freqs); 
    % Frequency dependent measures
    if ~ismember(strFooofDisp, {'exponent', 'offset'})
        Values = Values(:,:,ixFooofFreq);
    else
        Values = repmat(Values, [1,1,sum(ixFooofFreq)]); 
    end
    % New timefreqmat structure
    DataMat = TimeFreqMat;
    DataMat.TF            = Values;
    DataMat.Freqs         = TimeFreqMat.Options.FOOOF.freqs;
    DataMat.Comment       = [TimeFreqMat.Comment ' | ' strFooofDisp];
    DataMat.Method        = ['fooof-', strFooofDisp];                 
    DataMat.Options       = TimeFreqMat.Options;
    DataMat.Options.FOOOF = struct('options', DataMat.Options.FOOOF.options);
        
    % Add history entry
    DataMat = bst_history('add', DataMat, 'fooof-measure', ['Extract FOOOF measure: ' strFooofDisp]);
    DataMat = bst_history('add', DataMat, 'fooof-measure', ['Original file: ' sInput.FileName]);
    % Output file tag
    fileTag = bst_process('GetFileTag', sInput.FileName);
    % Output filename
    DataFile = bst_process('GetNewFilename', bst_fileparts(sInput.FileName), fileTag);
    % Save on disk
    bst_save(DataFile, DataMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, DataFile, DataMat);
    % Return data file
    OutputFiles{1} = DataFile;
end

            
%% ===== GET REQUESTED FOOOF MEASURE =====
% Extract FOOOF measure values
function Values = Compute(TimeFreqMat, FooofDisp, iRow)
    % Verify iRow
    if (nargin < 3) || isempty(iRow)
        iRow = 1 : size(TimeFreqMat.TF, 1);
    end        
    isFooofFreq = ismember(TimeFreqMat.Freqs, TimeFreqMat.Options.FOOOF.freqs);
    if isequal(FooofDisp, 'overlay')
        nFooofRow = 4;
    else
        nFooofRow = numel(iRow);
    end
    [s1 s2 s3] = size(TimeFreqMat.TF);
    Values = NaN([nFooofRow, s2, s3 ]);
    nFooofFreq = sum(isFooofFreq);
    % Check for old structure format with extra .FOOOF. level.
    if isfield(TimeFreqMat.Options.FOOOF.data, 'FOOOF')
        for iiRow = 1:numel(iRow)
            TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).fooofed_spectrum = ...
                TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).FOOOF.fooofed_spectrum;
            TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).ap_fit = ...
                TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).FOOOF.ap_fit;
            TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).peak_fit = ...
                TimeFreqMat.Options.FOOOF.data(iRow(iiRow)).FOOOF.peak_fit;
        end
    end
    switch FooofDisp
        case 'spectrum'
            Values = TimeFreqMat.TF;
        case 'overlay'
            Values(1,1,:) = TimeFreqMat.TF(iRow, 1, :);
            Values(4,1,isFooofFreq) = permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).fooofed_spectrum], nFooofFreq, []), [2, 3, 1]);
            Values(2,1,isFooofFreq) = permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).ap_fit], nFooofFreq, []), [2, 3, 1]);
            % Peaks are fit in log space, so they are multiplicative in linear space and not in the same scale, show difference instead. 
            Values(3,1,isFooofFreq) = Values(4,1,isFooofFreq) - Values(2,1,isFooofFreq); 
            %Values(3,1,isFooofFreq) = permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).peak_fit], nFooofFreq, []), [2, 3, 1]);
            % Use TF min as cut-off level for peak display.
            YLowLim = min(Values(1,1,:));
            Values(3,1,Values(3,1,:) < YLowLim) = NaN;
        case 'model'
            Values(:,:,isFooofFreq) = repmat(permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).fooofed_spectrum], nFooofFreq, []), [2, 3, 1]),[1 s2 1]);
        case 'aperiodic'
            Values(:,:,isFooofFreq) = repmat(permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).ap_fit], nFooofFreq, []), [2, 3, 1]),[1 s2 1]);
        case 'peaks'
            Values(:,:,isFooofFreq) = repmat(permute(reshape([TimeFreqMat.Options.FOOOF.data(iRow).peak_fit], nFooofFreq, []), [2, 3, 1]),[1 s2 1]);
        case 'error'
            Values(:,:,isFooofFreq) = repmat(permute(reshape([TimeFreqMat.Options.FOOOF.stats(iRow).frequency_wise_error], nFooofFreq, []), [2, 3, 1]),[1 s2 1]);
        case 'exponent'
            Values = [TimeFreqMat.Options.FOOOF.aperiodics(iRow).exponent]';
        case 'offset'
            Values = [TimeFreqMat.Options.FOOOF.aperiodics(iRow).offset]';
        otherwise
            error('Unknown FOOOF display option.');
    end
end
