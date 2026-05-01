function varargout = process_fastgraph( varargin )
% PROCESS_FASTGRAPH: Plot fastgraph for one or more SEEG recordings.
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
sProcess.Comment     = 'Plot Fastgraphs';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Stimulation';
sProcess.Index       = 1100;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Atlas to use for plotting Fastgraph
sProcess.options.atlas.Comment = 'Atlas to plot: ';
sProcess.options.atlas.Type    = 'atlas';
sProcess.options.atlas.Value   = [];
% Color Fastgraph by region or by label
sProcess.options.label2.Comment = '<U><B>Color Fastgraph by region or by label ?</U></B>';
sProcess.options.label2.Type    = 'label';
sProcess.options.colorscheme.Comment = {'Region', 'Label'; 'Region', 'Label'};
sProcess.options.colorscheme.Type    = 'radio_label';
sProcess.options.colorscheme.Value   = 'Region';
% Select regions to include
sProcess.options.label3.Comment = '<U><B>Select region(s) to include:</U></B>';
sProcess.options.label3.Type    = 'label';
sProcess.options.regionprefrontal.Comment = '1: Prefrontal';
sProcess.options.regionprefrontal.Type    = 'checkbox';
sProcess.options.regionprefrontal.Value   = 1;
sProcess.options.regionfrontal.Comment = '2: Frontal';
sProcess.options.regionfrontal.Type    = 'checkbox';
sProcess.options.regionfrontal.Value   = 1;
sProcess.options.regioncentral.Comment = '3: Central';
sProcess.options.regioncentral.Type    = 'checkbox';
sProcess.options.regioncentral.Value   = 1;
sProcess.options.regionparietal.Comment = '4: Parietal';
sProcess.options.regionparietal.Type    = 'checkbox';
sProcess.options.regionparietal.Value   = 1;
sProcess.options.regiontemporal.Comment = '5: Temporal';
sProcess.options.regiontemporal.Type    = 'checkbox';
sProcess.options.regiontemporal.Value   = 1;
sProcess.options.regionoccipital.Comment = '6: Occipital';
sProcess.options.regionoccipital.Type    = 'checkbox';
sProcess.options.regionoccipital.Value   = 1;
sProcess.options.regionlimbic.Comment = '7: Limbic';
sProcess.options.regionlimbic.Type    = 'checkbox';
sProcess.options.regionlimbic.Value   = 1;
% Atlas scout labels to plot
sProcess.options.label4.Comment  = '<HTML><I><FONT color="#777777">For multiple labels: separate them with commas</FONT></I>';
sProcess.options.label4.Type     = 'label';
sProcess.options.atlasscoutlabels.Comment = 'Atlas scout labels to plot: ';
sProcess.options.atlasscoutlabels.Type    = 'text';
sProcess.options.atlasscoutlabels.Value   = '';
% Add separator
sProcess.options.separator1.Type    = 'separator';
% Method for sorting the data
sProcess.options.label5.Comment = '<U><B>Select method to sort the data:</U></B>';
sProcess.options.label5.Type    = 'label';
sProcess.options.sortmethod.Comment = {'Root Mean Square', 'Max Absolute'};
sProcess.options.sortmethod.Type    = 'radio';
sProcess.options.sortmethod.Value   = 1;
% Sort window
sProcess.options.label6.Comment = '<U><B>Choose range to sort over:</U></B>';
sProcess.options.label6.Type    = 'label';
sProcess.options.label7.Comment  = ['<HTML><I><FONT color="#777777">' ...
                                    'Early latency:&nbsp;&nbsp;&nbsp; 0-60 ms <BR>' ...
                                    'Middle latency: 60-250 ms <BR>' ...
                                    'Late latency:&nbsp;&nbsp;&nbsp;&nbsp; 250-600 ms</FONT></I>'];
sProcess.options.label7.Type     = 'label';
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
sProcess.options.label8.Comment  = ['<HTML><I><FONT color="#777777">' ...
                                    'Exclude analysis of contacts within this distance from the stimulation site</FONT></I>'];
