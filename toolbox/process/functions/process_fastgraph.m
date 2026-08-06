function varargout = process_fastgraph( varargin )
% PROCESS_FASTGRAPH: Plot FastGraph for one or more SEEG recordings.
% For each stimulation pair, channels are split by hemisphere, sorted 
% by a user-selected metric, filtered by atlas region or scout label, and 
% plotted as stacked area plots
%
% USAGE:
%   OutputFiles = process_fastgraph('Run', sProcess, sInputs)

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
% Authors: Kenneth N. Taylor, 2020
%          John C. Mosher, 2020          
%          Chinmay Chinara, 2026

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Describe the process and its UI options
sProcess.Comment     = 'Plot FastGraphs';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'FastGraph';
sProcess.Index       = 1303;
sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/FastGraph';
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Scouts to use for plotting FastGraph
sProcess.options.scouts.Comment = '';
sProcess.options.scouts.Type    = 'scout';
sProcess.options.scouts.Value   = {};
% Color FastGraph by Region or by Scout
sProcess.options.colorscheme.Comment    = {'Region', 'Scout', 'Color scheme:&nbsp;&nbsp;'; ...
                                           'region', 'scout', ''};
sProcess.options.colorscheme.Type       = 'radio_linelabel';
sProcess.options.colorscheme.Value      = 'region';
sProcess.options.colorscheme.Controller = struct('region', 'region');
% Select regions to include
regionsStr = {'Prefrontal (PF)', 'Frontal (F)', 'Central (C)', 'Parietal (P)', 'Temporal (T)', 'Occipital (O)', 'Limbic (L)'};
sProcess.options.region.Comment = [regionsStr, {'<HTML><B>Select regions to include:</B>'}];
sProcess.options.region.Type    = 'list_horizontal';
sProcess.options.region.Value   = regionsStr;
sProcess.options.region.Class   = 'region';
% Method for sorting the data
sProcess.options.label1.Comment     = '<B>Method for sorting data:<B>';
sProcess.options.label1.Type        = 'label';
sProcess.options.sortmethod.Comment = {'Root Mean Square', 'Max Absolute'; 'rms', 'maxabs'};
sProcess.options.sortmethod.Type    = 'radio_label';
sProcess.options.sortmethod.Value   = 'rms';
% Sort window
sProcess.options.sortwindow.Comment = 'Time window to sort data: ';
sProcess.options.sortwindow.Type    = 'timewindow';
sProcess.options.sortwindow.Value   = {[], 'ms', []};
sProcess.options.label2.Comment     = ['<I><FONT color="#777777">' ...
                                       'Examples:<BR>'...
                                       'Early latency: 0-60 ms,<BR>' ...
                                       'Middle latency: 60-250 ms, or<BR>' ...
                                       'Late latency:   250-600 ms</FONT></I>'];
sProcess.options.label2.Type        = 'label';
% Exclude contacts within a certain distance from the stimulation sites
sProcess.options.excluderadius.Comment = 'Exclusion zone radius:<BR>';
sProcess.options.excluderadius.Type    = 'value';
sProcess.options.excluderadius.Value   = {20,'mm', 0};
sProcess.options.label3.Comment        = ['<I><FONT color="#777777">' ...
                                          'Exclude contacts within this distance ' ...
                                          'from the stimulation site</FONT></I>'];
