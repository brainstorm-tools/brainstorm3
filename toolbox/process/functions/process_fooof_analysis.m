function varargout = process_fooof_analysis(varargin)
% PROCESS_FOOOF: Applies the "Fitting Oscillations and One Over F"
% algorithm on a Welch's PSD

% @=============================================================================
% This software is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
%
% Copyright (c)2000-2020 Brainstorm by the University of Southern California
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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
%

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Analyze FOOOF models';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','FOOOF'};
    sProcess.Index       = 504;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % ===  EXTRACT PEAKS ===
    sProcess.options.extPeaks.Comment   = 'Extract peaks';
    sProcess.options.extPeaks.Type      = 'checkbox';
    sProcess.options.extPeaks.Value     = 0;
    % ===  EXTRACT STATS ===
    sProcess.options.extStats.Comment   = 'Extract stats';
    sProcess.options.extStats.Type      = 'checkbox';
    sProcess.options.extStats.Value     = 0;
    % === Options: FOOOF ===
    sProcess.options.edit.Comment = {'panel_fooof_analysis_options', ' Manage Options: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET OPTIONS =====
function [extPeaks, extStats, PeakType, SortBy, FreqBands, pullMSE, pullR2, pullFreqError] = GetOptions(sProcess)
    extPeaks = sProcess.options.extPeaks.Value;
    extStats = sProcess.options.extStats.Value;
    opts = panel_fooof_analysis_options('GetPanelContents');
    PeakType = opts.PeakType;
    SortBy = opts.SortBy;
    FreqBands = opts.FreqBands;
    pullMSE = opts.pullMSE;
    pullR2 = opts.pullR2;
    pullFreqError = opts.pullFreqError;
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFile = {}; % Initialize
    % Fetch user settings
    [ep, es, pt, sb, fb, pmse, pr2, pfe] = GetOptions(sProcess);
    for iP = 1:length(sInputs)
        inputFile = in_bst_timefreq(sInputs(iP).FileName); 
        ePeaks = []; eStats = [];
        if ep % Extract Peaks
            ePeaks = extractPeaks(inputFile, pt, sb, fb);
        end
        if es % Extract Stats
            eStats = extractStats(inputFile, pmse, pr2, pfe);
        end    
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(inputFile, ep, ePeaks, es, eStats, pt, fb, iOutputStudy);
    end
end

function ePeaks = extractPeaks(inputFile, pt, sb, fb)
    ChanNames = inputFile.RowNames;
    FOOOFdata = inputFile.FOOOF.FOOOF_data;
    maxEnt = length(ChanNames)*inputFile.FOOOF.FOOOF_options.max_peaks;
    switch pt
        case 1
            % Preallocate space
            ePeaks = table('Size', [maxEnt, 4], 'VariableNames', ...
                {'channel', 'center_frequency', 'amplitude', 'st_dev'}, ...
                'VariableTypes',{'string', 'double', 'double', 'double'});
            % Collect data from all peaks
            i = 0;
            for chan = 1:length(ChanNames)
                if ~isempty(FOOOFdata(chan).FOOOF.peak_params)
                    for p = 1:size(FOOOFdata(chan).FOOOF.peak_params,1)
                        i = i +1;
                        ePeaks.channel(i) = ChanNames(chan);
                        ePeaks.center_frequency(i) = FOOOFdata(chan).FOOOF.peak_params(p,1);
                        ePeaks.amplitude(i) = FOOOFdata(chan).FOOOF.peak_params(p,2);
                        ePeaks.st_dev(i) = FOOOFdata(chan).FOOOF.peak_params(p,3);
                    end
                end
            end
            % Remove unused rows
            ePeaks = ePeaks(1:i,:);
            % Apply specified sort
            switch sb
                case 1
                    ePeaks = sortrows(ePeaks,'center_frequency');
                case 2
                    ePeaks = sortrows(ePeaks,'amplitude','descend');
                case 3
                    ePeaks = sortrows(ePeaks,'st_dev');
            end 
        case 2
            % Preallocate space
            ePeaks = table('Size', [maxEnt, 5], 'VariableNames', ...
                {'channel', 'center_frequency', 'amplitude', 'st_dev', 'band'}, ...
                'VariableTypes',{'string', 'double', 'double', 'double', 'string'});
            % Generate bands from input
            bands = process_fooof_bands('Eval', fb);
            % Collect data from all peaks
            i = 0;
            for chan = 1:length(ChanNames)
                if ~isempty(FOOOFdata(chan).FOOOF.peak_params)
                    for p = 1:size(FOOOFdata(chan).FOOOF.peak_params,1)
                        i = i +1;
                        ePeaks.channel(i) = ChanNames(chan);
                        ePeaks.center_frequency(i) = FOOOFdata(chan).FOOOF.peak_params(p,1);
                        ePeaks.amplitude(i) = FOOOFdata(chan).FOOOF.peak_params(p,2);
                        ePeaks.st_dev(i) = FOOOFdata(chan).FOOOF.peak_params(p,3);
                        ePeaks.band(i) = findBand(ePeaks.center_frequency(i), bands);
                    end
                end
            end 
            % Remove unused rows
            ePeaks = ePeaks(1:i,:);
    end
end

function eStats = extractStats(inputFile, pmse, pr2, pfr)
    ChanNames = inputFile.RowNames;
    FOOOFdata = inputFile.FOOOF.FOOOF_data;
    VarUse = logical([1,pmse,pr2]);
    VarNames = {'channel', 'MSE', 'r_squared'};
    VarTypes = {'string','double','double'};
    Cols = sum([1,pmse,pr2]);
    % Preallocate space
    eStats = table('Size', [length(ChanNames), Cols], 'VariableNames', ...
        {VarNames{1,VarUse}}, 'VariableTypes', {VarTypes{1,VarUse}});
    eStats = table2struct(eStats);
    for chan = 1:length(ChanNames)
        if pmse
            eStats(chan).MSE = FOOOFdata(chan).FOOOF.error;
        end
        if pr2
            eStats(chan).r_squared = FOOOFdata(chan).FOOOF.r_squared;
        end
        if pfr
            spec = squeeze(log10(inputFile.TF(chan,1,ismember(inputFile.Freqs,inputFile.FOOOF.FOOOF_freqs))));
            fspec = squeeze(log10(FOOOFdata(chan).FOOOF.fooofed_spectrum))';
            eStats(chan).frequency_wise_error = table('Size',[length(spec),1],...
                'VariableNames',{'abs_error'}, 'VariableTypes',{'double'});
            eStats(chan).frequency_wise_error.abs_error = abs(spec-fspec);
        end
        eStats(chan).channel = ChanNames(chan);
    end 
    eStats = struct2table(eStats);
end

function bandName = findBand(cf,bands)
    bandName = 'None';
    for band = 1:size(bands,1)
        if cf >= bands{band,2}(1) && cf <= bands{band,2}(2)
            bandName = bands{band,1};
        end
    end
end

%% ===== SAVE FILE =====
function NewFile = SaveFile(inputFile, ep, ePeaks, es, eStats, pt, fb, iOutputStudy)

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = inputFile;
    if ep % Extracted peaks
        FileMat.FOOOF.extractedPeaks = ePeaks;
        if pt == 2 % Used frequnecy bands
            FileMat.FOOOF.bands = fb;
        else
            FileMat.FOOOF = rmfield(FileMat.FOOOF, 'bands');
        end
        opts = 'Peak parameters';
    end
    if es % Extracted stats
        FileMat.FOOOF.extractedStats = eStats;
        if ep 
            opts = 'Peak parameters and model stats';
        else
            opts = 'Model stats';
        end
    end
    % Comment
    FileMat.Comment     = strrep(FileMat.Comment, 'FOOOF', 'Analyzed FOOOF');
    % History: Computation
    FileMat = bst_history('add', FileMat, 'extract', opts);
    % ===== SAVE FILE =====
    % Get output study
    sOutputStudy = bst_get('Study', iOutputStudy);
    % File tag
    fileTag = 'timefreq_psd';
    % Output filename
    NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), fileTag);
    % Save file
    bst_save(NewFile, FileMat, 'v6');
    % Add file to database structure
    db_add_data(iOutputStudy, NewFile, FileMat);
end
