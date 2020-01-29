function [hFig, iDS, iFig] = view_topography(DataFile, Modality, TopoType, F, UseSmoothing, hFig, RefRowName)
% VIEW_TOPOGRAPHY: Display MEG/EEG topography in a new figure.
%
% USAGE:  [hFig, iDS, iFig] = view_topography(DataFile, Modality, TopoType, F, UseSmoothing, hFig, RefRowName)
% USAGE:  [hFig, iDS, iFig] = view_topography(DataFile, Modality, TopoType, F, UseSmoothing, 'NewFigure', RefRowName)
%         [hFig, iDS, iFig] = view_topography(DataFile, Modality, TopoType, F)
%         [hFig, iDS, iFig] = view_topography(DataFile, Modality, TopoType)
%         [hFig, iDS, iFig] = view_topography(MultiDataFiles, Modality, '2DLayout')
%
% INPUT: 
%     - DataFile       : Full or relative path to data file to visualize.
%     - MultiDataFiles : Cell array of files to display as overlays in a 2DLayout view  
%     - Modality       : {'MEG', 'MEG GRAD', 'MEG MAG', 'EEG', 'ECOG', 'SEEG', 'NIRS'}
%     - TopoType       : {'3DSensorCap', '2DDisc', '2DSensorCap', 2DLayout', '3DElectrodes', '3DElectrodes-Cortex', '3DElectrodes-Head', '3DElectrodes-MRI', '3DOptodes', '2DElectrodes'}
%     - F              : Data matrix to display instead of the real values from the file
%     - UseSmoothing   : Extrapolate magnetic values (for MEG only)
%     - hFig           : Specify the figure in which to display the MRI, or "NewFigure"
%     - RefRowName     : Reference sensor name, when displaying a NxN connectivity matrix
%
% OUTPUT: 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2016

global GlobalData;
% ===== PARSE INPUTS =====
if (nargin < 7) || isempty(RefRowName)
    RefRowName = [];
end
if (nargin < 6) || isempty(hFig) || isequal(hFig,0)
    hFig = [];
    CreateMode = [];
elseif isequal(hFig,'NewFigure')
    hFig = [];
    CreateMode = 'AlwaysCreate';
end
if (nargin < 5) || isempty(UseSmoothing)
    UseSmoothing = [];
end
if (nargin < 4) || isempty(F)
    F = [];
end
if (nargin < 3) || isempty(TopoType)
    TopoType = '2DSensorCap';
end
if (nargin < 2) || isempty(Modality)
    Modality = '';
end
% Check for multiple files in 2DLayout
MultiDataFiles = {};
if iscell(DataFile)
    if ~strcmpi(TopoType, '2DLayout')
        error('Only 2DLayout display type accepts multiple input files.');
    end
    if (length(DataFile) == 1)
        DataFile = DataFile{1};
    else
        MultiDataFiles = DataFile;
        DataFile = DataFile{1};
    end
end
% Detect surface type in the topo type string
switch (TopoType)
    case '3DElectrodes-Cortex'
        TopoType = '3DElectrodes';
        SurfaceType = 'cortex';
    case '3DElectrodes-Scalp'
        TopoType = '3DElectrodes';
        SurfaceType = 'scalp';
    case '3DElectrodes-MRI'
        TopoType = '3DElectrodes';
        SurfaceType = 'anatomy';
    otherwise
        SurfaceType = [];
end


%% ===== LOAD DATA =====
bst_progress('start', 'Topography', 'Loading data file...');
% Get DataFile type
fileType = file_gettype(DataFile);
% Load file
switch(fileType)
    case 'data'
        FileType = 'Data';
        iDS = bst_memory('LoadDataFile', DataFile);
        if isempty(iDS)
            return;
        end
        % Load additional files
        for iFile = 2:length(MultiDataFiles)
            iDSmulti = bst_memory('LoadDataFile', MultiDataFiles{iFile});
            if isempty(iDSmulti)
                bst_error(['An error occurred loading file: ', 10, file_short(MultiDataFiles{iFile})], 'View topography', 0);
                return;
            end
            % Channel names must be the same for all the files
            if ~isequal({GlobalData.DataSet(iDS).Channel.Name}, {GlobalData.DataSet(iDSmulti).Channel.Name})
                bst_error(['All the files must have the same list of channels.', 10, 'Consider using the process "Standardize > Uniform list of channels".'], 'View topography', 0);
                return;
            end
            % Add bad channels to the common list of bad channels (first file)
            GlobalData.DataSet(iDS).Measures.ChannelFlag(GlobalData.DataSet(iDSmulti).Measures.ChannelFlag == -1) = -1;
        end
        % Colormap type
        if ~isempty(GlobalData.DataSet(iDS).Measures.ColormapType)
            ColormapType = GlobalData.DataSet(iDS).Measures.ColormapType;
        else
            switch Modality
                case {'MEG', 'MEG MAG', 'MEG GRAD', 'MEG GRAD2', 'MEG GRAD3'}
                    ColormapType = 'meg';
                case {'EEG', 'ECOG', 'SEEG', 'ECOG+SEEG'}
                    ColormapType = 'eeg';
                case {'MEG GRADNORM'}
                    ColormapType = 'timefreq';
                case 'NIRS'
                    ColormapType = 'nirs';
                otherwise
                    error(['Modality "' Modality '" cannot be represented in 2D topography.']);
            end
        end
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Measures.DisplayUnits;
        % Data: Use magnetic interpolation only for real recordings and not 2DLayout
        if isempty(UseSmoothing)
            UseSmoothing = ismember(GlobalData.DataSet(iDS).Measures.DataType, {'recordings', 'raw'}) && ...
                           ~isempty(Modality) && ismember(Modality, {'MEG', 'MEG GRAD', 'MEG MAG', 'EEG'}) && ...
                           ~strcmpi(TopoType, '2DLayout');
        end
        UseMontage = ismember(GlobalData.DataSet(iDS).Measures.DataType, {'recordings', 'raw'});
        
    case 'pdata'
        FileType = 'Data';
        iDS = bst_memory('LoadDataFile', DataFile);
        if isempty(iDS)
            return;
        end
        % Load additional files
        for iFile = 2:length(MultiDataFiles)
            iDSmulti = bst_memory('LoadDataFile', MultiDataFiles{iFile});
            if isempty(iDSmulti)
                error(['An error occurred loading file: ' MultiDataFiles{iFile}]);
            end
        end
        % Colormap type
        if ~isempty(GlobalData.DataSet(iDS).Measures.ColormapType)
            ColormapType = GlobalData.DataSet(iDS).Measures.ColormapType;
        else
            ColormapType = 'stat2';
        end
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Measures.DisplayUnits;
        % Do not allow magnetic extrapolation for stat data
        UseSmoothing = 0;
        UseMontage = 0;
        
    case {'timefreq', 'ptimefreq'}
        FileType = 'Timefreq';
        [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', DataFile);
        if isempty(iDS)
            return;
        end
        % Additional files: not supported
        if ~isempty(MultiDataFiles)
            error('Multiple time-frequency files are not yet supported in 2DLayout.');
        end
        % Colormap type
        if ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType)
            ColormapType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType;
        elseif ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method, {'corr','cohere','spgranger','granger','plv','plvt'})
            ColormapType = 'connect1';
        elseif ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method, {'pac'})
            ColormapType = 'pac';
        else
            ColormapType = 'timefreq';
        end
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits;
        % Do not allow magnetic extrapolation for Timefreq data
        UseSmoothing = 0;
        UseMontage = 0;
        % Detect modality
        if isempty(Modality)
            Modality = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality;
        end
        AllModalities = GlobalData.DataSet(iDS).Timefreq(iTimefreq).AllModalities;
        % Sensor type that cannot be displayed
        if ~isempty(Modality) && ~ismember(Modality, {'MEG','MEG GRAD','MEG MAG','MEG GRAD2','MEG GRAD3','MEG GRADNORM', 'EEG','SEEG','ECOG','ECOG+SEEG','NIRS'})
            bst_error(['Cannot display 2D/3D topography for modality "' Modality '".'], 'View topography', 0);
            return;
        % If there are multiple modalities available in the file
        elseif isempty(Modality) && ~isempty(AllModalities)
            % If there are multiple modalities but one only that can be displayed as a topography
            DispMod = intersect(AllModalities, {'MEG','MEG GRAD','MEG MAG','EEG','ECOG','NIRS'});
            % No available display types
            if isempty(DispMod)
                Modality = [];
            % Only one display type
            elseif (length(DispMod) == 1)
                Modality = DispMod{1};
            % Else: ask user what to display
            else
                res = java_dialog('question', ['This file contains multiple sensor types.' 10 'Which modality would you like to display?'], 'Select sensor type', [], DispMod);
                if isempty(res) || strcmpi(res, 'Cancel')
                    bst_progress('stop');
                    return;
                else
                    Modality = res;
                end
            end
        end
        % No display option found
        if isempty(Modality)
            bst_error('Cannot display 2D/3D topography for this file.', 'View topography', 0);
            return;
        end
    case 'none'
        UseSmoothing = 0;
        UseMontage = 0;
    otherwise
        error(['This files contains information about cortical sources or regions of interest.' 10 ...
               'Cannot display it as a sensor topography.']);
