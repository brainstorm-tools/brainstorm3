function [hFig, iDS, iFig] = view_erpimage( DataFiles, DisplayMode, Modality, hFig )
% VIEW_ERPIMAGE: Display an interactive image [trials x time] or [channels x time].
%
% USAGE: [hFig, iDS, iFig] = view_erpimage(DataFiles, DisplayMode='trialimage', Modality=[], hFig=[])
%
% INPUT: 
%     - DataFiles    : List of files to display
%     - DisplayMode  : {'trialimage', 'erpimage'}
%     - Modality     : Modality to display ('MEG', 'EEG', ...)
%     - hFig         : If defined, display file in existing figure
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2015-2016

global GlobalData;

% ===== PARSE INPUTS =====
% Re-use existing figure
if (nargin < 4) || isempty(hFig)
    hFig = [];
end
if (nargin < 3) || isempty(Modality)
    Modality = [];
end
% Select display mode
if (nargin < 2) || isempty(DisplayMode)
    DisplayMode = 'trialimage';
end
if ~iscell(DataFiles)
    DataFiles = {DataFiles};
    DisplayMode = 'trialimage';
end
% Progress bar
bst_progress('start', 'ERP image', 'Loading data...');
% Get file type
FileType = file_gettype(DataFiles{1});
% Are we going to create a new figure?
isNewFig = isempty(hFig) || isequal(hFig, 'NewFigure');


% ===== LOAD DATA =====
switch (FileType)
    % ===== RECORDINGS =====
    case {'data','pdata'}
        % Load data file
        iDS = bst_memory('LoadDataFile', DataFiles{1});
        if isempty(iDS)
            return;
        end
        bst_memory('LoadRecordingsMatrix', iDS);
        % Get channel indices
        iChanModality = channel_find(GlobalData.DataSet(iDS).Channel, Modality);
        iChanDisplay = iChanModality;
        % Get data
        F = bst_memory('GetRecordingsValues', iDS, iChanModality, 'UserTimeWindow');
        % Row names = channel names
        RowNames = {GlobalData.DataSet(iDS).Channel(iChanModality).Name};
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Measures.DisplayUnits;
        % Get time vector
        Time = bst_memory('GetTimeVector', iDS);
        % Get bad channels
        ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag(iChanModality);

        % ===== MONTAGE =====
        isStat = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat');
        % Montage selection
        if isNewFig
            % New time series appdata structure
            TsInfo = db_template('TsInfo');
            TsInfo.FileName    = DataFiles{1};
            TsInfo.Modality    = Modality;
            TsInfo.DisplayMode = 'image';
            % Get current montage
            sMontage = panel_montage('GetCurrentMontage', Modality);
            % Use it for this figure
            if ~isempty(sMontage) && (~isStat || strcmpi(sMontage.Type, 'selection'))
                TsInfo.MontageName = sMontage.Name;
            else
                TsInfo.MontageName = [];
            end
        else
            % Get montage from existing figure
            TsInfo = getappdata(hFig, 'TsInfo');
            % Get montage structure
            if ~isempty(TsInfo.MontageName)
                sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
            else
                sMontage = [];
            end
        end
        % If no bad channels are available: do not accept bad channels montage
        if isequal(TsInfo.MontageName, 'Bad channels') && ~any(ChannelFlag == -1)
            TsInfo.MontageName = [];
        end
        % Set bad channels to zero
        if ~isequal(TsInfo.MontageName, 'Bad channels')
            F(ChannelFlag == -1,:) = 0;
        end
        % Apply to the data
        if ~isempty(TsInfo.MontageName) && ~isempty(sMontage)
            % Get channel indices in the figure montage
            if ~isempty(strfind(sMontage.Name, 'Average reference')) || ~isempty(strfind(sMontage.Name, 'Scalp current density')) || strcmpi(sMontage.Type, 'selection')
                [iChanSel, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, RowNames);
            else
                [iChanSel, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, RowNames, ChannelFlag);
        %         % All entries are good now
        %         ChannelFlag = ones(length(iChanSel),1);
            end
            % Some channels are selected in this montage
            if ~isempty(iMatrixDisp)
                % Get display names for the input channels
                F = panel_montage('ApplyMontage', sMontage, F(iChanSel,:), GlobalData.DataSet(iDS).DataFile, iMatrixDisp, iMatrixChan);
                % Replace row names
                RowNames = sMontage.DispNames(iMatrixDisp);
                % Save channel selections for next files
                iChanDisplay = iChanDisplay(iChanSel);
            else
                TsInfo.MontageName = [];
            end
        end
        % Colormap
        switch (Modality)
            case {'MEG','MEG MAG','MEG GRAD'}
                ColormapType = 'meg';
            case {'EEG','SEEG','ECOG'}
                ColormapType = 'eeg';
            otherwise    
                ColormapType = 'eeg';
        end
        PageName = [];
        
    % ===== TIME-FREQ =====
    case {'timefreq', 'ptimefreq'}
        % Load data file
        [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', DataFiles{1});
        if isempty(iDS)
            return;
        end
        % Get data
        F = bst_memory('GetTimefreqValues', iDS, iTimefreq, Modality, [], 'UserTimeWindow');
        % Get row labels
        RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
        % Get time vector
        Time = bst_memory('GetTimeVector', iDS);
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits;
        % Colormap 
        if ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType)
            ColormapType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType;
        else
            ColormapType = 'timefreq';
        end
        iChanModality = [];
        isStat = strcmpi(FileType, 'ptimefreq');
        TsInfo = [];
        PageName = '$freq';
    
    % ===== MATRIX =====
    case 'matrix'
        % Load data file
        [iDS, iMatrix] = bst_memory('LoadMatrixFile', DataFiles{1});
        if isempty(iDS)
            return;
        end 
        % Get time vector
        Time = bst_memory('GetTimeVector', iDS);
        % Row names = channel names
        RowNames = [GlobalData.DataSet(iDS).Matrix(iMatrix).Description(:)]';
        % Read matrix file
        sMat = in_bst_matrix(DataFiles{1}, 'Value');     
        % Get Value
        F = sMat.Value; 
        % Display units
        DisplayUnits = GlobalData.DataSet(iDS).Measures.DisplayUnits;   
        % Colormap 
        ColormapType = [];
        if isNewFig
            % New time series appdata structure
            TsInfo = db_template('TsInfo');
            TsInfo.FileName    = DataFiles{1};
            TsInfo.Modality    = Modality;
            TsInfo.DisplayMode = 'image';
        else
            % Get time series appdata structure from existing figure
            TsInfo = getappdata(hFig, 'TsInfo');
        end       
        iChanModality = [];
        isStat = strcmpi(FileType, 'pmatrix');