sProcess.options.label8.Type     = 'label';
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
    % Atlas to use for plotting Fastgraph
    OPTIONS.Atlas = sProcess.options.atlas.Value;    
    % Color figure by region or by label
    OPTIONS.ColorScheme = sProcess.options.colorscheme.Value;
    % Select regions to include
    OPTIONS.Region = logical([sProcess.options.regionprefrontal.Value
                              sProcess.options.regionfrontal.Value
                              sProcess.options.regioncentral.Value
                              sProcess.options.regionparietal.Value
                              sProcess.options.regiontemporal.Value
                              sProcess.options.regionoccipital.Value
                              sProcess.options.regionlimbic.Value]);
    % Atlas scout labels to plot    
    OPTIONS.AtlasScoutLabels = strtrim(strsplit(sProcess.options.atlasscoutlabels.Value,','));    
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
    
    % Get options
    OPTIONS = GetOptions(sProcess);
    
    % Early exit if no region is selected
    if ~any(OPTIONS.Region)
        bst_report('Error', sProcess, [], 'No region selected. Select at least one region to run the analysis.');
        return;
    end

    % Get subject
    sSubject = bst_get('Subject', sInputs(1).SubjectName);
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    sCortex = bst_memory('LoadSurface', CortexFile);

    % Get the last used atlas if atlas not selected
    if isempty(OPTIONS.Atlas)        
        OPTIONS.Atlas = sCortex.Atlas(sCortex.iAtlas).Name;
    end
    % Find the atlas selected by the user 
    iAtlas = find(strcmpi({sCortex.Atlas.Name}, OPTIONS.Atlas), 1);
    
    % Early exit if any entered atlas scout label does not exist
    allAtlasScoutLabels = {sCortex.Atlas(iAtlas).Scouts.Label};
    enteredLabels = OPTIONS.AtlasScoutLabels(~cellfun(@isempty, OPTIONS.AtlasScoutLabels));
    if ~isempty(enteredLabels) && ~all(ismember(enteredLabels, allAtlasScoutLabels))
        bst_report('Error', sProcess, [], 'One or more scout labels entered are not present in the selected atlas');
        return;
    end

    % Load the channel file
    ChannelFile = file_fullpath(sInputs(1).ChannelFile);
    ChannelMat = load(ChannelFile);
    % Get indices of SEEG channels
    iSeeg = channel_find(ChannelMat.Channel, 'SEEG');
    % Get the midpoint location of each stimulation pair from channel
    stimLocs = GetStimLocs(sInputs, ChannelMat);
    % Sort fastgraphs by stimulation-site location for LAPRAP style display
    sSortedFastgraphLocIdxs = SortLAPRAP(stimLocs);
  
    % Load SEEG recordings after applying Fastgraph sorting
    [seegData, excludedContacts] = GetSeegData(sInputs, sSortedFastgraphLocIdxs, stimLocs, ChannelMat, OPTIONS);    
    % Split SEEG contacts into left and right hemisphere groups
    sContactGroupLocIdxs = GroupSeegContacts(stimLocs, ChannelMat);     
    % Compute anatomical labels for the contacts from volume/surface parcellations
    [~, chanTableWithAtlas] = export_channel_atlas(ChannelFile, 'SEEG', [], 10, 0, 0);
    % Locate atlas related columns from channel table above
    hit = cellfun(@(x) ischar(x) && (~isempty(strfind(OPTIONS.Atlas, x)) || ~isempty(strfind(x, OPTIONS.Atlas))), chanTableWithAtlas(1,:));
    % Columns whose header matches the atlas name
    cols = find(any(hit, 1));
    % Extract SEEG channel names and their atlas scout labels
    chanNamesSeeg = chanTableWithAtlas(2:end, 1);
    atlasScoutLabelsSeeg = chanTableWithAtlas(2:end, cols);

    % Create figure for Fastgraph
    figure;
    % Maximize figure
    set(gcf, 'Position', get(0,'Screensize'));
    % Shared y-axis limits across Fastgraph subplots
    commonAxisLimits = [];    
    % Reserve one extra subplot for the legend
    nSubplots = length(sInputs)+1;
    % Define the plot parameters
    % Subplot grid dimensions
    nRows = floor(sqrt(nSubplots/1.5));
    nCols = ceil(nSubplots/floor(sqrt(nSubplots/1.5)));
    % Subplot spacing and margins
    gap = [0.075 0.0175];
    horzMargin = 0.03;
    vertMargin = 0.015;
    % Generate one fastgraph per selected input
    bst_progress('start', 'Process', 'Plotting Fastgraphs...', 0, 100);
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
        % Plot the Fastgraph for the current stimulation pair
        [hLeftAreaPLot, hRightAreaPLot] = PlotFastgraph(sInputs, stimLocs, iSubplot, subplotData, sSubplotDataSorted, seegData, excludedContacts, sContactGroupLocIdxs, ChannelMat, chanNamesSeeg, atlasScoutLabelsSeeg, OPTIONS);
        % Tighten axes to the plotted data and store the current axis handle
        axis tight
        axisLimits = axis;
        axSubplots(iSubplot) = gca;
        % Update the shared y-axis limits so all Fastgraph subplots can
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
    % Apply the shared y-axis limits to all Fastgraph subplots
    for iSubplot = 1:nSubplots-1
        axSubplots(iSubplot).YLim = commonAxisLimits(3:4);
    end
    % Link subplot axes so that zooming stays synchronized
    linkaxes(axSubplots)
    set(gcf,'units','normalized','outerposition',[0 0 1 1])
    zoom on

    % === Use the final subplot to display legend ===
    bst_progress('text', 'Plotting legend...');
    % Generate a cortex snapshot with atlas scout for display
    imgCortex = GenerateCortexSnapshot(sSubject, OPTIONS);
    % Create the legend subplot with the same spacing settings
    subtightplot(nRows, nCols, iSubplot+1, gap, horzMargin, vertMargin);
    % Plot the reference panel with the cortex snapshot and axis labels
    axSubplots(iSubplot+1) = gca;
    PlotLegend(axSubplots(iSubplot+1), imgCortex, round(axSubplots(1).XLim), [0 1], 'Time (ms)', 'Voltage (mV)');
    
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
        case 1 % Root Mean Square
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
        case 2 % Max Absolute
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
% Create one fastgraph subplot.
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

    fprintf('\n===== Fastgraph %d/%d:  Stimulation site "%s" =====\n', iSubplot, numel(sInputs), sInputs(iSubplot).Comment)
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

        % Skip plotting if no channels remain
        if isempty(plotLocs)
            fprintf('\n%s contacts and atlas scout labels:\n', sideName);
            if nChannelsBeforeFilter > 0
                fprintf('Nothing to plot. All contacts were excluded by the atlas/scout selection.\n');
            else
                fprintf('Nothing to plot. No contacts are available for this hemisphere.\n');
            end
            continue;
        end

        % Plot stacked area traces for the current hemisphere
        hAreaPlot = area(timeMs, signFactor * hemiData(:, plotWindowIdx)');

        % Print labels and assign colors
        fprintf('\n%s contacts and atlas scout labels:\n', sideName);
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
            fprintf('Nothing plotted. All contacts lie in the excluded region.\n');
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
%   1) explicit scout labels entered by the user, or
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
    % Keep only non-empty scout labels entered in the GUI
    enteredLabels = OPTIONS.AtlasScoutLabels(~cellfun(@isempty, OPTIONS.AtlasScoutLabels));
    if ~isempty(enteredLabels)
        % Explicit scout-label filtering
        isKeep = ismember({atlas.Scouts.Label}, enteredLabels);
    else
        % Region-based filtering
        allRegionCodes = {'PF','F','C','P','T','O','L'};
        selectedRegions = allRegionCodes(OPTIONS.Region);
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
function imgCortex = GenerateCortexSnapshot(sSubject, OPTIONS)
    % Default output
    imgCortex = [];
    % Load cortex
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
    % Set options
    switch(OPTIONS.ColorScheme)
        case 'Region'
            panel_scout('SetScoutsOptions', 0, 0, 1, 'select', 0, 1, 0, 1);
        case 'Label'
            panel_scout('SetScoutsOptions', 0, 0, 1, 'select', 0, 1, 0, 0);
    end
    % Show only selected scouts
    panel_scout('SetSelectedScouts', iSelectedScouts);
    % Capture image
    img = out_figure_image(hFigSurf);
    % Crop background
    bgColor = img(1,1,:);
    mask = (img(:,:,1) == bgColor(1)) & ...
           (img(:,:,2) == bgColor(2)) & ...
           (img(:,:,3) == bgColor(3));
    goodRows = any(~mask, 2);
    goodCols = any(~mask, 1);
    imgCortex = img(goodRows, goodCols, :);
    % Close figure
    close(hFigSurf);