end
if isempty(iDS)
    error(['Cannot load file : "', DataFile, '"']);
end


%% ===== CREATE FIGURE =====
if isempty(hFig)
    % Prepare FigureId structure
    FigureId.Type     = 'Topography';
    FigureId.SubType  = TopoType;
    FigureId.Modality = Modality;
    % Create TimeSeries figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, DataFile);
    if isempty(hFig)
        bst_error('Cannot create figure', 'View topography', 0);
        return;
    end
    % Configure appdata
    setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
    setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
    setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
% Use existing figure
else
    isNewFig = 0;
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
end


%% ===== CONFIGURE FIGURE =====
% If figure already existed: re-use its UseSmoothing value
if ~isNewFig
    oldTopoInfo = getappdata(hFig, 'TopoInfo');
    if ~isempty(oldTopoInfo) && ~isempty(oldTopoInfo.UseSmoothing)
        UseSmoothing = oldTopoInfo.UseSmoothing;
    end
end

MontageName = [];
% Only for recordings
if UseMontage
    % Get default montage
    sMontage = panel_montage('GetCurrentMontage', ['topo_' Modality]);
    sFigMontages = panel_montage('GetMontagesForFigure', hFig);
    % If there are montages available for this figure
    if ~isempty(sFigMontages)
        % Try to select previously selected montage
        if ~isempty(sMontage) && any(strcmpi({sFigMontages.Name}, sMontage.Name))
            % For NIRS: allow all types of montages
            if strcmpi(Modality, 'NIRS')
                MontageName = sMontage.Name;
            % For other types of data: do not accept "selection" montages
            elseif ~strcmpi(sMontage.Type, 'selection')
                MontageName = sMontage.Name;
            end
        end
        % For NIRS (: Force the selection of a montage
        if strcmpi(Modality, 'NIRS') && isempty(MontageName)
            % 3DOptodes and 3DSensorCap: Only one value can be displayed at a time
            if ismember(TopoType, {'3DSensorCap', '3DOptodes'}) 
                MontageName = sFigMontages(2).Name;
            elseif strcmpi(TopoType, '2DLayout')
                MontageName = sFigMontages(1).Name;
            end
        end
    end
end
% Get subject
sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
% Create topography information structure
TopoInfo = db_template('TopoInfo');
TopoInfo.FileName   = DataFile;
TopoInfo.FileType   = FileType;
TopoInfo.Modality   = Modality;
TopoInfo.TopoType   = TopoType;
TopoInfo.DataToPlot = F;
TopoInfo.UseSmoothing = UseSmoothing;
TopoInfo.MultiDataFiles = MultiDataFiles;
setappdata(hFig, 'TopoInfo', TopoInfo);
% Create recordings info structure
TsInfo = db_template('TsInfo');
TsInfo.FileName    = DataFile;
TsInfo.Modality    = Modality;
TsInfo.DisplayMode = 'topography';
TsInfo.MontageName = MontageName;
setappdata(hFig, 'TsInfo', TsInfo);
% Add colormap
bst_colormaps('AddColormapToFigure', hFig, ColormapType, DisplayUnits);

% Time-freq structure
if strcmpi(FileType, 'Timefreq')
    % Get study
    [sStudy, iStudy, iItem, DataType, sTimefreq] = bst_get('AnyFile', DataFile);
    if isempty(sStudy)
        error('File is not registered in database.');
    end
    % If displaying a NxN connectivity matrix and no reference sensors selection was made: Pick the first one
    if (length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames) > 1) && isempty(RefRowName)
        RefRowName = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames{1};
        gui_brainstorm('ShowToolTab', 'Display');
    end
    % Static dataset
    isStatic = (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 1) || ...
               ((GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples == 2) && isequal(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(:,1,:,:,:), GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(:,2,:,:,:)));
    setappdata(hFig, 'isStatic', isStatic);
    isStaticFreq = (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1);
    setappdata(hFig, 'isStaticFreq', isStaticFreq);
    % Create options structure
    TfInfo = db_template('TfInfo');
    TfInfo.FileName   = DataFile;
    TfInfo.Comment    = sTimefreq.Comment;
    TfInfo.RowName    = [];
    TfInfo.RefRowName = RefRowName;
    TfInfo.Function   = process_tf_measure('GetDefaultFunction', GlobalData.DataSet(iDS).Timefreq(iTimefreq));
    if isStaticFreq
        TfInfo.iFreqs = [];
    elseif ~isempty(GlobalData.UserFrequencies.iCurrentFreq)
        TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
    else
        TfInfo.iFreqs = 1;
    end
    % Set figure data
    setappdata(hFig, 'Timefreq', TfInfo);
    % Update figure name
    bst_figures('UpdateFigureName', hFig);
    % Display options panel
    isDisplayTab = ~strcmpi(TfInfo.Function, 'other');
    if isDisplayTab
        gui_brainstorm('ShowToolTab', 'Display');
    end