end


% ===== BUILD CLUSTER IMAGE =====
% Switch display mode
switch lower(DisplayMode)
    case 'trialimage'
        % Create the image volume: [N1 x N2 x Ntime x Nfreq]
        F = reshape(F, size(F,1), 1, size(F,2), size(F,3));
        % Create the labels
        Labels = cell(1,4);
        Labels{1} = RowNames;
        Labels{2} = [];
        Labels{3} = Time;
        Labels{4} = [];        
        % Show the image
        [hFig, iDS, iFig] = view_image_reg(F, Labels, [1,3], {'Channels','Time (s)'}, DataFiles{1}, hFig, ColormapType, 1, PageName, DisplayUnits);
        
    case 'erpimage'
        % Create the image volume: [N1 x N2 x Ntime x Nfreq]
        ERP = zeros(length(DataFiles), 1, size(F,2), size(F,1));
        FileComments = cell(1, length(DataFiles));
%         % Copy first file
%         ERP(1,1,:,:) = F';
%         % Get comment of first file
%         DataMat = in_bst_data(DataFiles{1}, 'Comment');
%         FileComments{1} = DataMat.Comment;
        % Detailed progress bar
        bst_progress('start', 'ERP image', 'Loading data...', 1, length(DataFiles));
        % Load all the other files
        for i = 1:length(DataFiles)
            switch (FileType)
                % ===== RECORDINGS =====
                case {'data','pdata'} 
                    % Load file
                    DataMat = in_bst_data(DataFiles{i});
                    Comment = DataMat.Comment;
                    % Check the time vector and channels list (all must be of the same length)
                    if (length(DataMat.Time) ~= length(Time))
                        error('All files must have the same number of time samples.');
                    elseif (size(DataMat.F,1) ~= length(GlobalData.DataSet(iDS).Channel))
                        error('All files must have the same number of channels.');
                    end
                    % Get data matrix
                    F = DataMat.F(iChanDisplay,:);
                    % Set bad channels to zero
                    if ~isequal(TsInfo.MontageName, 'Bad channels')
                        F(DataMat.ChannelFlag(iChanDisplay) == -1,:) = 0;
                    end
                    % Apply montage to the data
                    if ~isempty(TsInfo.MontageName) && ~isempty(sMontage)
                        F = panel_montage('ApplyMontage', sMontage, F, GlobalData.DataSet(iDS).DataFile, iMatrixDisp, iMatrixChan);
                    end
                    
                % ===== MATRIX =====
                case 'matrix'
                    % Read matrix file
                    sMat = in_bst_matrix(DataFiles{i});     
                    % Get Value
                    F = sMat.Value;
                    Comment = sMat.Comment;
                    % Check the time vector and row names (all must be of the same length)
                    if (length(sMat.Time) ~= length(Time))
                        error('All files must have the same number of time samples.');
                    elseif (size(sMat.Value,1) ~= length(RowNames))
                        error('All files must have the same number of rows.');
                    end
            end                   
            % Copy recordings
            ERP(i,1,:,:) = F';
            FileComments{i} = Comment;
            % Increment progress bar
            bst_progress('inc', 1);
        end
        % Make sure all the labels are unique
        if (length(RowNames) > 1)
            for i = 1:length(RowNames)
                RowNames{i} = file_unique(RowNames{i}, [RowNames(1:i-1), RowNames(i+1:end)]);
            end
        end
        % Create the labels
        Labels = cell(1,4);
        Labels{1} = FileComments;
        Labels{2} = [];
        Labels{3} = Time;
        Labels{4} = RowNames;

