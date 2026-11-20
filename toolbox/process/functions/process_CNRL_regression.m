function varargout = process_CNRL_regression( varargin ) %#ok<STOUT>
% PROCESS_AVERAGE: Average files, by subject, by condition, or all at once.
%
% USAGE:                    OutputFiles = process_average('Run', sProcess, sInputs)
%                            OutputFile = process_average('AverageFiles', sProcess, sInputs, KeepEvents, isScaleDspm, isWeighted, isMatchRows, isZeroBad)
%                        [sMat,isFixed] = process_average('FixWarpedSurfaceFile', sMat, sInput, sStudyDest)
%  [iGroups, GroupComments, GroupNames] = process_average('SortFiles', sInputs, avgtype)

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
% Authors: Francois Tadel, 2010-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() 
    % Description the process
    sProcess.Comment     = 'Process using trial-based regressors';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'CNRL';
    sProcess.Index       = 3012;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isPaired    = 0;
    sProcess.isSeparator = 1;
    % === GENERIC EXTRACT OPTIONS
    sProcess = DefineExtractOptions(sProcess);
    % === CONNECT INPUT
    % Definition of the options
    % === AVERAGE TYPE
    % sProcess.options.label1.Comment = '<U><B>Group files</B></U>:';
    % sProcess.options.label1.Type    = 'label';
    % sProcess.options.avgtype.Comment = {'Everything', 'By subject', 'By folder (subject average)', 'By folder (grand average)', 'By trial group (folder average)', 'By trial group (subject average)', 'By trial group (grand average)'};
    % sProcess.options.avgtype.Type    = 'radio';
    % sProcess.options.avgtype.Value   = 1;
    % % === FUNCTION
    % sProcess.options.label2.Comment = '<U><B>Function</B></U>:';
    % sProcess.options.label2.Type    = 'label';
    % sProcess.options.avg_func.Comment = {'Arithmetic average:  <FONT color="#777777">mean(x)</FONT>', ...
    %                                      'Average absolute values:  <FONT color="#777777">mean(abs(x))</FONT>', ...
    %                                      'Root mean square (RMS):  <FONT color="#777777">sqrt(sum(x.^2)/N)</FONT>', ...
    %                                      'Standard deviation:  <FONT color="#777777">sqrt(var(x))</FONT>', ...
    %                                      'Standard error:  <FONT color="#777777">sqrt(var(x)/N)</FONT>', ...
    %                                      'Arithmetic average + Standard deviation', ...
    %                                      'Arithmetic average + Standard error', ...
    %                                      'Median:  <FONT color="#777777">median(x)</FONT>'};
    % sProcess.options.avg_func.Type    = 'radio';
    % sProcess.options.avg_func.Value   = 1;
    % % === WEIGHTED AVERAGE
    % sProcess.options.weighted.Comment    = 'Weighted average:  <FONT color="#777777">mean(x) = sum(Leff_i * x(i)) / sum(Leff_i)</FONT>';
    % sProcess.options.weighted.Type       = 'checkbox';
    % sProcess.options.weighted.Value      = 0;
    % sProcess.options.weightedlabel.Comment    = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777">Leff_i = Effective number of averages for file #i</FONT>';
    % sProcess.options.weightedlabel.Type       = 'label';
    % % === KEEP EVENTS
    % sProcess.options.keepevents.Comment    = 'Keep all the event markers from the individual epochs';
    % sProcess.options.keepevents.Type       = 'checkbox';
    % sProcess.options.keepevents.Value      = 0;
    % sProcess.options.keepevents.InputTypes = {'data', 'matrix'};
    % % === SCALE NORMALIZE SOURCE MAPS (DEPRECATED OPTION AFTER INVERSE 2018)
    % sProcess.options.scalenormalized.Comment    = 'Adjust normalized source maps for SNR increase.<BR><FONT color="#777777"><I>Example: dSPM(Average) = sqrt(Navg) * Average(dSPM)</I></FONT>';
    % sProcess.options.scalenormalized.Type       = 'checkbox';
    % sProcess.options.scalenormalized.Value      = 0;
    % sProcess.options.scalenormalized.InputTypes = {'results'};
    % sProcess.options.scalenormalized.Hidden     = 1;
    % % === MATCH ROWS WITH NAMES
    % sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    % sProcess.options.matchrows.Type       = 'checkbox';
    % sProcess.options.matchrows.Value      = 1;
    % sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
    % % === EXCLUDE ZEROS FROM THE AVERAGE
    % sProcess.options.iszerobad.Comment    = 'Exclude the flat signals from the average (zero at all times)';
    % sProcess.options.iszerobad.Type       = 'checkbox';
    % sProcess.options.iszerobad.Value      = 1;
    % sProcess.options.iszerobad.InputTypes = {'timefreq', 'matrix'};
end


