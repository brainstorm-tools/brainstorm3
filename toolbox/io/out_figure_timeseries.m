function out_figure_timeseries( hFig, TSFile, varargin )
% OUT_FIGURE_TIMESERIES: Save all the time series found in a Matlab figure.
%
% USAGE:  out_figure_timeseries(hFig, TSFile)     : Extract time series from hFig and save them into TSFile
%         out_figure_timeseries(hFig, 'Variable') : Extract time series from hFig and save them in a base workspace variable
%         out_figure_timeseries(hFig, 'Database') : Extract time series from hFig and save them in a new file in database
%         out_figure_timeseries(hFig)             : Extract time series from hFig and ask user where to save them
%         out_figure_timeseries(... , 'SelectedChannels') : if some channels are highlighted in the figure, return only them
%         out_figure_timeseries(... , 'SelectedTime')     : if a time segment is highlighted in the figure, return only this segment
%         out_figure_timeseries(... , 'TimeAverage')      : Compute the average in time of the selection
%
% FORMAT:
%     Two output file format: .MAT and ASCII
%     MATLAB Format :
%     ---------------
%         |- F       : cell array of matrices of any size (all lines found each axes object)
%         |- Time    : Time vector (common for all the F cells)
%         |- Comment : Global comment for this file
%         |- Legend  : cell array of strings (comments for each F cell)
%            => Many other optional fields, depending on the DataType
% 
%     ASCII Format :
%     --------------
%        - One header:
%             "nbBlocks globalComment"
%        - One block for each F cell:
%             "nbChannel nbTimeSamples dataLabel"          
%             "<nbChannel x nbTimeSamples double matrix>
%        - One block for the time values:
%             "Time"
%             "<1 x nbTimeSamples double matrix>

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
% Authors: Francois Tadel, 2008-2018

global GlobalData;


%% ===== EXTRACT TIME SERIES =====
% Check montage 
TsInfo = getappdata(hFig, 'TsInfo');
if ~isempty(TsInfo) && isfield(TsInfo, 'MontageName') && ~isempty(TsInfo.MontageName)
    sMontage = panel_montage('GetMontage', TsInfo.MontageName);
    if ~isempty(sMontage) && ~isequal(sMontage.DispNames, sMontage.ChanNames)
        error(['Cannot export selected montage "' TsInfo.MontageName '".' 10 'Select montage "All channels" or use process "Apply montage".']);
    end
end
% Get values  (this takes care of the time selection)
[TSMat, iDS, iFig] = gui_figure_data(hFig, varargin{:});


