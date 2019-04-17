function varargout = bst_figures( varargin )
% BST_FIGURES: Manages all the visualization figures.
%
% USAGE :  
%    [hFig, iFig, isNewFig] = bst_figures('CreateFigure',     iDS, FigureId, CreateMode, Constrains)
%                             bst_figures('UpdateFigureName', hFig)
%        [hFigs,iFigs,iDSs] = bst_figures('GetFigure',        iDS,      FigureId)
%        [hFigs,iFigs,iDSs] = bst_figures('GetFigure',        DataFile, FigureId)
%        [hFigs,iFigs,iDSs] = bst_figures('GetFigure',        hFigure)

%                   [hFigs] = bst_figures('GetAllFigures')
% [hFigs,iFigs,iDSs,iSurfs] = bst_figures('GetFigureWithSurface', SurfFile)
% [hFigs,iFigs,iDSs,iSurfs] = bst_figures('GetFigureWithSurface', SurfFile, DataFile, FigType, Modality)
%        [hFigs,iFigs,iDSs] = bst_figures('GetFigureWithSurfaces')
%        [hFigs,iFigs,iDSs] = bst_figures('GetFiguresByType', figType)
% [hFigs,iFigs,iDSs,iSurfs] = bst_figures('GetFiguresForScouts')
%                             bst_figures('DeleteFigure', hFigure)
%                             bst_figures('DeleteFigure', hFigure, 'NoUnload')
%                             bst_figures('FireCurrentTimeChanged')
%                             bst_figures('FireCurrentFreqChanged')
%                             bst_figures('FireTopoOptionsChanged')
%                             bst_figures('SetCurrentFigure', hFig, Type)
%                             bst_figures('SetCurrentFigure', hFig)
%                             bst_figures('CheckCurrentFigure')
%                 [hNewFig] = bst_figures('CloneFigure', hFig)
%   [hClones, iClones, iDS] = bst_figures('GetClones', hFig)
%                             bst_figures('ReloadFigures')
%                             bst_figures('NavigatorKeyPress', hFig, keyEvent)
%                             bst_figures('ViewTopography',    hFig)
%                             bst_figures('ViewResults',       hFig)
%                             bst_figures('DockFigure',        hFig)
%                             bst_figures('ShowMatlabControls',    hFig, isMatlabCtrl)
%                             bst_figures('TogglePlotEditToolbar', hFig)
%                             bst_figures('SetSelectedRows',       RowNames)
%                             bst_figures('ToggleSelectedRow',     RowName)
%                             bst_figures('FireSelectedRowChanged')
%       [SelChan, iSelChan] = bst_figures('GetSelectedChannels', iDS)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2019
%          Martin Cousineau, 2017

eval(macro_method);
end


%% ===== CREATE FIGURE =====
% USAGE:  [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId)
%         [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, 'AlwaysCreate')
%         [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, 'AlwaysCreate', Constrains)
function [hFig, iFig, isNewFig] = CreateFigure(iDS, FigureId, CreateMode, Constrains)
    global GlobalData;
    hFig = [];
    iFig = [];
    % Parse inputs
    if (nargin < 4)
        Constrains = [];
    end
    if (nargin < 3) || isempty(CreateMode)
        CreateMode = 'Default';
    end
    isAlwaysCreate = strcmpi(CreateMode, 'AlwaysCreate');
    isDoLayout = 1;
    
    % If figure creation is not forced
    if ~isAlwaysCreate
        % Get all existing (valid) figure for this dataset
        [hFigures, iFigures] = GetFigure(iDS, FigureId);
        % If at least one valid figure was found
        if ~isempty(hFigures)
            % Refine selection for certain types of figures
            if ~isempty(Constrains) && ischar(Constrains) && ismember(FigureId.Type, {'Timefreq', 'Spectrum', 'Connect', 'Pac'})
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    if ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains)
                        hFig(end+1) = hFigures(i);
                        iFig(end+1) = iFigures(i);
                    end
                end
                % If there are more than one figure possible, try to take the last used one
                if (length(hFig) > 1)
                    if ~isempty(GlobalData.CurrentFigure.TypeTF)
                        iLast = find(hFig == GlobalData.CurrentFigure.TypeTF);
                        if ~isempty(iLast)
                            hFig = hFig(iLast);
                            iFig = iFig(iLast);
                        end
                    end
                    % If could not find a valid figure
                    if (length(hFig) > 1)
                        hFig = hFig(1);
                        iFig = iFig(1);
                    end
                end
            % Topography: Recordings or Timefreq
            elseif ~isempty(Constrains) && ischar(Constrains) && strcmpi(FigureId.Type, 'Topography')
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    FileType = file_gettype(Constrains);
                    if (ismember(FileType, {'data', 'pdata'}) && isempty(TfInfo)) || ...
                       (ismember(FileType, {'timefreq', 'ptimefreq'}) && ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains))
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                end
            % Data time series => Selected sensors must be the same
            elseif ~isempty(Constrains) && strcmpi(FigureId.Type, 'DataTimeSeries')
                for i = 1:length(hFigures)
                    TsInfo = getappdata(hFigures(i), 'TsInfo');
                    if isequal(TsInfo.RowNames, Constrains)
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                    %isDoLayout = 0;
                end
            % Result time series (scouts)
            elseif ~isempty(Constrains) && strcmpi(FigureId.Type, 'ResultsTimeSeries')
                for i = 1:length(hFigures)
                    TfInfo = getappdata(hFigures(i), 'Timefreq');
                    ResultsFiles = getappdata(hFigures(i), 'ResultsFiles');
                    if iscell(Constrains)
                        BaseFile = Constrains{1};
                    elseif ischar(Constrains)
                        BaseFile = Constrains;
                    end
                    FileType = file_gettype(BaseFile);
                    if (strcmpi(FileType, 'data') && isempty(TfInfo)) || ...
                       (strcmpi(FileType, 'timefreq') && ~isempty(ResultsFiles) && all(file_compare(ResultsFiles, Constrains))) || ...
                       (strcmpi(FileType, 'timefreq') && ~isempty(TfInfo) && file_compare(TfInfo.FileName, Constrains)) || ...
                       (ismember(FileType, {'results','link'}) && ~isempty(ResultsFiles) && all(file_compare(ResultsFiles, Constrains)))
                        hFig = hFigures(i);
                        iFig = iFigures(i);
                        break;
                    end
                end
            % Else: Use the first figure in the list (there can be more than one : for multiple views of same data)
            else
                hFig = hFigures(1);
                iFig = iFigures(1);
            end
        end
    end
       
    % No figure : create one
    isNewFig = isempty(hFig);
    if isNewFig
        % ==== CREATE FIGURE ====
        switch(FigureId.Type)
            case {'DataTimeSeries', 'ResultsTimeSeries'}
                hFig = figure_timeseries ('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimeSeries');
            case 'Topography'
                hFig = figure_3d('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTopography');
            case '3DViz'
                hFig = figure_3d('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandles3DViz');
            case 'MriViewer'
                [hFig, FigHandles] = figure_mri('CreateFigure', FigureId);
            case 'Timefreq'
                hFig = figure_timefreq('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Spectrum'
                hFig = figure_spectrum('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimeSeries');
            case 'Pac'
                hFig = figure_pac('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Connect'
                hFig = figure_connect('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesTimefreq');
            case 'Image'
                hFig = figure_image('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesImage');
            case 'Video'
                hFig = figure_video('CreateFigure', FigureId);
                FigHandles = db_template('DisplayHandlesVideo');
            otherwise
                error(['Invalid figure type : ', FigureId.Type]);
        end
        % Set graphics smoothing (Matlab >= 2014b)
        if (bst_get('MatlabVersion') >= 804)
            if bst_get('GraphicsSmoothing')
                set(hFig, 'GraphicsSmoothing', 'on');
            else
                set(hFig, 'GraphicsSmoothing', 'off');
            end
        end
       
        % ==== REGISTER FIGURE IN DATASET ====
        iFig = length(GlobalData.DataSet(iDS).Figure) + 1;
        GlobalData.DataSet(iDS).Figure(iFig)         = db_template('figure');
        GlobalData.DataSet(iDS).Figure(iFig).Id      = FigureId;
        GlobalData.DataSet(iDS).Figure(iFig).hFigure = hFig;
        GlobalData.DataSet(iDS).Figure(iFig).Handles = FigHandles;
    end   
    
    % Find selected channels
    [selChan,errMsg] = GetChannelsForFigure(iDS, iFig);
    % Error message
    if ~isempty(errMsg)
        error(errMsg);
    end
    % Save selected channels for this figure
    GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = selChan;
        
    % Set figure name
    UpdateFigureName(hFig);
    % Tile windows
    if isDoLayout
        gui_layout('Update');
    end
end


%% ===== GET CHANNELS FOR FIGURE =====
function [selChan,errMsg] = GetChannelsForFigure(iDS, iFig)
    global GlobalData;
    errMsg = [];
    selChan = [];
    % If no modality for the figure: return empty list of channels
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    if isempty(Modality)
        return;
    end
    % If "stat" modality: replace with the first display modality
    if strcmpi(Modality, 'stat')
        [tmp, dispMod] = channel_get_modalities(GlobalData.DataSet(iDS).Channel);
        if ~isempty(dispMod)
            Modality = dispMod{1};
        end
    end
    % Get selected channels
    selChan = good_channel(GlobalData.DataSet(iDS).Channel, ...
                           GlobalData.DataSet(iDS).Measures.ChannelFlag, ...
                           Modality);
    % If opening EEG/SEEG/ECOG topography or 3D view: exclude (0,0,0) points
    if ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'Topography', '3DViz'}) && ismember(Modality, {'EEG','SEEG','ECOG'}) ...
        && ~(ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, {'2DLayout', '2DElectrodes'}) && ismember(Modality, {'SEEG','ECOG'}))
        % Get the locations for all the channels
        chanLoc = {GlobalData.DataSet(iDS).Channel(selChan).Loc};
        % Detect the channels without location or at (0,0,0)
        iChanZero = find(~cellfun(@(c)(isequal(size(c),[3,1]) && any(abs(c)>=1e-5)), chanLoc));
        % Remove them from the list of available channels for this figure
        if ~isempty(iChanZero)
            % Display warning
            delNames = {GlobalData.DataSet(iDS).Channel(selChan(iChanZero)).Name};
            disp(['BST> Warning: The positions of the following sensors are not set: ' sprintf('%s ', delNames{:})]);
            % Remove them from the list
            selChan(iChanZero) = [];
        end
    end
    % Make sure that something can be displayed in this figure
    if isempty(selChan) && ~isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
        % Get the channels again, but ignoring the bad channels
        selChanAll = good_channel(GlobalData.DataSet(iDS).Channel, [], Modality);
        % Display an error message, depending on the results of this request
        if ~isempty(selChanAll)
            errMsg = ['Nothing to display: All the "' Modality '" channels are marked as bad or do not have 3D positions.'];
        else
            % THAT IS FINE TO SHOW DATA WITHOUT ANY CHANNEL
            %error(['There are no "' GlobalData.DataSet(iDS).Figure(iFig).Id.Modality '" channel in this channel file']);
        end
    end
