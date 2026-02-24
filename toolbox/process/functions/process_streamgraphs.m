%% KT comments 7/26/2024
%

% data types:
%    no need for different options for different data types (CCEPs vs seizure), use filename for subplot title
%    can potentially do EEG data as well as SEEG, but start with SEEG

% anatomy:
%    labeling of contacts can be handled outside the function, one option we may want to provide is
%    the ability to restrict visualizaiton to grey matter responses / exclude white matter contacts

% montage type - handle outside process

% sorting of data not needed based on max response, reasonable options are:
%    1. retain existing order of channel file
%    2. basic sorting, standard at CCF would be left and then right, e.g. from top to bottom T' I' A' E' J' T I A E etc...
%    3. custom basic sorting, I do this for clinical CCEPs, provide a text box, user enters [ T', I', A', E'] etc... 
%        anything not listed in the box is shown at the end/bottom

% plot range - I think this should be handled outside the process, users job to clip data from multiple seizures so they're aligned
% potentially we want a box to put annotations on the plot if they are in the file, e.g. CLINICAL ONSET, END etc...

% discard options from the bottom of process box for now, alpha, exclude contacts, etc...

% basic idea is we need a color to associate with each channel from the data, get absolute value of the data, plot the envelope,
% with left side above horizontal, right side below.

function varargout = process_streamgraphs( varargin )

% PROCESS_STREAMGRAPHS: Combined function for outward and inward
% streamgraphs

% Authors: Ken Taylor, 11/29/2016

% updated inward graph to support bipolar data 02/20/20
% added code to reorder inward plots by L1 norm 01/23/20
% added option to plot only selected labels 01/31/19
% fixed bug affecting plot with changing channel configs 06/18/18
% updating into blocks, inward graphs may be broken 06/19/17
% updated sort range to handle resampled data 10/06/16
% removed plot window - change input to do this

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'Streamgraphs';
sProcess.FileTag     = '';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Plots';
sProcess.Index       = 1100;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix'};
sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Definition of the options
% === GRAPH TYPE
sProcess.options.label5.Comment = '<U><B>Data type:</U></B>';
sProcess.options.label5.Type    = 'label';
sProcess.options.ccep.Comment = {'CCEPs data', 'Seizure data'};
sProcess.options.ccep.Type    = 'radio';
sProcess.options.ccep.Value   = 1;
% === GRAPH TYPE
sProcess.options.label0.Comment = '<U><B>Graph Type:</U></B>';
sProcess.options.label0.Type    = 'label';
sProcess.options.graphtype.Comment = {'Outward Streamgraph', 'Inward Streamgraph'};
sProcess.options.graphtype.Type    = 'radio';
sProcess.options.graphtype.Value   = 1;
% === CONTROL
sProcess.options.label3.Comment = '<U><B>Select regions to include:</U></B>';
sProcess.options.label3.Type    = 'label';
sProcess.options.control1.Comment = '1: Prefrontal';
sProcess.options.control1.Type    = 'checkbox';
sProcess.options.control1.Value   = 1;
sProcess.options.control2.Comment = '2: Frontal';
sProcess.options.control2.Type    = 'checkbox';
sProcess.options.control2.Value   = 1;
sProcess.options.control3.Comment = '3: Central';
sProcess.options.control3.Type    = 'checkbox';
sProcess.options.control3.Value   = 1;
sProcess.options.control4.Comment = '4: Parietal';
sProcess.options.control4.Type    = 'checkbox';
sProcess.options.control4.Value   = 1;
sProcess.options.control5.Comment = '5: Temporal';
sProcess.options.control5.Type    = 'checkbox';
sProcess.options.control5.Value   = 1;
sProcess.options.control6.Comment = '6: Occipital';
sProcess.options.control6.Type    = 'checkbox';
sProcess.options.control6.Value   = 1;
sProcess.options.control7.Comment = '7: Lateral';
sProcess.options.control7.Type    = 'checkbox';
sProcess.options.control7.Value   = 1;
sProcess.options.control8.Comment = '8: All others';
sProcess.options.control8.Type    = 'checkbox';
sProcess.options.control8.Value   = 0;
% === REGION OR LABEL COLORS?
sProcess.options.label4.Comment = '<U><B>Color figure by region or by label?:</U></B>';
sProcess.options.label4.Type    = 'label';
sProcess.options.colorscheme.Comment = {'Region', 'Label'};
sProcess.options.colorscheme.Type    = 'radio';
sProcess.options.colorscheme.Value   = 1;
% === REF/BIPOLAR
sProcess.options.label1.Comment = '<U><B>Montage Type:</U></B>';
sProcess.options.label1.Type    = 'label';
sProcess.options.montage.Comment = {'Referential', 'Bipolar'};
sProcess.options.montage.Type    = 'radio';
sProcess.options.montage.Value   = 1;
% % === SEPARATE LEFT FROM RIGHT?
% sProcess.options.label2.Comment = 'Separate the left and right hemispheres?:';
% sProcess.options.label2.Type    = 'label';
% sProcess.options.separate.Comment = {'Yes', 'No'};
% sProcess.options.separate.Type    = 'radio';
% sProcess.options.separate.Value   = 1;
% === SORTING OPTION
sProcess.options.warning1.Comment = '<U><B>Select sorting method:</U></B>';
sProcess.options.warning1.Type    = 'label';
sProcess.options.sorting.Comment = {'Sort by std(data)', 'Sort by max(abs(data))'};
sProcess.options.sorting.Type    = 'radio';
sProcess.options.sorting.Value   = 1;
% === SORT RANGE
sProcess.options.warning2.Comment = '<U><B>Choose range to sort over:</U></B>';
sProcess.options.warning2.Type    = 'label';
sProcess.options.sortwindow.Comment = 'Sort range:';
sProcess.options.sortwindow.Type    = 'timewindow';
sProcess.options.sortwindow.Value   = {[.050,.900], 'ms', 2};
sProcess.options.sep1.Type    = 'separator';
% === PLOT RANGE
sProcess.options.plotwindow.Comment = 'Plot range:';
sProcess.options.plotwindow.Type    = 'timewindow';
sProcess.options.plotwindow.Value   = [];
sProcess.options.sep2.Type    = 'separator';
% === LINE THICKNESS IN PLOTS
sProcess.options.example3.Comment = 'Alpha: ';
sProcess.options.example3.Type    = 'value';
sProcess.options.example3.Value   = {0.05,' ', 2};
% === EXCLUDE CONTACTS WITHIN A CERTAIN DISTANCE OF STIM CONTACTS
sProcess.options.exclude.Comment = 'Exclude contacts that are: ';
sProcess.options.exclude.Type    = 'value';
sProcess.options.exclude.Value   = {20,'mm', 2};
% === SELECT INWARD GRAPH ELECTRODE
sProcess.options.electrode.Comment = 'Select electrodes to view (inward only)';
sProcess.options.electrode.Type    = 'text';
sProcess.options.electrode.Value   = 'Q1, Q2';
sProcess.options.electrode.InputTypes = {'data', 'raw'};
% === SELECT LABELS TO PLOT
sProcess.options.selection.Comment = 'Selection of labels to plot';
sProcess.options.selection.Type    = 'text';
sProcess.options.selection.Value   = 'R. superior frontal gyrus - anterior (gm)';
sProcess.options.selection.InputTypes = {'data', 'raw'};
% sProcess.options.electrode.Comment = 'Select an electrode to view (inward only):';
% sProcess.options.electrode.Type    = 'value';
% sProcess.options.electrode.Value   = {1, ' ', 0};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
% Initialize returned list of files
OutputFiles = {};