end

%% ===== PLOT LEGEND =====
% Shows the legend for the Fastgraph plots as in the paper
function PlotLegend(axSubplotLegend, brainImg, xRange, yRange, xLabel, yLabel)    
    % === Prepare the plot area ===
    % Set the visible x- and y-axis limits
    set(axSubplotLegend, 'XLim', xRange, 'YLim', yRange);
    % Add x-axis label
    axSubplotLegend.XLabel.String = xLabel;
    % Move x-axis label closer to the axis (slightly upward)
    axSubplotLegend.XLabel.Position = [mean(axSubplotLegend.XLim), axSubplotLegend.YLim(1) - 0.01, 0];
    % Add y-axis label
    axSubplotLegend.YLabel.String = yLabel;
    % Move the y-axis label closer to the axis (slightly right)
    axSubplotLegend.YLabel.Position = [axSubplotLegend.XLim(1) - 5, mean(axSubplotLegend.YLim), 0];
    % Show ticks only at the minimum and maximum values of each axis
    axSubplotLegend.XTick = [xRange(1), xRange(2)];
    axSubplotLegend.YTick = [yRange(1), yRange(2)];

    % === Create overlay axes for the brain atlas image ===
    axImg = axes('Parent', ancestor(axSubplotLegend, 'figure'), ...
        'Units', 'pixels', ...
        'Color', 'none');
    % Display the brain image inside the overlay axes
    hImg = imshow(brainImg, 'Parent', axImg);
    % Hide the overlay axes so only the image is visible
    axis(axImg, 'off');
    % Keep the original axes limits fixed so the image does not alter them
    axis(axSubplotLegend, 'manual');
    % Initial placement
    UpdateLegendImage(axSubplotLegend, axImg, brainImg);
    % Update placement whenever the figure is resized/moved
    hFig = ancestor(axSubplotLegend, 'figure');
    hFig.SizeChangedFcn = @(~,~)UpdateLegendImage(axSubplotLegend, axImg, brainImg);
    
    % Add left/right hemisphere labels with pixel-based spacing
    AddLegendHemisphereLabels(axSubplotLegend, xRange, yRange);
