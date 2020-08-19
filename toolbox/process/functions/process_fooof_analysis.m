function varargout = process_fooof_analysis(varargin)
% PROCESS_FOOOF_ANALYSIS: Extracts features from FOOOF models
%
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
% Author: Luc Wilson, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Extract FOOOF features';
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
    % === EXTRACT APERIODIC ===
    sProcess.options.extAper.Comment   = 'Extract aperiodic';
    sProcess.options.extAper.Type      = 'checkbox';
    sProcess.options.extAper.Value     = 0;
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
function [extPeaks, extAper, extStats, PeakType, SortBy, FreqBands, pullMSE, pullR2, pullFreqError] = GetOptions(sProcess)
    extPeaks = sProcess.options.extPeaks.Value;
    extAper = sProcess.options.extAper.Value;
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
    [ep, ea, es, pt, sb, fb, pmse, pr2, pfe] = GetOptions(sProcess);
    for iP = 1:length(sInputs)
        bst_progress('text','Standby: Extracting FOOOF features');
        inputFile = in_bst_timefreq(sInputs(iP).FileName); 
        ePeaks = []; eAper = []; eStats = []; % to avoid SaveFile errors
        if ep % Extract Peaks
            ePeaks = extractPeaks(inputFile, pt, sb, fb);
        end
        if ea % Extract Aperiodic
            eAper = extractAperiodic(inputFile);
        end
        if es % Extract Stats
            eStats = extractStats(inputFile, pmse, pr2, pfe);
        end    
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputs(iP));
        OutputFile{end+1} = SaveFile(file_fullpath(sInputs(iP).FileName),...
            inputFile, ep, ePeaks, ea, eAper, es, eStats, pt, fb, iOutputStudy);
    end
end

function ePeaks = extractPeaks(inputFile, pt, sb, fb)
    % Organize/extract peak components from FOOOF models
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

function eAper = extractAperiodic(inputFile)
    % Organize/extract aperiodic components from FOOOF models
    ChanNames = inputFile.RowNames;
    FOOOFdata = inputFile.FOOOF.FOOOF_data;
    VarNames = {'channel', 'offset', 'exponent', 'knee_frequency'};
    VarTypes = {'string', 'double', 'double', 'double'};
    hasKnee = length(FOOOFdata(1).FOOOF.aperiodic_params)-2;
    eAper = table('Size', [length(ChanNames), 3+hasKnee], 'VariableNames', ...
                {VarNames{logical([1 1 1 hasKnee])}}, 'VariableTypes', ...
                {VarTypes{logical([1 1 1 hasKnee])}});
    for chan = 1:length(ChanNames)
            eAper.channel(chan) = ChanNames(chan);
            eAper.offset(chan) = FOOOFdata(chan).FOOOF.aperiodic_params(1);
        if hasKnee % Legacy FOOOF alters order of parameters
            eAper.exponent(chan) = FOOOFdata(chan).FOOOF.aperiodic_params(3);
            eAper.knee_frequency(chan) = FOOOFdata(chan).FOOOF.aperiodic_params(2);
        else
            eAper.exponent(chan) = FOOOFdata(chan).FOOOF.aperiodic_params(2);
        end
    end       
end

function eStats = extractStats(inputFile, pmse, pr2, pfe)
    % Organize/extract stats from FOOOF models
    if ~any([pmse pr2 pfe])
        eStats = 'No stats selected';
        return
    end
    ChanNames = inputFile.RowNames;
    FOOOFdata = inputFile.FOOOF.FOOOF_data;
    VarUse = logical([1,pmse,pr2]);
    VarNames = {'channel', 'MSE', 'r_squared'};
    VarTypes = {'string','double','double'};
    Cols = sum(VarUse);
    % Preallocate space
    eStats = table('Size', [length(ChanNames), Cols], 'VariableNames', ...
        {VarNames{1,VarUse}}, 'VariableTypes', {VarTypes{1,VarUse}});
    eStats = table2struct(eStats);
    for chan = 1:length(ChanNames)
        eStats(chan).channel = ChanNames(chan);
        if pmse
            eStats(chan).MSE = FOOOFdata(chan).FOOOF.error;
        end
        if pr2
            eStats(chan).r_squared = FOOOFdata(chan).FOOOF.r_squared;
        end
        if pfe
            spec = squeeze(log10(inputFile.TF(chan,1,ismember(inputFile.Freqs,inputFile.FOOOF.FOOOF_freqs))));
            fspec = squeeze(log10(FOOOFdata(chan).FOOOF.fooofed_spectrum))';
            eStats(chan).frequency_wise_error = table('Size',[length(spec),1],...
                'VariableNames',{'abs_error'}, 'VariableTypes',{'double'});
            eStats(chan).frequency_wise_error = abs(spec-fspec);
        end
    end 
    eStats = struct2table(eStats);
end

function bandName = findBand(cf,bands)
    % Find name of frequency band from user definitions
    bandName = 'None';
    for band = 1:size(bands,1)
        if cf >= bands{band,2}(1) && cf <= bands{band,2}(2)
            bandName = bands{band,1};
        end
    end
end

%% ===== SAVE FILE =====
function inFileName = SaveFile(inFileName, inputFile, ep, ePeaks, ea, eAper, es, eStats, pt, fb, iOutputStudy)
    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = inputFile;
    opts = [];
    if ep % Extracted peaks
        FileMat.FOOOF.extractedPeaks = ePeaks;
        if pt == 2 % Used frequnecy bands
            FileMat.FOOOF.bands = fb;
        else
            if isfield(FileMat.FOOOF,'bands')
                FileMat.FOOOF = rmfield(FileMat.FOOOF, 'bands');
            end
        end
        opts = 'Peaks';
    end
    if ea
        FileMat.FOOOF.extractedAperiodics = eAper;
        opts = [opts '/Aperiodics'];
    end
    if es % Extracted stats
        FileMat.FOOOF.extractedStats = eStats;
        opts = [opts '/Stats'];
    end
    opts = strip(opts,'left','/');
    % Comment
    % Two cases in the event that we are overwriting a previous FOOOF analysis
    FileMat.Comment     = strrep(FileMat.Comment, 'Analyzed FOOOF', 'FOOOF');
    FileMat.Comment     = strrep(FileMat.Comment, 'FOOOF', 'Analyzed FOOOF');
    % History: Computation
    FileMat = bst_history('add', FileMat, 'extract', opts);
    % ===== SAVE FILE =====
    bst_save(inFileName, FileMat, 'v6');
    db_reload_studies(iOutputStudy)
end