%% ===== PARSE INPUTS =====
%% === FILENAME ===
% If image filename is not specified
if (nargin < 2) || isempty(TSFile)   
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.DataOut)
        case 'BST-BIN',         DefaultExt = '.bst';
        case 'EEG-BRAINAMP',    DefaultExt = '.eeg';
        case 'EEG-CARTOOL-EPH', DefaultExt = '.eph';
        case 'EEG-EGI-RAW',     DefaultExt = '.raw';
        case 'EEG-EDF',         DefaultExt = '.edf';
        case 'ASCII-CSV',       DefaultExt = '.csv';
        case 'ASCII-CSV-HDR',   DefaultExt = '.csv';
        case 'ASCII-SPC',       DefaultExt = '.txt';  
        case 'ASCII-SPC-HDR',   DefaultExt = '.txt';        
        case 'EXCEL',           DefaultExt = '.xlsx';
        case 'BST',             DefaultExt = '_timeseries.mat';
        otherwise,              DefaultExt = '_timeseries.mat';
    end
    % Get the default filename (from the window title)
    wndTitle = get(hFig, 'Name');
    if isempty(wndTitle)
        TSFile = 'timeseries_01.mat';
    else
        TSFile = ['timeseries_', file_standardize(wndTitle), DefaultExt];
        TSFile = strrep(TSFile, '__', '_');
    end
    % Ask confirmation for the figure filename
    TSFile = bst_fullfile(LastUsedDirs.ExportData, TSFile);
    % Make filename unique
    TSFile = file_unique(TSFile);
    % Get output formats 
    if strcmpi(TSMat.FigType, 'DataTimeSeries')
        ExportFormats = bst_get('FileFilters', 'dataout');
    else
        ExportFormats = bst_get('FileFilters', 'matrixout');
    end
        
    % === Ask user filename ===
    % Get filename where to store the filename
    [TSFile, TSFormat] = java_getfile( 'save', ...
        'Export time series...', ... % Window title
        TSFile, ...                  % Default directory
        'single', 'files', ...       % Selection mode
        ExportFormats, ...
        DefaultFormats.DataOut);
    % If no file was selected: exit
    if isempty(TSFile)
        return;
    end    
    % Decompose filename
    [filePath, fileBase, fileExt] = bst_fileparts(TSFile);
    % Check that filename contains the 'timeseries' tag (Brainstorm only)
    if strcmpi(TSFormat, 'BST')
        fileBase = strrep(fileBase, '_timeseries', '');
        fileBase = strrep(fileBase, 'timeseries_', '');
        fileBase = ['timeseries_' fileBase];
        TSFile = bst_fullfile(filePath, [fileBase fileExt]);
    end
    % Save new default export path
    LastUsedDirs.ExportData = filePath;
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.DataOut = TSFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end
% Options: 
isTimeAverage      = any(strcmpi(varargin, 'TimeAverage'));
isSelectedChannels = any(strcmpi(varargin, 'SelectedChannels'));


%% ===== PREPARE EXPORT =====
% Get number of plots in the figure
nbBlocks = length(TSMat.F);
% Compute time average if necessary
if isTimeAverage
    % Average values
    for iCell = 1:nbBlocks
        TSMat.F{iCell} = repmat(mean(TSMat.F{iCell}, 2), [1 2]);
    end
    % Keep only first and last times
    TSMat.Time = [TSMat.Time(1), TSMat.Time(end)];
end


%% ===== SAVE TIME SERIES =====
% ===== EXPORT TO MATLAB =====
if strcmpi(TSFile, 'Variable')
    export_matlab(TSMat);

