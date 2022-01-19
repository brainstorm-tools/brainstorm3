function out_figure_timefreq( hFig, OutputFile, varargin )
% OUT_FIGURE_TIMEFREQ: Save the current time-freq map displayed in this figure.
%
% USAGE:  out_figure_timefreq(hFig, OutputFile)  : Extract values from hFig and save them into OutputFile
%         out_figure_timefreq(hFig, 'Variable')  : Extract values from hFig and save them in a base workspace variable
%         out_figure_timefreq(hFig, 'Database')  : Extract values from hFig and save them in a new file in database
%         out_figure_timefreq(hFig)              : Extract values from hFig and ask user where to save them
%         out_figure_timefreq(... , 'Selection') : Keep only the current selection in the figure
%         out_figure_timefreq(... , 'Average')   : Compute the average in time/frequency of the selection
%         out_figure_timefreq(... , 'Matrix')    : Save as a "matrix" structure, instead of a time-freq file

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
% Authors: Francois Tadel, 2010-2014

global GlobalData;
    
%% ===== PARSE INPUTS =====
% Options
isAverage   = any(strcmpi(varargin, 'Average'));
isSelection = any(strcmpi(varargin, 'Selection'));
isMatrix    = any(strcmpi(varargin, 'Matrix'));

% Get original filename
TfInfo = getappdata(hFig, 'Timefreq');
TfFile = file_fullpath(TfInfo.FileName);
iExportDb = 0;
% Get structure from intial file
TfMat = load(TfFile);
% If image filename is not specified
if (nargin < 2) || isempty(OutputFile)   
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.TimefreqOut)
        case 'ASCII-CSV',       DefaultExt = '.csv';
        case 'ASCII-CSV-HDR',   DefaultExt = '.csv';
        case 'ASCII-SPC',       DefaultExt = '.txt';  
        case 'ASCII-SPC-HDR',   DefaultExt = '.txt';        
        case 'EXCEL',           DefaultExt = '.xlsx';
        case 'BST',             DefaultExt = '_timefreq.mat';
        otherwise,              DefaultExt = '_timefreq.mat';
    end
    % Get the default filename
    [initPath, initBase, initExt] = bst_fileparts(TfFile);
    % Ask confirmation for the figure filename
    OutputFile = bst_fullfile(LastUsedDirs.ExportData, [initBase, '_extract', DefaultExt]);
    OutputFile = file_unique(OutputFile);
    % Get filename where to store the filename
    [OutputFile, FileFormat] = java_getfile( 'save', ...
        'Export time-frequency...', ... % Window title
        OutputFile, ...                 % Default directory
        'single', 'files', ...          % Selection mode
        bst_get('FileFilters', 'timefreqout'), ...
        DefaultFormats.TimefreqOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return;
    end
    % Decompose filename
    [filePath, fileBase, fileExt] = bst_fileparts(OutputFile);
    % Check that filename contains the 'timefreq' tag (Brainstorm only)
    if strcmpi(FileFormat, 'BST')
        fileBase = strrep(fileBase, '_timefreq', '');
        fileBase = strrep(fileBase, 'timefreq_', '');
        fileBase = ['timefreq_' fileBase];
        OutputFile = bst_fullfile(filePath, [fileBase fileExt]);
    end
    % Save new default export path
    LastUsedDirs.ExportData = filePath;
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.TimefreqOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
% Export to database
elseif strcmpi(OutputFile, 'Database')
    % Exporting a matrix file
    if isMatrix
        OutputFile = bst_process('GetNewFilename', bst_fileparts(TfFile), 'matrix_');
    else
        OutputFile = strrep(TfFile, '.mat', '_extract_fig.mat');
        OutputFile = file_unique(OutputFile);
    end
    iExportDb = 1;
end


%% ===== EXTRACT VALUES =====
% Progress bar
bst_progress('start', 'Export time-frequency values', 'Exporting values...');
% Get values
[Time, Freqs, TfInfo, TF, RowNames, FullTimeVector] = figure_timefreq('GetFigureData', hFig, 'UserTimeWindow');
% If there are time bands defined
if iscell(Time)
    TimeBands = Time;
    Time = FullTimeVector;
else
    TimeBands = {};
end
% If power spectrum density
isSpectrum = ~isempty(strfind(TfInfo.FileName, '_psd')) || ~isempty(strfind(TfInfo.FileName, '_fft'));
if isSpectrum
    Time = Time([1 end]);
end
% If there is only one row: need to reshape the TF matrix (rows x time x freq)
if ischar(RowNames)
    RowNames = {RowNames};
end


%% ===== SENSOR SELECTION =====
% SPECTRUM windows only: Get mouse selected sensor
if ismember(TfInfo.DisplayMode, {'Spectrum', 'TimeSeries'})
    % Get figure
    [hFig, iFig, iDS]  = bst_figures('GetFigure', hFig);
    % Find file definition in memory
    iTimefreq = bst_memory('GetTimefreqInDataSet', iDS, TfInfo.FileName);
    % Find row names in full TF file
    AllRows = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
    [SelRowNames, iRowsTf] = figure_timeseries('GetFigSelectedRows', hFig, AllRows);
    % If something is selected: Keep only the selected sensors
    if ~isempty(iRowsTf)
        TF       = TF(iRowsTf,:,:);
        RowNames = SelRowNames;
    end
end

    
%% ===== TIME/FREQ SELECTION =====
% Get time-freq selection
if isSelection
    GraphSelection = getappdata(hFig, 'GraphSelection');
    % === TIME SELECTION ===
    % Cannot remove time if export to database + file dependent on another file
    if (iExportDb && ~isempty(TfMat.DataFile)) && (strcmpi(TfInfo.DisplayMode, 'TimeSeries') || strcmpi(TfInfo.DisplayMode, 'SingleSensor')) && ~isMatrix
        java_dialog('warning', ['Cannot apply time selection for files exported to database. ' 10 10 ...
                                'The fime-frequency files saved in the database need a time definition' 10 ...
                                'compatible with the files they have been computed from.' 10 ...
                                'This operation will export only the selected frequencies, but will' 10 ...
                                'keep all the times instants.'], 'Export');
    else
        % Time series: extract selection
        if strcmpi(TfInfo.DisplayMode, 'TimeSeries')
            iSelTimeBounds = bst_closest(GraphSelection, Time);
            iSelTime = min(iSelTimeBounds) : max(iSelTimeBounds);
            Time = Time(iSelTime);
        % Regular timefreq maps
        elseif strcmpi(TfInfo.DisplayMode, 'SingleSensor')
            TimeSel = [min(GraphSelection(1,:)), max(GraphSelection(1,:))];
            % Find all the time points in the selection interval
            iSelTime = find((Time >= TimeSel(1)) & (Time <= TimeSel(2)));
            Time = Time(iSelTime);
            % Time selection
            if ~isempty(TimeBands)
                % Find the time bands in the selection interval
                iSelBands = [];
                BandBounds = process_tf_bands('GetBounds', TimeBands);
                for i = 1:size(TimeBands,1)
                    if (~all(BandBounds(i,:) < TimeSel(1)) && ~all(BandBounds(i,:) > TimeSel(2)))
                        iSelBands(end+1) = i;
                        BandBounds(i,1) = max(BandBounds(i,1), TimeSel(1));
                        BandBounds(i,2) = max(BandBounds(i,2), TimeSel(2));
                        TimeBands{iSelBands,2} = [num2str(BandBounds(i,1)) ', ' num2str(BandBounds(i,2))];
                    end
                end
                TimeBands = TimeBands(iSelBands,:);
                % Keep the data of interest
                iSelTime = iSelBands;            
            end
        else
            iSelTime = [];
        end
        % Remove times
        if ~isempty(iSelTime)
            TF = TF(:,iSelTime,:);
        end
    end

    % === FRENQUENCY SELECTION ===
    if strcmpi(TfInfo.DisplayMode, 'Spectrum')
        iSelFreqBounds = bst_closest(GraphSelection, Freqs);
        iSelFreq = min(iSelFreqBounds) : max(iSelFreqBounds);
        % Frequency bands
        if iscell(Freqs)
            Freqs = Freqs(iSelFreq,:);
        else
            Freqs = Freqs(iSelFreq);
        end
    elseif strcmpi(TfInfo.DisplayMode, 'TimeSeries')
        iSelFreq = 1:size(TF,3);
    else
        iSelFreq = min(GraphSelection(2,:)) : max(GraphSelection(2,:));
        % Frequency bands
        if iscell(Freqs)
            Freqs = Freqs(iSelFreq,:);
        else
            Freqs = Freqs(iSelFreq);
        end
    end
    % Keep the selected frequencies
    TF = TF(:,:,iSelFreq);
end


%% ===== AVERAGE =====
% Compute time average if necessary
if isAverage 
    % Average time 
    TF = mean(TF, 2);
    Time = [Time(1), Time(end)];
    TimeBands = {};
    % Average freq
    TF = mean(TF, 3);
    if iscell(Freqs)
        BandBounds = process_tf_bands('GetBounds', Freqs);
        Freqs = [BandBounds(1,1), BandBounds(end,2)];
    else
        Freqs = [Freqs(1), Freqs(end)];
    end
end



%% ===== CREATE TIMEFREQ STRUCTURE =====
% Update some fields
if isMatrix
    OutputMat = db_template('matrixmat');
    OutputMat.Comment     = [TfMat.Comment, ' | extract fig'];
    OutputMat.Time        = Time;
    OutputMat.Description = {};
    if (size(TF,3) > 1)
        for iFreq = 1:size(TF,3)
            OutputMat.Value = [OutputMat.Value ; TF(:,:,iFreq)];
            for iRow = 1:length(RowNames)
                if iscell(Freqs)
                    OutputMat.Description{end+1,1} = sprintf('%s: %s', RowNames{iRow}, Freqs{iFreq,1});
                else
                    OutputMat.Description{end+1,1} = sprintf('%s: %1.2fHz', RowNames{iRow}, Freqs(iFreq));
                end
            end
        end
    else
        OutputMat.Value = TF;
        OutputMat.Description = RowNames(:);
    end
else
    OutputMat = TfMat;
    OutputMat.TF        = TF;
    OutputMat.Measure   = TfInfo.Function;
    OutputMat.Comment   = [TfMat.Comment, ' | extract fig'];
    OutputMat.Time      = Time;
    OutputMat.TimeBands = TimeBands;
    OutputMat.Freqs     = Freqs;
    OutputMat.RowNames  = RowNames;
end


%% ===== SAVE VALUES =====
% ===== EXPORT TO MATLAB =====
if strcmpi(OutputFile, 'Variable')
    export_matlab(OutputMat);

% ===== EXPORT TO DATABASE =====
% Assume that there is only one block of data, and if they actually come from a DATA FILE
elseif iExportDb
    % History: Time window
    if isAverage
        strMsg = sprintf('Average time-freq window: [%1.2f,%1.2f]ms', OutputMat.Time([1,end]) * 1000);
    else
        strMsg = sprintf('Extract time-freq window: [%1.2f,%1.2f]ms', OutputMat.Time([1,end]) * 1000);
    end
    OutputMat = bst_history('add', OutputMat, 'extract', strMsg);
    
    % Save file
    bst_save(OutputFile, OutputMat, 'v6');
    
    % === ADD NEW FILE TO STUDY ===
    % Get study
    [sStudy, iStudy] = bst_get('TimefreqFile', TfFile);
    % Create new data descriptor and add it to strudy
    if isMatrix
        sNewTf = db_template('Matrix');
        sNewTf.FileName = file_short(OutputFile);
        sNewTf.Comment  = OutputMat.Comment;
        sStudy.Matrix(end+1) = sNewTf;
    else
        sNewTf = db_template('Timefreq');
        sNewTf.FileName = file_short(OutputFile);
        sNewTf.Comment  = OutputMat.Comment;
        sNewTf.DataFile = OutputMat.DataFile;
        sNewTf.DataType = OutputMat.DataType;
        sStudy.Timefreq(end+1) = sNewTf;
    end
    % Update study
    bst_set('Study', iStudy, sStudy);
    % Update links for target study
    db_links('Study', iStudy);
    % Reload tree
    panel_protocols('UpdateNode', 'Study', iStudy);
    panel_protocols('SelectNode', [], sNewTf.FileName );
    
% ===== EXPORT TO .MAT FILE =====
% Brainstorm format: simply save the matrix
elseif strcmpi(FileFormat, 'BST')
    bst_save(OutputFile, OutputMat, 'v6');

% ===== EXPORT TO TEXT FILE =====
else
    % Save file
    export_timefreq(OutputMat, OutputFile, FileFormat);
end

% Close progress bar
bst_progress('stop');