end

    
%% ===== UPDATE FIGURE NAME =====
function UpdateFigureName(hFig)
    global GlobalData;
    % Get figure description in GlobalData
    [hFig, iFig, iDS] = GetFigure(hFig);
    
    % ==== FIGURE NAME ====
    % SubjectName/Condition/Modality
    figureName = '';
    % Get Subject name and Study name to define window title
    sStudy   = [];
    sSubject = [];
    % Get study
    if ~isempty(GlobalData.DataSet(iDS).StudyFile)
        [sStudy, iStudy] = bst_get('Study', GlobalData.DataSet(iDS).StudyFile);
    end
    % Get subject
    if ~isempty(GlobalData.DataSet(iDS).SubjectFile)
        sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    end
    % Add subject name
    if ~isempty(sSubject) && ~isempty(sSubject.Name)
        figureName = [figureName sSubject.Name];
    end
    isFileSet = 0;
    % Add condition name, data comment, and inverse comment
    if ~isempty(sStudy)
        isInterSubject = (iStudy == -2);
        % === CONDITION NAME ===
        if ~isempty(sStudy.Condition)
            for iCond = 1:length(sStudy.Condition)
                figureName = [figureName '/' sStudy.Condition{iCond}];
            end
        % Inter-subject node
        elseif isInterSubject
            figureName = [figureName 'Inter-subject'];
        end
        % === DATA FILE COMMENT ===
        % If a DataFile is defined for this dataset
        % AND there is MORE THAN ONE data files in this study => display data file comment
        if ~isempty(GlobalData.DataSet(iDS).DataFile) && (length(sStudy.Data) >= 2)
            % Look for current data file in study database structure
            iData = find(file_compare({sStudy.Data.FileName}, GlobalData.DataSet(iDS).DataFile), 1);
            % If a data file is found
            if ~isempty(iData)
                figureName = [figureName '/' sStudy.Data(iData).Comment];
                isFileSet = 1; 
            end
        end
        % === DATA/STAT FILE COMMENT ===
        if ~isempty(GlobalData.DataSet(iDS).DataFile) && (length(sStudy.Stat) >= 2)
            % Look for current stat file in study database structure
            iStat = find(file_compare({sStudy.Stat.FileName}, GlobalData.DataSet(iDS).DataFile), 1);
            % If a stat file is found
            if ~isempty(iStat)
                figureName = [figureName '/' sStudy.Stat(iStat).Comment];
                isFileSet = 1; 
            end
        end
        % === RESULTS NAME ===
        % If a ResultsFile is defined for this FIGURE
        % AND there is MORE THAN ONE results files in this study => display results file indice
        figResultsFile = getappdata(hFig, 'ResultsFile');
        if ~isempty(figResultsFile) && (length(sStudy.Result) >= 2)
            % Look for current results file in study database structure
            iResult = find(file_compare({sStudy.Result.FileName}, figResultsFile), 1);
            % If a data file is found
            if ~isempty(iResult)
                figureName = [figureName '/' sStudy.Result(iResult).Comment];
                isFileSet = 1; 
            end
        end
        % === RESULTS/STAT FILE COMMENT ===
        if ~isempty(figResultsFile) && (length(sStudy.Stat) >= 2)
            % Look for current stat file in study database structure
            iStat = find(file_compare({sStudy.Stat.FileName}, figResultsFile), 1);
            % If a stat file is found
            if ~isempty(iStat)
                figureName = [figureName '/' sStudy.Stat(iStat).Comment];
                isFileSet = 1; 
            end
        end
        % === TIME-FREQ FILE COMMENT ===
        TfInfo = getappdata(hFig, 'Timefreq');
        if ~isempty(TfInfo) && ~isempty(TfInfo.FileName) && (length(sStudy.Timefreq) >= 2)
            iPipe = find(TfInfo.FileName == '|', 1);
            if ~isempty(iPipe)
                TimefreqFile = TfInfo.FileName(1:iPipe-1);
                RefRowName = [' (' TfInfo.FileName(iPipe+1:end) ')'];
            else
                TimefreqFile = TfInfo.FileName;
                RefRowName = '';
            end
            % Look for current timefreq file in study database structure
            iTimefreq = find(file_compare({sStudy.Timefreq.FileName}, TimefreqFile), 1);
            % If a stat file is found
            if ~isempty(iTimefreq)
                figureName = [figureName '/' sStudy.Timefreq(iTimefreq).Comment, RefRowName];
                isFileSet = 1; 
            end
        end
    end
    % Add Modality
    FigureId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    if ~isempty(FigureId.Modality)
        figureNameModality = [FigureId.Modality '/'];
    else
        figureNameModality = '';
    end
    % If figureName is still empty : use the figure index
    if isempty(figureName)
        figureName = sprintf('#%d', iFig);
    end
    
    % Add prefix : figure type
    switch(FigureId.Type)
        case 'DataTimeSeries'
            % Get current montage
            TsInfo = getappdata(hFig, 'TsInfo');
            if isempty(TsInfo) || isempty(TsInfo.MontageName) || ~isempty(TsInfo.RowNames)
                strMontage = 'All';
            elseif ~isempty(strfind(TsInfo.MontageName, 'Average reference')) || ~isempty(strfind(TsInfo.MontageName, '(local average ref)'))
                strMontage = 'AvgRef';
            elseif ~isempty(strfind(TsInfo.MontageName, 'Scalp current density'))
                strMontage = 'SCD';
            elseif strcmpi(TsInfo.MontageName, 'Head distance')
                strMontage = 'Head';
            elseif strcmpi(TsInfo.MontageName, 'Bad channels')
                strMontage = 'Bad';
            elseif strcmpi(TsInfo.MontageName, 'ICA components[tmp]')
                strMontage = 'ICA';
            elseif strcmpi(TsInfo.MontageName, 'SSP components[tmp]')
                strMontage = 'SSP';
            else
                strMontage = TsInfo.MontageName;
            end
            figureName = [figureNameModality strMontage ': ' figureName];
        case 'ResultsTimeSeries'
            if ~isempty(figureNameModality)
                figureName = [figureNameModality(1:end-2) ': ' figureName];
            end
            % Matrix file: display the file name
            TsInfo = getappdata(hFig, 'TsInfo');
            if ~isempty(TsInfo) && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'matrix')
                iMatrix = find(file_compare({sStudy.Matrix.FileName}, TsInfo.FileName), 1);
                if ~isempty(iMatrix)
                    figureName = [figureName '/' sStudy.Matrix(iMatrix).Comment];
                end
            end
        case 'Topography'
            figureName = [figureNameModality  'TP: ' figureName];
        case '3DViz'
            figureName = [figureNameModality  '3D: ' figureName];
        case 'MriViewer'
            TessInfo = getappdata(hFig, 'Surface');
            if isempty(TessInfo) || ~isempty(TessInfo.OverlayCube) || ~isempty(TessInfo.DataSource.FileName)
                figureName = [figureNameModality  'MriViewer: ' figureName];
            else
                [sSubject, iSubject, iAnatomy] = bst_get('MriFile', TessInfo.SurfaceFile);
                if ~isempty(iAnatomy)
                    figureName = [figureNameModality  'MriViewer: ' figureName, '/', sSubject.Anatomy(iAnatomy).Comment];
                else
                    figureName = [figureNameModality  'MriViewer: ' figureName];
                end
            end
        case 'Timefreq'
            figureName = [figureNameModality  'TF: ' figureName];
        case 'Spectrum'
            switch (FigureId.SubType)
                case 'TimeSeries'
                    figType = 'TS';
                case 'Spectrum'
                    figType = 'PSD';
                otherwise
                    figType = 'TF';
            end
            figureName = [figureNameModality figType ': ' figureName];
        case 'Pac'
            figureName = [figureNameModality 'PAC: ' figureName];
        case 'Connect'
            figureName = [figureNameModality 'Connect: ' figureName];
        case 'Image'
            % Add dependent file comment
            FileName = getappdata(hFig, 'FileName');
            if ~isempty(FileName)
                [sStudy, iStudy, iFile, DataType] = bst_get('AnyFile', FileName);
                if ~isempty(sStudy)
                    switch (DataType)
                        case {'data'}
                            % Get current montage
                            TsInfo = getappdata(hFig, 'TsInfo');
                            if isempty(TsInfo) || isempty(TsInfo.MontageName) || ~isempty(TsInfo.RowNames)
                                strMontage = 'All';
                            elseif ~isempty(strfind(TsInfo.MontageName, 'Average reference')) || ~isempty(strfind(TsInfo.MontageName, '(local average ref)'))
                                strMontage = 'AvgRef';
                            elseif ~isempty(strfind(TsInfo.MontageName, 'Scalp current density'))
                                strMontage = 'SCD';
                            elseif strcmpi(TsInfo.MontageName, 'Head distance')
                                strMontage = 'Head';
                            elseif strcmpi(TsInfo.MontageName, 'Bad channels')
                                strMontage = 'Bad';
                            else
                                strMontage = TsInfo.MontageName;
                            end
                            figureName = [figureNameModality strMontage ': ' figureName];
                            %figureName = ['Recordings: ' figureName];
                            imageFile = ['/' sStudy.Data(iFile).Comment];
                        case {'results', 'link'}
                            figureName = ['Sources: ' figureName];
                            imageFile = ['/' sStudy.Results(iFile).Comment];
                        case {'timefreq'}
                            if isequal(FigureId.SubType, 'trialimage')
                                figureName = ['Image: ' figureName];
                            else
                                figureName = ['Connect: ' figureName];
                            end
                            imageFile = ['/' sStudy.Timefreq(iFile).Comment];
                        case 'matrix'
                            figureName = ['Matrix: ' figureName];
                            imageFile = ['/' sStudy.Matrix(iFile).Comment];
                        case {'pdata', 'ptimefreq', 'presults', 'pmatrix'}
                            figureName = ['Stat: ' figureName];
                            imageFile = ['/' sStudy.Stat(iFile).Comment];
                    end
                    if ~isFileSet
                        figureName = [figureName, imageFile];
                    end
                end
            end
        case 'Video'
            FileName = getappdata(hFig, 'FileName');
            VideoFile = getappdata(hFig, 'VideoFile');
            if ~isempty(VideoFile)
                figureName = ['Video: ' VideoFile];
            elseif ~isempty(FileName)
                figureName = ['Video: ' FileName];
            else
                figureName = 'Video';
            end
        otherwise
            error(['Invalid figure type : ', FigureId.Type]);
    end
    
    % Update figure name
    set(hFig, 'Name', figureName);
