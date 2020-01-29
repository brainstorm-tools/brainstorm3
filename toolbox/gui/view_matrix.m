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
        [hFig, iDS, iFig] = view_timeseries_matrix(MatFile, Value, [], [], AxesLabels, LinesLabels, [], hFig, Std);
        
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
        % Show the image
        [hFig, iDS, iFig] = view_image_reg(M, Labels, [1,3], DimLabels, MatFile, hFig, [], 1, '$freq');
        % Add stat info in the file
        if ~isempty(StatInfo)
            setappdata(hFig, 'StatInfo', StatInfo);
        end
        % Save reload call
        ReloadCall = {'view_matrix', MatFile, DisplayMode, hFig};
        setappdata(hFig, 'ReloadCall', ReloadCall);
        
    case 'table'
        ViewTable(Value, sMat.Description, sMat.Time, MatFile);
        
    otherwise
        error('Unknown display mode.');
end
end


%% ===== VIEW TABLE =====
function ViewTable(Data, Description, Time, wndTitle)
    import java.awt.*;
    import javax.swing.*;
    import javax.swing.table.*;
    import org.brainstorm.icon.*;
    % Progress bar
    bst_progress('start', 'View data as table', 'Loading data...');
    % Create figure
    jFrame = java_create('javax.swing.JFrame', 'Ljava.lang.String;', wndTitle);
    % Set icon
    jFrame.setIconImage(IconLoader.ICON_APP.getImage());
    % Create cell matrix of strings to display
    rows = reshape(cellstr(num2str(Data(:))), size(Data,1), size(Data,2));
    % Define column headers 
    if (size(Description,2) == size(Data,2))
        colTitle = Description(1,:);
        firstCol = ' ';
    elseif (length(Time) == size(Data,2))
        colTitle = cellstr(num2str(Time(:)))';
        firstCol = 'Time';
    else
        colTitle = [];
    end
    % Add row descriptions
    isRowTitle = (size(Description,1) == size(Data,1));
    if isRowTitle
        rows = cat(2, Description(:,1), rows);
        if ~isempty(colTitle)
            colTitle = cat(2, firstCol, colTitle);
        end
    end
    % Create tabel model
    model = DefaultTableModel(size(rows,1), size(rows,2));
    for i = 1:size(rows)
        model.insertRow(i-1, rows(i,:));
    end
    % Create table
    jTable = JTable(model);
    jTable.setEnabled(0);
    jTable.setAutoResizeMode( JTable.AUTO_RESIZE_OFF );
    jTable.getTableHeader.setReorderingAllowed(0);
    % Set columns titles
    for iCol = 1:length(colTitle)
        % jTable.getColumnModel().getColumn(iCol-1).setPreferredWidth(50);
        jTable.getColumnModel().getColumn(iCol-1).setHeaderValue(colTitle{iCol});
    end
    % Create scroll panel
    jScroll = JScrollPane(jTable);
    jScroll.setBorder([]);
    jFrame.getContentPane.add(jScroll, BorderLayout.CENTER);
    % Show window
    jFrame.pack();
    jFrame.show();
    bst_progress('stop');
end   