%% ===== DEFINE EXTRACT OPTIONS =====
function sProcess = DefineExtractOptions(sProcess)
    % === SELECT: TIME WINDOW
    sProcess.options.timewindow.Comment    = 'Time window:';
    sProcess.options.timewindow.Type       = 'timewindow';
    sProcess.options.timewindow.Value      = [];
    sProcess.options.timewindow.InputTypes = {'data', 'results', 'timefreq', 'matrix'};
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Baseline method
    sProcess.options.method.Comment = {'DC offset correction: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;x_std = x - &mu;'; 'bl'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'bl';
    sProcess.options.method.Hidden  = 1;
% === SELECT: CHANNELS
    sProcess.options.sensortypes.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type       = 'text';
    sProcess.options.sensortypes.Value      = '';
    sProcess.options.sensortypes.InputTypes = {'data'};
%     % === SELECT: Regection threshold
%     sProcess.options.threshmax.Comment    = 'Upper limit for bad trial rejection: ';
%     sProcess.options.threshmax.Type       = 'value';
%     sProcess.options.threshmax.Value      = {0.00, '', 2};
%     sProcess.options.threshmax.InputTypes = {'data', 'results', 'timefreq', 'matrix'};    
%     % === SELECT: Regection threshold
%     sProcess.options.threshmin.Comment    = 'Lower limit for bad trial rejection: ';
%     sProcess.options.threshmin.Type       = 'value';
%     sProcess.options.threshmin.Value      = {0.00, '', 2};
%     sProcess.options.threshmin.InputTypes = {'data', 'results', 'timefreq', 'matrix'};    
%     % units
%     sProcess.options.label1.Comment = '<BR><U><B>Threshold Units</B></U>:';
%     sProcess.options.label1.Type    = 'label';
%     sProcess.options.units.Comment = {'mX: 10<SUP>-3</SUP>', 'uX: 10<SUP>-6</SUP>','pX: 10<SUP>-12</SUP>', 'fX: 10<SUP>-15</SUP>', ''};
%     sProcess.options.units.Type    = 'radio_line';
%     sProcess.options.units.Value   = 1;
    % === SELECT: FREQUENCY RANGE
    sProcess.options.freqrange.Comment    = 'Frequency range: ';
    sProcess.options.freqrange.Type       = 'freqrange';
    sProcess.options.freqrange.Value      = [];
    sProcess.options.freqrange.InputTypes = {'timefreq'};
    % % === SELECT: ROWS
    % sProcess.options.rows.Comment    = 'Signals names or indices (empty=all): ';
    % sProcess.options.rows.Type       = 'text';
    % sProcess.options.rows.Value      = '';
    % sProcess.options.rows.InputTypes = {'timefreq', 'matrix'};
    % 
    % % === SCOUTS SELECTION ===
    % sProcess.options.scoutsel.Comment    = 'Use scouts';
    % sProcess.options.scoutsel.Type       = 'scout_confirm';
    % sProcess.options.scoutsel.Value      = {};
    % sProcess.options.scoutsel.InputTypes = {'results'};
    % % === SCOUTS: FUNCTION
    % sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    % sProcess.options.scoutfunc.Type       = 'radio_line';
    % sProcess.options.scoutfunc.Value      = 1;
    % sProcess.options.scoutfunc.InputTypes = {'results'};
    % 
    % % === NORM XYZ
    % sProcess.options.isnorm.Comment    = ['Compute absolute values (or norm for unconstrained sources). <BR>' ...
    %                                       '<i>Applied after scout function.</i>'];
    % sProcess.options.isnorm.Type       = 'checkbox';
    % sProcess.options.isnorm.Value      = 0;
    % sProcess.options.isnorm.InputTypes = {'results'};
    % === ABSOLUTE VALUE
    sProcess.options.isabs.Comment    = 'Compute absolute values';
    sProcess.options.isabs.Type       = 'checkbox';
    sProcess.options.isabs.Value      = 0;
    sProcess.options.isabs.InputTypes = {'data', 'timefreq', 'matrix'};
    % 
    % === AVERAGE: TIME
    sProcess.options.avgtime.Comment    = 'Average selected time window';
    sProcess.options.avgtime.Type       = 'checkbox';
    sProcess.options.avgtime.Value      = 0;
    sProcess.options.avgtime.InputTypes = {'data', 'results', 'timefreq', 'matrix'};
    % % === AVERAGE: CHANNELS
    % sProcess.options.avgrow.Comment    = 'Average selected signals';
    % sProcess.options.avgrow.Type       = 'checkbox';
    % sProcess.options.avgrow.Value      = 0;
    % sProcess.options.avgrow.InputTypes = {'data', 'timefreq', 'matrix'};
    % === AVERAGE: FREQUENCY
    sProcess.options.avgfreq.Comment    = 'Average selected frequency band';
    sProcess.options.avgfreq.Type       = 'checkbox';
    sProcess.options.avgfreq.Value      = 0;
    sProcess.options.avgfreq.InputTypes = {'timefreq'};
    % % === MATCH ROWS WITH NAMES
    % sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    % sProcess.options.matchrows.Type       = 'checkbox';
    % sProcess.options.matchrows.Value      = 1;
    % sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
end
%%
function OPTIONS = GetExtractOptions(sProcess, sInputs)
    % Time window
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    else
        OPTIONS.TimeWindow = [];
    end

%     % rejection thresholds
%     if isfield(sProcess.options, 'threshmax') && ~isempty(sProcess.options.threshmax) && ~isempty(sProcess.options.threshmax.Value) && sProcess.options.threshmax.Value{1}~=0
%         OPTIONS.ThreshMax = sProcess.options.threshmax.Value{1};
%     else
%         OPTIONS.ThreshMax = [];
%     end
% 
%     if isfield(sProcess.options, 'threshmin') && ~isempty(sProcess.options.threshmin) && ~isempty(sProcess.options.threshmin.Value) && sProcess.options.threshmin.Value{1}~=0
%         OPTIONS.ThreshMin = sProcess.options.threshmin.Value{1};
%     else
%         OPTIONS.ThreshMin = [];
%     end
%     iUnits = sProcess.options.units.Value;
%     switch iUnits
%         case 1
%             OPTIONS.ThreshMax = OPTIONS.ThreshMax * 1e-3;
%             OPTIONS.ThreshMin = OPTIONS.ThreshMin * 1e-3;
%         case 2
%             OPTIONS.ThreshMax = OPTIONS.ThreshMax * 1e-6;
%             OPTIONS.ThreshMin = OPTIONS.ThreshMin * 1e-6;
%         case 3
%             OPTIONS.ThreshMax = OPTIONS.ThreshMax * 1e-12;
%             OPTIONS.ThreshMin = OPTIONS.ThreshMin * 1e-12;
%         case 4
%             OPTIONS.ThreshMax = OPTIONS.ThreshMax * 1e-15;
%             OPTIONS.ThreshMin = OPTIONS.ThreshMin * 1e-15;
%     end
% 
    % Sensor type
    if ismember(sInputs(1).FileType, {'data'}) && isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes) && ~isempty(sProcess.options.sensortypes.Value)
        OPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        OPTIONS.SensorTypes = [];
    end
    % Row indices
    if ismember(sInputs(1).FileType, {'results', 'timefreq', 'matrix'}) && isfield(sProcess.options, 'rows') && ~isempty(sProcess.options.rows) && ~isempty(sProcess.options.rows.Value)
        OPTIONS.Rows = sProcess.options.rows.Value;
    else
        OPTIONS.Rows = [];
    end
    % Freq indices
    if ismember(sInputs(1).FileType, {'timefreq'}) && isfield(sProcess.options, 'freqrange') && isfield(sProcess.options.freqrange, 'Value') && iscell(sProcess.options.freqrange.Value) && (length(sProcess.options.freqrange.Value) == 3) && (length(sProcess.options.freqrange.Value{1}) == 2)
        OPTIONS.FreqRange = sProcess.options.freqrange.Value{1};
    else
        OPTIONS.FreqRange = [];
    end
    % Scouts: Selection
    if isfield(sProcess.options, 'scoutsel') && isfield(sProcess.options.scoutsel, 'Value') && isfield(sProcess.options, 'scoutfunc') && isfield(sProcess.options.scoutfunc, 'Value')
        OPTIONS.ScoutSel = sProcess.options.scoutsel.Value;
        switch lower(sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, OPTIONS.ScoutFunc = 'mean';
            case {2, 'max'},  OPTIONS.ScoutFunc = 'max';
            case {3, 'pca'},  OPTIONS.ScoutFunc = 'pca';
            case {4, 'std'},  OPTIONS.ScoutFunc = 'std';
            case {5, 'all'},  OPTIONS.ScoutFunc = 'all';
            otherwise,  bst_report('Error', sProcess, [], 'Invalid scout function.');  return;
        end
    else
        OPTIONS.ScoutSel = [];
    end    
    % Absolute values / Norm
    OPTIONS.isAbsolute = 0;
    if isfield(sProcess.options, 'isabs') && isfield(sProcess.options.isabs, 'Value')
        OPTIONS.isAbsolute = sProcess.options.isabs.Value;
    end

    if isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value')
        OPTIONS.isAbsolute = sProcess.options.isnorm.Value;
    end

    % Averages
    if isfield(sProcess.options, 'avgtime') && isfield(sProcess.options.avgtime, 'Value')
        OPTIONS.isAvgTime = sProcess.options.avgtime.Value;
    else
        OPTIONS.isAvgTime = 0;
    end
    if isfield(sProcess.options, 'avgrow') && isfield(sProcess.options.avgrow, 'Value')
        OPTIONS.isAvgRow = sProcess.options.avgrow.Value;
    else
        OPTIONS.isAvgRow = 0;
    end
    if isfield(sProcess.options, 'avgfreq') && isfield(sProcess.options.avgfreq, 'Value')
        OPTIONS.isAvgFreq = sProcess.options.avgfreq.Value;
    else
        OPTIONS.isAvgFreq = 0;
    end

    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        OPTIONS.isMatchRows = sProcess.options.matchrows.Value;
    else
        OPTIONS.isMatchRows = 1;
    end
    
    % Time window
    if isfield(sProcess.options, 'baseline') && ~isempty(sProcess.options.baseline) && ~isempty(sProcess.options.baseline.Value) && iscell(sProcess.options.baseline.Value)
        OPTIONS.Baseline = sProcess.options.baseline.Value{1};
        OPTIONS.BaselineMethod = sProcess.options.method.Value;
    else
        OPTIONS.Baseline = [];
        OPTIONS.BaselineMethod = [];
    end

end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<*INUSD>
    % % Function
    % if isfield(sProcess.options, 'avg_func')
    %     switch(sProcess.options.avg_func.Value)
    %         case 1,  Comment = 'Average: ';
    %         case 2,  Comment = 'Average/abs: ';
    %         case 3,  Comment = 'RMS: ';
    %         case 4,  Comment = 'Standard deviation: ';
    %         case 5,  Comment = 'Standard error: ';
    %         case 6,  Comment = 'Average+Std: ';
    %         case 7,  Comment = 'Average+Stderr: ';
    %         case 8,  Comment = 'Median: ';    
    %     end
    % else
    %     Comment = 'Average: ';
    % end
    % % Weighted
    % if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value) && sProcess.options.weighted.Value
    %     Comment = ['Weighted ' Comment];
    % end
    % % Average type
    % iAvgType = sProcess.options.avgtype.Value;
    % Comment = [Comment, sProcess.options.avgtype.Comment{iAvgType}];
        Comment = sProcess.Comment;