end


%% ===== GET FIGURE =====
%Search for a registered figure in the GlobalData structure
% Usage : GetFigure(iDS, FigureId)
%         GetFigure(hFigure)
% To avoid one search criteria, just set it to []
function [hFigures, iFigures, iDataSets] = GetFigure(varargin)
    global GlobalData;
    hFigures  = [];
    iFigures  = [];
    iDataSets = [];
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end

    % Call : GetFigure(iDS, FigureId)
    if (nargin == 2)
        iDS      = varargin{1};
        FigureId = varargin{2};
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            if (compareFigureId(FigureId, GlobalData.DataSet(iDS).Figure(iFig).Id))
                hFigures  = [hFigures,  GlobalData.DataSet(iDS).Figure(iFig).hFigure];
                iFigures  = [iFigures,  iFig];
                iDataSets = [iDataSets, iDS];
            end
        end
    % Call : GetFigure(hFigure)
    elseif (nargin == 1)
        hFig = varargin{1};
        for iDS = 1:length(GlobalData.DataSet)
            if ~isempty(GlobalData.DataSet(iDS).Figure)
                iFig = find([GlobalData.DataSet(iDS).Figure.hFigure] == hFig, 1);
                if ~isempty(iFig)
                    hFigures  = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
                    iFigures  = iFig;
                    iDataSets = iDS;
                    break
                end
            end
        end
    % Invalid call
    else
        error(['Usage : GetFigure(iDS, FigureId)' 10 ...
               '        GetFigure(DataFile, FigureId)' 10 ...
               '        GetFigure(hFigure)']);
    end
end
    

%% ===== GET ALL FIGURES =====
% Return handles of all the figures registred by Brainstorm
function hFigures = GetAllFigures()
    global GlobalData;
    hFigures  = [];
    % Process all DataSets
    for iDS = 1:length(GlobalData.DataSet)
        hFigures = [hFigures, GlobalData.DataSet(iDS).Figure.hFigure];
    end
end

   
%% ===== GET FIGURE WITH A SPECIFIC SURFACE =====
%  Usage : GetFigureWithSurface(SurfaceFile, DataFile, FigType, Modality)
%          GetFigureWithSurface(SurfaceFile)
%          GetFigureWithSurface(SurfaceFiles)
function [hFigures, iFigures, iDataSets, iSurfaces] = GetFigureWithSurface(SurfaceFile, DataFile, FigType, Modality)
    global GlobalData;
    hFigures  = [];
    iFigures  = [];
    iDataSets = [];
    iSurfaces = [];
    % Parse inputs
    if (nargin < 4)
        DataFile = '';
        FigType  = '3DViz';
        Modality = '';
    end
    % Process all DataSets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all figures of this dataset
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            % Look only in 3DViz figures (there cannot be surfaces displayed in other widow types)
            % and figures that have the appropriate Modality
            if strcmpi(Figure.Id.Type, FigType) && (isempty(Modality) || strcmpi(Figure.Id.Modality, Modality))
                % Get surfaces list
                TessInfo = getappdata(Figure.hFigure, 'Surface');
                % Look for surface
                for iTess = 1:length(TessInfo)
                    % If the surface contain registered spheres: skip
                    if ~isempty(TessInfo(iTess).SurfaceFile) && ~isempty(strfind(TessInfo(iTess).SurfaceFile, '|reg'))
                        isSurfFileOk = 0;
                    % Check if the (or one of the) surface file is valid
                    elseif iscell(SurfaceFile)
                        isSurfFileOk = 0;
                        i = 1;
                        while (i <= length(SurfaceFile) && ~isSurfFileOk)
                            isSurfFileOk = file_compare(TessInfo(iTess).SurfaceFile, SurfaceFile{i});
                            i = i + 1;
                        end
                    else
                        isSurfFileOk = file_compare(TessInfo(iTess).SurfaceFile, SurfaceFile);
                    end
                    % If figure is accepted: add it to the list
                    if isSurfFileOk && (isempty(DataFile) ...
                                        || file_compare(TessInfo(iTess).DataSource.FileName, DataFile))
                        hFigures  = [hFigures,  Figure.hFigure];
                        iFigures  = [iFigures,  iFig];
                        iDataSets = [iDataSets, iDS];
                        iSurfaces = [iSurfaces, iTess];
                    end
                end
            end
        end
    end
end    


%% ===== GET FIGURES BY TYPE =====
function [hFigures, iFigures, iDataSets] = GetFiguresByType(figType)
    global GlobalData;
    hFigures  = [];
    iFigures  = [];
    iDataSets = [];
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end
    % Process all DataSets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all figures of this dataset
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            % If figure has the right type : return it
            if (ischar(figType) && strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, figType)) || (iscell(figType) && ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, figType))
                hFigures  = [hFigures,  GlobalData.DataSet(iDS).Figure(iFig).hFigure];
                iFigures  = [iFigures,  iFig];
                iDataSets = [iDataSets, iDS];
            end
        end
    end
end


%% ===== GET FIGURES FOR SCOUTS =====
% Get all the Brainstorm 3DVIz figures that have a cortex surface displayed
%  Usage : GetFiguresForScouts()
function [hFigures, iFigures, iDataSets, iSurfaces] = GetFiguresForScouts()
    global GlobalData;
    hFigures  = [];
    iFigures  = [];
    iDataSets = [];
    iSurfaces = [];
    % Process all DataSets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all figures of this dataset
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            % If 3DViz figure
            if strcmpi(Figure.Id.Type, '3DViz')
                % Look for a cortex surface in figure
                TessInfo = getappdata(Figure.hFigure, 'Surface');
                iCortex  = find(strcmpi({TessInfo.Name}, 'cortex'));
                iAnatomy = find(strcmpi({TessInfo.Name}, 'Anatomy'));
                iValidSurface = [iCortex, iAnatomy];
                % If a cortex is found : add figure to returned figures list
                if ~isempty(iValidSurface) 
                    hFigures  = [hFigures,  Figure.hFigure];
                    iFigures  = [iFigures,  iFig];
                    iDataSets = [iDataSets, iDS];
                    iSurfaces = [iSurfaces, iValidSurface(1)];
                end
            end
        end
    end
end    


%% ===== GET FIGURES WITH SURFACES ======
% Get all the Brainstorm 3DVIz figures that have at list on surface displayed in them
%  Usage : GetFigureWithSurfaces()
function [hFigs,iFigs,iDSs] = GetFigureWithSurfaces()
    hFigs = [];
    iFigs = [];
    iDSs  = [];
    % Get 3D Viz figures
    [hFigs3D, iFigs3D, iDSs3D] = GetFiguresByType('3DViz');
    % Loop to find figures with surfaces
    for i = 1:length(hFigs3D)
        if ~isempty(getappdata(hFigs3D(i), 'Surface'))
            hFigs(end+1) = hFigs3D(i);
            iFigs(end+1) = iFigs3D(i);
            iDSs(end+1)  = iDSs3D(i);
        end
    end
end

%% ===== GET FIGURE HANDLES =====
function [Handles,iFig,iDS] = GetFigureHandles(hFig) %#ok<DEFNU>
    global GlobalData;
    % Get figure description
    [hFig,iFig,iDS] = GetFigure(hFig);
    if ~isempty(iDS)
        % Return handles
        Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    else
        warning('Figure is not registered in Brainstorm.');
        Handles = [];
    end
end

%% ===== SET FIGURE HANDLES =====
function [Handles,iFig,iDS] = SetFigureHandles(hFig, Handles) %#ok<DEFNU>
    global GlobalData;
    % Get figure description
    [hFig,iFig,iDS] = GetFigure(hFig);
    if isempty(iDS)
        error('Figure is not registered in Brainstorm');
    end
    % Return handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = Handles;
end


%% ===== DELETE FIGURE =====
%  Usage : DeleteFigure(hFigure)
%          DeleteFigure(..., 'NoUnload') : do not unload the corresponding datasets
%          DeleteFigure(..., 'NoLayout') : do not call the layout manager
function DeleteFigure(hFigure, varargin)
    % Get GlobalData
    global GlobalData;
    if isempty(GlobalData)
        disp('BST> Warning: Brainstorm is not started.');
        delete(hFigure);
        return;
    end
    % Parse inputs
    NoUnload = any(strcmpi(varargin, 'NoUnload'));
    NoLayout = any(strcmpi(varargin, 'NoLayout'));
    isKeepAnatomy = 1;

    % Find figure index in GlobalData structure
    [hFig, iFig, iDS] = GetFigure(hFigure);
    % If figure is registered
    if isempty(iFig) 
        warning('Figure is not registered in Brainstorm.');
        delete(hFigure);
        return;
    end
    % Get figure type
    Figure = GlobalData.DataSet(iDS).Figure(iFig);

    % ===== MRI VIEWER =====
    % Check for modifications of the MRI (MRI Viewer figures only)
    if strcmpi(Figure.Id.Type, 'MriViewer') && Figure.Handles.isModifiedMri
        if java_dialog('confirm', ['The MRI volume was modified.' 10 'Save changes ?'], 'MRI Viewer')
            % Save MRI
            isCloseAccepted = figure_mri('SaveMri', hFig);
            % If the save function refused to close the window
            if ~isCloseAccepted
                return
            end
        end
        % Unload anatomy
        isKeepAnatomy = 0;
    % VIDEO: Release interfaces
    elseif strcmpi(Figure.Id.Type, 'Video')
        figure_video('CloseVideo', hFig);
    end
    
    % Check if surfaces were modified
    if ~isempty(GlobalData.Surface) && any([GlobalData.Surface.isAtlasModified])
        % Force unload of the anatomy
        isKeepAnatomy = 0;
    end
    % Remove figure reference from GlobalData
    GlobalData.DataSet(iDS).Figure(iFig) = [];
    
    % Check if figure was the current TF figure
    wasCurTf = isequal(GlobalData.CurrentFigure.TypeTF, hFigure);
    % Clear selected figure
