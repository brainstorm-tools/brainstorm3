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
sProcess.SubGroup    = 'FAST graph';
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
% Color FastGraph by region or by label
sProcess.options.colorscheme.Comment = {'Region', 'Label', '<HTML><U><B>FastGraph color:</U></B></HTML>'; ...
                                        'Region', 'Label', ''};
sProcess.options.colorscheme.Type    = 'radio_linelabel';
sProcess.options.colorscheme.Value   = 'Region';
% Select regions to include
sProcess.options.region.Comment = [{'Prefrontal (PF)', 'Frontal (F)', 'Central (C)', 'Parietal (P)', 'Temporal (T)', 'Occipital (O)', 'Limbic (L)'}, {'<HTML><U><B>Select region(s) to include:</U></B></HTML>'}];
sProcess.options.region.Type    = 'list_horizontal';
sProcess.options.region.Value   = '';
% Add separator
sProcess.options.separator1.Type    = 'separator';
% Method for sorting the data
sProcess.options.label5.Comment = '<U><B>Select method to sort the data:</U></B>';
sProcess.options.label5.Type    = 'label';
sProcess.options.sortmethod.Comment = {'Root Mean Square', 'Max Absolute'; 'Root Mean Square', 'Max Absolute'};
sProcess.options.sortmethod.Type    = 'radio_label';
sProcess.options.sortmethod.Value   = 'Root Mean Square';
% Sort window
sProcess.options.label6.Comment  = ['<HTML><U><B>Choose range to sort over:</U></B>' ...
                                    '<I><FONT color="#777777">' ...
                                    'Early latency:&nbsp;&nbsp;&nbsp; 0-60 ms <BR>' ...
                                    'Middle latency: 60-250 ms <BR>' ...
                                    'Late latency:&nbsp;&nbsp;&nbsp;&nbsp; 250-600 ms</FONT></I></HTML>'];
sProcess.options.label6.Type     = 'label';
sProcess.options.sortwindow.Comment = 'Sort range: ';
sProcess.options.sortwindow.Type    = 'timewindow';
sProcess.options.sortwindow.Value   = [];
% Add separator
sProcess.options.separator2.Type    = 'separator';
% Plot window
sProcess.options.plotwindow.Comment = 'Plot range: ';
sProcess.options.plotwindow.Type    = 'timewindow';
sProcess.options.plotwindow.Value   = [];
% Edge transparency of plot
sProcess.options.edgealpha.Comment = 'Edge transparency of plot: ';
sProcess.options.edgealpha.Type    = 'value';
sProcess.options.edgealpha.Value   = {0.05,' ', 2};
% Exclude contacts within a certain distance from the stimulation sites
sProcess.options.label7.Comment  = ['<HTML><I><FONT color="#777777">' ...
                                    'Exclude analysis of contacts within this distance from the stimulation site</FONT></I>'];