sProcess.options.label3.Type           = 'label';
sProcess.options.separator1.Type    = 'separator';
% Plot window
sProcess.options.plotwindow.Comment = 'Plot time range: ';
sProcess.options.plotwindow.Type    = 'timewindow';
sProcess.options.plotwindow.Value   = {[], 'ms', []};
% Edge transparency of plot
sProcess.options.edgealpha.Comment = 'Edge transparency of plot: ';
sProcess.options.edgealpha.Type    = 'value';
sProcess.options.edgealpha.Value   = {0.05,' ', 2};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== GET OPTIONS =====
function OPTIONS = GetOptions(sProcess)
    OPTIONS = struct();
    % Atlas and scouts to use for plotting FastGraph
    OPTIONS.Atlas = sProcess.options.scouts.Value{1,1};
    OPTIONS.AtlasScoutLabels = sProcess.options.scouts.Value{1,2};
    % Color figure by region or by label
    OPTIONS.ColorScheme = sProcess.options.colorscheme.Value;
    % Select regions to include
    OPTIONS.Region = sProcess.options.region.Value;
    % Method for sorting the data   
    OPTIONS.SortMethod = sProcess.options.sortmethod.Value;
    % Time window for sorting the data [s]
    if isfield(sProcess.options, 'sortwindow') && isfield(sProcess.options.sortwindow, 'Value') && iscell(sProcess.options.sortwindow.Value) && ~isempty(sProcess.options.sortwindow.Value)
        OPTIONS.SortWindow = sProcess.options.sortwindow.Value{1};
    else
        OPTIONS.SortWindow = [];
    end
    % Exclude contacts within a certain distance of stimulation sites
    OPTIONS.ExcludeRadius = sProcess.options.excluderadius.Value{1};
    % Time window for plotting [s]
    if isfield(sProcess.options, 'plotwindow') && isfield(sProcess.options.plotwindow, 'Value') && iscell(sProcess.options.plotwindow.Value) && ~isempty(sProcess.options.plotwindow.Value)
        OPTIONS.PlotWindow = sProcess.options.plotwindow.Value{1};
    else
        OPTIONS.PlotWindow = [];
    end
    % Edge transparency for plotting
    OPTIONS.EdgeAlpha = sProcess.options.edgealpha.Value{1};    
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>    
    % Initialize output
    OutputFiles = {};
    % Get options
    OPTIONS = GetOptions(sProcess);
    
    % ===== Check regions for 'region' color scheme =====
    if strcmpi(OPTIONS.ColorScheme, 'region') && isempty(OPTIONS.Region)
        bst_report('Error', sProcess, [], 'No region selected. Select at least one region to run the analysis.');
        return;
    end

    % ===== Check that all input files use the same channel file =====
    ChannelFiles = {sInputs.ChannelFile};
    if length(unique(ChannelFiles)) > 1
        bst_report('Error', sProcess, sInputs, 'All input files must use the same channel file.');
        return;
    end

    % ===== Check that every comment contains a bipolar channel name =====
    % Extract bipolar channel pairs from all comments
    bipolarPattern = '([A-Za-z]+''?\d+)\s*-\s*([A-Za-z]+''?\d+)';
    bipolarChannels = regexp({sInputs.Comment}, bipolarPattern, 'tokens', 'once');
    % Check that every comment contains a bipolar pair
    isBipolar = ~cellfun(@isempty, bipolarChannels);
    if ~all(isBipolar)
        iInvalid = find(~isBipolar);    
        bst_report('Error', sProcess, sInputs(iInvalid), ...
                   sprintf('Could not find a bipolar channel name in the file comment: "%s".\n', sInputs(iInvalid).Comment));
        return;
    end

    % ===== Check channels for bipolar channels are valid channel names =====
    % Load the channel file
    ChannelMat = in_bst_channel(ChannelFiles{1});
    channelNames = {ChannelMat.Channel.Name};
    % Flatten all extracted pairs
    allBipolarChannels = [bipolarChannels{:}];
    % Check whether all extracted channel names exist
    isChannelFound = ismember(allBipolarChannels, channelNames);
    if ~all(isChannelFound)
        missingChannels = unique(allBipolarChannels(~isChannelFound), 'stable');    
        bst_report('Error', sProcess, sInputs, ...
                   sprintf('The following channels were not found in the channel file: %s.', strjoin(missingChannels, ', ')));
        return;
    end

    % === Sort SEEG contacts and Stimulus by location
    % Sort ONLY SEEG Contacts using Location or Group name into Left | Right groups
    sContactLocIdxs = SortSeegContacts(ChannelMat);
    % Sort stimulus location from each Input into Left | Right groups, Anterior->Posterior within group
    stimLocs = GetStimLocs(sInputs, ChannelMat);
    sStimLocIdxs = SortLAPRAP(stimLocs);
    % Sort Inputs and StimLocs by their Stimulus location: I.e. SubPlot order
    sInputs  = sInputs(sStimLocIdxs.All);
    stimLocs = stimLocs(sStimLocIdxs.All, :);

    % === Anatomical labels for SEEG contacts
    [~, chanTableWithAtlas] = export_channel_atlas(ChannelFiles{1}, 'SEEG', [], 5, 0, 0, OPTIONS.Atlas);
    % Locate atlas related columns from channel table above
    hit = cellfun(@(x) ischar(x) && (~isempty(strfind(OPTIONS.Atlas, x)) || ~isempty(strfind(x, OPTIONS.Atlas))), chanTableWithAtlas(1,:));
    % Columns whose header matches the atlas name
    cols = find(any(hit, 1));
    % Extract SEEG channel names and their atlas scout labels
    chanNamesSeeg = chanTableWithAtlas(2:end, 1);
    atlasScoutLabelsSeeg = chanTableWithAtlas(2:end, cols);

    % ===== Create figure for FastGraph =====
    hFig = figure;
    hFig.Visible = 'off';
    % Maximize figure
    set(gcf, 'Position', get(0,'Screensize'));
    % Reserve one extra subplot for the legend (brain surface with Scouts)
    nFastGraphs = length(sInputs);
    hFastGraphAxes = gobjects(nFastGraphs, 0);
    % Subplot grid dimensions
    nCols = ceil(sqrt(nFastGraphs+1));
    nRows = ceil((nFastGraphs+1) / nCols);
    % Subplot spacing and margins
    gap = [0.075 0.0175];
    horzMargin = 0.03;
    vertMargin = 0.015;

    % ===== Get data and Plot each FastGraph and  =====
    bst_progress('start', 'Process', 'Plotting FastGraphs...', 0, 100);
    for iFastGraph = 1:nFastGraphs
        sInput  = sInputs(iFastGraph);
        stimLoc = stimLocs(iFastGraph, :);

        % Show progress
        bst_progress('set', round(100 .* (iFastGraph-1) ./ nFastGraphs));
        fprintf('\n===== FastGraph %d/%d:  Stimulation file "%s" =====\n', iFastGraph, nFastGraphs, sInput.Comment);

        % Load ONLY SEEG recordings
        [seegData, excludedContacts] = GetSeegData(sInput, stimLoc, ChannelMat, OPTIONS);
        % Data to be plotted for the current subplot
        subplotData = struct();
        % Separate L and R hemisphere data
        subplotData.leftData  = seegData.F(sContactLocIdxs.Left,:);
        subplotData.rightData = seegData.F(sContactLocIdxs.Right,:);
        % Sort channels within each hemisphere using the selected metric and time window
        sSubplotDataSorted = ApplyDataSorting(subplotData, seegData, OPTIONS);

        % Create the subplot with custom spacing 
        hFastGraphAxes(iFastGraph) = subtightplot(nRows, nCols, iFastGraph, gap, horzMargin, vertMargin);
        % Plot the FastGraph for the current stimulation pair
        [hLeftAreaPLot, hRightAreaPLot] = PlotFastgraph(sInput, stimLoc, subplotData, sSubplotDataSorted, seegData, excludedContacts, sContactLocIdxs, chanNamesSeeg, atlasScoutLabelsSeeg, OPTIONS);
        % Apply edge transparency to the subplot
        set(hLeftAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        set(hRightAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        % Add the stimulation pair and atlas scout label as the subplot title
        AddFastgraphTitle(sInput, chanNamesSeeg, atlasScoutLabelsSeeg);
    end

    % === Common feature on FastGraph plots ===
    % Set limits for axes before linking for improved performance
    xlim(hFastGraphAxes, [seegData.Time(1), seegData.Time(end)]*1000);
    ylims = ylim(hFastGraphAxes);
    ylims = cat(1,ylims{:});
    ylim(hFastGraphAxes, [min(ylims(:,1)), max(ylims(:,2))]);
    linkaxes(hFastGraphAxes, 'xy');
    % Set axis labels
    xlabel(hFastGraphAxes, 'Time (ms)');
    ylabel(hFastGraphAxes, 'Voltage (mV)');
    % Line and label to distinguish hemispheres
    SetHemisphereLabels(hFastGraphAxes);

    % === Plot brain legend ===
    bst_progress('set', 100);
    bst_progress('text', 'Plotting legend...');
    % Generate a cortex snapshot with atlas scout for display
    imgCortex = GenerateCortexSnapshot(sInputs, OPTIONS);
    % Create the legend subplot with the same spacing settings
    axBrain = subtightplot(nRows, nCols, nRows*nCols, gap, horzMargin, vertMargin);
    % Plot the reference panel with the cortex snapshot and axis labels
    PlotLegend(axBrain, imgCortex, round(hFastGraphAxes(1).XLim), hFastGraphAxes(1).YLim);
    % Close progress
    bst_progress('stop');

    % Show figure
    hFig.Visible = 'on';
end

%% ===== GET STIMULATION SITE CONTACT LOCATION =====
% Get the midpoint location of each stimulation pair in Comment
function stimLocs = GetStimLocs(sInputs, ChannelMat)
    % Preallocate one [x y z] SCS midpoint per stimulation pair
    stimLocs = zeros(numel(sInputs), 3);
    % Get channel names once for lookup
    chanNames = {ChannelMat.Channel.Name};

    % Loop over all stimulation entries
    for k = 1:numel(sInputs)
        % Split the comment into the two parts
        parts = strsplit(sInputs(k).Comment, '-');
        if numel(parts) ~= 2
            continue;
        end
        % Get the contact names
        contact1Parts = strsplit(parts{1}, ' ');
        contact2Parts = strsplit(parts{2}, ' ');
        contact1 = contact1Parts{end};
        contact2 = contact2Parts{1};
        % Find the channel indices
        iContact1 = find(strcmp(chanNames, contact1), 1);
        iContact2 = find(strcmp(chanNames, contact2), 1);
        % Compute midpoint only if both contacts exist
        if ~isempty(iContact1) && ~isempty(iContact2)
            loc1 = ChannelMat.Channel(iContact1).Loc(:)';
            loc2 = ChannelMat.Channel(iContact2).Loc(:)';
            stimLocs(k, :) = (loc1 + loc2) / 2;
        end
    end
end

%% ===== LAPRAP STYLE LOCATION SORTING =====
% Get indices of location sorted in (L)eft side (A)nterior to (P)osterior (LAP), 
% then (R)ight side (A)nterior to (P)osterior (RAP) style given the contact locations
% 
% Contacts are first separated into left and right hemispheres using the
% y coordinate (left:  y >= 0, right: y < 0). Within each hemisphere, contacts 
% are ordered by x-coordinate in descending order.
%
% Repeated locations (when there are multiple recordings from the same stimulation site)
% are handled safely by using the original row index as a secondary sorting key. 
% This keeps identical locations grouped together while preserving their original input order.
%
% Contacts exactly on the midline (y == 0) are assigned to the left hemisphere.
function sSortedLocIdxs = SortLAPRAP(contactLocs)
    % Initialize output structure
    sSortedLocIdxs = struct('Left', [], 'Right', [], 'All', []);
    % Original row index of each location
    contactIdxs = (1:size(contactLocs, 1))';
    % Append original row indices so duplicate coordinates keep input order
    contactLocsWithIdx = [contactLocs, contactIdxs];
    % Identify contacts in the left and right hemispheres
    isLeftHemisphere = contactLocsWithIdx(:, 2) >= 0;
    isRightHemisphere = ~isLeftHemisphere;
    % Extract contact locations for each hemisphere
    leftContactLocs = contactLocsWithIdx(isLeftHemisphere, :);
    rightContactLocs = contactLocsWithIdx(isRightHemisphere, :);
    % Sort left and right hemisphere contacts by x-coordinate in descending order (-xCoordColumn). 
    % Use original index (idxColumn) as a secondary key so repeated locations remain grouped 
    % and keep their original input order. Store sorted original indices for each hemisphere
    xCoordColumn = 1;
    idxColumn    = 4;
    if ~isempty(leftContactLocs)
        leftContactLocs = sortrows(leftContactLocs, [xCoordColumn, idxColumn], {'descend' 'ascend'});
        sSortedLocIdxs.Left = leftContactLocs(:, 4)';
    end
    if ~isempty(rightContactLocs)
        rightContactLocs = sortrows(rightContactLocs, [xCoordColumn, idxColumn], {'descend' 'ascend'});
        sSortedLocIdxs.Right = rightContactLocs(:, 4)';
    end
    % Combined sorted indices
    sSortedLocIdxs.All = [sSortedLocIdxs.Left, sSortedLocIdxs.Right];
end

%% ===== LOAD AND FILTER SEEG DATA =====
% Load each selected SEEG block and optionally exclude contacts based on
% distance from the stimulation site
function [seegData, excludedContacts] = GetSeegData(sInput, stimLoc, ChannelMat, OPTIONS)
    % Get index of SEEG channel types
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
    % Load current file
    allData = load(file_fullpath(sInput.FileName));
    % Set data from bad channels to NaN
    allData.F(allData.ChannelFlag<0, :) = NaN;
    % Keep only data from SEEG
    seegData.F = allData.F(iSeeg, :);
    seegData.Time = allData.Time;
    if all(stimLoc ~= 0)
        % Compute distance [mm] from stimulation site to each SEEG contact (mm)
        contactLocs = cat(2, [ChannelMat.Channel(iSeeg).Loc])';
        contactDist = sqrt(sum((contactLocs - repmat(stimLoc, length(iSeeg), 1)).^2, 2)) * 1000;
        % Exclude stimulation contacts themselves
        iStimContacts = (contactDist >= 0) & (contactDist <= 2);
        % Exclude contacts within user-provided distance from the stimulation sites
        iExcluded = (contactDist > 2) & (contactDist <= OPTIONS.ExcludeRadius);
        % Keep only valid SEEG contacts
        validContacts = ~iExcluded & ~iStimContacts;
        excludedContacts = ~validContacts;
        % Report excluded contacts
        fprintf('Contacts excluded for being at the stimulation location ( <= 2 mm):\n');
        fprintf('%s  ', ChannelMat.Channel(iSeeg(iStimContacts)).Name);
        fprintf('\n');
        fprintf('Contacts excluded for being within the %d mm exclusion zone:\n', OPTIONS.ExcludeRadius);
        fprintf('%s  ', ChannelMat.Channel(iSeeg(iExcluded)).Name);
        fprintf('\n');
        % Set data from excluded channels to NaN
        seegData.F(excludedContacts, :) = NaN;
    else
        % If no stimulation locations are available, keep only SEEG channels
        excludedContacts = ~iSeeg;
    end
end

%% ===== SORT CONTACTS INTO LEFT/RIGHT HEMISPHERE =====
% Sort SEEG contacts into left and right hemisphere groups
function sContactGroupLocIdxs = SortSeegContacts(ChannelMat)
    % Get index of SEEG channel type
    iSeegs = channel_find(ChannelMat.Channel, 'SEEG');
    % For each SEEG Concact, if no valid location, add temporary Loc based on the Group Name
    for ix = 1 : iSeegs
        iSeeg = iSeegs(ix);
        if isempty(ChannelMat.Channel(iSeeg).Loc) || all(ChannelMat.Channel(iSeeg).Loc == 0) || any(isnan(ChannelMat.Channel(iSeeg).Loc))            
            % SEEG groups in Left hemisphere end with an apostrophe
            if strcmp(ChannelMat.Channel(iSeeg).Group(end), '''')
                ChannelMat.Channel(iSeeg).Loc = [ 1; 0; 0]; % Left hemisphere in SCS
            else
                ChannelMat.Channel(iSeeg).Loc = [-1; 0; 0]; % Right hemisphere in SCS
            end
        end
    end
    % Store SEEG contact coordinates
    contactLocs = cat(2, [ChannelMat.Channel(iSeegs).Loc])';
    % Use coordinates to split contacts by hemisphere
    sContactGroupLocIdxs = SortLAPRAP(contactLocs);
end

%% ===== WITHIN-HEMISPHERE DATA SORTING =====
% Sort left and right hemisphere channel data within a selected time
% window using either RMS amplitude or maximum absolute amplitude
function sSorted = ApplyDataSorting(subplotData, seegData, OPTIONS)
    % Initialize output structure
    sSorted = struct();
    % Get sample indices used for sorting
    if isempty(OPTIONS.SortWindow)
        sortWindowIdx = 1:size(seegData.F,2);
    else
        sortWindowIdx = bst_closest(OPTIONS.SortWindow, seegData.Time);
        sortWindowIdx = [sortWindowIdx(1):sortWindowIdx(2)];
    end
    % Sort channels within each hemisphere using the selected metric
    switch lower(OPTIONS.SortMethod)
        case 'rms'
            if ~isempty(subplotData.leftData)
                leftDataRms = sqrt(sum(subplotData.leftData(:,sortWindowIdx).^2, 2));
                leftDataRms(isnan(leftDataRms)) = -Inf;
                [sSorted.Vals.Left, sSorted.Idxs.Left] = sort(leftDataRms,'ascend');
            end
            if ~isempty(subplotData.rightData) 
                rightDataRms = sqrt(sum(subplotData.rightData(:,sortWindowIdx).^2, 2));
                rightDataRms(isnan(rightDataRms)) = -Inf;
                [sSorted.Vals.Right, sSorted.Idxs.Right] = sort(rightDataRms,'ascend');
            end        
        case 'maxabs'
            if ~isempty(subplotData.leftData)
                leftDataMax = max(abs(subplotData.leftData(:,sortWindowIdx)),[],2);
                leftDataMax(isnan(leftDataMax)) = -Inf;
                [sSorted.Vals.Left, sSorted.Idxs.Left] = sort(leftDataMax,1,'ascend');
            end
            if ~isempty(subplotData.rightData)
                rightDataMax = max(abs(subplotData.rightData(:,sortWindowIdx)),[],2);
                rightDataMax(isnan(rightDataMax)) = -Inf;
                [sSorted.Vals.Right, sSorted.Idxs.Right] = sort(rightDataMax,1,'ascend');
            end
    end
end

%% ===== PLOT FASTGRAPH =====
% Create one FastGraph subplot.
% Left-hemisphere SEEG channels are plotted as positive stacked areas
% Right-hemisphere SEEG channels are plotted as negative stacked areas
function [hLeftAreaPlot, hRightAreaPlot] = PlotFastgraph(sInput, stimLoc, subplotData, sSubplotDataSorted, seegData, excludedContacts, sContactGroupLocIdxs, chanNamesSeeg, atlasScoutLabelsSeeg, OPTIONS)
    % Initialize output handles
    hLeftAreaPlot  = [];
    hRightAreaPlot = [];
    
    % Get cortex to be used for region/color lookup
    sSubject = bst_get('Subject', sInput.SubjectName);
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    sCortex = bst_memory('LoadSurface', CortexFile);
    % Resolve selected scouts
    selectedScoutLabels = ResolveScoutSelection(sCortex, OPTIONS);
    % Check whether stimulation location is available
    hasStimLocs = any(stimLoc);

    % Select the time samples to display
    if isempty(OPTIONS.PlotWindow)
        plotWindowIdx = 1:size(seegData.F,2);
    else
        plotWindowIdx = bst_closest(OPTIONS.PlotWindow, seegData.Time);
        plotWindowIdx = [plotWindowIdx(1):plotWindowIdx(2)];
    end
    timeMs = seegData.Time(plotWindowIdx) * 1000;

    % Loop over left and right hemispheres
    for iSide = 1:2
        if iSide == 1
            % Left hemisphere settings
            if isempty(subplotData.leftData)
                continue;
            end
            sideName     = 'Left';
            groupLocIdxs = sContactGroupLocIdxs.Left;
            sortedIdxs   = sSubplotDataSorted.Idxs.Left;
            signFactor   = 1;
        else
            % Right hemisphere settings
            if isempty(subplotData.rightData)
                continue;
            end
            sideName     = 'Right';
            groupLocIdxs = sContactGroupLocIdxs.Right;
            sortedIdxs   = sSubplotDataSorted.Idxs.Right;
            signFactor   = -1;
        end

        % Reorder SEEG channels for the current hemisphere
        contactIdxs = groupLocIdxs(sortedIdxs);
        hemiData    = abs(seegData.F(contactIdxs, :));
        % Get atlas scout labels for these channels
        channelScoutLabels = cell(1, numel(contactIdxs));
        for i = 1:numel(contactIdxs)
            channelScoutLabels{i} = atlasScoutLabelsSeeg{contactIdxs(i)};
        end
        % Filter channels using resolved scout selection
        if hasStimLocs
            toPlot = ismember(channelScoutLabels, selectedScoutLabels);
        else
            toPlot = true(1, numel(contactIdxs));
        end
        % Keep track of number of channel before filtering 
        nChannelsBeforeFilter = numel(contactIdxs);
        % Keep only channels that pass the filters
        contactIdxs = contactIdxs(toPlot);
        hemiData = hemiData(toPlot, :);
        channelScoutLabels = channelScoutLabels(toPlot);

        % Skip plotting if no channels remain after atlas/scout filtering
        fprintf('\n%s contacts and atlas scout labels:\n', sideName);
        if isempty(contactIdxs)
            if nChannelsBeforeFilter > 0
                fprintf('Nothing to plot. All contacts were filtered out by the selected atlas/scout regions.\n');
            else
                fprintf('Nothing to plot. No contacts are available for this hemisphere.\n');
            end
            continue;
        end

        % Plot stacked area traces for the current hemisphere
        hAreaPlot = area(timeMs, signFactor * hemiData(:, plotWindowIdx)');

        % Print labels and assign colors
        strMaxLen = max(cellfun(@length, chanNamesSeeg));
        isAllContactsExcluded = 1;
        for i = 1:numel(contactIdxs)
            atlasScoutLabelSeeg = channelScoutLabels{i};
            if ~excludedContacts(contactIdxs(i))
                fprintf('%-*s - %s\n', strMaxLen, chanNamesSeeg{contactIdxs(i)}, atlasScoutLabelSeeg);
                isAllContactsExcluded = 0;
            end
            region = GetRegionFromScouts(sCortex, atlasScoutLabelSeeg, OPTIONS);
            hAreaPlot(i).FaceColor = region.Color;
        end
        if isAllContactsExcluded
            fprintf('Nothing plotted. All contacts lie within the stimulation-site exclusion zone.\n');
        end
        % Store handles in the correct output variable
        if iSide == 1
            hLeftAreaPlot = hAreaPlot;
            % Keep current plot so right side plot can be added
            hold on;
        else
            hRightAreaPlot = hAreaPlot;
            % Release the hold state after plotting both sides
            hold off;
        end
    end
    fprintf('\n');
end

%% ===== ATLAS REGION FROM SCOUTS =====
% Map an atlas scout label to a Brainstorm region code and plot color
function region = GetRegionFromScouts(sCortex, inputAtlasScoutLabel, OPTIONS)
    % Default output if no matching scout is found
    region.Name  = '?';
    region.Color = [0.5 0.5 0.5];
    % Find the atlas selected by the user
    iAtlas = find(strcmpi({sCortex.Atlas.Name}, OPTIONS.Atlas), 1);
    if isempty(iAtlas)
        return;
    end
    % Get the selected atlas
    atlas = sCortex.Atlas(iAtlas);
    % Match the input atlas scout label against atlas scouts
    for iScout = 1:numel(atlas.Scouts)
        atlasScoutLabel = atlas.Scouts(iScout).Label(1:end-2);
        if ~isempty(strfind(lower(inputAtlasScoutLabel), lower(atlasScoutLabel)))
            % Matching scout found: assign region name
            region.Name = atlas.Scouts(iScout).Region(2:end);
            % Assign color based on the selected color scheme
            switch lower(OPTIONS.ColorScheme)
                case 'region'
                    region.Color = panel_scout('GetRegionColor', atlas.Scouts(iScout).Region);
                case 'scout'
                    region.Color = atlas.Scouts(iScout).Color;
            end
            return;
        end
    end
end

%% ===== FASTGRAPH TITLE =====
% Build the title shown above each subplot using the stimulation pair and
% the atlas label associated with the first contact
function AddFastgraphTitle(sInput, chanNamesSeeg, atlasScoutLabelsSeeg)
    % Split the comment into the two parts
    parts = strsplit(sInput.Comment, '-');
    % Clean extracted comment
    contact1 = strtrim(parts{1});
    % Get the contact names
    contact1Parts = strsplit(contact1);
    contact1 = contact1Parts{end};
    % Look up atlas label for the first contact
    iContact1 = find(strcmp(chanNamesSeeg, contact1), 1);
    if ~isempty(iContact1)
        contact1AtlasScoutLabel = atlasScoutLabelsSeeg{iContact1};
    else
        contact1AtlasScoutLabel = '?';
    end
    title(sprintf('%s\n%s', sInput.Comment, contact1AtlasScoutLabel),'fontsize', 8);
end

%% ===== RESOLVE SELECTED SCOUTS =====
% Resolve which atlas scouts should be used based on either:
%   1) explicit scout labels selected by the user, or
%   2) selected anatomical regions from the checkboxes
function [selectedScoutLabels, iSelectedScouts, iAtlas] = ResolveScoutSelection(sCortex, OPTIONS)
    % Default outputs
    selectedScoutLabels = {};
    iSelectedScouts     = [];
    iAtlas              = [];
    % Find selected atlas
    iAtlas = find(strcmpi({sCortex.Atlas.Name}, OPTIONS.Atlas), 1);
    if isempty(iAtlas)
        return;
    end
    atlas = sCortex.Atlas(iAtlas);
    if ~isempty(OPTIONS.AtlasScoutLabels)
        % Explicit scout-label filtering
        isKeep = ismember({atlas.Scouts.Label}, OPTIONS.AtlasScoutLabels);
    else
        % Region-based filtering
        selectedRegions = regexprep(OPTIONS.Region, '^.*\((.*?)\).*$', '$1');
        % Remove the leading character from Brainstorm scout region code
        scoutRegions = cellfun(@(x) x(2:end), {atlas.Scouts.Region}, 'UniformOutput', false);
        isKeep = ismember(scoutRegions, selectedRegions);
    end
    % Return selected scout indices and labels
    iSelectedScouts = find(isKeep);
    selectedScoutLabels = {atlas.Scouts(iSelectedScouts).Label};
end

%% ===== GENERATE IMAGE FOR LEGEND =====
% Render the cortex surface with only the scouts selected from the GUI and
% color them either by region or by label
function imgCortex = GenerateCortexSnapshot(sInputs, OPTIONS)
    % Default output
    imgCortex = [];
    % Load cortex
    sSubject = bst_get('Subject', sInputs(1).SubjectName);
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    sCortex = bst_memory('LoadSurface', CortexFile);
    % Resolve selected scouts from GUI options
    [~, iSelectedScouts, iAtlas] = ResolveScoutSelection(sCortex, OPTIONS);
    if isempty(iAtlas) || isempty(iSelectedScouts)
        return;
    end
    % Open cortex figure
    hFigSurf = view_surface(CortexFile);
    figure_3d('SetStandardView', hFigSurf, 'left');
    bst_figures('SetBackgroundColor', hFigSurf, [1 1 1]);
    % Select atlas
    panel_scout('SetCurrentAtlas', iAtlas);    
    % Color scouts by region or individual label
    isRegionColor = strcmpi(OPTIONS.ColorScheme, 'region');
    panel_scout('SetScoutsOptions', 0, 0, 1, 'select', 0, 1, 0, isRegionColor);
    % Show only selected scouts
    panel_scout('SetSelectedScouts', iSelectedScouts);
    % Set background color
    bst_figures('SetBackgroundColor', hFigSurf, [1 1 1]);
    % Capture and crop the cortex image
    img = out_figure_image(hFigSurf);
    isBackground = all(img == 255, 3);
    imgCortex = img(any(~isBackground, 2), any(~isBackground, 1), :);
    % Close figure
    close(hFigSurf);
end

%% ===== PLOT LEGEND =====
% Show the reference cortex image using the same axes layout as the plots
function PlotLegend(axLegend, brainImg, xLim, yLim)
    % Configure legend axes
    set(axLegend, ...
        'XLim', xLim, ...
        'YLim', yLim, ...
        'XAxisLocation', 'bottom');
    axLegend.XLabel.String = 'Time (ms)';
    axLegend.YLabel.String = 'Voltage (mV)';
    % Create overlay axes for the cortex image
    hFig = ancestor(axLegend, 'figure');
    axImg = axes('Parent', hFig, 'Units', 'pixels', 'Color', 'none');
    imshow(brainImg, 'Parent', axImg);
    axis(axImg, 'off');
    axis(axLegend, 'manual');
    % Position the image initially and after resizing
    UpdateLegendImage(axLegend, axImg, brainImg);
    hFig.SizeChangedFcn = @(~,~) UpdateLegendImage(axLegend, axImg, brainImg);
end

%% ===== DECORATE FASTGRAPH AXES =====
% Add the zero-reference line and L/R hemisphere labels
function SetHemisphereLabels(hFastGraphAxes)
    % Positions for elements, assumes all hFastGraphAxes have the same XY Limits
    XLim = hFastGraphAxes(1).XLim;
    YLim = hFastGraphAxes(1).YLim;
    xPositionText = XLim(1) + (0.95 * diff(XLim));
    yPositionText = min(abs(YLim)) * 0.15;
    % Add 0 mV line and labels for L and R hemispheres
    for hAxes = hFastGraphAxes
        line(hAxes, XLim, [0 0], ...
            'Color',      [0 0 0], ...
            'LineWidth',  0.5);
        textProperties = { ...
            'Parent',     hAxes, ...
            'FontSize',   14, ...
            'FontWeight', 'bold'};
            % Place text L/R above and below 0 mV line
            text(xPositionText,  yPositionText, 'L', textProperties{:});
            text(xPositionText, -yPositionText, 'R', textProperties{:});
    end
end


%% ===== UPDATE LEGEND IMAGE =====
% Update the overlay image position so it stays centered inside the
% legend subplot when the figure is resized or moved across screens
function UpdateLegendImage(axSubplotLegend, axImg, brainImg)
    % Axes position in pixels
    axPos = getpixelposition(axSubplotLegend);
    % Original image dimensions
    imgSize = size(brainImg);
    imgH = imgSize(1);
    imgW = imgSize(2);
    % Scale while preserving image aspect ratio
    scale = 0.75 * min(axPos(3) / imgW, axPos(4) / imgH);
    newW = imgW * scale;
    newH = imgH * scale;
    % Center inside the legend subplot
    xLeft = axPos(1) + (axPos(3) - newW) / 2;
    yBottom = axPos(2) + (axPos(4) - newH) / 2;
    set(axImg, 'Units', 'pixels', 'Position', [xLeft, yBottom, newW, newH]);
end