%     Comment = 'BetaWeights_4RegressorModel';
    % Get time window for baseline subtractions
    %if sProcess.options.outputmode.Value == 4 
        if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
            Time = sProcess.options.baseline.Value{1};
        else
            Time = [];
        end
        % Add time window to the comment
        if isempty(Time)
            Comment = [Comment, ' bl: [All file]'];
        elseif any(abs(Time) > 2)
            Comment = [Comment, sprintf(' bl: [%1.3fs,%1.3fs]', Time(1), Time(2))];
        else
            Comment = [Comment, sprintf(' bl: [%dms,%dms]', round(Time(1)*1000), round(Time(2)*1000))];
        end
    %end
end
%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs, sInputsB) 

    OutputFiles={};
    defMeasure = 'magnitude'; 

    % Types of files in input
    inFileType = sInputs(1).FileType;

    % Input options
    OPTIONS = GetExtractOptions(sProcess, sInputs);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Get baseline indices based on the first file
    sInput = bst_process('LoadInputFile', sInputs(1).FileName, [], OPTIONS.TimeWindow);
    if ~isempty(OPTIONS.Baseline)            
        OPTIONS.iBaseline = panel_time('GetTimeIndices', sInput.Time, OPTIONS.Baseline);
        if isempty(OPTIONS.iBaseline)
            bst_report('Error', sProcess, sInputs, 'Invalid baseline definition.');
            OPTIONS = []; 
            return;
        elseif (length(OPTIONS.iBaseline) < 3)
            bst_report('Warning', sProcess, sInput, ['The baseline time window you selected contains only ' num2str(length(OPTIONS.iBaseline)) ' sample(s).' 10 ...
                'This is probably an error: check the baseline definition or the input file type ' ...
                '(eg. you cannot use this process to normalize PSD files because they do not have a time dimension.)']);
        end
    % Get all file
    else
        OPTIONS.iBaseline = 1:size(sInput.A,2);
    end
               
    % sort input files by condition/subject
    [iGroups, ~] = process_average('SortFiles',sInputs, 3);
    [iGroupsB, ~] = process_average('SortFiles',sInputsB, 3);

    OutputFiles = cell(1,length(iGroups));

    if length(iGroups)~=length(iGroupsB)
        bst_report('Error', sProcess, [], 'Files on left do not match files on right.');  return;
    end
    for i = 1:length(iGroups)
        bst_progress('set', 0);     
        bst_progress('text',['Processing Subject ' num2str(i) ' of ' num2str(length(iGroups))]);

        sInput = sInputs(iGroups{i});
        sInputB = sInputsB(iGroupsB{i});
    
        [FileMat, matName] = in_bst(sInput(1).FileName,OPTIONS.TimeWindow);
        FileMat.DataFile=[];
        if strcmpi(matName, 'TF') && ~isreal(FileMat.(matName))
            FileMat.Measure = defMeasure;
        end
    
       %trial_reject = false(1,length(sInputs));
        [RegsMat, matName] = in_bst(sInputB(1).FileName);
        regs = RegsMat.(matName);
        regs = regs';
        trial_reject = logical(regs(:,end)); %regs(:,6) > 7;
        regs = regs(:,1:end-1);
        regs_desc = RegsMat.Description;
    
        for iFile=1:length(sInput)
    
            if trial_reject(iFile)
                continue
            end
    
    %         [sMat, matName] = in_bst(sInput(iFile).FileName,OPTIONS.TimeWindow);
            switch (inFileType)
                case {'data', 'raw', 'pdata'}
                    eFileMat = in_bst_data(sInput(iFile).FileName, 'Events', 'DataFile','DataType');
                case {'results', 'link', 'presults'}
                    eFileMat = in_bst_results(sInput(iFile).FileName, 0, 'Events', 'DataFile','DataType');
                case {'timefreq', 'ptimefreq'}
                    eFileMat = in_bst_timefreq(sInput(iFile).FileName, 0, 'Events', 'DataFile','DataType');
                case {'matrix', 'pmatrix'}
                    eFileMat = in_bst_matrix(sInput(iFile).FileName, 'Events', 'DataFile','DataType');
            end
                
    
            if isfield(eFileMat, 'Events') && ~isempty(eFileMat.Events)
                Events = eFileMat.Events;
            elseif isfield(eFileMat, 'DataFile') && ~isempty(eFileMat.DataFile)
                if isfield(eFileMat, 'DataType') && ~isempty(eFileMat.DataType)
                    switch (eFileMat.DataType)
                        case {'results', 'link', 'presults'}
                            eFileMat = in_bst_results(eFileMat.DataFile, 0, 'Events', 'DataFile','DataType');
                        case {'timefreq', 'ptimefreq'}
                            eFileMat = in_bst_timefreq(eFileMat.DataFile, 0, 'Events', 'DataFile','DataType');
                        case {'matrix', 'pmatrix'}
                            eFileMat = in_bst_matrix(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                        otherwise
                            eFileMat = in_bst_data(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                    end
                else
                    eFileMat = in_bst_data(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                end
                if isfield(eFileMat, 'Events') && ~isempty(eFileMat.Events)
                    Events = eFileMat.Events;
                elseif isfield(eFileMat, 'DataFile') && ~isempty(eFileMat.DataFile)
                    if isfield(eFileMat, 'DataType') && ~isempty(eFileMat.DataType)
                        switch (eFileMat.DataType)
                            case {'results', 'link', 'presults'}
                                eFileMat = in_bst_results(eFileMat.DataFile, 0, 'Events', 'DataFile','DataType');
                            case {'timefreq', 'ptimefreq'}
                                eFileMat = in_bst_timefreq(eFileMat.DataFile, 0, 'Events', 'DataFile','DataType');
                            case {'matrix', 'pmatrix'}
                                eFileMat = in_bst_matrix(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                            otherwise
                                eFileMat = in_bst_data(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                        end
                    else
                        eFileMat = in_bst_data(eFileMat.DataFile, 'Events', 'DataFile','DataType');
                    end
                    if isfield(eFileMat, 'Events') && ~isempty(eFileMat.Events)
                        Events = eFileMat.Events;
                    else
                        disp(['Warning - no events found within file #' num2str(iFile)]);
                        Events = [];
                    end
                else
                    disp(['Warning - no events found within file #' num2str(iFile)]);
                    Events = [];
                end
            else
                disp(['Warning - no events found within file #' num2str(iFile)]);
                Events = [];
            end
            
            if ~isempty(Events)
                if any(contains({Events.label},'omit'))
                    trial_reject(iFile) = true;
                end
            end
        end
        disp(['Using ' num2str(sum(~trial_reject)) ' of ' num2str(length(sInput)) ' files'])
        sInput=sInput(~trial_reject);
        cInputs=cell(1,length(sInput));
        for iFile=1:length(sInput)
    % 	    fprintf("0");
    
    %         if trial_reject(iFile)
    %             continue
    %         end
    
            bst_progress('text',['Processing Subject ' num2str(i) ' of ' num2str(length(iGroups)) ':           Loading File ' num2str(iFile) ' of ' num2str(length(sInput))]);
            [sMat, matName] = in_bst(sInput(iFile).FileName,OPTIONS.TimeWindow);
            % Unconstrained sources: Compute the norm of the three orientations
            if strcmpi(matName, 'ImageGridAmp') && (sMat.nComponents ~= 1) && ismember(Function, {'norm', 'rms', 'normdiff', 'normdiffnorm'})
                sMat = process_source_flat('Compute', sMat, 'rms');
            end
            % Connectivity matrix: unpack NxN matrices
            if strcmpi(matName, 'TF') && (length(sMat.RefRowNames) > 1) && isfield(sMat, 'Options') && isfield(sMat.Options, 'isSymmetric') && isequal(sMat.Options.isSymmetric, 1)
                sMat.TF = process_compress_sym('Expand', sMat.TF, length(sMat.RowNames));
                sMat.Options.isSymmetric = 0;
            end
            
            % Copy additional fields
            if isfield(sMat, 'nComponents') && ~isempty(sMat.nComponents)
                nComponents = sMat.nComponents; %#ok<*NASGU>
            end
            if isfield(sMat, 'GridAtlas') && ~isempty(sMat.GridAtlas)
                GridAtlas = sMat.GridAtlas;
            end
            if isfield(sMat, 'Freqs') && ~isempty(sMat.Freqs)
                Freqs = sMat.Freqs;
            end
            if isfield(sMat, 'TFmask') && ~isempty(sMat.TFmask)
                TFmask = sMat.TFmask;
            end
    
    
            % Get values to process
            matValues = double(sMat.(matName));
            TimeVector = sMat.Time;
        
                
            % Apply default measure to TF values
            if strcmpi(matName, 'TF') && ~isreal(matValues)
    %             fprintf("1");
	        % Get default function
                %process_tf_measure('GetDefaultFunction', sMat);
                % Apply default function
                [matValues, isError] = process_tf_measure('Compute', matValues, sMat.Measure, defMeasure);
                if isError
                    Messages = [Messages, 'Error: Invalid measure conversion: ' sMat.Measure ' => ' defMeasure, 10];
                    continue;
                end
    % 	    fprintf("2");
            end
    
            % Get the signals descriptions
            switch (inFileType)
                case 'data'
                    % % Load channel file (only if new one)
                    % if ~isequal(ChannelFile, sInput(iInput).ChannelFile)
                    %     ChannelFile = sInput(iInput).ChannelFile;
                    %     ChannelMat = in_bst_channel(ChannelFile);
                    % end
                    % % Select sensors
                    % if ~isempty(OPTIONS.SensorTypes)
                    %     % Find selected channels
                    %     iChannels = channel_find(ChannelMat.Channel, OPTIONS.SensorTypes);
                    %     if isempty(iChannels)
                    %         bst_report('Error', sProcess, sInput(iInput), 'Could not load anything from the input file. Check the sensor selection.');
                    %         return;
                    %     end
                    %     % Keep only selected channels
                    %     matValues = matValues(iChannels,:,:);
                    %     Description = {ChannelMat.Channel(iChannels).Name}';
                    %     FileMat.ChannelFlag = FileMat.ChannelFlag(iChannels);
                    % else
                    %     Description = {ChannelMat.Channel.Name}';
                    % end
                    % % Set the bad values to zero
                    % if OPTIONS.isBadZero
                    %     matValues(FileMat.ChannelFlag == -1, :) = 0;
                    % end
                    % % Report good/bad channels
                    % if isempty(ChannelFlag)
                    %     ChannelFlag = FileMat.ChannelFlag;
                    % % When setting the bad channels to zero: set as good all the channels that are good in at least one file
                    % elseif OPTIONS.isBadZero
                    %     ChannelFlag(FileMat.ChannelFlag == 1) = 1;
                    % % Regular case: Set as bad all the channels that are bad in at least one file
                    % else
                    %     ChannelFlag(FileMat.ChannelFlag == -1) = -1;
                    % end
                    Description = [];
                    Freqs = [];
                    TFmask = [];
                case 'results'
                    Description = [];
                    Freqs = [];
                    TFmask = [];
                        
                case 'timefreq'
                    Description = FileMat.RowNames;
                    % Get file frequency vector
                    if iscell(FileMat.Freqs)
                        BandBounds = process_tf_bands('GetBounds', FileMat.Freqs);
                        FreqVector = mean(BandBounds,2);
                    else
                        FreqVector = FileMat.Freqs;
                    end
                    % Rounds the frequency vector, to have the same level of precision as the process (3 significant digits)
                    FreqVector = round(FreqVector * 1000) / 1000;
                    % Get TFmask
                    if isfield(FileMat, 'TFmask') && ~isempty(FileMat.TFmask) % && ((length(sInput) == 1) || (OPTIONS.Dim == 0))
                        TFmask = FileMat.TFmask;
                    else
                        TFmask = [];
                    end
                    % Keep only selected frequencies
                    if ~isempty(OPTIONS.FreqRange) && ~isempty(FreqVector) && ~isequal(FreqVector, 0)
                        iFreqs = find((FreqVector >= OPTIONS.FreqRange(1)) & (FreqVector <= OPTIONS.FreqRange(2)));
                        if isempty(iFreqs)
                            bst_report('Error', sProcess, sInput(iFile), 'Invalid frequency range.');
                            return;
                        end
                        matValues = matValues(:,:,iFreqs);
                        % Keep only the selected frequencies
                        if iscell(FileMat.Freqs)
                            Freqs = FileMat.Freqs(iFreqs,:);
                        else
                            Freqs = FileMat.Freqs(iFreqs);
                        end
                        FreqVector = FreqVector(iFreqs);
                        % Report selection on TFmask
                        if ~isempty(TFmask)
                            TFmask = TFmask(iFreqs,:);
                        end
                    else
                        Freqs = FileMat.Freqs;
                    end
                case 'matrix'
                    Description = FileMat.Description;
                    Freqs = [];
                    TFmask = [];
            end

            if isfield(sMat, 'RowNames') && ~isempty(sMat.RowNames)
                RowNames = sMat.RowNames;
            elseif isfield(sMat, 'Description') && ~isempty(sMat.Description)
                RowNames = sMat.Description;
            else
                RowNames = [];
            end
            if isfield(sMat, 'RefRowNames') && ~isempty(sMat.RefRowNames)
                if ~isempty(DestRowNames) && (length(sMat.RefRowNames) == length(sMat.RowNames))
                    RefRowNames = DestRowNames;
                else
                    RefRowNames = sMat.RefRowNames;
                end
            end
    
    
            % === BAD CHANNELS ===
            % Use an existing list of bad channels
            if isfield(sMat, 'ChannelFlag') && ~isempty(sMat.ChannelFlag) && (length(sMat.ChannelFlag) == size(matValues,1))
                ChannelFlag = sMat.ChannelFlag;
            % Else: Detect bad channels in matrix/timefreq files
            elseif ~isempty(RowNames)
                % By default: all channels are good
                ChannelFlag = ones(size(matValues,1),1);
            else
                ChannelFlag = [];
            end
            % Clear the loaded file
            clear sMat;
                
            % === BASELINE ===
            if isfield(OPTIONS, 'iBaseline') && ~isempty(OPTIONS.iBaseline) 
                indx = repmat({1},1,ndims(matValues));
                matSize = size(matValues);
                for d=1:ndims(matValues)
                    indx{d}=1:matSize(d);
                end
                indx{2}=find(OPTIONS.iBaseline);
                matValues = process_baseline_norm('Compute', matValues, matValues(indx{:}), OPTIONS.BaselineMethod);
            end
            
            % === AVERAGE TIME ===
            if OPTIONS.isAvgTime && (size(matValues,2) > 1)
                % Compute average in time
                matValues = mean(matValues, 2);

                % % If we are concatenating multiple files in time dimension: keep only one time point for each file
                % if (OPTIONS.Dim == 2) && (length(sInput) > 1)
                FileMat.Time = FileMat.Time(1);

                % Discard edge effects map
                TFmask = [];
            end
            % === AVERAGE FREQUENCY ===
            if OPTIONS.isAvgFreq && (size(matValues,3) > 1) && ~isempty(Freqs)
                matValues = mean(matValues, 3);
                Freqs = {'AVG', [num2str(FreqVector(1)), ', ' num2str(FreqVector(end))], 'mean'};
                % Edge effects map: good only if good in all the frequencies
                if ~isempty(TFmask)
                    TFmask = all(TFmask, 1);
                end
            end
            
            cInputs{end+1} = matValues; %#ok<*AGROW>
            bst_progress('set', iFile*(50/sum(~trial_reject)));
       
        end
            
        FileMat.(matName) = matValues;
        if exist("Freqs","var") && ~isempty(Freqs)
            FileMat.Freqs = Freqs;
        end
    
        dim = ndims(cInputs{1});
        yValues=cat(dim+1,cInputs{:});
    
        clear cInputs
    
        yValues=reshape(yValues,[numel(yValues)./iFile iFile]);
    
        regs=regs(~trial_reject,:);

        bst_progress('text',['Processing Subject ' num2str(i) ' of ' num2str(length(iGroups)) ': Regressing ' num2str(length(regs(1,:))) ' variables onto trial data']);
        parfor v=1:size(yValues,1)
            [b(v,:), b_int(v,:,:), ~, ~, stats(v,:)] = regress(yValues(v,:)',regs);
        end
        clear yValues
    
        tmap = b./(diff(b_int,1,ndims(b_int))/(2*1.96));
        tmap(isnan(tmap))=0;
        
        df   = size(regs,1) - 1;
        dfmap = ones(size(tmap)) .* df;
        
        % Calculate p-values from t-values
        pmap = ComputePvalues(tmap, df, 't', 'two');

        bst_progress('set',80);
        bst_progress('text',['Processing Subject ' num2str(i) ' of ' num2str(length(iGroups)) ':  Writing Datafiles']);      
       
        % SETUP STATS OUTPUT STRUCTURE %
        DisplayUnits = 't';
        
        statOutput = db_template('statmat');
        statOutput.Correction   = 'no';
        statOutput.ChannelFlag  = ChannelFlag;
        statOutput.Time         = FileMat.Time;
        statOutput.ColormapType = 'stat2';
        statOutput.DisplayUnits = DisplayUnits;
        Options.TimeWindow = [];
        Options.SensorTypes=[];
        Options.Rows=[];
        Options.FreqRange=[];
        Options.ScoutSel=[];
        Options.isAbsolute=0;
        Options.isAvgTime=0;
        Options.isAvgRow=0;
        Options.isAvgFreq=0;
        Options.isMatchRows=1;
        Options.isZeroBad=1;
        Options.TestType='ttest_onesample';
        Options.TestTail='two';
        Options.nGoodSamplesA=ones(size(matValues));
        Options.nGoodSamplesB=[];
        statOutput.Options = Options;
        if isfield(FileMat, 'nComponents') && ~isempty(FileMat.nComponents)
    	    statOutput.nComponents  = FileMat.nComponents;
        else
    	    statOutput.nComponents  = 1;
        end
        if isfield(FileMat, 'Freqs') && ~isempty(FileMat.Freqs)
    	    statOutput.Freqs  = FileMat.Freqs;
        end
        if isfield(FileMat, 'TFmask') && ~isempty(FileMat.TFmask)
    	    statOutput.TFmask  = FileMat.TFmask;
        end
        if isfield(FileMat, 'HeadModelType') && ~isempty(FileMat.HeadModelType)
    	    statOutput.HeadModelType  = FileMat.HeadModelType;
        end
        if isfield(FileMat, 'SurfaceFile') && ~isempty(FileMat.SurfaceFile)
    	    statOutput.SurfaceFile  = FileMat.SurfaceFile;
            OutputFileType = 'results';
        else
            OutputFileType = sInput(1).FileType;
        end
        
        statOutput.Type         = OutputFileType;
        
        % Row names
        if isfield(FileMat, 'RowNames') && ~isempty(FileMat.RowNames)
            if strcmpi(OutputFileType, 'matrix')
                statOutput.Description = FileMat.RowNames;
            elseif strcmpi(OutputFileType, 'timefreq')
                statOutput.RowNames = FileMat.RowNames;
            end
        end
        
        % LOOP THROUGH ALL PREDICTOR VARIABLES
        for iBeta=1:length(b(1,:))
    
            FileMat.(matName) = reshape(b(:,iBeta),size(FileMat.(matName)));
            
            % === CREATE OUTPUT STRUCTURE FOR BETAS ===
            % Get output study
            [sStudy, iStudy, Comment, ~] = bst_process('GetOutputStudy', sProcess, sInput);
            FileMat.Comment=[Comment, '(', num2str(length(trial_reject)),') Beta', num2str(iBeta - 1), ' ', regs_desc{iBeta}];

            % === SAVE FILE ===
            % Output filename
            if strcmpi(sInput(1).FileType, 'data')
                allFiles = {};
                for iInput = 1:length(sInput)
                    [~, allFiles{end+1}, ~] = bst_fileparts(sInput(iInput).FileName);
                end
                fileTag = str_common_path(allFiles, '_');
            else
                fileTag = bst_process('GetFileTag', sInput(1).FileName);
            end
            OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [fileTag, '_Beta', num2str(iBeta - 1), ' ', regs_desc{iBeta}]);

            % Save on disk
            bst_save(OutputFile, FileMat, 'v6');

            % Register in database
            db_add_data(iStudy, OutputFile, FileMat);
            OutputFiles{end+1}=OutputFile;
            
            % === CREATE OUTPUT STRUCTURE FOR STATS ===
            statOutput.pmap         = reshape(pmap(:,iBeta),size(FileMat.(matName)));
            statOutput.tmap         = reshape(tmap(:,iBeta),size(FileMat.(matName)));
            statOutput.df           = reshape(dfmap(:,iBeta),size(FileMat.(matName)));
    
            % Get output study
            [sStudy, iStudy, Comment, ~] = bst_process('GetOutputStudy', sProcess, sInput);
            statOutput.Comment=[Comment, '(', num2str(length(trial_reject)),') tval', num2str(iBeta - 1), ' ', regs_desc{iBeta}];

            % === SAVE FILE ===
            OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['p' OutputFileType '_no_t', num2str(iBeta - 1), ' ', regs_desc{iBeta}]);

            % Save on disk
            bst_save(OutputFile, statOutput, 'v6');

            % Register in database
            db_add_data(iStudy, OutputFile, statOutput);
            OutputFiles{end+1}=OutputFile;
        end
            

        % === CREATE OUTPUT STRUCTURE FOR RSQ===
        df   = size(regs,1) - size(regs,2) - 1;
        dfmap = ones(size(tmap)) .* df;
        statOutput.DisplayUnits = 'Rsq';
        statOutput.pmap         = reshape(stats(:,3),size(FileMat.(matName)));
        statOutput.tmap         = reshape(stats(:,1),size(FileMat.(matName)));
        statOutput.df           = reshape(dfmap(:,1),size(FileMat.(matName)));

        % Get output study
        [sStudy, iStudy, Comment, ~] = bst_process('GetOutputStudy', sProcess, sInput);
        statOutput.Comment=[Comment,'(', num2str(length(trial_reject)),') Rsq'];

        % === SAVE FILE ===
        % Output filename
        OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['p' OutputFileType '_no_Rsq']);

        % Save on disk
        bst_save(OutputFile, statOutput, 'v6');

        % Register in database
        db_add_data(iStudy, OutputFile, statOutput);
        OutputFiles{end+1}=OutputFile;
        db_reload_studies(iStudy);

    end
    % Close progress bar
    bst_progress('stop');
end
%% ===== COMPUTE P-VALUES ====
function p = ComputePvalues(t, df, TestDistrib, TestTail)
    % Default: two-tailed tests
    if (nargin < 4) || isempty(TestTail)
        TestTail = 'two';
    end
    % Default: F-distribution
    if (nargin < 3) || isempty(TestDistrib)
        TestDistrib = 'f';
    end
    % Nothing to test
    if strcmpi(TestTail, 'no')
        p = zeros(size(t));
        return;
    end
    
    % Different distributions
    switch lower(TestDistrib)
        % === T-TEST ===
        case 't'
            % Calculate p-values from t-values 
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed t-test:   p = tcdf(t, df);
                    % Equivalent without the statistics toolbox (FieldTrip formula)            
                    p = 0.5 .* ( 1 + sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) );
                case 'two'
                    % Two-tailed t-test:     p = 2 * (1 - tcdf(abs(t),df));
                    % Equivalent without the statistics toolbox
                    p = betainc( df ./ (df + t .^ 2), df./2, 0.5);
                    % FieldTrip equivalent: p2 = 1 - betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df );
                case 'one+'
                    % Superior one-tailed t-test:    p = 1 - tcdf(t, df);
                    % Equivalent without the statistics toolbox (FieldTrip formula)
                    p = 0.5 .* ( 1 - sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) );
            end
            
        % === F-TEST ===
        case 'f'
            v1 = df{1};
            v2 = df{2};
            % Evaluate for which values we can compute something
            k = ((t > 0) & ~isinf(t) & (v1 > 0) & (v2 > 0));
            % Initialize returned p-values
            p = ones(size(t));                    
            % Calculate p-values from F-values 
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed F-test
                    % p = fcdf(t, v1, v2);
                    p(k) = 1 - betainc(v2(k)./(v2(k) + v1(k).*t(k)), v2(k)./2, v1(k)./2);
                case 'two'
                    % Two tailed F-test
                    % p = 2*min(fcdf(F,df1,df2),fpval(F,df1,df2))
                    p(k) = 2 * min(...
                            1 - betainc(v2(k)./(v2(k) + v1(k).*t(k)), v2(k)./2, v1(k)./2), ...
                            1 - betainc(v1(k)./(v1(k) + v2(k)./t(k)), v1(k)./2, v2(k)./2));
                case 'one+'
                    % Superior one-tailed F-test
                    % p = fpval(t, v1, v2);
                    %   = fcdf(1/t, v2, v1);
                    p(k) = 1 - betainc(v1(k)./(v1(k) + v2(k)./t(k)), v1(k)./2, v2(k)./2);
            end
            
        % === CHI2-TEST ===
        case 'chi2'
            % Calculate p-values from Chi2-values 
            %   chi2cdf(x,n) = gammainc(t/2, n/2)
            switch (TestTail)
                case 'one-'
                    % Inferior one-tailed Chi2-test:    p = gammainc(t./2, df./2);
                    error('Not relevant.');
                case 'two'
                    % Two-tailed Chi2-test
                    error('Not relevant.');
                case 'one+'
                    % Superior one-tailed Chi2-test:    p = 1 - gammainc(t./2, df./2);
                    p = 1 - gammainc(t./2, df./2);
            end
    end
end