% Read in user input
[userInput] = getInput(sProcess);

if userInput.isCCEP
    % Create and populate arrays of stim locations and region colors
    [stimContacts, stimLocations, stimLocationColors, cortex] = getStimSites(userInput,sInput);
    
    % once the stim location for each subplot is obtained, they can be sorted
    % so that the subplots can be ordered meaningfully
    % [allfiles, leftfiles, rightfiles] = sortLAPPAR(avg_locs);
    if size(unique(stimLocations,'rows'),1) == 1
        [Files] = sortLAPPAR(stimLocations);
    elseif size(unique(stimLocations,'rows'),1) == size(stimLocations,1)
        [Files] = sortLAPPAR(stimLocations);
    else
        % temporary fix for inability to process seperate recordings at the
        % same stim site
        keyboard
        disp('ERROR - stim locations must be either all the same or all unique')
        return
    end
else
    Files = '';
    stimLocations = '';
    stimLocationColors = '';
    [sSubject, ~] = bst_get('Subject');
    cortexLink = sSubject.Surface(sSubject.iCortex);
    if ~isempty(cortexLink)
        cortex = load(file_fullpath(cortexLink.FileName));
    end
    stimContacts = '';
end

fig = figure;
max_axis = [];
clear ax
set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.

% load in the SEEG data block
[data,F,Fcell,excludeContacts] = getSEEG(sInput,userInput,Files,stimLocations);

% [Inds] = sortSEEG(stimLocations,sInput);


% set the number of subplots depending on graph type
[numSubplots,SEEG_inds,electrode_inds] = getSubplots(sProcess,sInput,userInput,excludeContacts,stimContacts);

% set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.
% generate each subplot

% %% this section is only required if you want the inward graphs to be sorted by L1 norm response
% % also need to change back lines 217 220 261 283 if not using this
% for subplotNum = 1:numSubplots-1
%     [Inds] = sortSEEG(stimLocations,sInput,subplotNum);
%     [subplotData] = getSubplotData(subplotNum,userInput,F,Fcell,SEEG_inds,Inds,Files);
%     a = isnan(subplotData.leftData);
%     subplotData.leftData(a) = 0;
%     b = isnan(subplotData.rightData);
%     subplotData.rightData(b) = 0;
%     temp = sum([abs(subplotData.rightData); abs(subplotData.leftData)]);
%     % 106:end = 5 to 900ms
%     % 111:160 = 10 to 60ms      early
%     % 161:350 = 61 to 250ms     middle 
%     % 351:700 = 250 to 600ms    late
%     L1max(subplotNum) = max(temp(106:end));
%     if isnan(L1max(subplotNum))
%         keyboard
%     end
% end
% chLink = file_fullpath(sInput(1).ChannelFile);
% ch = load(chLink);
% [X,Y] = sort(L1max);
% Z = {ch.Channel(electrode_inds(Y)).Name};

%%
for subplotNum = 1:numSubplots-1
    
    [Inds] = sortSEEG(stimLocations,sInput,subplotNum);
%     [Inds] = sortSEEG(stimLocations,sInput,Y(subplotNum));    
    % get the data used in each subplot
    [subplotData] = getSubplotData(subplotNum,userInput,F,Fcell,SEEG_inds,Inds,Files);
%     [subplotData] = getSubplotData(Y(subplotNum),userInput,F,Fcell,SEEG_inds,Inds,Files);
    
    % normalize the responses to one contact per label
%     [subplotData, Fcell,excludeContacts] = normalizeSubplotData(subplotData,Fcell,sInput,Inds,subplotNum,excludeContacts);
    
    % apply the chosen sort method
    [sorted] = applySorting(userInput,subplotData,data);
    
    % generate each subplot
    if userInput.isCCEP
        subtightplot(floor(sqrt(numSubplots/1.5)),ceil(numSubplots/floor(sqrt(numSubplots/1.5))),subplotNum,[0.075 0.0175],0.03,0.015)
    else
        m = max([floor(numSubplots/6) 1]);
        n = ceil(numSubplots/floor(sqrt(numSubplots/1.5)));
        subtightplot(m,n,subplotNum,[0.075 0.0175],0.03,0.015)
    end
    [h1, h2] = createSubplot(userInput,subplotNum,sInput,data,subplotData,F,Fcell,Inds,sorted,stimLocations,stimLocationColors,cortex,userInput.isCCEP,excludeContacts);
    
    % manipulate plots to make them more readable
    axis tight
    axis_temp = axis;
    ax(subplotNum) = gca;
    if subplotNum == 1
        max_axis = axis_temp;
    else
        max_axis(3) = min(max_axis(3),axis_temp(3));
        max_axis(4) = max(max_axis(4),axis_temp(4));
    end
    if exist('h1','var')
        set(h1,'edgealpha',userInput.Alpha);
    end
    if exist('h2','var')
        set(h2,'edgealpha',userInput.Alpha);
    end
    
    if userInput.isCCEP
        % put a useful title on each subplot
        switch userInput.Graphtype
            case 1 % Outward Streamgraph
                addSubtitleLegend(Files.All(subplotNum),userInput,sInput,electrode_inds);
            case 2 % Inward Streamgraph
                addSubtitleLegend(subplotNum,userInput,sInput,electrode_inds);
%                 addSubtitleLegend(Y(subplotNum),userInput,sInput,electrode_inds);
        end
    end