else
    isDisplayTab = 0;
    setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));
end

%% ===== PLOT FIGURE =====
isOk = figure_topo('PlotFigure', iDS, iFig, 1);
% If an error occured: delete figure
if ~isOk
    close(hFig);
    bst_progress('stop');
    return
end
% For 3D views: Add a surface
if isNewFig && ismember(TopoType, {'3DSensorCap', '3DElectrodes', '3DOptodes'})
    % Default surface type
    if isempty(SurfaceType)
        switch (Modality)
            case 'ECOG',      SurfaceType = 'cortex';
            case 'SEEG',      SurfaceType = 'anatomy';
            case 'ECOG+SEEG', SurfaceType = 'cortex';
            case 'NIRS',      SurfaceType = 'scalp';
            otherwise,        SurfaceType = 'scalp';
        end
    end
    % Display surface
    if isequal(SurfaceType, 'cortex') && ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
        iSurf = panel_surface('AddSurface', hFig, sSubject.Surface(sSubject.iCortex).FileName);
    elseif isequal(SurfaceType, 'scalp') && ~isempty(sSubject.iScalp) && (sSubject.iScalp <= length(sSubject.Surface))
        iSurf = panel_surface('AddSurface', hFig, sSubject.Surface(sSubject.iScalp).FileName);
    elseif isequal(SurfaceType, 'anatomy') && ~isempty(sSubject.iAnatomy) && (sSubject.iAnatomy <= length(sSubject.Anatomy))
        iSurf = panel_surface('AddSurface', hFig, sSubject.Anatomy(sSubject.iAnatomy).FileName);
    else
        iSurf = [];
    end
    % Set surface transparency
    if ~isempty(iSurf)
        if strcmpi(SurfaceType, 'anatomy') 
            SurfAlpha = 0.1;
        elseif strcmpi(Modality, 'SEEG') 
            SurfAlpha = 0.8;
        elseif ismember(Modality, {'MEG', 'MEG GRAD', 'MEG MAG'})
            SurfAlpha = 0;
        elseif strcmpi(TopoType, '3DElectrodes')
            SurfAlpha = 0;
        elseif strcmpi(TopoType, '3DOptodes')
            SurfAlpha = 0.8;
        else 
            SurfAlpha = 0.8;
        end
        panel_surface('SetSurfaceTransparency', hFig, iSurf, SurfAlpha);
    end
end
% 2DDisc: Set white background
if strcmpi(TopoType, '2DDisc')
    bst_figures('SetBackgroundColor', hFig, [1 1 1]);
end


%% ===== UPDATE ENVIRONMENT =====
% Update 2D figure selection
bst_figures('SetCurrentFigure', hFig, '2D');
if isDisplayTab
    panel_display('UpdatePanel', hFig);
end
% Update 3D figure selection
if ismember(TopoType, {'3DSensorCap', '3DElectrodes', '3DOptodes'})
    bst_figures('SetCurrentFigure', hFig, '3D');
end
% Update TF figure selection
if strcmpi(FileType, 'Timefreq')
    bst_figures('SetCurrentFigure', hFig, 'TF');
end
% 3DElectrodes: Open tab "iEEG"
if ismember(TopoType, {'3DElectrodes','2DElectrodes'}) && ismember(Modality, {'SEEG', 'ECOG'})
    gui_brainstorm('ShowToolTab', 'iEEG');
end
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');





