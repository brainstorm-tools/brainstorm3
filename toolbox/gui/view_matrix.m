function [hFig, iDS, iFig] = view_matrix( MatFile, DisplayMode, hFig )
% VIEW_MATRIX: Display a matrix file.
%
% USAGE: [hFig, iDS, iFig] = view_matrix(MatFile, DisplayMode='timeseries', hFig=[])
%
% INPUT: 
%     - MatFile     : Matrix file to display
%     - DisplayMode : {'timeseries', 'image', 'table'}
%     - hFig        : If defined, display file in existing figure
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
% Authors: Francois Tadel, 2010-2019

global GlobalData;

% ===== READ INPUTS =====
% Read matrix file
sMat = in_bst(MatFile);
% Re-use existing figure
if (nargin < 3) || isempty(hFig)
    hFig = [];
end
% Select display mode
if (nargin < 2) || isempty(DisplayMode)
    DisplayMode = 'timeseries';
end
if strcmpi(DisplayMode, 'timeseries') && isempty(sMat.Time)
    DisplayMode = 'table';
end
iDS = [];
iFig = [];


% ===== PREPARE VALUES =====
% Stat file
if strcmpi(file_gettype(MatFile), 'pmatrix')
    % Apply current stat thresholding to the values
    Value = process_extract_pthresh('Compute', sMat);
    % No standard deviation available
    Std = [];
    % Show "stat" tab
    gui_brainstorm('ShowToolTab', 'Stat');
    % Add tag in the figure appdata
    StatInfo.StatFile    = MatFile;
    StatInfo.DisplayMode = DisplayMode;
    Modality = 'stat';

% Regular matrix file
else
    % Get signals and stderr from the file
    Value = sMat.Value;
    Std   = sMat.Std;
    % Apply online filters
    if (size(Value,2) > 50) && GlobalData.VisualizationFilters.FullSourcesEnabled
        sfreq = 1 ./ (sMat.Time(2) - sMat.Time(1));
        Value = bst_memory('FilterLoadedData', Value, sfreq);
    end
    StatInfo = [];
    Modality = [];
end
% Colormap type
if isfield(sMat, 'ColormapType') && ~isempty(sMat.ColormapType)
    ColormapType = sMat.ColormapType;
else
    ColormapType = [];
end
% Display units
if isfield(sMat, 'DisplayUnits') && ~isempty(sMat.DisplayUnits)
    DisplayUnits = sMat.DisplayUnits;
else
    DisplayUnits = [];
end

% Duplicate time if only one time frame
if (size(Value,2) == 1)
    Value = [Value, Value];
    if ~isempty(Std) && (size(Std,2) == 1)
        Std = [Std, Std];
    end
end

% ===== DISPLAY =====
% Switch display mode
switch lower(DisplayMode)
    case 'timeseries'
        if iscell(Value)
            AxesLabels = sMat.Description;
            LinesLabels = [];
        else
            AxesLabels = sMat.Comment;
            LinesLabels = sMat.Description;
        end
        [hFig, iDS, iFig] = view_timeseries_matrix(MatFile, Value, [], Modality, AxesLabels, LinesLabels, [], hFig, Std, DisplayUnits);
        
    case 'image'
        % Load file
        bst_memory('LoadMatrixFile', MatFile);
        % Create the labels
        Labels = cell(1,4);
        if (size(sMat.Description,1) == size(Value,1))
            Labels{1} = sMat.Description(:,1)';
        else
            Labels{1} = 1:size(Value,1);
        end
        Labels{2} = [];
        if (size(sMat.Description,2) == size(Value,2))
            Labels{3} = sMat.Description(1,:);
        elseif (length(sMat.Time) == size(Value,2))
            Labels{3} = sMat.Time;
        else
            Labels{3} = 1:size(Value,2);
        end
        Labels{4} = [];
        % Create the dimension labels
        [tmp, MatFileName] = bst_fileparts(MatFile);
        if ~isempty(strfind(MatFileName, '_temporalgen'))
            % For temporal generalization decoding, matrix is a Time x Time
            DimLabels = {'Time (s)', 'Time (s)'};
            Labels{1} = sMat.Time;
        else
            DimLabels = {'Signals', 'Time (s)'};
        end
        % Create the image volume: [N1 x N2 x Ntime x Nfreq]
        M = reshape(Value, size(Value,1), 1, size(Value,2), 1);
        [hFig, iDS, iFig] = view_image_reg(M, Labels, [1,3], DimLabels, MatFile, hFig, ColormapType, 1, '$freq', DisplayUnits);
        % Add stat info in the file
        if ~isempty(StatInfo)
            setappdata(hFig, 'StatInfo', StatInfo);
        end
        % Save reload call
        ReloadCall = {'view_matrix', MatFile, DisplayMode, hFig};
        setappdata(hFig, 'ReloadCall', ReloadCall);
        
    case 'table'
        % Progress bar
        bst_progress('start', 'View data as table', 'Loading data...');
        % Values as cell of char verctors
        ValueCell = reshape(cellstr(num2str(Value(:))), size(Value,1), size(Value,2));
        % Define column headers
        if (size(sMat.Description,2) == size(Value,2))
            headers = sMat.Description(1,:);
            firstHeader = ' ';
        elseif (length(sMat.Time) == size(Value,2))
            headers = cellstr(num2str(sMat.Time(:)))';
            firstHeader = 'Time';
        else
            headers = [];
        end
        % Add row descriptions as first column
        isRowTitle = (size(sMat.Description,1) == size(Value,1));
        if isRowTitle
            ValueCell = cat(2, sMat.Description(:,1), ValueCell);
            if ~isempty(headers)
                headers = cat(2, firstHeader, headers);
            end
        end
        % View table
        view_table(ValueCell, headers, MatFile);
        bst_progress('stop');

    otherwise
        error('Unknown display mode.');
end
end

