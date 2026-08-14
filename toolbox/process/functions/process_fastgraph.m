function varargout = process_fastgraph( varargin )
% PROCESS_FASTGRAPH: Plot FastGraph for one or more SEEG recordings.
% For each stimulation pair, channels are split by hemisphere, sorted 
% by a user-selected metric, filtered by anatomical parcels or regions, and
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
% Anatomical parcels to be use for plotting FastGraph
sProcess.options.parcels.Comment = '';
sProcess.options.parcels.Type    = 'anatparcel';
sProcess.options.parcels.Value   = {};
% Color FastGraph by Parcel or Region
sProcess.options.colorscheme.Comment    = {'Parcel', 'Region', 'Color scheme:&nbsp;&nbsp;'; ...
                                           'parcel', 'region', ''};
sProcess.options.colorscheme.Type       = 'radio_linelabel';
sProcess.options.colorscheme.Value      = 'parcel';
sProcess.options.colorscheme.Controller = struct('region', 'region');
% Select regions to include
regionsStr = {'Prefrontal(PF)', 'Frontal (F)',   'Central (C)', 'Parietal (P)', ...
              'Temporal (T)',   'Occipital (O)', 'Limbic (L)',  'White', ...
              'CSF',            'Other'};
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
    % Anatomy Atlas and Parcels to use for plotting FastGraph
    OPTIONS.AnatAtlas = sProcess.options.parcels.Value{1,1};
    OPTIONS.AnatAtlasParcels = sProcess.options.parcels.Value{1,2};
    % Color figure by region or by label
    OPTIONS.ColorScheme = sProcess.options.colorscheme.Value;
    % Select regions to include
    OPTIONS.AllRegions = sProcess.options.region.Comment(1:end-1);
    OPTIONS.Regions = sProcess.options.region.Value;
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
    if strcmpi(OPTIONS.ColorScheme, 'region') && isempty(OPTIONS.Regions)
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

    % === Get sAnatAtlas information
    sSubject = bst_get('Subject', sInputs(1).SubjectName);
    iAnatAtlas = find(strcmp(OPTIONS.AnatAtlas, {sSubject.Anatomy.Comment}));
    if isempty(iAnatAtlas)
        errMsg = 'TODO: Anat Atlas was not found in Subject';
        return
    end
    sAnatAtlas = load(file_fullpath(sSubject.Anatomy(iAnatAtlas).FileName), 'Labels');
    % Colors in sAnataAtlas.Labels are in the 0-255 range, convert them to 0-1 range
    sAnatAtlas.Labels(:, 3) = cellfun(@(x) x / 255, sAnatAtlas.Labels(:, 3), 'UniformOutput', false);

    % Handle Region color scheme
    if strcmpi(OPTIONS.ColorScheme, 'region')
        % 1. Get Region for each Parcel in sAnatAtlas. Cortical version of atlas used as reference
        [sAnatAtlas, errMsg] = GetParcelRegion(sSubject, OPTIONS.AnatAtlas, sAnatAtlas);
        if ~isempty(errMsg)
            % Error
        end
        % 2. Update colors in sAnatAtlas by Parcel region
        defaultScoutColors = panel_scout('GetScoutsColorTable');
        allRegionIds = regexprep(OPTIONS.AllRegions, '^.*\((.*?)\).*$', '$1');
        regionColorTable = allRegionIds';
        regionColorTable(1:7, 2) = num2cell(defaultScoutColors(1:7, :), 2); % PF, F, C, P, T, O and L
        regionColorTable{  8, 2} = [220, 220, 220] / 255; % White
        regionColorTable{  9, 2} = [ 44, 152, 254] / 255; % CSF
        regionColorTable{ 10, 2} = [130, 130, 130] / 255; % Other
        for iRegion = 1 : size(regionColorTable, 1)
            iAnatAtlasLabel = ismember(sAnatAtlas.Labels(:,4), regionColorTable{iRegion, 1});
            if any(iAnatAtlasLabel)
                [sAnatAtlas.Labels{iAnatAtlasLabel, 3}] = deal(regionColorTable{iRegion, 2});
            end
        end
        % 3. If no parcel was selected, select parcels from selected regions
        if isempty(OPTIONS.AnatAtlasParcels)
            regionSelIds = regexprep(OPTIONS.Regions, '^.*\((.*?)\).*$', '$1');
            isKeep = ismember(sAnatAtlas.Labels{:, 4}, regionSelIds);
            OPTIONS.AnatAtlasParcels = sAnatAtlas.Labels{isKeep, 1}';
        end
    end
    % Add Parcel 'N/A': Name and Color
    iNA = size(sAnatAtlas.Labels, 1) + 1;
    sAnatAtlas.Labels{iNA,2} = 'N/A';
    sAnatAtlas.Labels{iNA,3} = [0,0,0];

    % === Anatomical labels for SEEG contacts
    [~, chanTableWithAtlas] = export_channel_atlas(ChannelFiles{1}, 'SEEG', [], 5, 0, 0, OPTIONS.AnatAtlas);
    % Locate anatomy atlas in columns from channel table. Full match to get Anatomical parcellations (volatlas) only
    iCol = find(strcmp(OPTIONS.AnatAtlas, chanTableWithAtlas(1,:)));
    if length(iCol) > 1
        bst_report('Error', sProcess, sInputs, 'Two or more anatomical atlases have the same name, you should rename them to be unique');
    end
    % Number of SEEG channels
    nSeegChan = size(chanTableWithAtlas,1) - 1;
    % SEEG channels: Names, Anatomical Parcel, and Color
    seegLocInfo = repmat(struct('Name', '', 'Parcel', '', 'Color', []), nSeegChan, 1);
    [seegLocInfo.Name]   = deal(chanTableWithAtlas{2:end, 1});
    [seegLocInfo.Parcel] = deal(chanTableWithAtlas{2:end, iCol});
    [~, iAnatAtlasLabel] = ismember({seegLocInfo.Parcel}, sAnatAtlas.Labels(:,2));
    [seegLocInfo.Color] = deal(sAnatAtlas.Labels{iAnatAtlasLabel,3});

    % ===== Create figure for FastGraph =====
    hFig = figure;
    hFig.Visible = 'off';
    % Maximize figure
    set(gcf, 'Position', get(0,'Screensize'));
    % Reserve one extra subplot for the legend (brain figure)
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
        seegData = GetSeegData(sInput, stimLoc, ChannelMat, OPTIONS);
        % Add indices for L and R hemisphere data
        seegData.LeftIx  = sContactLocIdxs.Left;
        seegData.RightIx = sContactLocIdxs.Right;
        % Sort L and R indices using the selected metric and time window
        seegData = SortHemiIndices(seegData, OPTIONS);

        % Create the subplot with custom spacing 
        hFastGraphAxes(iFastGraph) = subtightplot(nRows, nCols, iFastGraph, gap, horzMargin, vertMargin);
        % Plot the FastGraph for the current stimulation pair
        [hLeftAreaPLot, hRightAreaPLot] = PlotFastgraph(sInput, stimLoc, seegData, seegLocInfo, OPTIONS);
        % Apply edge transparency to the subplot
        set(hLeftAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        set(hRightAreaPLot,'edgealpha', OPTIONS.EdgeAlpha);
        % Add the stimulation pair and atlas parcels label as the subplot title
        AddFastgraphTitle(sInput, seegLocInfo);
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
    % Generate a brain snapshot for display
    % imgCortex = GenerateCortexSnapshot(sInputs, OPTIONS);
    % Create the legend subplot with the same spacing settings
    axBrain = subtightplot(nRows, nCols, nRows*nCols, gap, horzMargin, vertMargin);
    % Plot the reference panel with the cortex snapshot and axis labels
    % PlotLegend(axBrain, imgCortex, round(hFastGraphAxes(1).XLim), hFastGraphAxes(1).YLim);
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
function seegData = GetSeegData(sInput, stimLoc, ChannelMat, OPTIONS)
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
        seegData.excludedContacts = ~validContacts;
        % Report excluded contacts
        fprintf('Contacts excluded for being at the stimulation location ( <= 2 mm):\n');
        fprintf('%s  ', ChannelMat.Channel(iSeeg(iStimContacts)).Name);
        fprintf('\n');
        fprintf('Contacts excluded for being within the %d mm exclusion zone:\n', OPTIONS.ExcludeRadius);
        fprintf('%s  ', ChannelMat.Channel(iSeeg(iExcluded)).Name);
        fprintf('\n');
        % Set data from excluded channels to NaN
        seegData.F(seegData.excludedContacts, :) = NaN;
    else
        % If no stimulation locations are available, keep only SEEG channels
        seegData.excludedContacts = ~iSeeg;
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

%% ===== WITHIN-HEMISPHERE SORTING OF INDICES =====
% Sort left and right indices for SEEG data within a selected time
% window using either RMS amplitude or maximum absolute amplitude
function seegData = SortHemiIndices(seegData, OPTIONS)
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
            if ~isempty(seegData.LeftIx)
                leftDataRms = sqrt(sum(seegData.F(seegData.LeftIx, sortWindowIdx).^2, 2));
                leftDataRms(isnan(leftDataRms)) = -Inf;
                [~, iSort] = sort(leftDataRms(:), 'ascend');
                seegData.LeftIx = seegData.LeftIx(iSort);
            end
            if ~isempty(seegData.RightIx)
                rightDataRms = sqrt(sum(seegData.F(seegData.RightIx, sortWindowIdx).^2, 2));
                rightDataRms(isnan(rightDataRms)) = -Inf;
                [~, iSort] = sort(rightDataRms(:), 'ascend');
                seegData.RightIx = seegData.RightIx(iSort);
            end        
        case 'maxabs'
            if ~isempty(seegData.LeftIx)
                leftDataMax = max(abs(seegData.F(seegData.LeftIx, sortWindowIdx)), [], 2);
                leftDataMax(isnan(leftDataMax)) = -Inf;
                [~, iSort] = sort(leftDataMax(:), 'ascend');
                seegData.LeftIx = seegData.LeftIx(iSort);
            end
            if ~isempty(seegData.RightIx)
                rightDataMax = max(abs(seegData.F(seegData.RightIx, sortWindowIdx)), [], 2);
                rightDataMax(isnan(rightDataMax)) = -Inf;
                [~, iSort] = sort(rightDataMax(:), 'ascend');
                seegData.RightIx = seegData.RightIx(iSort);
            end
    end
end

%% ===== PLOT FASTGRAPH =====
% Create one FastGraph subplot.
% Left-hemisphere SEEG channels are plotted as positive stacked areas
% Right-hemisphere SEEG channels are plotted as negative stacked areas
function [hLeftAreaPlot, hRightAreaPlot] = PlotFastgraph(sInput, stimLoc, seegData, seegLocInfo, OPTIONS)
    % Initialize output handles
    hLeftAreaPlot  = [];
    hRightAreaPlot = [];
    % Selected parcels
    selectedParcels = OPTIONS.AnatAtlasParcels;
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
            if isempty(seegData.LeftIx)
                continue;
            end
            sideName     = 'Left';
            contactIdxs  = seegData.LeftIx;
            signFactor   = 1;
        else
            % Right hemisphere settings
            if isempty(seegData.RightIx)
                continue;
            end
            sideName     = 'Right';
            contactIdxs  = seegData.RightIx;
            signFactor   = -1;
        end

        % Filter channels using resolved parcel selection
        if hasStimLocs
            toPlot = ismember({seegLocInfo(contactIdxs).Parcel}, selectedParcels);
        else
            toPlot = true(1, numel(contactIdxs));
        end
        % Keep track of number of channel before filtering 
        nChannelsBeforeFilter = numel(contactIdxs);
        % Keep only channels that pass the filters
        contactIdxs = contactIdxs(toPlot);

        % Skip plotting if no channels remain after atlas/parcel filtering
        fprintf('\n%s contacts and anatomical atlas parcels labels:\n', sideName);
        if isempty(contactIdxs)
            if nChannelsBeforeFilter > 0
                fprintf('Nothing to plot. All contacts were filtered out by the selected atlas/parcels regions.\n');
            else
                fprintf('Nothing to plot. No contacts are available for this hemisphere.\n');
            end
            continue;
        end

        % Plot stacked area traces for the current hemisphere
        hAreaPlot = area(timeMs, signFactor * abs(seegData.F(contactIdxs, plotWindowIdx))');

        % Print labels and assign colors
        strMaxLen = max(cellfun(@length, {seegLocInfo.Name}));
        isAllContactsExcluded = 1;
        for i = 1:numel(contactIdxs)
            if ~seegData.excludedContacts(contactIdxs(i))
                fprintf('%-*s - %s\n', strMaxLen, seegLocInfo(contactIdxs(i)).Name, seegLocInfo(contactIdxs(i)).Parcel);
                isAllContactsExcluded = 0;
            end
            hAreaPlot(i).FaceColor = seegLocInfo(contactIdxs(i)).Color;
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

%% ===== FASTGRAPH TITLE =====
% Build the title shown above each subplot using the stimulation pair and
% the atlas label associated with the first contact
function AddFastgraphTitle(sInput, seegLocInfo)
    % Split the comment into the two parts
    parts = strsplit(sInput.Comment, '-');
    % Clean extracted comment
    contact1 = strtrim(parts{1});
    % Get the contact names
    contact1Parts = strsplit(contact1);
    contact1 = contact1Parts{end};
    % Look up atlas label for the first contact
    iContact1 = find(strcmp({seegLocInfo.Name}, contact1), 1);
    if ~isempty(iContact1)
        contact1AtlasParcelLabel = seegLocInfo(iContact1).Parcel;
    else
        contact1AtlasParcelLabel = '?';
    end
    title(sprintf('%s\n%s', sInput.Comment, contact1AtlasParcelLabel),'fontsize', 8);
end


%% ===== GET REGION FOR PARCEL =====
function [sAnatAtlas, errMsg] = GetParcelRegion(sSubject, AnatAtlasName, sAnatAtlas)
    errMsg = [];
    % 1. Search for cortical version of anatomical atlas to retrieve region labels
    sSurf = load(file_fullpath(sSubject.Surface(sSubject.iCortex).FileName), 'Atlas');
    iAnatAtlas = find(strcmp(AnatAtlasName, {sSurf.Atlas.Name}));
    if isempty(iAnatAtlas)
        errMsg = 'Anatomical atlas does not have cortical version. Needed for regions. Try Parcel colors.';
        return
    elseif length(iAnatAtlas) > 1
        errMsg = 'Two or more surface atlases have the same name, you should rename them to be unique';
        return
    end
    sSurfAtlas = sSurf.Atlas(iAnatAtlas);
    % Normalize labels from anatomical atlas and surface atlas
    anatAtlasLabels = lower(strrep(sAnatAtlas.Labels(:, 2),  ' ', ''));
    surfAtlasLabels = lower(strrep({sSurfAtlas.Scouts.Label}, ' ', ''));

    % 2. Obtain region for each parcel in sAnatAtlas
    for iAnatAtlasLabel = 1 : length(anatAtlasLabels)
        anatAtlasLabel = anatAtlasLabels{iAnatAtlasLabel};
        iScoutFound = find(strcmpi(anatAtlasLabel, surfAtlasLabels));
        % Match
        if ~isempty(iScoutFound)
            % Region without hemisphere indicator
            sAnatAtlas.Labels{iAnatAtlasLabel, 4} = sSurfAtlas.Scouts(iScoutFound(1)).Region(2:end);
            continue
        end
        % Try some common fixes for the label
        anatAtlasLabel2 = anatAtlasLabel;
        anatAtlasLabel2 = strrep(anatAtlasLabel2, 'antcing',  'anteriorcingulate');
        anatAtlasLabel2 = strrep(anatAtlasLabel2, 'midfront', 'middlefrontal');
        iScoutFound = find(strcmpi(anatAtlasLabel2, surfAtlasLabels));
        if ~isempty(iScoutFound)
            % Region without hemisphere indicator
            sAnatAtlas.Labels{iAnatAtlasLabel, 4} = sSurfAtlas.Scouts(iScoutFound(1)).Region(2:end);
            continue
        end
        % White matter
        if ~isempty(regexp(anatAtlasLabel, '^white[l|r]?$', 'once'))
            sAnatAtlas.Labels{iAnatAtlasLabel, 4} = 'White';
            continue
        end
        % CSF
        if strcmpi(anatAtlasLabel, 'csf')
            sAnatAtlas.Labels{iAnatAtlasLabel, 4} = 'CSF';
            continue
        end
        % Other
        sAnatAtlas.Labels{iAnatAtlasLabel, 4} = 'Other';
    end
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