%     camroll(90)
end
if userInput.isCCEP
    % add the legend subplot
    subtightplot(floor(sqrt(numSubplots/1.5)),ceil(numSubplots/floor(sqrt(numSubplots/1.5))),subplotNum+1,[0.075 0.0175],0.03,0.015)
    [X1,map1] = imread('D:\ATLAS\private\matlab_code\brain_legend3.png');
    imshow(X1,map1)
end

% more plot manipulations
for subplotNum = 1:numSubplots-1
    %     subplot(ceil(sqrt(num_subplots)),ceil(num_subplots/ceil(sqrt(num_subplots))),k)
    ax(subplotNum).YLim = max_axis(3:4);
    
    % axis(max_axis)
end
linkaxes(ax)
set(gcf,'units','normalized','outerposition',[0 0 1 1])
shg
zoom yon
% for i = 1:length(Z)
%     disp([Z{i} ' ' num2str(X(i))])
% end
end

function [userInput] = getInput(sProcess)
userInput.isCCEP = (sProcess.options.ccep.Value) < 2;
userInput.Graphtype = sProcess.options.graphtype.Value;

userInput.Regions = logical([sProcess.options.control1.Value % prefrontal
    sProcess.options.control2.Value % frontal
    sProcess.options.control3.Value % central
    sProcess.options.control4.Value % parietal
    sProcess.options.control5.Value % temporal
    sProcess.options.control6.Value % occipital
    sProcess.options.control7.Value 
    sProcess.options.control8.Value]);

userInput.Montage = sProcess.options.montage.Value;

selection = sProcess.options.selection.Value;
userInput.Selection = strtrim(strsplit(selection,','));

userInput.ColorScheme = (sProcess.options.colorscheme.Value) < 2;

userInput.sortMethod = sProcess.options.sorting.Value;
if isfield(sProcess.options, 'sortwindow') && isfield(sProcess.options.sortwindow, 'Value') && iscell(sProcess.options.sortwindow.Value) && ~isempty(sProcess.options.sortwindow.Value)
    userInput.SortWindow = (sProcess.options.sortwindow.Value{1} * 1000)+100;
else
    userInput.SortWindow = [];
end
if isfield(sProcess.options, 'plotwindow') && isfield(sProcess.options.plotwindow, 'Value') && iscell(sProcess.options.plotwindow.Value) && ~isempty(sProcess.options.plotwindow.Value)
    userInput.PlotWindow = round((sProcess.options.plotwindow.Value{1} * 1000));
else
    userInput.PlotWindow = [];
end
userInput.Alpha = sProcess.options.example3.Value{1};

userInput.ExcludeRegion = sProcess.options.exclude.Value{1};
% are we separating left from right?  - Just always do this unless we
%                                       decide otherwise
% userInput.Separate = sProcess.options.separate.Value;
userInput.Separate = 1;
end

function [stimContacts, stimLocations, stimLocationColors, cortex] = getStimSites(userInput,sInput)
[sSubject, ~] = bst_get('Subject');
cortexLink = sSubject.Surface(sSubject.iCortex);
if ~isempty(cortexLink)
    cortex = load(file_fullpath(cortexLink.FileName));
end
stimLocations = zeros(length(sInput),3);
stimLocationColors = zeros(length(sInput),3);
i = 1;
for k = 1:length(sInput)
    % get the channel information
    chLink = file_fullpath(sInput(k).ChannelFile);
    ch = load(chLink);
    dashind = find(sInput(k).Comment== '-');
    if userInput.Montage == 2
        contact = strtrim(sInput(k).Comment(dashind-4:dashind+4));
    else
        contact = strtrim(sInput(k).Comment(dashind-4:dashind-1));
    end
    %     contact = strtrim(sInput(k).Comment(dashind-4:dashind+4));
    if length(contact)>2
        if strcmp(contact(3),'-')
            contact = contact(1:end-1);
        end
    end
    if userInput.Montage == 2
        contact2 = strtrim(sInput(k).Comment(dashind-4:dashind+4));
    else
        contact2 = strtrim(sInput(k).Comment(dashind+1:dashind+4));
    %     contact = strtrim(sInput(k).Comment(dashind-4:dashind+4));
    end
    if strcmp(contact2(3),' ')
        [contact2,~] = strtok(contact2);
    end
    
    if any(strcmp({ch.Channel.Name},strtrim(contact)))
        stimLocations(k,:) = ((ch.Channel(strcmp({ch.Channel.Name},strtrim(contact))).Loc')+(ch.Channel(strcmp({ch.Channel.Name},strtrim(contact2))).Loc'))/2;
        region = applyRegionColor(userInput,ch.Channel(strcmp({ch.Channel.Name},strtrim(contact))).Comment,cortex);
        stimLocationColors(k,:) = region.Color;
    end
    stimContacts{i} = contact;
    stimContacts{i+1} = contact2;
    i = i+2;
end
stimContacts = unique(stimContacts);
end

function [data,F,Fcell,outsideSEEG] = getSEEG(sInput,userInput,Files,stimLocations)
% load in the SEEG data block
Fcell = cell(length(sInput),1);


% %% start of section to single out stim contacts
% % note - also edit last part of line 398 if editing this
% contactInd = 1;
% for k = 1:length(sInput)
%     dashind = find(sInput(k).Comment== '-');
%     contact = strtrim(sInput(k).Comment(dashind-4:dashind-1));
%     %     contact = strtrim(sInput(k).Comment(dashind-4:dashind+4));
%     if length(contact)>2
%         if strcmp(contact(3),'-')
%             contact = contact(1:end-1);
%         end
%     end
%     
%     contact2 = strtrim(sInput(k).Comment(dashind+1:dashind+4));
%     %     contact = strtrim(sInput(k).Comment(dashind-4:dashind+4));
%     if strcmp(contact2(3),' ')
%         [contact2,~] = strtok(contact2);
%     end
%     stimContacts{contactInd} = contact;
%     stimContacts{contactInd+1} = contact2;
%     contactInd = contactInd + 2;
% end
% stimContacts = unique(stimContacts);
% ch = load(file_fullpath(sInput(1).ChannelFile));
% SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
% stimSEEG = strcmp('SEEG',{ch.Channel.Type});
% for k = 1:length(stimSEEG)
%     if stimSEEG(k)
%         temp = any(strcmp(ch.Channel(k).Name,stimContacts));
%         if ~temp
%             stimSEEG(k) = false;
%         end
%     end
% end
% % end of section to single out stim contacts
%%
for k = 1:length(sInput)
    % get the channel information
    
    switch userInput.isCCEP
        case 1
            FileLink = file_fullpath(sInput(Files.All(k)).FileName);
            chLink = file_fullpath(sInput(Files.All(k)).ChannelFile);
        case 0
            FileLink = file_fullpath(sInput(k).FileName);
            chLink = file_fullpath(sInput(k).ChannelFile);
    end
    ch = load(chLink);
    
    data = load(FileLink);
    data.F(data.ChannelFlag<0,:) = NaN;
    SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
    
    if ~isempty(stimLocations)
        stimCenter = stimLocations(Files.All(k),:);
        contactDist = zeros(1,length(ch.Channel));
        for j = SEEGcontacts
            contactDist(j) = sqrt((stimCenter(1)-ch.Channel(j).Loc(1))^2+(stimCenter(2)-ch.Channel(j).Loc(2))^2+(stimCenter(3)-ch.Channel(j).Loc(3))^2)*1000;
        end
        SEEGs = strcmp('SEEG',{ch.Channel.Type});
        if userInput.ExcludeRegion <0
            outside = contactDist<abs(userInput.ExcludeRegion);
        else
            outside = contactDist>abs(userInput.ExcludeRegion);
        end
        stimInds = (contactDist<2)&(contactDist>0);
        insideSEEG = (~outside)&SEEGs&(~stimInds)%&stimSEEG;
        outsideSEEG = ~insideSEEG;
        fprintf('Contacts within %0.1fmm excluded, including:\n',userInput.ExcludeRegion)
        fprintf('%s  ',ch.Channel(outside).Name)
        fprintf('\n\n')
        data.F(~insideSEEG,:) = NaN;
    else
        outsideSEEG = ~strcmp('SEEG',{ch.Channel.Type});
    end
    F(:,:,k) = data.F(SEEGcontacts,:);
    %     F = [];
    Fcell(k) = {data.F(SEEGcontacts,:)};