%     GlobalData.CurrentFigure.Last   = setdiff(GlobalData.CurrentFigure.Last,   hFigure);
%     GlobalData.CurrentFigure.Type3D = setdiff(GlobalData.CurrentFigure.Type3D, hFigure);
%     GlobalData.CurrentFigure.Type2D = setdiff(GlobalData.CurrentFigure.Type2D, hFigure);
%     GlobalData.CurrentFigure.TypeTF = setdiff(GlobalData.CurrentFigure.TypeTF, hFigure);
    % Check if the figure was selected, type by type
    for figlast = {'3D', '2D', 'TF'}
        % If the figure was selected
        field = ['Type' figlast{1}];
        if isequal(GlobalData.CurrentFigure.(field), hFigure)
            % Remove selection
            GlobalData.CurrentFigure.(field) = [];
            % Get all the figures of the same type
            switch (figlast{1})
                case '3D',   figTypes = {'3DViz'};
                case '2D',   figTypes = {'DataTimeSeries', 'ResultsTimeSeries', 'Topography'};
                case 'TF',   figTypes = {'Timefreq'};
            end
            % Get other figures of the same type
            hNewFig = GetFiguresByType(figTypes);
            % If other figures available
            if ~isempty(hNewFig)
                SetCurrentFigure(hNewFig(1), figlast{1});
            end
        end
    end
    % If the figure is a 3DViz figure
    if ishandle(hFigure) && isappdata(hFigure, 'Surface')
        % Signals the "Surfaces" and "Scouts" panel that a figure was closed
        panel_surface('UpdatePanel');
        % Remove scouts references
        panel_scout('RemoveScoutsFromFigure', hFigure);
        % Reset "Coordinates" panel
        if gui_brainstorm('isTabVisible', 'Coordinates')
            panel_coordinates('RemoveSelection');
        end
        % Reset "Coordinates" panel
        if gui_brainstorm('isTabVisible', 'Dipinfo')
            panel_dipinfo('RemoveSelection');
        end
        % Reset "Dipoles" panel
        if gui_brainstorm('isTabVisible', 'Dipoles')
        	panel_dipoles('UpdatePanel');
        end
    end
    % If figure is an OpenGL connectivty graph: call the destructor
    if strcmpi(Figure.Id.Type, 'Connect')
        figure_connect('Dispose', hFigure);
    end
    % Delete graphic object
    if ishandle(hFigure)
        delete(hFigure);
    end
    % Unload unused datasets
    if ~NoUnload
        if isKeepAnatomy
            bst_memory('UnloadAll', 'KeepMri', 'KeepSurface');
        else
            bst_memory('UnloadAll');
        end
    end   
    % Update layout
    if ~NoLayout
        gui_layout('Update');
    end
    % If closed figure was a TimeSeries one: update time series scales
    if strcmpi(Figure.Id.Type, 'DataTimeSeries')
        % === Unformize time series scales if required ===
        isSynchro = bst_get('UniformizeTimeSeriesScales');
        if ~isempty(isSynchro) && (isSynchro == 1)
            figure_timeseries('UniformizeTimeSeriesScales', 1); 
        end
    end
    % If closed figure was the selected time-freq figure, and Display panel still visible
    %if strcmpi(Figure.Id.Type, 'Timefreq') || strcmpi(Figure.Id.Type, 'Spectrum') || strcmpi(Figure.Id.Type, 'Connect')
    if wasCurTf && gui_brainstorm('isTabVisible', 'Display')
        % Finds the next Timefreq figure
        FindCurrentTimefreqFigure();
    end
end
    

%% ===== FIRE CURRENT TIME CHANGED =====
%Call the 'CurrentTimeChangedCallback' function for all the registered figures
function FireCurrentTimeChanged(ForceTime)
    global GlobalData;
    if (nargin < 1) || isempty(ForceTime)
        ForceTime = 0;
    end
    for iDS = 1:length(GlobalData.DataSet)
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            sFig = GlobalData.DataSet(iDS).Figure(iFig);
            % Only fires for currently visible displayed figures, AND not static
            if strcmpi(get(sFig.hFigure, 'Visible'), 'off') || (~ForceTime && getappdata(sFig.hFigure, 'isStatic'))
                continue;
            end
            % Notice figure
            switch (sFig.Id.Type)
                case {'DataTimeSeries', 'ResultsTimeSeries'}
                    figure_timeseries('CurrentTimeChangedCallback', iDS, iFig);
                case 'Topography'
                    figure_topo('CurrentTimeChangedCallback', iDS, iFig);
                case '3DViz'
                    panel_surface('UpdateSurfaceData', sFig.hFigure);
                    if gui_brainstorm('isTabVisible', 'Dipoles')
                        panel_dipoles('CurrentTimeChangedCallback', sFig.hFigure);
                    end
                    % If there are topo 3D electrode plots on top of the figure: update them as well
                    hElectrodeGrid = findobj(sFig.hFigure, 'Tag', 'ElectrodeGrid');
                    TopoInfo = getappdata(sFig.hFigure, 'TopoInfo');
                    if ~isempty(hElectrodeGrid) && ~isempty(TopoInfo) && ~isempty(TopoInfo.FileName)
                        figure_topo('CurrentTimeChangedCallback', iDS, iFig);
                    end
                case 'MriViewer'
                    panel_surface('UpdateSurfaceData', sFig.hFigure);
                case 'Timefreq'
                    figure_timefreq('CurrentTimeChangedCallback', sFig.hFigure);
                case 'Spectrum'
                    figure_spectrum('CurrentTimeChangedCallback', sFig.hFigure);
                case 'Pac'
                    figure_pac('CurrentTimeChangedCallback', sFig.hFigure);
                case 'Connect'
                    figure_connect('CurrentTimeChangedCallback', sFig.hFigure);
                case 'Image'
                    figure_image('CurrentTimeChangedCallback', sFig.hFigure);
                case 'Video'
                    figure_video('CurrentTimeChangedCallback', sFig.hFigure);
            end
        end 
    end
end


%% ===== FIRE CURRENT FREQUENCY CHANGED =====
%Call the 'CurrentFreqChangedCallback' function for all the registered figures
function FireCurrentFreqChanged()
    global GlobalData;
    for iDS = 1:length(GlobalData.DataSet)
%         % If no time-frequency information: skip
%         if isempty(GlobalData.DataSet(iDS).Timefreq)
%             continue;
%         end
        % Process all figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            sFig = GlobalData.DataSet(iDS).Figure(iFig);
            % Only fires for currently visible displayed figures, AND not static
            if strcmpi(get(sFig.hFigure, 'Visible'), 'off') || (isempty(getappdata(sFig.hFigure, 'Timefreq')) && ~strcmpi(sFig.Id.Type,'Image')) || getappdata(sFig.hFigure, 'isStaticFreq')
                continue;
            end
            % Notice figures
            switch (sFig.Id.Type)
                case {'DataTimeSeries', 'ResultsTimeSeries'}
                    % Nothing to do
                case 'Topography'
                    figure_topo('CurrentFreqChangedCallback', iDS, iFig);
                case '3DViz'
                    %panel_surface('UpdateSurfaceData', sFig.hFigure);
                    panel_surface('CurrentFreqChangedCallback', iDS, iFig);
                case 'MriViewer'
                    %panel_surface('UpdateSurfaceData', sFig.hFigure);
                    panel_surface('CurrentFreqChangedCallback', iDS, iFig);
                case 'Timefreq'
                    figure_timefreq('CurrentFreqChangedCallback', sFig.hFigure);
                case 'Spectrum'
                    figure_spectrum('CurrentFreqChangedCallback', sFig.hFigure);
                case 'Pac'
                    % Nothing
                case 'Connect'
                    bst_progress('start', 'Connectivity graph', 'Reloading connectivity graph...');
                    figure_connect('CurrentFreqChangedCallback', sFig.hFigure);
                    bst_progress('stop');
                case 'Image'
                    figure_image('CurrentFreqChangedCallback', sFig.hFigure);
                case 'Video'
                    % Nothing to do
            end
        end
    end
end


%% ===== FIRE TOPO LAYOUT OPTIONS CHANGED =====
function FireTopoOptionsChanged(isLayout)
    global GlobalData;
    % Loop on all the datasets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            sFig = GlobalData.DataSet(iDS).Figure(iFig);
            if strcmpi(get(sFig.hFigure, 'Visible'), 'off') || ~strcmpi(sFig.Id.Type, 'Topography') || ...
               (isLayout && ~strcmpi(sFig.Id.SubType, '2DLayout')) || (~isLayout && strcmpi(sFig.Id.SubType, '2DLayout'))
                continue
            end
            GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax = [];
            figure_topo('UpdateTopoPlot', iDS, iFig);
        end
    end
end


%% ===== SET CURRENT FIGURE =====
% Usage:  bst_figures('SetCurrentFigure', hFig, Type);
%         bst_figures('SetCurrentFigure', hFig);
function SetCurrentFigure(hFig, Type)
    global GlobalData;
    if isempty(GlobalData) || isempty(GlobalData.CurrentFigure)
        return;
    end
    % No type specified: sets only the last figure selected
    if (nargin < 2) || isempty(Type)
        Type = 'Last';
    else
        Type = ['Type' Type];
    end
    % Check if figure changed
    oldFig = GlobalData.CurrentFigure.Last;
    oldFigType = GlobalData.CurrentFigure.(Type);
    if ~isempty(hFig) && ~isempty(GlobalData.CurrentFigure.Last) && ~isempty(oldFigType) && (oldFigType == hFig) && (GlobalData.CurrentFigure.Last == hFig)
        return
    end
    % Update GlobalData structure
    GlobalData.CurrentFigure.(Type) = hFig;
    GlobalData.CurrentFigure.Last = hFig;

    % === FIRE EVENT FOR ALL PANELS ===
    switch (Type)
        case 'Type2D'
            % Update tab: Record
            panel_record('CurrentFigureChanged_Callback', hFig);
            % Update tab: Display (for raster plots/erpimage)
            panel_display('UpdatePanel', hFig);