sProcess.options.label7.Type     = 'label';
sProcess.options.excluderadius.Comment = 'Exclusion zone radius: ';
sProcess.options.excluderadius.Type    = 'value';
sProcess.options.excluderadius.Value   = {20,'mm', 0};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== GET OPTIONS =====
function OPTIONS = GetOptions(sProcess)
    OPTIONS = struct();
    % Atlas and scouts to use for plotting FastGraph
    ScoutsList = sProcess.options.scouts.Value;
    OPTIONS.Atlas = ScoutsList{1,1};
    OPTIONS.AtlasScoutLabels = ScoutsList{1,2};
    % Color figure by region or by label
    OPTIONS.ColorScheme = sProcess.options.colorscheme.Value;
    % Select regions to include
    OPTIONS.Region = sProcess.options.region.Value;
    % Method for sorting the data   
    OPTIONS.SortMethod = sProcess.options.sortmethod.Value;
    % Sort window
    if isfield(sProcess.options, 'sortwindow') && isfield(sProcess.options.sortwindow, 'Value') && iscell(sProcess.options.sortwindow.Value) && ~isempty(sProcess.options.sortwindow.Value)
        OPTIONS.SortWindow = round((sProcess.options.sortwindow.Value{1} * 1000)) + 101;
    else
        OPTIONS.SortWindow = [];
    end
    % Plot window
    if isfield(sProcess.options, 'plotwindow') && isfield(sProcess.options.plotwindow, 'Value') && iscell(sProcess.options.plotwindow.Value) && ~isempty(sProcess.options.plotwindow.Value)
        OPTIONS.PlotWindow = round((sProcess.options.plotwindow.Value{1} * 1000));
    else
        OPTIONS.PlotWindow = [];
    end
    % Edge transparency of plot
    OPTIONS.EdgeAlpha = sProcess.options.edgealpha.Value{1};    
    % Exclude contacts within a certain distance of stimulation sites
    OPTIONS.ExcludeRadius = sProcess.options.excluderadius.Value{1};
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>    
    % Initialize output
    OutputFiles = {};
    
    % Check that all input files use the same channel file
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

    % ===== Check whether all channel names in comment are valid =====
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

    % Get options
    OPTIONS = GetOptions(sProcess);
    
    % Early exit if no region is selected
    if isempty(OPTIONS.Region)
        bst_report('Error', sProcess, [], 'No region selected. Select at least one region to run the analysis.');
        return;
    end

    % Get indices of SEEG channels
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
    % Get the midpoint location of each stimulation pair from channel
    stimLocs = GetStimLocs(sInputs, ChannelMat);
    % Sort FastGraphs by stimulation-site location for LAPRAP style display
    sSortedFastgraphLocIdxs = SortLAPRAP(stimLocs);
  
    % Load SEEG recordings after applying FastGraph sorting
    [seegData, excludedContacts] = GetSeegData(sInputs, sSortedFastgraphLocIdxs, stimLocs, ChannelMat, OPTIONS);    
    % Split SEEG contacts into left and right hemisphere groups
    sContactGroupLocIdxs = GroupSeegContacts(stimLocs, ChannelMat);     
    % Compute anatomical labels for the contacts from volume/surface parcellations
    [~, chanTableWithAtlas] = export_channel_atlas(ChannelFiles{1}, 'SEEG', [], 5, 0, 0);
    % Locate atlas related columns from channel table above
    hit = cellfun(@(x) ischar(x) && (~isempty(strfind(OPTIONS.Atlas, x)) || ~isempty(strfind(x, OPTIONS.Atlas))), chanTableWithAtlas(1,:));
    % Columns whose header matches the atlas name
    cols = find(any(hit, 1));
    % Extract SEEG channel names and their atlas scout labels
    chanNamesSeeg = chanTableWithAtlas(2:end, 1);
    atlasScoutLabelsSeeg = chanTableWithAtlas(2:end, cols);

    % Create figure for FastGraph
    figure;
    % Maximize figure
    set(gcf, 'Position', get(0,'Screensize'));
    % Shared y-axis limits across FastGraph subplots
    commonAxisLimits = [];    
    % Reserve one extra subplot for the legend
    nSubplots = length(sInputs)+1;
    % Define the plot parameters
    % Subplot grid dimensions
    nCols = ceil(sqrt(nSubplots));
    nRows = ceil(nSubplots / nCols);
    % Subplot spacing and margins
    gap = [0.075 0.0175];
    horzMargin = 0.03;
    vertMargin = 0.015;
    % Generate one FastGraph per selected input
    bst_progress('start', 'Process', 'Plotting FastGraphs...', 0, 100);
    for iSubplot = 1:nSubplots-1
        % Show progress
        progressPrc = round(100 .* iSubplot ./ (nSubplots-1));
        bst_progress('set', progressPrc);
        % Data to be plotted for the current subplot
        subplotData = struct();
        Fout = seegData{iSubplot}.F(iSeeg, :);
        % Keep only left-hemisphere channels if present
        if any(sContactGroupLocIdxs.Left)
            subplotData.leftData = Fout(sContactGroupLocIdxs.Left,:);
        end
        % Keep only left-hemisphere channels if present
        if any(sContactGroupLocIdxs.Right)
            subplotData.rightData = Fout(sContactGroupLocIdxs.Right,:);
        end        
        % Sort channels within each hemisphere using the selected metric and time window
        sSubplotDataSorted = ApplyDataSorting(subplotData, seegData, OPTIONS);
        % Create the subplot with custom spacing 
        subtightplot(nRows, nCols, iSubplot, gap, horzMargin, vertMargin);
        % Plot the FastGraph for the current stimulation pair
        [hLeftAreaPLot, hRightAreaPLot] = PlotFastgraph(sInputs, stimLocs, iSubplot, subplotData, sSubplotDataSorted, seegData, excludedContacts, sContactGroupLocIdxs, ChannelMat, chanNamesSeeg, atlasScoutLabelsSeeg, OPTIONS);
        % Tighten axes to the plotted data and store the current axis handle
        axis tight
        axisLimits = axis;
        axSubplots(iSubplot) = gca;
        % Update the shared y-axis limits so all FastGraph subplots can
        % use the same vertical range for visual comparison
        if iSubplot == 1
            commonAxisLimits = axisLimits;
        else
            commonAxisLimits(3) = min(commonAxisLimits(3), axisLimits(3));
            commonAxisLimits(4) = max(commonAxisLimits(4), axisLimits(4));
        end
        % Apply edge transparency to the subplot
        if exist('hLeftAreaPLot','var')
            set(hLeftAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        end
        if exist('hRightAreaPLot','var')
            set(hRightAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        end        
        % Add the stimulation pair and atlas scout label as the subplot title
        AddFastgraphTitle(sInputs, sSortedFastgraphLocIdxs.All(iSubplot), chanNamesSeeg, atlasScoutLabelsSeeg);
    end    
    % Format all FastGraph axes
    axFastGraphs = axSubplots(1:nSubplots-1);
    % Set axis labels for all FastGraph subplots
    set([axFastGraphs.XLabel], 'String', 'Time (ms)');
    set([axFastGraphs.YLabel], 'String', 'Voltage (mV)');
    % Apply common axes properties
    set(axFastGraphs, 'YLim', commonAxisLimits(3:4), 'XAxisLocation', 'bottom');
    % Add zero-reference lines and hemisphere labels
    DecorateFastgraphAxes(axFastGraphs);
    % Link subplot axes so that zooming stays synchronized
    linkaxes(axFastGraphs)
    set(gcf,'units','normalized','outerposition',[0 0 1 1])
    zoom on

    % === Use the final subplot to display legend ===
    bst_progress('text', 'Plotting legend...');
    % Generate a cortex snapshot with atlas scout for display
    imgCortex = GenerateCortexSnapshot(sInputs, OPTIONS);
    % Create the legend subplot with the same spacing settings
    subtightplot(nRows, nCols, iSubplot+1, gap, horzMargin, vertMargin);
    % Plot the reference panel with the cortex snapshot and axis labels
    axSubplots(iSubplot+1) = gca;
    PlotLegend(axSubplots(iSubplot+1), imgCortex, round(axSubplots(1).XLim), axSubplots(1).YLim);
    
    % Close progress 
    bst_progress('stop');
end

%% ===== GET STIMULATION SITE CONTACT LOCATION =====
% Get the midpoint location of each stimulation pair from channel
function stimLocs = GetStimLocs(sInputs, ChannelMat)
    % Preallocate one [x y z] midpoint per stimulation pair
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
        % Clean extracted comment
        contact1 = parts{1};
        contact2 = parts{2};
        % Get the contact names
        contact1Parts = strsplit(contact1);
        contact2Parts = strsplit(contact2);
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
    sSortedLocIdxs = struct();
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
    % and keep their original input order
    xCoordColumn = 1;
    idxColumn = 4;
    leftContactLocs = sortrows(leftContactLocs, [xCoordColumn, idxColumn], {'descend' 'ascend'});
    rightContactLocs = sortrows(rightContactLocs, [xCoordColumn, idxColumn], {'descend' 'ascend'});
    % Store sorted original indices for each hemisphere
    sSortedLocIdxs.Left = leftContactLocs(:, 4)';
    sSortedLocIdxs.Right = rightContactLocs(:, 4)';
    % Combined sorted indices
    sSortedLocIdxs.All = [sSortedLocIdxs.Left, sSortedLocIdxs.Right];
end

%% ===== LOAD AND FILTER SEEG DATA =====
% Load each selected SEEG block and optionally exclude contacts based on
% distance from the stimulation site
function [seegData, excludedContacts] = GetSeegData(sInputs, sSortedFastgraphLocIdxs, stimLocs, ChannelMat, OPTIONS)
    % Intialize output 
    seegData = cell(numel(sInputs), 1);
    excludedContacts = cell(numel(sInputs), 1);
    % Get index of SEEG channel types
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
    for k = 1:numel(sInputs)
        % Load current file
        data = load(file_fullpath(sInputs(sSortedFastgraphLocIdxs.All(k)).FileName));
        % Mark bad channels as NaN
        data.F(data.ChannelFlag<0, :) = NaN;
        if ~isempty(stimLocs)
            % Current stimulation center
            stimCenter = stimLocs(sSortedFastgraphLocIdxs.All(k), :);
            % Compute distance from stimulation site to each SEEG contact (mm)
            contactDist = zeros(1, numel(ChannelMat.Channel));
            for j = iSeeg
                contactDist(j) = norm(stimCenter - ChannelMat.Channel(j).Loc', 2) * 1000;
            end
            % Exclude stimulation contacts themselves
            iStimContacts = (contactDist > 0) & (contactDist <= 2);
            % Exclude contacts within user-provided distance from the stimulation sites
            % iExcluded = contactDist > OPTIONS.ExcludeRadius;
            iExcluded = (contactDist > 2) & (contactDist <= OPTIONS.ExcludeRadius);            
            % Keep only valid SEEG contacts
            isSeeg = strcmp('SEEG',{ChannelMat.Channel.Type});
            validContacts = isSeeg & ~iExcluded & ~iStimContacts;
            excludedContacts{k} = ~validContacts;
            % Report excluded contacts
            fprintf('Contacts excluded for being within the %d mm exclusion zone "%s":\n', OPTIONS.ExcludeRadius, sInputs(k).Comment);
            fprintf('%s  %s  ', ChannelMat.Channel(iStimContacts).Name, ChannelMat.Channel(iExcluded).Name);
            fprintf('\n\n');
            % Remove excluded channels
            data.F(excludedContacts{k}, :) = NaN;
        else
            % If no stimulation locations are available, keep only SEEG channels
            excludedContacts{k} = ~iSeeg;
        end
        % Store SEEG data for the current block
        seegData{k} = data;
    end
end

%% ===== SPLIT CONTACTS TO LEFT/RIGHT HEMISPHERE =====
% Split SEEG contacts into left and right hemisphere groups
function sContactGroupLocIdxs = GroupSeegContacts(stimLocs, ChannelMat)
    % Initialize output structure
    sContactGroupLocIdxs = struct();
    % Get index of SEEG channel type
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
    % Check if valid location data is available
    noLocations = isempty(stimLocs) || ~any(stimLocs(:));
    if noLocations
        % Use channel group names to assign hemisphere
        sContactGroupLocIdxs.Left = zeros(1, length(iSeeg));
        for i = 1:length(iSeeg)
            % Left groups start with an apostrophe
            sContactGroupLocIdxs.Left(i) = strcmp(ChannelMat.Channel(iSeeg(i)).Group(1), '''');
        end
        % Remaining contacts belong to the right hemisphere
        sContactGroupLocIdxs.Right = ~sContactGroupLocIdxs.Left;
    else
        % Store SEEG contact coordinates
        contactLocs = zeros(length(iSeeg), 3);
        for i = 1:length(iSeeg)
            contactLocs(i, :) = ChannelMat.Channel(iSeeg(i)).Loc';
        end
        % Use coordinates to split contacts by hemisphere
        sContactGroupLocIdxs = SortLAPRAP(contactLocs);
    end
end

%% ===== WITHIN-HEMISPHERE DATA SORTING =====
% Sort left and right hemisphere channel data within a selected time
% window using either RMS amplitude or maximum absolute amplitude
function sSorted = ApplyDataSorting(subplotData, seegData, OPTIONS)
    % Initialize output structure
    sSorted = struct();
    % Get sample indices used for sorting
    if isempty(OPTIONS.SortWindow)
        sortWindowIdx = 1:size(seegData{1}.F,2);
    else
        sortWindowIdx = OPTIONS.SortWindow(1):OPTIONS.SortWindow(2);
    end
    % Sort channels within each hemisphere using the selected metric
    switch OPTIONS.SortMethod        
        case 'Root Mean Square'
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
        case 'Max Absolute'
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
function [hLeftAreaPlot, hRightAreaPlot] = PlotFastgraph(sInputs, stimLocs, iSubplot, subplotData, sSubplotDataSorted, seegData, excludedContacts, sContactGroupLocIdxs, ChannelMat, chanNamesSeeg, atlasScoutLabelsSeeg, OPTIONS)
    % Initialize output handles
    hLeftAreaPlot  = [];
    hRightAreaPlot = [];
    
    % Get cortex to be used for region/color lookup
    sSubject = bst_get('Subject', sInputs(1).SubjectName);
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    sCortex = bst_memory('LoadSurface', CortexFile);
    % Resolve selected scouts
    selectedScoutLabels = ResolveScoutSelection(sCortex, OPTIONS);
    % Get indices of all SEEG channels
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');    
    % Match channel names against atlas table names 
    [~, iChanLocs] = ismember({ChannelMat.Channel.Name}, chanNamesSeeg);
    % Check whether stimulation locations are available
    hasStimLocs = any(stimLocs(:));    
    % Select the time samples to display
    plotWindowIdx = OPTIONS.PlotWindow(1) + 101 : OPTIONS.PlotWindow(2) + 101;
    timeMs = seegData{iSubplot}.Time(plotWindowIdx) * 1000;

    fprintf('\n===== FastGraph %d/%d:  Stimulation site "%s" =====\n', iSubplot, numel(sInputs), sInputs(iSubplot).Comment)
    % Extract SEEG data once for this subplot
    Fout = seegData{iSubplot}.F(iSeeg, :);
    
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
        plotLocs    = iSeeg(contactIdxs);
        hemiData    = abs(Fout(contactIdxs, :));       
        % Get atlas scout labels for these channels
        channelScoutLabels = cell(1, numel(plotLocs));
        for i = 1:numel(plotLocs)
            channelScoutLabels{i} = atlasScoutLabelsSeeg{iChanLocs(plotLocs(i))};
        end
        % Filter channels using resolved scout selection
        if hasStimLocs
            toPlot = ismember(channelScoutLabels, selectedScoutLabels);
        else
            toPlot = true(1, numel(plotLocs));
        end
        % Keep track of number of channel before filtering 
        nChannelsBeforeFilter = numel(plotLocs);
        % Keep only channels that pass the filters
        plotLocs = plotLocs(toPlot);
        hemiData = hemiData(toPlot, :);
        channelScoutLabels = channelScoutLabels(toPlot);

        % Skip plotting if no channels remain after atlas/scout filtering
        fprintf('\n%s contacts and atlas scout labels:\n', sideName);
        if isempty(plotLocs)            
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
        isAllContactsExcluded = 1;
        for i = 1:numel(plotLocs)
            atlasScoutLabelSeeg = channelScoutLabels{i};
            if ~excludedContacts{iSubplot}(plotLocs(i))
                fprintf('%s - %s\n', ChannelMat.Channel(plotLocs(i)).Name, atlasScoutLabelSeeg);
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
            if strcmp(OPTIONS.ColorScheme, 'Region')
                region.Color = panel_scout('GetRegionColor', atlas.Scouts(iScout).Region);
            else
                region.Color = atlas.Scouts(iScout).Color;
            end
            return;
        end
    end
end

%% ===== FASTGRAPH TITLE =====
% Build the title shown above each subplot using the stimulation pair and
% the atlas label associated with the first contact
function AddFastgraphTitle(sInputs, iSortedFastgraph, chanNamesSeeg, atlasScoutLabelsSeeg)
    % Split the comment into the two parts
    parts = strsplit(sInputs(iSortedFastgraph).Comment, '-');
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
    title(sprintf('%s\n%s', sInputs(iSortedFastgraph).Comment, contact1AtlasScoutLabel),'fontsize', 8);
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
    isRegionColor = strcmp(OPTIONS.ColorScheme, 'Region');
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
function DecorateFastgraphAxes(axFastgraphs)
    for ax = axFastgraphs
        line(ax, ax.XLim, [0 0], ...
            'Color', [0 0 0], ...
            'LineWidth', 0.5, ...
            'HandleVisibility', 'off');
        AddHemisphereLabels(ax);
    end
end

%% ===== ADD HEMISPHERE LABELS =====
% Add L/R labels immediately above and below the y = 0 reference line
function AddHemisphereLabels(ax)
    % Common label properties
    labelProperties = { ...
        'Parent', ax, ...
        'Units', 'normalized', ...
        'FontSize', 8, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', ...
        'Clipping', 'off'};
    % Find the normalized vertical position of y = 0
    yZeroNormalized = -ax.YLim(1) / diff(ax.YLim);
    % Position labels close to the right edge
    xPosition = 0.96;
    % Normalized vertical spacing around the zero line
    labelGap = 0.035;
    % Place labels above and below the bottom x-axis
    text(xPosition, yZeroNormalized + labelGap, 'L', labelProperties{:});
    text(xPosition, yZeroNormalized - labelGap, 'R', labelProperties{:});
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