end
end

function [Inds] = sortSEEG(stimLocations,sInput,subplotNum)
% get the channel information (assumed equal for all input files)
chLink = file_fullpath(sInput(1).ChannelFile);
% chLink = file_fullpath(sInput(subplotNum).ChannelFile);
ch = load(chLink);
% sort the contact locations
SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
Inds.Left = zeros(1,length(SEEGcontacts));
% if no locations available distinguish left from right using the '
if ~any(any(stimLocations))
    noLocations = 1;
else
    noLocations = 0;
end
if isempty(stimLocations)
    noLocations = 0;
end
if noLocations
    temp_ind = 1;
    for i = SEEGcontacts
        Inds.Left(temp_ind) = strcmp(ch.Channel(i).Group(2),'''');
        temp_ind = temp_ind + 1;
    end
    Inds.Right = ~Inds.Left;
else
    contact_locs = zeros(3,length(SEEGcontacts));
    for i = 1:length(SEEGcontacts)
        contact_locs(:,i) = ch.Channel(SEEGcontacts(i)).Loc;
    end
    [Inds] = sortLAPPAR(contact_locs');
end
end

function [num_subplots,SEEG_inds,electrode_inds] = getSubplots(sProcess,sInput,userInput,outsideSEEG,stimContacts)
% set the number of subplots depending on graph type
switch userInput.Graphtype
    case 1 % Outward Streamgraph
        num_subplots = length(sInput);
        electrode_inds = [];
        SEEG_inds = [];
    case 2 %  Inward Streamgraph
        % get the channel information (assumed equal for all input files)
        chLink = file_fullpath(sInput(1).ChannelFile);
        ch = load(chLink);
        SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
        %         electrode = upper(sProcess.options.electrode.Value);
        %         num_subplots = sum(strcmp({ch.Channel.Group},electrode));
        %         for i = 1:length(ch.Channel)
        %             comp(i) = strcmp(ch.Channel(i).Group,electrode);
        %             if strcmp(ch.Channel(i).Type,'OUT')&&strcmp(ch.Channel(i).Group,electrode)
        %                 comp(i) = 0;
        %                 num_subplots = num_subplots -1;
        %             end
        %         end
        %         electrode_inds  = find(comp);
        electrodes = sProcess.options.electrode.Value;
        if isempty(electrodes)
            electrodes = {ch.Channel.Name};
            electrodes = electrodes(~outsideSEEG);
        elseif strcmp(electrodes,'STIM')
            electrodes = stimContacts;
        else
            electrodes = strtrim(strsplit(electrodes,','));
        end
        num_subplots = length(electrodes);
        for i = 1:length(ch.Channel)
            comp(i) = any(strcmp(ch.Channel(i).Name,electrodes));
        end
        electrode_inds  = find(comp);
        for i = 1:length(electrode_inds)
            SEEG_inds(i) = find(SEEGcontacts == electrode_inds(i));
        end
    otherwise
        error('wrong switch')
end
% add an extra subplot for the legend
num_subplots = num_subplots + 1;
end

function [subplotData] = getSubplotData(subplotNum,userInput,F,Fcell,SEEG_inds,Inds,Files)
% get the data that will be used in each subplot
subplotData.leftData = [];
subplotData.rightData = [];
subplotData.allData = [];
switch userInput.Graphtype
    case 1 % Outward Streamgraph
        Fout = Fcell{subplotNum};
        switch userInput.Separate
            case 1 % split left and right
                if any(Inds.Left)
                    %                     subplotData.leftData = F(Inds.Left,:,subplotNum);
                    subplotData.leftData = Fout(Inds.Left,:);
                end
                if any(Inds.Right)
                    %                     subplotData.rightData = F(Inds.Right,:,subplotNum);
                    subplotData.rightData = Fout(Inds.Right,:);
                end
            case 2 % don't split
                %                 subplotData.allData = F(Inds.All,:,subplotNum);
                subplotData.allData = Fout(Inds.All,:);
        end
    case 2 % Inward Streamgraph
        switch userInput.Separate
            case 1
                if any(Inds.Left)
                    subplotData.leftData = squeeze(F(SEEG_inds(subplotNum),:,Files.Left))';
                end
                if any(Inds.Right)
                    subplotData.rightData = squeeze(F(SEEG_inds(subplotNum),:,Files.Right))';
                end
            case 2
                subplotData.allData = squeeze(F(SEEG_inds(subplotNum),:,Files.All))';
        end
end
end

function [subplotData, Fcell,excludeContacts] = normalizeSubplotData(subplotData,Fcell,sInput,Inds,subplotNum,excludeContacts)

chLink = file_fullpath(sInput(1).ChannelFile);
ch = load(chLink);
SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));


tempData = Fcell{subplotNum};

for i = 1:size(tempData,1)
        sameRegion = false(1,size(tempData,1));
        for j = 1:size(tempData,1)
            if strcmp(ch.Channel(SEEGcontacts(j)).Comment, ch.Channel(SEEGcontacts(i)).Comment)
                sameRegion(j) = true;
            end
        end
        labelCount = sum(sameRegion);
        tempData(i,:) = tempData(i,:)/labelCount;
end

Fcell{subplotNum} = tempData;

subplotData.leftData = tempData(Inds.Left,:);
subplotData.rightData = tempData(Inds.Right,:);
%     for i = 1:size(subplotData.leftData,1)
%         sameRegion = false(1,size(subplotData.leftData,1));
%         sameRegion(i) = true;
%         for j = i+1:size(subplotData.leftData,1)-1
%             if strcmp(ch.Channel(j).Comment, ch.Channel(i).Comment)
%                 sameRegion(j) = true;
%             end
%         end
%         temp = subplotData.leftData(sameRegion,:);
%         subplotData.leftData(i,:) = mean(abs(temp))';
%         sameRegion(i) = false;
%         subplotData.leftData(sameRegion,:) = NaN;
%     end
%     for i = 1:size(subplotData.rightData,1)
%         sameRegion = false(1,size(subplotData.rightData,1));
%         sameRegion(i) = true;
%         for j = i+1:size(subplotData.rightData,1)-1
%             if strcmp(ch.Channel(j).Comment, ch.Channel(i).Comment)
%                 sameRegion(j) = true;
%             end
%         end
%         temp = subplotData.rightData(sameRegion,:);
%         subplotData.rightData(i,:) = mean(abs(temp))';
%         sameRegion(i) = false;
%         subplotData.rightData(sameRegion,:) = NaN;
%     end
end

function [sorted] = applySorting(userInput,subplotData,data)
% set the indexing for the window of data to sort over
% if ~isempty(userInput.SortWindow)
%     SortWindowIndx = panel_time('GetTimeIndices', data.Time, userInput.SortWindow);
% else
%     SortWindowIndx = 1:size(data.F,2);
% end
if isempty(userInput.SortWindow)
    SortWindowIndx = 1:size(data.F,2);
else
    SortWindowIndx = userInput.SortWindow(1):userInput.SortWindow(2);
end
sorted.Inds.Left = [];
sorted.Inds.Right = [];
sorted.Inds.All = [];
% apply the chosen sort method
switch userInput.sortMethod
    
    case 1 % 'std'
        % sort inside out using stand deviation
        switch userInput.Separate
            case 1
                if ~isempty(subplotData.leftData)
                    leftDataStd = std(subplotData.leftData(:,SortWindowIndx),0,2);
                    leftDataStd(isnan(leftDataStd)) = -Inf;
                    [sorted.Vals.Left,sorted.Inds.Left] = sort(leftDataStd,'ascend');
                end
                if ~isempty(subplotData.rightData)
                    rightDataStd = std(subplotData.rightData(:,SortWindowIndx),0,2);
                    rightDataStd(isnan(rightDataStd)) = -Inf;
                    [sorted.Vals.Right,sorted.Inds.Right] = sort(rightDataStd,'ascend');
                end
            case 2
                allDataStd = std(subplotData.allData(:,SortWindowIndx),0,2);
                [sorted.Vals.All,sorted.Inds.All] = sort(allDataStd,'ascend');
        end
    case 2 %'abs max'
        % sort inside out using max absolute value
        switch userInput.Separate
            case 1
                if ~isempty(subplotData.leftData)
                    leftDataMax = max(abs(subplotData.leftData(:,SortWindowIndx)),[],2);
                    leftDataMax(isnan(leftDataMax)) = -Inf;
                    [sorted.Vals.Left,sorted.Inds.Left] = sort(leftDataMax,1,'ascend');
                end
                if ~isempty(subplotData.rightData)
                    rightDataMax = max(abs(subplotData.rightData(:,SortWindowIndx)),[],2);
                    rightDataMax(isnan(rightDataMax)) = -Inf;
                    [sorted.Vals.Right,sorted.Inds.Right] = sort(rightDataMax,1,'ascend');
                end
            case 2
                allDataMax = max(abs(subplotData.allData(:,SortWindowIndx)),[],2);
                [sorted.Vals.All,sorted.Inds.All] = sort(allDataMax,2,'ascend');
        end
    otherwise
        error('wrong switch')
end
end

function [sortedLocs] = sortLAPPAR(locs)
% returns the index of locations sorted by
% (L)eft side (A)nterior to (P)osterior (LAP),
% then (P)osterior to (A)nterior on the (R)ight (PAR)
% given input [x-pos; y-pos; z-pos] of electrode locations

% separate out the left and right sides
lhemi = locs(locs(:,2) >= 0,:);
rhemi = locs(locs(:,2) <  0,:);

% sort the left side descending, and right side ascending
% LAPPAR_sorted = [fliplr(sortrows(lhemi,1)') sortrows(rhemi,1)'];
LAPPAR_sorted = [fliplr(sortrows(lhemi,1)') fliplr(sortrows(rhemi,1)')];
% relate sorted electrodes to input to find indices
% all = zeros(1,size(LAPPAR_sorted,2));
% for i = 1:size(LAPPAR_sorted,2)
%     all(i) = find(locs(:,1)==LAPPAR_sorted(1,i));
% end
% instead to account for duplicate locations
sortedLocs.All = [];
for i = 1:size(unique(LAPPAR_sorted','rows'),1)
    x = find(locs(:,1)'==LAPPAR_sorted(1,i)');
    y = find(locs(:,2)'==LAPPAR_sorted(2,i)');
    z = find(locs(:,3)'==LAPPAR_sorted(3,i)');
    sortedLocs.All = [sortedLocs.All intersect(intersect(x,y),z)];
end
leftrows = fliplr(sortrows(lhemi,1)');
rightrows = sortrows(rhemi,1)';
% left = zeros(1,size(leftrows,2));
% right = zeros(1,size(rightrows,2));
% for i = 1:size(leftrows,2)
%     left(i) = find(locs(:,1)==leftrows(1,i));
% end
% for i = 1:size(rightrows,2)
%     right(i) = find(locs(:,1)==rightrows(1,i));
% end
sortedLocs.Left = [];
sortedLocs.Right = [];
for i = 1:size(unique(leftrows','rows'),1)
    x = find(locs(:,1)'==leftrows(1,i)');
    y = find(locs(:,2)'==leftrows(2,i)');
    z = find(locs(:,3)'==leftrows(3,i)');
    sortedLocs.Left = [sortedLocs.Left intersect(intersect(x,y),z)];
end
for i = 1:size(unique(rightrows','rows'),1)
    x = find(locs(:,1)'==rightrows(1,i)');
    y = find(locs(:,2)'==rightrows(2,i)');
    z = find(locs(:,3)'==rightrows(3,i)');
    sortedLocs.Right = [sortedLocs.Right intersect(intersect(x,y),z)];
end
end

function region = applyRegionColor(userInput,loc_region,cortex)
% returns the color that a region should be based on the location

m = 1;
search_on = 1;
while (m <= length(cortex.Atlas(2).Scouts)) && search_on
    if ~isempty(strfind(loc_region,cortex.Atlas(2).Scouts(m).Label(1:end-2)))
        search_on = 0;
    else
        m = m+1;
    end
end
if m < length(cortex.Atlas(2).Scouts)
    region.Name = cortex.Atlas(2).Scouts(m).Region(2:end);
    if userInput.ColorScheme
        switch region.Name
            case 'O'           % orange
                region.Color = [1, 0.6, 0];
            case 'T'           % cyan
                %             regionColor = [0, 1, 1]*0.8;
                region.Color = [0, 1, 1];
            case 'F'           % green
                %             regionColor = [0, 1, 0]*0.8;
                region.Color = [0, 1, 0];
            case 'PF'          % red
                %             regionColor = [1, 0, 0]*0.8;
                region.Color = [1, 0, 0];
            case 'C'           % pink
                region.Color = [1, 0.4, 0.6];
            case 'P'           % blue
                region.Color = [0, 0, 1];
            case 'L'           % brown
                region.Color = [0.8, 0.5, 0];
            otherwise
                % add warning message here
                disp('Warning: Region unknown')
                region.Color = [0.5, 0.5, 0.5];
                region.Name = '?';
        end
    else
        region.Color = cortex.Atlas(2).Scouts(m).Color;
    end
else
    region.Color = [1, 1, 1]*0.5;
    region.Name = '?';
end

end

function h=subtightplot(m,n,p,gap,marg_h,marg_w,varargin)
%function h=subtightplot(m,n,p,gap,marg_h,marg_w,varargin)
%
% Functional purpose: A wrapper function for Matlab function subplot. Adds the ability to define the gap between
% neighbouring subplots. Unfotrtunately Matlab subplot function lacks this functionality, and the gap between
% subplots can reach 40% of figure area, which is pretty lavish.
%
% Input arguments (defaults exist):
%   gap- two elements vector [vertical,horizontal] defining the gap between neighbouring axes. Default value
%            is 0.01. Note this vale will cause titles legends and labels to collide with the subplots, while presenting
%            relatively large axis.
%   marg_h  margins in height in normalized units (0...1)
%            or [lower uppper] for different lower and upper margins
%   marg_w  margins in width in normalized units (0...1)
%            or [left right] for different left and right margins
%
% Output arguments: same as subplot- none, or axes handle according to function call.
%
% Issues & Comments: Note that if additional elements are used in order to be passed to subplot, gap parameter must
%       be defined. For default gap value use empty element- [].
%
% Usage example: h=subtightplot((2,3,1:2,[0.5,0.2])

if (nargin<4) || isempty(gap),    gap=0.01;  end
if (nargin<5) || isempty(marg_h),  marg_h=0.05;  end
if (nargin<5) || isempty(marg_w),  marg_w=marg_h;  end
if isscalar(gap),   gap(2)=gap;  end
if isscalar(marg_h),  marg_h(2)=marg_h;  end
if isscalar(marg_w),  marg_w(2)=marg_w;  end
gap_vert   = gap(1);
gap_horz   = gap(2);
marg_lower = marg_h(1);
marg_upper = marg_h(2);
marg_left  = marg_w(1);
marg_right = marg_w(2);

%note n and m are switched as Matlab indexing is column-wise, while subplot indexing is row-wise :(
[subplot_col,subplot_row]=ind2sub([n,m],p);

% note subplot suppors vector p inputs- so a merged subplot of higher dimentions will be created
subplot_cols=1+max(subplot_col)-min(subplot_col); % number of column elements in merged subplot
subplot_rows=1+max(subplot_row)-min(subplot_row); % number of row elements in merged subplot

% single subplot dimensions:
%height=(1-(m+1)*gap_vert)/m;
%axh = (1-sum(marg_h)-(Nh-1)*gap(1))/Nh;
height=(1-(marg_lower+marg_upper)-(m-1)*gap_vert)/m;
%width =(1-(n+1)*gap_horz)/n;
%axw = (1-sum(marg_w)-(Nw-1)*gap(2))/Nw;
width =(1-(marg_left+marg_right)-(n-1)*gap_horz)/n;

% merged subplot dimensions:
merged_height=subplot_rows*( height+gap_vert )- gap_vert;
merged_width= subplot_cols*( width +gap_horz )- gap_horz;

% merged subplot position:
merged_bottom=(m-max(subplot_row))*(height+gap_vert) +marg_lower;
merged_left=(min(subplot_col)-1)*(width+gap_horz) +marg_left;
pos_vec=[merged_left merged_bottom merged_width merged_height];

% h_subplot=subplot(m,n,p,varargin{:},'Position',pos_vec);
% Above line doesn't work as subplot tends to ignore 'position' when same mnp is utilized
h=subplot('Position',pos_vec,varargin{:});

if (nargout < 1),  clear h;  end

end

function addSubtitleLegend(subplotNum,userInput,sInput,electrode_inds)
% put a useful title on each subplot
% get the channel information
% chLink = file_fullpath(sInput(subplotNum).ChannelFile);
chLink = file_fullpath(sInput(1).ChannelFile);
ch = load(chLink);
switch userInput.Graphtype
    case 1 % Outward Streamgraph
        thisTitle = title(sInput(subplotNum).Comment,'fontsize',8,'Interpreter','none');
        dashInd = find(thisTitle.String == '-');
        contact1 = strtok(thisTitle.String(dashInd-4:dashInd-1)); % referential
        contact1Label = ch.Channel(strcmp({ch.Channel.Name},contact1)).Comment;
        contact2 = strtok(thisTitle.String(dashInd+1:dashInd+4)); % referential
        contact2Label = ch.Channel(strcmp({ch.Channel.Name},contact2)).Comment;
        if isempty(contact1Label)
            contact1Label = '?';
        end
        switch contact1Label(1)
            case 'L'
                l = legend(contact1Label,contact2Label,'Location','North');
                %             case 'R'
                %                 l = legend(contact1Label,contact2Label,'Location','North');
            otherwise
                l = legend(contact1Label,contact2Label,'Location','North');
        end
        loc = l.Position;
        % temp patch for weird bug with F1979H2S data without N'11-N'12
        loc(loc<0) = 0;
        legend('off');
%         annotation('textbox',loc,'String',contact1Label,'FitBoxToText','on');
    case 2 % Inward Streamgraph
        %         title([ch.Channel(electrode_inds(subplotNum)).Name ' - ' ch.Channel(electrode_inds(subplotNum)).Comment])
        title(ch.Channel(electrode_inds(subplotNum)).Name)
        
end
end

function [h1, h2] = createSubplot(userInput,subplotNum,sInput,data,subplotData,F,Fcell,Inds,sorted,stimLocations,stimLocationColors,cortex,isCCEP,excludeContacts)

h1 = [];
h2 = [];
if ~any(any(stimLocations))
    noLocations = 1;
else
    noLocations = 0;
end
if ~isCCEP
    noLocations = 0;
end
% set the indexing for the window of data to plot over
if isempty(userInput.PlotWindow)
    thisWindow = Fcell{subplotNum};
    PlotWindowIndx = 1:size(thisWindow,2);
    %     PlotWindowIndx = 1:size(F,2);
else
    PlotWindowIndx = userInput.PlotWindow(1)+101:userInput.PlotWindow(2)+101;
%     PlotWindowIndx = panel_time('GetTimeIndices', data.Time, userInput.PlotWindow);
    %     tmpIndx1 = 1-(data.Time(1)*1000-userInput.PlotWindow(1));
    %     tmpIndx2 = size(F,2)-((data.Time(end)*1000)-userInput.PlotWindow(2));
    %     PlotWindowIndx = round(tmpIndx1:tmpIndx2);
end
% get the channel information (assumed equal for all input files)
chLink = file_fullpath(sInput(1).ChannelFile);
ch = load(chLink);
SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));

% % plotting onset and spread start
% chLink   = 'D:\ATLAS\private\matlab_code\ch.xlsx';
% [~,chData] = xlsread(chLink);
% % plotting onset and spread end
                            
switch userInput.Separate
    case 1 % separate left and right
        if ~isempty(subplotData.leftData)
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    Fout = Fcell{subplotNum};
                    %                     Xl = F(Inds.Left(sortedInds.Left),:,subplotNum);
                    Xl = Fout(Inds.Left(sorted.Inds.Left),:);
                    if ~userInput.isCCEP
                        for i = 1:size(Xl,1)
                            % there's a bug here - row of NaN data causes
                            % crash, temp try catch fix to get around it
                            try
                                Xl(i,:) = envelope(abs(Xl(i,:)),1000,'peak');
                            catch

                            end
                        end
                    else
                        Xl = abs(Xl);
                    end
                case 2 % Inward Streamgraph
                    Xl = abs(subplotData.leftData(sorted.Inds.Left,:));
            end
            %% region selection update
            
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    plot_locs = SEEGcontacts(Inds.Left(sorted.Inds.Left));
                    num_plot_locs = length(plot_locs);
                case 2 % Inward Streamgraph
                    plot_locs = stimLocations(sorted.Inds.Left,:);
                    num_plot_locs = size(plot_locs,1);
            end
            %             jetset = jet(num_plot_locs);
            leftRegions = cell(1,num_plot_locs);
            leftSelections = cell(1,num_plot_locs);
            
            for i = 1:num_plot_locs
                if noLocations
                    %                     h1(i).FaceColor = jetset(i,:);
                else
                    switch userInput.Graphtype
                        case 1 % Outward Streamgraph
                            region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
                            leftRegions{i} = region.Name;
                            leftSelections{i} = ch.Channel(plot_locs(i)).Comment;
                            %                             h1(i).FaceColor = region.Color;
                        case 2 % Inward Streamgraph
                            %                             h1(i).FaceColor = stimLocationColors(sortedInds.Left(i),:);
                    end
                end
            end
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    toPlot = zeros(1,length(leftRegions));
                    regions = {'PF','F','C','P','T','O','L','?'};
                    included = regions(userInput.Regions);
                    for k = 1:length(leftRegions)
                        toPlot(k) = any(strcmp(leftRegions(k),included));
                    end
                    toPlot = logical(toPlot);
                    selections = userInput.Selection;
                    if ~isempty(selections{1})
                        toPlot2 = zeros(1,length(leftSelections));
                        for m = 1:length(leftSelections)
                            toPlot2(m) = any(strcmp(leftSelections(m),userInput.Selection));
                        end
                        toPlot2 = logical(toPlot2);
                        toPlot = and(toPlot,toPlot2);
                    end
                    
                    Xl2 = Xl(toPlot,:);
                case 2 % Inward Streamgraph
                    Xl2 = Xl;
            end
            clear h1
            h1 = area(data.Time(PlotWindowIndx)*1000,Xl2(:,PlotWindowIndx)');
            
            % for loop to do subplots for left side of the brain
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    plot_locs = SEEGcontacts(Inds.Left(sorted.Inds.Left));
                    plot_locs = plot_locs(toPlot);
                    num_plot_locs = length(plot_locs);
                case 2 % Inward Streamgraph
                    plot_locs = stimLocations(sorted.Inds.Left,:);
                    num_plot_locs = size(plot_locs,1);
            end
            jetset = jet(num_plot_locs);
            leftRegions = cell(1,num_plot_locs);
            disp(' ')
            disp('left side contacts')
            disp(' ')
            for i = 1:num_plot_locs
                if noLocations
                    h1(i).FaceColor = jetset(i,:);
                else
                    switch userInput.Graphtype
                        case 1 % Outward Streamgraph
%                             keyboard
                            if ~excludeContacts(plot_locs(i))
%                                 disp([ch.Channel(plot_locs(i)).Name ' - ' ch.Channel(plot_locs(i)).Comment])
                                disp([ch.Channel(plot_locs(i)).Name ' - ' sprintf('%.10f',round(sorted.Vals.Left(i)*30000,2))])
                            end
                            region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
                            leftRegions{i} = region.Name;
                            h1(i).FaceColor = region.Color;
%                             % plotting onset and spread start
%                             thisInd = find(strcmp(chData(:,2),ch.Channel(plot_locs(i)).Name));
%                             h1(i).FaceColor = [0 0.5 0];
%                             switch chData{thisInd,5}
%                                 case 'Onset'
%                                     h1(i).FaceColor = [1 0 0];
%                                 case 'Early Spread'
%                                     h1(i).FaceColor = [1 0.5 0];
%                             end
%                             % plotting onset and spread end
                        case 2 % Inward Streamgraph
                            h1(i).FaceColor = stimLocationColors(sorted.Inds.Left(i),:);
%                              h1(i).FaceColor = [0 0 1];
                    end
                end
            end
            %%
            hold on
        end
        % check for contacts on the right side, plot if they exist
        
        if ~isempty(subplotData.rightData)
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    Fout = Fcell{subplotNum};
                    %                     Xr = F(Inds.Right(sortedInds.Right),:,subplotNum);
                    Xr = Fout(Inds.Right(sorted.Inds.Right),:);
                    if ~userInput.isCCEP
                        for i = 1:size(Xr,1)
                            Xr(i,:) = envelope(abs(Xr(i,:)),1000,'peak');
                        end
                    else
                        Xr = abs(Xr);
                    end
                case 2 % Inward Streamgraph
                    Xr = abs(subplotData.rightData(sorted.Inds.Right,:));
            end
            %% region selection update
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    plot_locs = SEEGcontacts(Inds.Right(sorted.Inds.Right));
                    num_plot_locs = length(plot_locs);
                case 2 % Inward Streamgraph
                    plot_locs = stimLocations(sorted.Inds.Right,:);
                    num_plot_locs = size(plot_locs,1);
            end
            jetset = jet(num_plot_locs);
            rightRegions = cell(1,num_plot_locs);
            rightSelections = cell(1,num_plot_locs);
            disp(' ')
            disp('right side contacts')
            disp(' ')
            for i = 1:num_plot_locs
                if noLocations
                    %                     h2(i).FaceColor = jetset(i,:);
                else
                    switch userInput.Graphtype
                        case 1 % Outward Streamgraph

                            region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
                            rightRegions{i} = region.Name;
                            rightSelections{i} = ch.Channel(plot_locs(i)).Comment;
                            %                             h2(i).FaceColor = region.Color;
                        case 2 % Inward Streamgraph
                            h2(i).FaceColor = stimLocationColors(sorted.Inds.Right(i),:);
%                             h2(i).FaceColor = [0 0 1];
                    end
                end
            end
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    toPlot = zeros(1,length(rightRegions));
                    regions = {'PF','F','C','P','T','O','L','?'};
                    included = regions(userInput.Regions);
                    for k = 1:length(rightRegions)
                        toPlot(k) = any(strcmp(rightRegions(k),included));
                    end
                    toPlot = logical(toPlot);
                    
                    selections = userInput.Selection;
                    if ~isempty(selections{1})
                        toPlot2 = zeros(1,length(rightSelections));
                        for m = 1:length(rightSelections)
                            toPlot2(m) = any(strcmp(rightSelections(m),userInput.Selection));
                        end
                        toPlot2 = logical(toPlot2);
                        toPlot = and(toPlot,toPlot2);
                    end
                    
                    Xr2 = Xr(toPlot,:);
                case 2 % Inward Streamgraph
                    Xr2 = Xr;
            end
            clear h2
%             h2 = area(data.Time(PlotWindowIndx)*1000,Xr2(:,PlotWindowIndx)');
            h2 = area(data.Time(PlotWindowIndx)*1000,-Xr2(:,PlotWindowIndx)');
            % this is the normal code above, temp switch for ride side only
            %             h2 = area(data.Time(PlotWindowIndx)*1000,Xr2(:,PlotWindowIndx)');
            % for loop to do subplots for right side of the brain
            switch userInput.Graphtype
                case 1 % Outward Streamgraph
                    plot_locs = SEEGcontacts(Inds.Right(sorted.Inds.Right));
                    plot_locs = plot_locs(toPlot);
                    num_plot_locs = length(plot_locs);
                case 2 % Inward Streamgraph
                    plot_locs = stimLocations(sorted.Inds.Right,:);
                    num_plot_locs = size(plot_locs,1);
            end
            jetset = jet(num_plot_locs);
            rightRegions = cell(1,num_plot_locs);
            for i = 1:num_plot_locs
                if noLocations
                    h2(i).FaceColor = jetset(i,:);
                else
                    switch userInput.Graphtype
                        case 1 % Outward Streamgraph
                            if ~excludeContacts(plot_locs(i))
%                                 disp([ch.Channel(plot_locs(i)).Name ' - ' ch.Channel(plot_locs(i)).Comment])
                                disp([ch.Channel(plot_locs(i)).Name ' - ' sprintf('%.10f',round(sorted.Vals.Right(i)*30000,2))])
%                                 fprintf('%.10f\n',sorted.Vals.Right(i))
                            end
                            region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
                            rightRegions{i} = region.Name;
                            h2(i).FaceColor = region.Color;
%                             % plotting onset and spread start
%                             thisInd = find(strcmp(chData(:,2),ch.Channel(plot_locs(i)).Name));
%                             h2(i).FaceColor = [0 0.5 0];
%                             switch chData{thisInd,5}
%                                 case 'Onset'
%                                     h2(i).FaceColor = [1 0 0];
%                                 case 'Early Spread'
%                                     h2(i).FaceColor = [1 0.5 0];
%                             end
%                             % plotting onset and spread end
                        case 2 % Inward Streamgraph
                            h2(i).FaceColor = stimLocationColors(sorted.Inds.Right(i),:);
%                             h2(i).FaceColor = [0 0 1];
                    end
                end
            end
            %%
            hold off
        end
    case 2 % don't separate left and right
        switch userInput.Graphtype
            case 1 % Outward Streamgraph
                %                 X = abs(F(Inds.All(sortedInds.All),:,subplotNum));
                X = abs(Fout(Inds.All(sorted.Inds.All),:));
            case 2 % Inward Streamgraph
                X = abs(subplotData.leftData(sorted.Inds.All,:));
        end
        h1 = area(data.Time(PlotWindowIndx)*1000,X(:,PlotWindowIndx)');
        % for loop to do subplots for left side of the brain
        switch userInput.Graphtype
            case 1 % Outward Streamgraph
                plot_locs = SEEGcontacts(Inds.All);
                num_plot_locs = length(plot_locs);
            case 2 % Inward Streamgraph
                plot_locs = stimLocations(sorted.Inds.All,:);
                num_plot_locs = size(plot_locs,1);
        end
        jetset = jet(num_plot_locs);
        allRegions = cell(1,num_plot_locs);
        for i = 1:num_plot_locs
            if noLocations
                h1(i).FaceColor = jetset(i,:);
            else
                switch userInput.Graphtype
                    case 1 % Outward Streamgraph
                        region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
                        allRegions{i} = region.Name;
                        h1(i).FaceColor = region.Color;
                    case 2 % Inward Streamgraph
                        h1(i).FaceColor = stimLocationColors(sorted.Inds.All(i),:);
                end
            end
        end
end
end