%             FigureId = getappdata(hFig, 'FigureId');
%             if ~isempty(FigureId) && isequal(FigureId.SubType, 'erpimage')
%                 panel_display('UpdatePanel', hFig);
%             end
        case 'Type3D'
            % Only when figure changed (within the figure type)
            if ~isempty(hFig) && ~isequal(oldFigType, hFig)
                panel_surface('CurrentFigureChanged_Callback');
                panel_scout( 'CurrentFigureChanged_Callback', oldFig, hFig);
                if gui_brainstorm('isTabVisible', 'Coordinates')
                    panel_coordinates('CurrentFigureChanged_Callback');
                end
                if gui_brainstorm('isTabVisible', 'Dipinfo')
                    panel_dipinfo('CurrentFigureChanged_Callback');
                end
                if gui_brainstorm('isTabVisible', 'Dipoles')
                    panel_dipoles('CurrentFigureChanged_Callback', hFig);
                end
                if gui_brainstorm('isTabVisible', 'iEEG')
                    panel_ieeg('CurrentFigureChanged_Callback', hFig);
                end
            end
        case 'TypeTF'
            % Only when figure changed (whatever the type of the figure is)
            if ~isempty(hFig) && ~isequal(oldFigType, hFig)
                panel_display('CurrentFigureChanged_Callback', hFig);
            end
    end

    % === SELECT CORRESPONDING TREE NODE ===
    if ~isempty(hFig) && ~isequal(oldFig, hFig)
        isStat = 0;
        % Get all the data accessible in this figure
        SubjectFile = getappdata(hFig, 'SubjectFile');
        StudyFile   = getappdata(hFig, 'StudyFile');
        DataFile    = getappdata(hFig, 'DataFile');
        ResultsFile = getappdata(hFig, 'ResultsFile');
        TfInfo      = getappdata(hFig, 'Timefreq');
        FileName    = getappdata(hFig, 'FileName');
        TsInfo      = getappdata(hFig, 'TsInfo');
        Dipoles     = getappdata(hFig, 'Dipoles');
        % Replace DataFile with TsInfo.FileName
        if ~isempty(TsInfo) && isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName) && ~isequal(DataFile, TsInfo.FileName)
            DataFile = [];
            FileName = TsInfo.FileName;
        end
        % Try to select a node in the tree
        if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
            [tmp__, iStudy, iTimefreq] = bst_get('TimefreqFile', TfInfo.FileName);
            if ~isempty(iStudy)
                if ~isempty(strfind(TfInfo.FileName, '_psd')) || ~isempty(strfind(TfInfo.FileName, '_fft'))
                    panel_protocols('SelectNode', [], 'spectrum', iStudy, iTimefreq);
                else
                    panel_protocols('SelectNode', [], 'timefreq', iStudy, iTimefreq);
                end
            % File not found: Try in stat files
            else
                [tmp__, iStudy, iStat] = bst_get('StatFile', TfInfo.FileName);
                if ~isempty(iStudy)
                    if ~isempty(strfind(TfInfo.FileName, '_psd')) || ~isempty(strfind(TfInfo.FileName, '_fft'))
                        panel_protocols('SelectNode', [], 'pspectrum', iStudy, iStat);
                    else
                        panel_protocols('SelectNode', [], 'ptimefreq', iStudy, iStat);
                    end
                    isStat = 1;
                end
            end
        elseif ~isempty(ResultsFile)
            if iscell(ResultsFile)
                ResultsFile = ResultsFile{1};
            end
            [tmp__, iStudy, iResult] = bst_get('ResultsFile', ResultsFile);
            if ~isempty(iStudy)
                if isequal(ResultsFile(1:4), 'link')
                    panel_protocols('SelectNode', [], 'link', iStudy, iResult);
                else
                    panel_protocols('SelectNode', [], 'results', iStudy, iResult);
                end
            % ResultsFile not found: Try in stat files
            else
                [tmp__, iStudy, iStat] = bst_get('StatFile', ResultsFile);
                if ~isempty(iStudy)
                    panel_protocols('SelectNode', [], 'presults', iStudy, iStat);
                    isStat = 1;
                else
                    [tmp__, iStudy, iTimefreq] = bst_get('TimefreqFile', ResultsFile);
                    if ~isempty(iStudy)
                        panel_protocols('SelectNode', [], 'presults', iStudy, iTimefreq);
                        isStat = 1;
                    end
                end
            end
        elseif ~isempty(DataFile)
            if iscell(DataFile)
                DataFile = DataFile{1};
            end
            [tmp__, iStudy, iData] = bst_get('DataFile', DataFile);
            if ~isempty(iStudy)
                panel_protocols('SelectNode', [], 'data', iStudy, iData);
            % DataFile not found: Try in stat files
            else
                [tmp__, iStudy, iStat] = bst_get('StatFile', DataFile);
                if ~isempty(iStudy)
                    panel_protocols('SelectNode', [],'pdata', iStudy, iStat);
                    isStat = 1;
                end
            end
        elseif ~isempty(FileName)
            panel_protocols('SelectNode', [], FileName);
            if ismember(file_gettype(FileName), {'pdata','presults','pmatrix','ptimefreq'})
                isStat = 1;
            end
        elseif ~isempty(Dipoles) && ~isempty(Dipoles.FileName)
            [tmp__, iStudy, iDip] = bst_get('DipolesFile', Dipoles.FileName);
            panel_protocols('SelectNode', [], 'dipoles', iStudy, iDip);
        elseif ~isempty(StudyFile)
            [tmp__, iStudy] = bst_get('Study', StudyFile);
            panel_protocols('SelectNode', [], 'studysubject', iStudy, -1);
        elseif ~isempty(SubjectFile)
            [tmp__, iSubject] = bst_get('Subject', SubjectFile);
            panel_protocols('SelectNode', [], 'subject', -1, iSubject);
        end
        
        % If this is a stat file: update of the stat panel
        if isStat
            panel_stat('CurrentFigureChanged_Callback', hFig);
        end
    end
end