%         % Set artificially the current frequency
%         gui_brainstorm('ShowToolTab', 'FreqPanel');
%         GlobalData.UserFrequencies.Freqs = RowNames';
%         GlobalData.UserFrequencies.iCurrentFreq = 1;
%         panel_freq('UpdatePanel');
        % Show the image
        [hFig, iDS, iFig] = view_image_reg(ERP, Labels, [1,3], {'Trials','Time (s)'}, DataFiles{1}, hFig, ColormapType, 1, [], DisplayUnits);
        
    otherwise
        error(['Invalid display mode: "' DisplayMode '"']);
end

% ===== APPDATA =====
% Save figure description
GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = iChanModality;
GlobalData.DataSet(iDS).Figure(iFig).Id.Modality      = Modality;
GlobalData.DataSet(iDS).Figure(iFig).Id.SubType       = DisplayMode;
% Figure Id
setappdata(hFig, 'FigureId', GlobalData.DataSet(iDS).Figure(iFig).Id);
% Stat file
if isStat
    StatInfo.StatFile    = DataFiles{1};
    StatInfo.DisplayMode = DisplayMode;
    setappdata(hFig, 'StatInfo', StatInfo);
end
% Time series
setappdata(hFig, 'TsInfo', TsInfo);
% Reload call
ReloadCall = {'view_erpimage', DataFiles, DisplayMode, Modality, hFig};
setappdata(hFig, 'ReloadCall', ReloadCall);

% ===== UPDATE GUI =====
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '2D');
% Reload "Record" panel
panel_record('UpdatePanel', hFig);
% Display the Display tab
if (length(RowNames) > 1)
    if isNewFig
        gui_brainstorm('ShowToolTab', 'Display');
    end
    panel_display('UpdatePanel', hFig);
end
% Stat panel: reload clusters list
if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
    panel_stat('CurrentFigureChanged_Callback', hFig);
end
% If this is not a new figure: force resizing for updating the size of the labels
if ~isNewFig
    figure_image('ResizeCallback', hFig);
end
% Close progress bar
bst_progress('stop');