% ===== EXPORT TO DATABASE =====
% Assume that there is only one block of data, and if they actually come from a DATA FILE
elseif strcmpi(TSFile, 'Database')
    % === GET DATA ===
    % Check number of plots
    if (nbBlocks > 1)
        error('You can use the "Database" option only if there is only one plot in the file.');
    end
    % Check modality
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    if ~ismember(Modality, {'EEG','MEG','MEG GRAD','MEG MAG','ECOG','SEEG'})
        error('You can use the "Database" option only to extract recordings time series.');
    end
    
    % Get mouse selected channels
    [RowNames, iRows] = figure_timeseries('GetFigSelectedRows', hFig, {GlobalData.DataSet(iDS).Channel.Name});
    % Get the selected channels
    if isSelectedChannels && isempty(iRows)
        iRows = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    end
    % Get the real ammount of channels
    nChannels = length(GlobalData.DataSet(iDS).Measures.ChannelFlag);
    % Initialize returned data matrix
    F = zeros(nChannels, size(TSMat.F{1},2));
    % Copy extracted values
    F(iRows,:) = TSMat.F{1};
    
    % === STRUCTURE TO SAVE ===
    bst_progress('start', 'Save time series', 'Reading original file...');
    % Get protocol directories
    ProtocolInfo = bst_get('ProtocolInfo');
    % Load initial data file
    DataFile = GlobalData.DataSet(iDS).DataFile;
    DataMat = in_bst_data(DataFile);
    % Prepare structure to be save
    DataMat.F       = F;
    DataMat.Comment = [DataMat.Comment ' | extract fig'];
    DataMat.Time    = TSMat.Time;
    % If saving raw data
    isRaw = isfield(DataMat, 'DataType') && strcmpi(DataMat.DataType, 'raw');
    if isRaw
        DataMat.DataType = 'recordings';
    end
    % Copy events
    if ~isempty(TSMat.Events)
        DataMat.Events = TSMat.Events;
    end
    % History: Time window
    if isTimeAverage
        strMsg = sprintf('Average time window: [%1.2f,%1.2f] ms', TSMat.Time([1,end]) * 1000);
    else
        strMsg = sprintf('Extract time window: [%1.2f,%1.2f] ms', TSMat.Time([1,end]) * 1000);
    end
    DataMat = bst_history('add', DataMat, 'extract', strMsg);
    bst_progress('stop');
    
    % === OUTPUT FILE ===
    % Else: Use same condition as the original file
    [sInputStudy, iInputStudy] = bst_get('DataFile', DataFile);
    % Get output condition
    if isRaw
        % Raw data: ask the user in which condition to save the file
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
        % Ask condition
        [selCond, iOutputStudy] = gui_select_condition(iSubject, iInputStudy);
        if isempty(iOutputStudy)
            return
        end
        % Get study
        sOutputStudy = bst_get('Study', iOutputStudy);
        % If no channel file in the output study: copy the source one
        if ~isempty(GlobalData.DataSet(iDS).ChannelFile) && isempty(sOutputStudy.Channel)
            srcChannelFile = file_fullpath(GlobalData.DataSet(iDS).ChannelFile);
            db_set_channel(iOutputStudy, srcChannelFile, 0, 0);
        end
    else
        % Else: Use same condition as the original file
        sOutputStudy = sInputStudy;
        iOutputStudy = iInputStudy;
    end
    % Output filename
    [tmp__, baseName, tmp__] = bst_fileparts(DataFile);
    baseName = strrep(baseName, '_0raw', '');
    OutputFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), [baseName '_extract_fig.mat']);
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, DataMat, 'v6');
    
    % === ADD NEW DATA TO STUDY ===
    % Add data file to study
    db_add_data(iOutputStudy, OutputFile, DataMat);
    % Update links for target study
    db_links('Study', iOutputStudy);
    % Reload tree
    panel_protocols('UpdateNode', 'Study', iOutputStudy);
    panel_protocols('SelectStudyNode', iOutputStudy );
    
% ===== EXPORT TO .MAT FILE =====
% Brainstorm format: simply save the synthesis matrix
elseif strcmpi(TSFormat, 'BST')
    bst_save(TSFile, TSMat, 'v6');

% ===== EXPORT TO FILE =====
% Call export_data()
else
    % Get channel file
    if strcmpi(TSMat.FigType, 'DataTimeSeries')
        ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
        ChannelMat.Channel = ChannelMat.Channel(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels);
    end
    % Save one file per axes
    for iCell = 1:nbBlocks
        % Output filename
        % If more that one block : add current indice at the end of the filename
        if (nbBlocks > 1)
            OutputFile = bst_fullfile(filePath, [fileBase, sprintf('_%02d',iCell), fileExt]);
        else
            OutputFile = TSFile;
        end
        % Export recordings (type 'data')
        if strcmpi(TSMat.FigType, 'DataTimeSeries')
            % Build file structure
            DataMat = db_template('DataMat');
            DataMat.F           = TSMat.F{iCell};
            DataMat.Comment     = [fileBase, sprintf('_%02d',iCell)];
            DataMat.ChannelFlag = 1:size(TSMat.F{iCell},1);
            DataMat.Time        = TSMat.Time;
            DataMat.DataType    = 'recordings';
            % Save data file
            export_data(DataMat, ChannelMat, OutputFile, TSFormat);
        % Other types of data (eg. scouts)
        else
            % Build file structure
            MatrixMat = db_template('MatrixMat');
            MatrixMat.Value       = TSMat.F{iCell};
            MatrixMat.Comment     = [fileBase, sprintf('_%02d',iCell)];
            MatrixMat.Description = TSMat.AxesLegend{iCell};
            MatrixMat.Time        = TSMat.Time;
            % Save data file
            export_matrix(MatrixMat, OutputFile, TSFormat);
        end
    end
end







