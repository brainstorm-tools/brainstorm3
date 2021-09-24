function [FigData, iDS, iFig] = gui_figure_data( hFig, varargin )
% GUI_FIGURE_DATA: Retrieve the time series displayed in figure hFig.
%
% USAGE:  FigData = gui_figure_data( hFig )
%         FigData = gui_figure_data( ..., 'SelectedChannels' )
%         FigData = gui_figure_data( ..., 'SelectedTime' )
%
% INPUT:
%    - hFig : handle to a brainstorm figure
%    - 'SelectedChannels' : if some channels are highlighted in the figure, return only them
%    - 'SelectedTime'     : if a time segment is highlighted in the figure, return only this segment
% OUTPUT: 
%    - FigData : structure 

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
% Authors: Francois Tadel, 2008-2018

% === INITIALIZATIONS ===
global GlobalData;
% Parse inputs
isSelectedChannels = any(strcmpi(varargin, 'SelectedChannels'));
isSelectedTime     = any(strcmpi(varargin, 'SelectedTime'));
% Initialize save TimeSeries matrix
FigData = struct('F',          [], ...
                 'Time',       [], ...
                 'FigTitle',   get(hFig, 'Name'), ...
                 'FigType',    [], ...
                 'AxesTitle',  [], ... 
                 'AxesLegend', [], ...
                 'Events',     repmat(db_template('Event'),0));
FigData.F = {};
FigData.AxesTitle = {};
FigData.AxesLegend = {};

% === GET FIGURE INFORMATION ===
% Get figure description
[hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
% Check downsampling factor
if (Handles.DownsampleFactor > 1)
    error(['The signals were downsampled before being displayed and cannot be exported from the figure.' 10 ...
        'For continuous files: import the recordings first.' 10 ...
        'For imported time series: read directly the corresponding .mat files.' 10 ...
        'For scouts: use the proces "Extract > Scout time series".' ]);
end
% Get y-factor and offsets
Factor = Handles(1).DisplayFactor;
if isfield(Handles(1), 'ChannelOffsets')
    ChannelOffsets = Handles(1).ChannelOffsets;
else
    ChannelOffsets = [];
end
FigData.FigType = GlobalData.DataSet(iDS).Figure(iFig).Id.Type;

% === FIND CHANNELS INDICES ===
% Only valid for data time series (real channels)
if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'DataTimeSeries')
    iChannel = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    Channel = GlobalData.DataSet(iDS).Channel(iChannel);
else
    Channel = [];
end

% Find selected indices
if isSelectedTime
    timeSelection = getappdata(hFig, 'GraphSelection');
    if ~isempty(timeSelection) && ~isinf(timeSelection(2))
        selTime = [min(timeSelection), max(timeSelection)];
        % Get time vector
        if ~isempty(GlobalData.DataSet(iDS).Measures.Time)
            TimeVector = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        % If no time window defined: use the X values from the lines in axes
        elseif ~isempty(Handles(1).hLines)
            iValidLine = find(Handles(1).hLines > 0, 1);
            hLine = Handles(1).hLines(iValidLine);
            TimeVector = get(hLine, 'XData');
        else
            error('You must define a channel file to use this feature.');
        end
        % Get time indices to save
        iTimeBounds = bst_closest(selTime, TimeVector);
        iTime = iTimeBounds(1):iTimeBounds(2);
    else
        iTime = []; % Select all time indices
    end
else
    iTime = [];
end