%% ===== GET CURRENT FIGURE =====
% Usage:  [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '2D');
%         [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '3D');
%         [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', 'TF');
%         [hFig,iFig,iDS] = bst_figures('GetCurrentFigure');
function [hFig,iFig,iDS] = GetCurrentFigure(Type)
	global GlobalData;
    hFig = [];
    iFig = [];
    iDS  = [];
    % No type specified: return the last figure selected
    if (nargin < 1) || isempty(Type)
        Type = 'Last';
    else
        Type = ['Type' Type];
    end
    % Remove selected point from current figure
    if ~isempty(GlobalData.CurrentFigure.(Type)) && ishandle(GlobalData.CurrentFigure.(Type))
        hFig = GlobalData.CurrentFigure.(Type);
    else
        return
    end
    % Get information from figure, if necessary
    if (nargout > 1)
        [hFig,iFig,iDS] = GetFigure(hFig);
    end
end


%% ===== FIND CURRENT FIGURE =====
% Tries to guess what the current figure that contains timefreq information
function [hFig,iFig,iDS] = FindCurrentTimefreqFigure()
    global GlobalData;
    % Tries to use the current referenced figure
    [hFig,iFig,iDS] = GetCurrentFigure('TF');
    if ~isempty(hFig)
        return;
    end
    % Else: Look for another figure
    for iDS = 1:length(GlobalData.DataSet)
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            h = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
            if ~ishandle(h) || ~isappdata(h, 'Timefreq')
                continue;
            end
            if ~isempty(getappdata(h, 'Timefreq'))
                hFig = h;
                % Set the current figure to this figure
                SetCurrentFigure(hFig, 'TF');
                return;
            end
        end
    end
    hFig = [];
    iFig = [];
    iDS = [];
end


%% ===== CHECK CURRENT FIGURE =====
function CheckCurrentFigure()
    global GlobalData;
    % Get current figure
    hFig = get(0, 'CurrentFigure');
    if ~isempty(hFig) && isappdata(hFig, 'hasMoved')
        GlobalData.CurrentFigure.Last = hFig;
    end
end

%% ===== CLONE FIGURE =====
function hNewFig = CloneFigure(hFig)
    global GlobalData;
    % Get figure description in GlobalData
    [tmp, iFig, iDS] = GetFigure(hFig);
    if isempty(iFig)
        if strcmpi(get(hFig, 'Tag'), 'FigHistograms')
            % Histograms are not registered figures but can still be cloned
            % using their UserData
            hNewFig = view_histogram(hFig.UserData.FileNames, hFig.UserData.forceOld);
        else
            warning('Brainstorm:FigureNotRegistered','Figure is not registered in Brainstorm.');
        end
        return;
    end
    FigureId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    % Get original figure appdata
    AppData = getappdata(hFig);
    
    % ===== COPY TF FIGURE =====
    if strcmpi(FigureId.Type, 'Spectrum')
        hNewFig = view_spectrum(AppData.Timefreq.FileName, AppData.Timefreq.DisplayMode, AppData.Timefreq.RowName, 1);
        return;
    elseif strcmpi(FigureId.Type, 'Timefreq')
        hNewFig = view_timefreq(AppData.Timefreq.FileName, AppData.Timefreq.DisplayMode, AppData.Timefreq.RowName, 1);
        return;
    end
    
    % ===== CREATE FIGURE =====
    % Create new empty figure
    [hNewFig, iNewFig] = CreateFigure(iDS, FigureId, 'AlwaysCreate');
    % Remove unwanted objects from the AppData structure
    for field = fieldnames(AppData)'
        if ~isempty(strfind(field{1}, 'uitools')) || isjava(AppData.(field{1})) || ismember(field{1}, {'SubplotDefaultAxesLocation', 'SubplotDirty'})
            AppData = rmfield(AppData, field{1});
            continue;
        end
    end
        
    % ===== 3D FIGURES =====
    if strcmpi(FigureId.Type, '3DViz') || strcmpi(FigureId.Type, 'Topography')
        % Remove all children objects (axes are automatically created)
        delete(get(hNewFig, 'Children'));
        % Copy all the figure objects
        hChild = get(hFig, 'Children');
        copyobj(hChild, hNewFig);
        % Copy figure colormap
        set(hNewFig, 'Colormap', get(hFig, 'Colormap'));
        % Copy Figure UserData
        set(hNewFig, 'UserData', get(hFig, 'UserData'));

        % === Copy and update figure AppData ===
        % Get patches handles
        hAxes    = findobj(hFig,    'tag', 'Axes3D');
        hNewAxes = findobj(hNewFig, 'tag', 'Axes3D');
        hPatches    = [findobj(hAxes,    'type', 'patch')',  findobj(hAxes,    'type', 'surf')'];
        hNewPatches = [findobj(hNewAxes, 'type', 'patch')',  findobj(hNewAxes, 'type', 'surf')'];
        % Update handles
        for iSurf = 1:length(AppData.Surface)
            for iPatch = 1:length(AppData.Surface(iSurf).hPatch)
                ip = find(AppData.Surface(iSurf).hPatch(iPatch) == hPatches);
                AppData.Surface(iSurf).hPatch(iPatch) = hNewPatches(ip);
            end
        end
        % Update new figure appdata
        fieldList = fieldnames(AppData);
        for iField = 1:length(fieldList)
            setappdata(hNewFig, fieldList{iField}, AppData.(fieldList{iField}));
        end

        % === 2D/3D FIGURES ===
        % Update sensor markers and labels
        GlobalData.DataSet(iDS).Figure(iNewFig).Handles.hSensorMarkers = findobj(hNewAxes, 'tag', 'SensorMarker');
        GlobalData.DataSet(iDS).Figure(iNewFig).Handles.hSensorLabels  = findobj(hNewAxes, 'tag', 'SensorsLabels');
        % Topography handles
        if strcmpi(FigureId.Type, 'Topography')
            GlobalData.DataSet(iDS).Figure(iNewFig).Handles.hSurf = findobj(hNewAxes, 'tag', get(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSurf, 'Tag'));
            GlobalData.DataSet(iDS).Figure(iNewFig).Handles.Wmat        = GlobalData.DataSet(iDS).Figure(iFig).Handles.Wmat;
            GlobalData.DataSet(iDS).Figure(iNewFig).Handles.DataMinMax  = GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax;
        end
        % Delete scouts
        delete(findobj(hNewAxes, 'Tag', 'ScoutLabel'));
        delete(findobj(hNewAxes, 'Tag', 'ScoutMarker'));
        delete(findobj(hNewAxes, 'Tag', 'ScoutPatch'));
        delete(findobj(hNewAxes, 'Tag', 'ScoutContour'));
        % Update current figure selection
        if strcmpi(FigureId.Type, '3DViz') || strcmpi(FigureId.SubType, '3DSensorCap')
            SetCurrentFigure(hNewFig, '3D');
        else
            SetCurrentFigure(hNewFig);
        end
        % Redraw scouts if any
        panel_scout('PlotScouts', [], hNewFig);
        panel_scout('UpdateScoutsDisplay', hNewFig);

        % === RESIZE ===
        % Call Resize and ColormapChanged callback to reposition correctly the colorbar
        figure_3d(get(hNewFig, bst_get('ResizeFunction')), hNewFig, []);
        figure_3d('ColormapChangedCallback', iDS, iNewFig);
        % Copy position and size of the initial figure (if no automatic repositioning)
        if isempty(bst_get('Layout', 'WindowManager'))
            newPos = get(hFig, 'Position') + [10 -10 0 0];
            set(hNewFig, 'Position', newPos);
        end
        % Update Surfaces panel
        panel_surface('UpdatePanel');
        
    % ===== TIME SERIES =====
    elseif strcmpi(FigureId.Type, 'DataTimeSeries')
        % Update new figure appdata
        fieldList = fieldnames(AppData);
        for iField = 1:length(fieldList)
            setappdata(hNewFig, fieldList{iField}, AppData.(fieldList{iField}));
        end
        GlobalData.DataSet(iDS).Figure(iNewFig).SelectedChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        % Update figure selection
        SetCurrentFigure(hNewFig, '2D');
        % Update figure
        figure_timeseries('PlotFigure', iDS, iNewFig);
        
    % ===== MATRIX =====
    elseif strcmpi(FigureId.Type, 'ResultsTimeSeries')
        % Update new figure appdata
        fieldList = fieldnames(AppData);
        for iField = 1:length(fieldList)
            setappdata(hNewFig, fieldList{iField}, AppData.(fieldList{iField}));
        end
        GlobalData.DataSet(iDS).Figure(iNewFig).SelectedChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        % Update figure selection
        SetCurrentFigure(hNewFig, '2D');
        % Update figure
        ReloadFigures(hNewFig);
    end
    % Copy figure name
    set(hNewFig, 'Name', get(hFig, 'Name'));
    % Make new figure visible
    set(hNewFig, 'Visible', 'on');
end


%% ===== GET CLONES =====
function [hClones, iClones, iDS] = GetClones(hFig)
    global GlobalData;
    % Get figure description in GlobalData
    [hFig, iFig, iDS] = GetFigure(hFig);
    if isempty(iFig)
        warning('Brainstorm:FigureNotRegistered','Figure is not registered in Brainstorm.');
        return;
    end
    % Get all figures that have the same FigureId in the same DataSet
    [hClones, iClones, iDS] = GetFigure(iDS, GlobalData.DataSet(iDS).Figure(iFig).Id);
    % Remove input figure
    iDel = find(hClones == hFig);
    hClones(iDel) = [];
    iClones(iDel) = [];
    iDS(iDel) = [];
    % Remove figures that do not have the same ResultsFile displayed
    ResultsFile = getappdata(hFig, 'ResultsFile');
    if ~isempty(ResultsFile)
        iDel = [];
        for i = 1:length(hClones)
            cloneResultsFile = getappdata(hClones(i), 'ResultsFile');
            if~strcmpi(ResultsFile, cloneResultsFile)
                iDel = [iDel i];
                break
            end
        end
        if ~isempty(iDel)
            hClones(iDel) = [];
            iClones(iDel) = [];
            iDS(iDel) = [];
        end
    end
end



%% ======================================================================
%  ===== CALLBACK SHARED BY ALL FIGURES =================================
%  ======================================================================
%% ===== NAVIGATOR KEYPRESS =====
function NavigatorKeyPress( hFig, keyEvent ) %#ok<DEFNU>
    % Get figure description
    [hFig, iFig, iDS] = GetFigure(hFig);
    if isempty(hFig)
        return
    end

    % ===== PROCESS BY KEYS =====
    switch (keyEvent.Key)
        % === DATABASE NAVIGATOR ===
        case 'f1'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousSubject', iDS);
            else
                bst_navigator('DbNavigation', 'NextSubject', iDS);
            end
        case 'f2'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousCondition', iDS);
            else
                bst_navigator('DbNavigation', 'NextCondition', iDS);
            end
        case 'f3'
            if ismember('shift', keyEvent.Modifier)
                bst_navigator('DbNavigation', 'PreviousData', iDS);
            else
                bst_navigator('DbNavigation', 'NextData', iDS);
            end
        case 'f4'
            %             if ismember('shift', keyEvent.Modifier)
            %                 bst_navigator('DbNavigation', 'PreviousResult', iDS);
            %             else
            %                 bst_navigator('DbNavigation', 'NextResult', iDS);
            %             end
    end
end


%% ===== VIEW TOPOGRAPHY =====
function ViewTopography(hFig, UseSmoothing)
    global GlobalData;
    if (nargin < 2) || isempty(UseSmoothing)
        UseSmoothing = 1;
    end
    % Get figure description
    [hFig, iFig, iDS] = GetFigure(hFig);
    if isempty(iDS) || isempty(GlobalData.DataSet(iDS).ChannelFile)
        return
    end
    % Get figure type
    FigureType  = GlobalData.DataSet(iDS).Figure(iFig).Id.Type;
    Modalities = [];
    switch(FigureType)
        case 'Topography'
            % Nothing to do
            return
        case {'3DViz', 'DataTimeSeries', 'ResultsTimeSeries'}
            % Get all the figure information 
            DataFile = getappdata(hFig, 'DataFile');
            FigMod = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
            RecType = GlobalData.DataSet(iDS).Measures.DataType;
            % Get displayable sensor types
            [AllMod, DispMod, DefaultMod] = bst_get('ChannelModalities', DataFile);
            % If current modality is not MEG or EEG, cannot display topography: get default modality
            if ~ismember(FigMod, {'MEG','MEG GRAD','MEG MAG','EEG','ECOG','SEEG','NIRS','ECOG+SEEG'}) && ~isempty(DataFile)
                Modalities = {DefaultMod};
            % If displaying Stat on Neuromag recordings: Display all sensors separately
            elseif ismember(FigMod, {'MEG','MEG GRAD'}) && all(ismember({'MEG MAG','MEG GRAD'}, AllMod)) && ~isempty(DataFile) && (strcmpi(file_gettype(DataFile), 'pdata') || ~ismember(RecType, {'recordings','raw'}))
                Modalities = {'MEG MAG', 'MEG GRAD2', 'MEG GRAD3'};
            else
                Modalities = {FigMod};
            end           
                
        case {'Timefreq', 'Spectrum', 'Pac'}
            % Get time freq information
            TfInfo = getappdata(hFig, 'Timefreq');
            DataFile = TfInfo.FileName;
            iTimefreq = bst_memory('GetTimefreqInDataSet', iDS, DataFile);
            % Switch depending on the data type
            switch (GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType)
                case 'data'
                    % Display all the modalities available
                    Modalities = bst_get('TimefreqDisplayModalities', DataFile);
                    % If displaying TF of Neuromag recordings: Display all sensors separately
                    if all(ismember({'MEG MAG','MEG GRAD'}, Modalities))
                        Modalities = {'MEG MAG', 'MEG GRAD2', 'MEG GRAD3'};
                    end
%                     % Get the type of the sensor that is currently displayed
%                     iSelChan = find(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, TfInfo.RowName));
%                     if ~isempty(iSelChan)
%                         Modalities{1} = GlobalData.DataSet(iDS).Channel(iSelChan).Type;
%                     else
%                         Modalities{1} = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
%                     end
                otherwise
                    error(['This files contains information about cortical sources or regions of interest.' 10 ...
                           'Cannot display it as a sensor topography.']);
            end
            RecType = '';
        case 'Connect'
            warning('todo');
    end
    % Call view data function
    if ~isempty(DataFile) && ~isempty(Modalities)
        for i = 1:length(Modalities)
            if ismember(Modalities{i}, {'ECOG', 'SEEG', 'ECOG+SEEG'})
                % 3D figure: plot topography in the same figure
                if isequal(FigureType, '3DViz')
                    view_topography(DataFile, Modalities{i}, '3DElectrodes', [], [], hFig);
                % Other types of figures: Create new figure
                elseif ~isempty(DispMod) && ismember(Modalities{i}, DispMod)
                    view_topography(DataFile, Modalities{i}, '3DElectrodes');
                else
                    view_topography(DataFile, Modalities{i}, '2DElectrodes');
                end
            elseif isequal(Modalities{i}, 'NIRS')
                % Get montage used in figure
                TsInfo = getappdata(hFig, 'TsInfo');
                % Set as default montage for NIRS topography
                if ~isempty(TsInfo.MontageName) && ~ismember(TsInfo.MontageName, {'NIRS overlay[tmp]', 'Bad channels'})
                    GlobalData.ChannelMontages.CurrentMontage.mod_topo_nirs = TsInfo.MontageName;
                end
                % Open topography figure
                view_topography(DataFile, Modalities{i}, '3DOptodes');
            else
                if ~ismember(RecType, {'recordings','raw'}) || strcmpi(file_gettype(DataFile), 'pdata')
                    UseSmoothing = 0;
                end
                view_topography(DataFile, Modalities{i}, '2DSensorCap', [], UseSmoothing);
            end
        end
    end