end

%% ===== ADD 'L/R' HEMISPHERE LABELS IN THE LEGEND =====
% Add 'L/R' hemisphere labels to the legend axes
function AddLegendHemisphereLabels(axSubplotLegend, xRange, yRange)
    % Position labels near the right side of the legend axes
    xSpan = diff(xRange);
    ySpan = diff(yRange);
    xLR = xRange(2) - 0.08 * xSpan;

    % Get axes height in pixels
    oldUnits = axSubplotLegend.Units;
    axSubplotLegend.Units = 'pixels';
    axPos = axSubplotLegend.Position;
    axSubplotLegend.Units = oldUnits;

    % Convert a fixed pixel gap into data units
    pixelsPerDataY = axPos(4) / ySpan;
    gapPx = max(14, axSubplotLegend.FontSize + 4);
    gapData = gapPx / pixelsPerDataY;

    % Place labels above and below the x-axis
    yAxisLevel = yRange(1);
    yL = yAxisLevel + gapData;
    yR = yAxisLevel - gapData;

    % Draw the labels
    text(axSubplotLegend, xLR, yL, 'L', ...
        'FontSize', 8, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', ...
        'Clipping', 'off', ...
        'Margin', 1);

    text(axSubplotLegend, xLR, yR, 'R', ...
        'FontSize', 8, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', ...
        'Clipping', 'off', ...
        'Margin', 1);
end

%% ===== UPDATE LEGEND IMAGE =====
% Update the overlay image position so it stays centered inside the
% legend subplot when the figure is resized or moved across screens
function UpdateLegendImage(axSubplotLegend, axImg, brainImg)
    % Get original image size in pixels
    imgH = size(brainImg, 1);
    imgW = size(brainImg, 2);
    % Read the legend subplot position in pixel units
    oldUnits = axSubplotLegend.Units;
    axSubplotLegend.Units = 'pixels';
    % Get the axes position in pixel units: [left, bottom, width, height]
    pos = axSubplotLegend.Position;
    axSubplotLegend.Units = oldUnits;
    % Available subplot width and height in pixels
    boxW = pos(3);
    boxH = pos(4);
    % Scale the image to fit inside the subplot while preserving aspect ratio
    scale = min(boxW / imgW, boxH / imgH) * 0.75;
    newW = imgW * scale;
    newH = imgH * scale;
    % Center the image inside the legend subplot
    xLeft = pos(1) + (boxW - newW) / 2;
    yBottom = pos(2) + (boxH - newH) / 2;
    % Update the overlay axes position in pixel coordinates
    axImg.Units = 'pixels';
    axImg.Position = [xLeft, yBottom, newW, newH];
end