% Process axes : one cell by axes displayed
for iAxes = 1:length(Handles)
    % === DATA ===
    % Get lines handles
    iDispChannels = find(ishandle(Handles(iAxes).hLines));
    hLines = Handles(iAxes).hLines(iDispChannels);
    % If no data in these axes => next ones
    if isempty(hLines)
        continue
    end
    
    % Keep only selected channels
    iSel = [];
    if isSelectedChannels
        % Get display width of all lines
        linesWidth = get(hLines, 'LineWidth');
        if iscell(linesWidth)
            linesWidth = [linesWidth{:}];
        end
        % Selected ones have a width > 1
        iSel = find(linesWidth > 1);
    end
    % If no channel selected: use all the channels
    if isempty(iSel)
        iSel = 1:length(hLines);
    end

    % Extract F (Y-values)
    linesY = get(hLines(iSel), 'YData');
    if iscell(linesY)
        FigData.F{iAxes} = cat(1,linesY{:});
    else
        FigData.F{iAxes} = linesY;
    end
    
    % Remove offsets
    if ~isempty(ChannelOffsets)
        chOffset = ChannelOffsets(iDispChannels(iSel));
        % Channel with negative offsets: ignore them (set them to zero)
        FigData.F{iAxes}(chOffset < 0, :) = 0;
        % Positive offsets: remove them
        iPosOffset = find(chOffset > 0);
        if ~isempty(iPosOffset)
            % Apply offsets
            FigData.F{iAxes}(iPosOffset,:) = FigData.F{iAxes}(iPosOffset,:) - repmat(chOffset, 1, size(FigData.F{iAxes},2));
        end
    end
    % Remove display factor
    FigData.F{iAxes} = FigData.F{iAxes} ./ Factor;
    % Undo the magnetometer / gradiometer scaling (CTF + Neuromag)
    if ~isempty(Channel)
        FigData.F{iAxes} = bst_scale_gradmag( FigData.F{iAxes}, Channel(iDispChannels(iSel)), 'reverse' );
    end
    
    % Keep only selected time indices
    if isSelectedTime && ~isempty(iTime)
        FigData.F{iAxes} = FigData.F{iAxes}(:,iTime);
    end
    
    % If some sensors are not displayed: recreate a full matrix
    if (length(iDispChannels) ~= length(Handles(iAxes).hLines)) && (length(iSel) == length(hLines))
        Ffull = zeros(length(Handles(iAxes).hLines), size(FigData.F{iAxes},2));
        Ffull(iDispChannels(iSel),:) = FigData.F{iAxes};
        FigData.F{iAxes} = Ffull;
    end
    
    % === COMMENTS ===
    % Get title for these axes
    FigData.AxesTitle{iAxes} = get(get(Handles(iAxes).hAxes, 'Title'), 'String');
    % Get legend of these axes (newer matlab create legend if does not exist: avoided with this test)
    if (bst_get('MatlabVersion') >= 903) && isempty(Handles(iAxes).hAxes.Legend)
        hLegend = [];
    else
        hLegend = legend(Handles(iAxes).hAxes);
    end
    if ~isempty(hLegend)
        if (bst_get('MatlabVersion') < 804)
            legendText = get(findobj(hLegend, 'type','text'), 'string');
            FigData.AxesLegend{iAxes} = bst_flip(legendText,1);
        else
            FigData.AxesLegend{iAxes} = get(hLegend, 'String');
        end
    % Legend are not accessible in the figure: need to reconstruct them
    elseif ~isempty(Channel)
        FigData.AxesLegend{iAxes} = {Channel(iDispChannels).Name};
    else
        FigData.AxesLegend{iAxes} = {};
    end
    
    % === TIME ===
    % Extract Time (X-values)
    if (iAxes == 1)
        FigData.Time = get(hLines(iSel(1)), 'XData');
        % If subselection of the time indices
        if isSelectedTime && ~isempty(iTime)
            FigData.Time = FigData.Time(iTime);
        end
    end
end
% If no data was extracted : exit
if isempty(FigData.F)
    FigData = [];
    return   
end

% ===== GET EVENTS =====
hEventsBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesEventsBar');
if (iAxes == 1) && ~isempty(hEventsBar) && ~isempty(GlobalData.DataSet(iDS).Measures.sFile) && ~isempty(GlobalData.DataSet(iDS).Measures.sFile.events)
    % Get events in current time window
    events = panel_record('GetEventsInTimeWindow', hFig);
    % Change the time vector
    FigData.Events = panel_record('ChangeTimeVector', events, 1./GlobalData.DataSet(iDS).Measures.SamplingRate, FigData.Time);
end