end


%% ===== VIEW RESULTS =====
function ViewResults(hFig)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = GetFigure(hFig);
    if isempty(iDS)
        return
    end
    % Get all the figure information 
    DataFile    = getappdata(hFig, 'DataFile');
    ResultsFile = getappdata(hFig, 'ResultsFile');
    Modality    = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % Display results only for figures without results
    if ~isempty(ResultsFile) || isempty(DataFile)
        return
    end
    % === RESULTS FILE ===
    % Get first available results files for figure data file
    [sStudy, iStudy, iResults] = bst_get('ResultsForDataFile', DataFile);
    if isempty(iResults)
        return
    end
    ListResultsFiles = {sStudy.Result(iResults).FileName};
    % Try to find a results file with the same modality
    if ~isempty(Modality)
        ResultsFile = '';
        for i = 1:length(ListResultsFiles)
            if ~isempty(strfind(ListResultsFiles{i}, ['_' Modality '_']))
                ResultsFile = ListResultsFiles{i};
                break;
            end
        end
        % Check if a ResultsFile is found
        if isempty(ResultsFile)
            java_dialog('warning', ['No sources computed for modality "' Modality '".'],'View sources');
            return
        end
    else
        ResultsFile = ListResultsFiles{1};
    end
    % Call view results function
    view_surface_data([], ResultsFile, Modality);
end


%% ===== DOCK FIGURE =====
function DockFigure(hFig, isDocked) %#ok<DEFNU>
    if isDocked
        set(hFig, 'WindowStyle', 'docked');
        ShowMatlabControls(hFig, 1);
        plotedit('off');
    else
        set(hFig, 'WindowStyle', 'normal');
        ShowMatlabControls(hFig, 0);
    end
    gui_layout('Update');
end

    
%% ===== SHOW MATLAB CONTROLS =====
function ShowMatlabControls(hFig, isMatlabCtrl)
    if ~isMatlabCtrl
        set(hFig, 'Toolbar', 'none', 'MenuBar', 'none');
        plotedit('off');
    else
        set(hFig, 'Toolbar', 'figure', 'MenuBar', 'figure');
        plotedit('on');
    end
    gui_layout('Update');
end

%% ===== PLOT EDIT TOOLBAR =====
function TogglePlotEditToolbar(hFig)
    % Keep in the figure appdata whether toolbar is displayed
    isPlotEditToolbar = getappdata(hFig, 'isPlotEditToolbar');
    setappdata(hFig, 'isPlotEditToolbar', ~isPlotEditToolbar);
    % Show/Hide Matlab controls at the same time
    ShowMatlabControls(hFig, ~isPlotEditToolbar);
    plotedit('off');
    drawnow
    % Toggle Plot Edit toolbar display
    try
        plotedit(hFig, 'plotedittoolbar', 'toggle');
    catch
    end
    % Reposition figures
    gui_layout('Update');
end




%% ======================================================================
%  ===== LOCAL HELPERS ==================================================
%  ======================================================================
% Check if a Figure structure is a valid 
function isValid = isFigureId(FigureId)
    if (~isempty(FigureId) && isstruct(FigureId) && ...
            isfield(FigureId, 'Type') && ...
            isfield(FigureId, 'SubType') && ...
            isfield(FigureId, 'Modality') && ...
            ismember(FigureId.Type, {'DataTimeSeries', 'ResultsTimeSeries', 'Topography', '3DViz', 'MriViewer', 'Timefreq', 'Spectrum', 'Pac', 'Connect', 'Image'}));
        isValid = 1;
    else
        isValid = 0;
    end
end
    
% Compare two figure identification structures.
% FOR THE MOMENT : COMPARISON EXCLUDES 'SUBTYPE' FIELD
% Return : 1 if the two structures are equal,
%          0 else
function isEqual = compareFigureId(fid1, fid2)
    if (strcmpi(fid1.Type, fid2.Type) && ...
        (isempty(fid1.SubType) || isempty(fid2.SubType) || strcmpi(fid1.SubType, fid2.SubType)) && ... 
        (isempty(fid1.Modality) || isempty(fid2.Modality) || strcmpi(fid1.Modality, fid2.Modality)))
    
        isEqual = 1;
    else
        isEqual = 0;
    end
end
        


%% ===== RELOAD FIGURES ======
% Reload all the figures (needed for instance after changing the visualization filters parameters).
%
% USAGE:  ReloadFigures(FigureType)  : Reload all the figures of a specific type
%         ReloadFigures(FigureTypes) : Reload all the figures of a list of types
%         ReloadFigures('Stat')      : Reload all the stat figures
%         ReloadFigures(hFigs)       : Reload a specific list of figures
%         ReloadFigures()            : Reload all the figures
%         ReloadFigures(..., isFastUpdate=1):  If 0, clear all the figures and plot them completely
function ReloadFigures(FigureTypes, isFastUpdate)
    global GlobalData;
    % By default: fast update
    if (nargin < 2) || isempty(isFastUpdate)
        isFastUpdate = 1;
    end
    % If figure type not sepcified
    isStatOnly = 0;
    hFigs = [];
    if (nargin == 0)
        FigureTypes = [];
    elseif ischar(FigureTypes)
        if strcmpi(FigureTypes, 'Stat')
            FigureTypes = [];
            isStatOnly = 1;
        else
            FigureTypes = {FigureTypes};
        end
    elseif ~isempty(FigureTypes)
        hFigs = FigureTypes;
        FigureTypes = [];
    end
    FigClose = [];
    % Process all the loaded datasets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all the figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            % Check figure type
            if ~isempty(FigureTypes) && ~ismember(Figure.Id.Type, FigureTypes)
                continue;
            end
            if ~isempty(hFigs) && ~ismember(Figure.hFigure, hFigs)
                continue;
            end
            % Check if reload call is available
            ReloadCall = getappdata(Figure.hFigure, 'ReloadCall');
            if ~isempty(ReloadCall)
                ReloadFcn = str2func(ReloadCall{1});
                ReloadFcn(ReloadCall{2:end});
            end
            % Switch according to figure type
            switch(Figure.Id.Type)
                case 'DataTimeSeries'
                    % Ignore non-stat files
                    if isStatOnly && ~strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
                        continue;
                    end
                    % Reload
                    if isempty(Figure.Id.Modality)
                        % Nothing to do
                    elseif (Figure.Id.Modality(1) == '$')
                        DataFiles = getappdata(Figure.hFigure, 'DataFiles');
                        iClusters = getappdata(Figure.hFigure, 'iClusters');
                        if ~isempty(DataFiles) && ~isempty(iClusters)
                            view_clusters(DataFiles, iClusters, Figure.hFigure);
                        end
                    else
                        TsInfo = getappdata(Figure.hFigure, 'TsInfo');
                        if TsInfo.AutoScaleY
                            GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax = [];
                        end
                        GlobalData.DataSet(iDS).Figure(iFig).Handles.DownsampleFactor = [];
                        isOk = figure_timeseries('PlotFigure', iDS, iFig, [], [], isFastUpdate);
                        % The figure could not be refreshed: close it
                        if ~isOk
                            close(Figure.hFigure);
                            continue;
                        end
                    end
                    UpdateFigureName(Figure.hFigure);
                    
                case 'ResultsTimeSeries'
                    % Get file names displayed in this figure
                    ResultsFiles = getappdata(Figure.hFigure, 'ResultsFiles');
                    TsInfo = getappdata(Figure.hFigure, 'TsInfo');
                    StatInfo = getappdata(Figure.hFigure, 'StatInfo');
                    % Ignore non-stat files
                    if isStatOnly
                        if ~isempty(ResultsFiles) && iscell(ResultsFiles) && ~strcmpi(file_gettype(ResultsFiles{1}), 'presults')
                            continue;
                        elseif ~isempty(TsInfo) && isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName) && ~strcmpi(file_gettype(TsInfo.FileName), 'pmatrix')
                            continue;
                        end
                    end
                    % Reload
                    if ~isempty(StatInfo)
                        view_statcluster(StatInfo.StatFile, StatInfo.DisplayMode, [], Figure.hFigure);
                    elseif ~isempty(ResultsFiles)
                        view_scouts(ResultsFiles, 'SelectedScouts', Figure.hFigure);
                    elseif ~isempty(TsInfo) && isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName)
                        %FigClose = [FigClose, Figure.hFigure];
                        view_matrix(TsInfo.FileName, 'TimeSeries', Figure.hFigure);
                    end
                    
                case 'Topography'
                    if isFastUpdate
                        figure_topo('UpdateTopoPlot', iDS, iFig);
                    else
                        figure_topo('PlotFigure', iDS, iFig, 1);
                    end
                    
                case '3DViz'
                    % Get the kind of data represented in this window
                    TessInfo = getappdata(Figure.hFigure, 'Surface');

                    % === PROCESS SURFACES ===
                    for iTess = 1:length(TessInfo)
                        % Ignore non-stat files
                        if isStatOnly && ~isempty(TessInfo(iTess).DataSource.FileName)
                            if ~ismember(file_gettype(TessInfo(iTess).DataSource.FileName), {'pdata', 'presults', 'ptimefreq'})
                                continue;
                            end
                        end
                        % Reset maximum
                        TessInfo(iTess).DataMinMax = [];
                        setappdata(Figure.hFigure, 'Surface', TessInfo);
                        % Get type of source file: anatomy/surface
                        SurfaceType = file_gettype(TessInfo(iTess).SurfaceFile);
                        % View 3D MRI
                        if strcmpi(SurfaceType, 'subjectimage')
                            OverlayFile = TessInfo(iTess).DataSource.FileName;
                            if ~isempty(OverlayFile)
                                view_surface_data(TessInfo(iTess).SurfaceFile, TessInfo(iTess).DataSource.FileName, Figure.Id.Modality);
                            else
                                view_mri_3d(TessInfo(iTess).SurfaceFile, [], [], Figure.hFigure);
                            end
                        else
                            % View surface only
                            if isempty(TessInfo(iTess).DataSource.FileName)
                                view_surface(TessInfo(iTess).SurfaceFile, [], [], Figure.hFigure);
                            % View data on surface
                            else
                                view_surface_data(TessInfo(iTess).SurfaceFile, TessInfo(iTess).DataSource.FileName, Figure.Id.Modality, Figure.hFigure);
                            end
                        end
                    end
                    % === PROCESS SENSORS ===
                    ChannelFile = GlobalData.DataSet(iDS).ChannelFile;
                    if ~isempty(ChannelFile)
                        isMarkers = ~isempty(Figure.Handles.hSensorMarkers) && ishandle(Figure.Handles.hSensorMarkers(1)) && strcmpi(get(Figure.Handles.hSensorMarkers(1), 'Visible'), 'on');
                        isLabels  = ~isempty(Figure.Handles.hSensorLabels) && ishandle(Figure.Handles.hSensorLabels(1)) && strcmpi(get(Figure.Handles.hSensorLabels(1), 'Visible'), 'on');
                        hElectrodeObjects = [findobj(Figure.hFigure, 'Tag', 'ElectrodeGrid'); findobj(Figure.hFigure, 'Tag', 'ElectrodeDepth'); findobj(Figure.hFigure, 'Tag', 'ElectrodeWire')];
                        % Update 3D electrodes
                        if ~isempty(hElectrodeObjects)
                            figure_3d('PlotSensors3D', iDS, iFig);
                        % Update channels display
                        elseif isMarkers || isLabels
                            %view_channels(ChannelFile, Figure.Id.Modality, isMarkers, isLabels);
                            figure_3d('ViewSensors', Figure.hFigure, isMarkers, isLabels);
                        end
                    end
                    
                case 'MriViewer'
                    % Get the kind of data represented in this window
                    TessInfo = getappdata(Figure.hFigure, 'Surface');
                    % === PROCESS SURFACES ===
                    for iTess = 1:length(TessInfo)
                        % Ignore non-stat files
                        isStat = ~isempty(TessInfo(iTess).DataSource.FileName) && ismember(file_gettype(TessInfo(iTess).DataSource.FileName), {'pdata', 'presults', 'ptimefreq'});
                        if isStatOnly && ~isStat
                            continue;
                        end
                        % Update channels display
                        view_mri(TessInfo(iTess).SurfaceFile, TessInfo(iTess).DataSource.FileName);
                    end
                    
                case 'Timefreq'
                    figure_timefreq('UpdateFigurePlot', Figure.hFigure, 1);
                case 'Spectrum'
                    figure_spectrum('UpdateFigurePlot', Figure.hFigure);
                    UpdateFigureName(Figure.hFigure);
                case 'Pac'
                    figure_pac('UpdateFigurePlot', Figure.hFigure);
                case 'Connect'
                    warning('todo: reload figure');
                case 'Image'
                    % ReloadCall only
                case 'Video'
                    figure_video('CurrentTimeChangedCallback', Figure.hFigure);
            end
        end
        % Update selected sensors
        FireSelectedRowChanged();
    end
    % Re-uniformize figures
    figure_timeseries('UniformizeTimeSeriesScales');
    % Close figures
    if ~isempty(FigClose)
        close(FigClose);
    end
end


%% =========================================================================================
%  ===== MOUSE SELECTION ===================================================================
%  =========================================================================================
% ===== TOGGLE SELECTED ROW =====
function ToggleSelectedRow(RowNames)
    global GlobalData;
    % Convert to cell
    if ~iscell(RowNames)
        RowNames = {RowNames};
    end
    % Remove spaces in channel names
    RowNames = cellfun(@(c)strrep(c,' ',''), RowNames, 'UniformOutput', 0);
    % Expand bipolar montages
    for i = 1:length(RowNames)
        bipNames = str_split(RowNames{i}, '-');
        if (length(bipNames) == 2)
            RowNames = cat(2, RowNames, bipNames);
        end
    end
    % If row name is already in list: remove it
    if ismember(RowNames, GlobalData.DataViewer.SelectedRows)
        SetSelectedRows(setdiff(GlobalData.DataViewer.SelectedRows, RowNames));
    % Else: add it
    else
        SetSelectedRows(union(GlobalData.DataViewer.SelectedRows, RowNames));
    end
end

%% ===== SET SELECTED ROWS =====
function SetSelectedRows(RowNames, isUpdateClusters)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(isUpdateClusters)
        isUpdateClusters = 1;
    end
    % Convert to cell
    if isempty(RowNames)
        RowNames = {};
    elseif ischar(RowNames)
        RowNames = {RowNames};
    end
    % Remove spaces in channel names
    RowNames = cellfun(@(c)strrep(c,' ',''), RowNames, 'UniformOutput', 0);
    % Set list
    GlobalData.DataViewer.SelectedRows = RowNames;
    % Update all figures
    FireSelectedRowChanged();
    % Update selected clusters
    if isUpdateClusters
        panel_cluster('SetSelectedClusters', [], 0);
    end
end

%% ===== GET SELECTED CHANNELS =====
function [SelChan, iSelChan] = GetSelectedChannels(iDS)
    global GlobalData;
    % No channel file: return
    if isempty(GlobalData.DataSet(iDS).Channel)
        return;
    end
    AllChan = {GlobalData.DataSet(iDS).Channel.Name};
    % Remove spaces in channel names
    AllChanNoSpace = cellfun(@(c)strrep(c,' ',''), AllChan, 'UniformOutput', 0);
    % Get the channel names and indices
    SelChan = {};
    iSelChan = [];
    for i = 1:length(GlobalData.DataViewer.SelectedRows)
        iChan = find(strcmpi(GlobalData.DataViewer.SelectedRows{i}, AllChanNoSpace));
        if ~isempty(iChan)
            SelChan{end+1} = AllChan{iChan};
            iSelChan(end+1) = iChan;
        end
    end
end

%% ===== FIRE SELECTED ROWS CHANGED =====
% Call SelectedRowChangedCallback on all the figures
function FireSelectedRowChanged()
    global GlobalData;
    for iDS = 1:length(GlobalData.DataSet)
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            sFig = GlobalData.DataSet(iDS).Figure(iFig);
            % Only fires for currently visible displayed figures, AND not static
            switch (sFig.Id.Type)
                case 'DataTimeSeries'
                    figure_timeseries('SelectedRowChangedCallback', iDS, iFig);
                case 'ResultsTimeSeries'
                    figure_timeseries('SelectedRowChangedCallback', iDS, iFig);
                case 'Topography'
                    figure_3d('UpdateFigSelectedRows', iDS, iFig);
                case '3DViz'
                    figure_3d('UpdateFigSelectedRows', iDS, iFig);
                case 'MriViewer'
                    % Nothing to do
                case 'Timefreq'
                    % Nothing to do
                case 'Spectrum'
                    figure_spectrum('SelectedRowChangedCallback', iDS, iFig);
                case 'Pac'
                    % Nothing to do
                case 'Connect'
                    figure_connect('SelectedRowChangedCallback', iDS, iFig);
                case 'Image'
                    % Nothing to do
                otherwise
                    % Nothing to do
            end
        end 
    end
end


%% ===== SET BACKGROUND COLOR =====
function SetBackgroundColor(hFig, newColor) %#ok<*DEFNU>
    % Use previous scout color
    if (nargin < 2) || isempty(newColor)
        % newColor = uisetcolor([0 0 0], 'Select scout color');
        newColor = java_dialog('color');
    end
    % If no color was selected: exit
    if (length(newColor) ~= 3)
        return
    end
    % Find all the dependent axes
    hAxes = findobj(hFig, 'Type', 'Axes')';
    % Set background
    set([hFig hAxes], 'Color', newColor);
    % Find opposite colors
    if (sum(newColor .^ 2) > 0.8)
        textColor = [0 0 0];
        topoColor = [0 0 0];
    else
        textColor = [.8 .8 .8];
        topoColor = [.4 .4 .4];
    end
    % Change color for buttons
    hControls = findobj(hFig, 'Type', 'uicontrol');
    if ~isempty(hControls)
        set(hControls, 'BackgroundColor', newColor);
    end
    % Change color of ears + nose
    hRefTopo = findobj(hFig, 'Tag', 'RefTopo');
    if ~isempty(hRefTopo)
        set(hRefTopo, 'Color', topoColor);
    end
    % Change color of topo circle
    hRefTopo = findobj(hFig, 'Tag', 'CircleTopo');
    if ~isempty(hRefTopo)
        set(hRefTopo, 'EdgeColor', topoColor);
    end
    % Change color of colorbar text
    hColorbar = findobj(hFig, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        set(hColorbar, 'XColor', textColor, ...
                       'YColor', textColor);
    end
end


