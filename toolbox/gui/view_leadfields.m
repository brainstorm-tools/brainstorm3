function hFig = view_leadfields(bstNodes)
% VIEW_LEADFIELDS: Show all the leadfield vectors from a "Gain matrix" of the forward model.
% 
% USAGE:  hFig = view_leadfields(bstNodes)
%                 bstNodes : liste of the selected nodes from the
%                 brainstomr GUI
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
% Authors: Takfarinas MEDANI, 2020

% more details : https://www.researchgate.net/publication/260603026_Biomagnetism
%                       http://www.bem.fi/book/11/11x/1119x.htm        

%% ===== PARSE INPUTS =====
ProtocolInfo = bst_get('ProtocolInfo');
% number of selected files
nbSelectedFiles = length(bstNodes);
% assuming 7 values of colors the display 7 values of LF
indexColor = [0 0 1; 1 0 1;...
    0 1 0; 1 1 0;...
    0 1 1; 1 1 1;...
    1 0 0];
if nbSelectedFiles > length(indexColor)
    error('Too much files ... ')
end

%% Get the data selected from all the nodes
X = []; Y = []; Z = []; LF_finale = []; ChannelFile =[]; Channel =[];
for indFile = 1 :  nbSelectedFiles
    %% Get study description
    iStudy = bstNodes(indFile).getStudyIndex();
    sStudy = bst_get('Study', iStudy);
    
    %%% Get Head model data
    iHeadModel = bstNodes(indFile).getItemIndex();
    HeadModelFileNames{indFile} = fullfile(ProtocolInfo.STUDIES, sStudy.HeadModel(iHeadModel).FileName);
    % Get the size of the Lead field matrix
    data = whos('-file', HeadModelFileNames{indFile}); % headModelData{indFile} = load(HeadModelFileNames{indFile})
    index = find(strcmp({data.name}, 'Gain')==1); % to check       data(index).name
    sizeOfGainMatrix{indFile} =  data(index).size; %
    index = find(strcmp({data.name}, 'SurfaceFile')==1); % to check       data(index).name
    sourceSpaceFile = load(HeadModelFileNames{indFile},'SurfaceFile');
    
    %%% Get the modalities used in this study
    isEEG(indFile) = ~isempty(sStudy.HeadModel(iHeadModel).EEGMethod);
    isMEG(indFile) = ~isempty(sStudy.HeadModel(iHeadModel).MEGMethod);
    isSEEG(indFile) = ~isempty(sStudy.HeadModel(iHeadModel).SEEGMethod);
    isECOG(indFile) = ~isempty(sStudy.HeadModel(iHeadModel).ECOGMethod);
    
    %%% Get channel data
    ChannelFile{indFile} = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Channel.FileName);
    data = whos('-file', ChannelFile{indFile});
    index = find(strcmp({data.name}, 'Channel')==1); % to check       data(index).name
    sizeOfSensorSpace(indFile) =  data(index).size(2); %
    
    %%% Get source space data
    % Source Space file name : Cortex File
    CortexModelFile{indFile}  = bst_fullfile(ProtocolInfo.SUBJECTS,sourceSpaceFile.SurfaceFile);
    data = whos('-file', CortexModelFile{indFile});
    index = find(strcmp({data.name}, 'Vertices')==1); % to check       data(index).name
    sizeOfSourceSpace(indFile) =  3*data(index).size(1); % multiply by 3 for unconstrained source
    
    %%% Check the size of the different data
    if (sizeOfGainMatrix{indFile}(1) ~= sizeOfSensorSpace(indFile)) && ...
            (sizeOfGainMatrix{indFile}(2) ~= sizeOfSourceSpace(indFile))
        error('The size of the LeadField Matrix does not match the number of source and sensors');
    end
    
    if indFile >1
        %         % TODO : does it make sens to compare different LF comming from different source space and sensor??
        %         if sum(sizeOfGainMatrix{indFile} == sizeOfGainMatrix{indFile-1}) ~= 2
        %             warning('The two head models are differents');
        %         end
    end
    
    %% Load the data
    %%% Load the LeadFIled
    headModelData{indFile}  = load(HeadModelFileNames{indFile});
    % LF(indFile) = {headModelData{indFile}.Gain(iEeg{indFile},:)}; LFnames(indFile) = {headModelData{indFile}.Comment }; LFcolor(indFile) = {indxColor(indFile,:)};
    LF(indFile) = {headModelData{indFile}.Gain};
    pathparts = strsplit(headModelData{indFile}.SurfaceFile,'/'); % use filesep intead of /...
    LFnames(indFile).Comment =headModelData{indFile}.Comment;
    LFnames(indFile).EEGMethod = headModelData{indFile}.EEGMethod;
    LFnames(indFile).MEGMethod = headModelData{indFile}.MEGMethod;
    LFnames(indFile).ECOGMethod = headModelData{indFile}.ECOGMethod;
    LFnames(indFile).SEEGMethod =headModelData{indFile}.SEEGMethod;
    LFnames(indFile).Comment = headModelData{indFile}.Comment;
    LFcolor(indFile) = {indexColor(indFile,:)};
    %%% load the Cortex in the case where they are differents
    % channelModelData{indFile}  = load(ChannelFile{indFile});
    cortexModelData{indFile}  = load(CortexModelFile{indFile} );
    % Source Space
    GridLoc{indFile} = cortexModelData{indFile}.Vertices';
    % % sensor locations
    % SensorLoc{indFile} = sensorLocalisation{indFile}';
    % [hFig, iDS, iFig] =
    % view_surface(CortexModelFile{indFile})
    SurfaceFile{indFile} = CortexModelFile{indFile};    
    % convenient for plotting command later
    X{indFile} = GridLoc{indFile}(1,:);Y{indFile} = GridLoc{indFile}(2,:); Z{indFile}=GridLoc{indFile}(3,:);
end

%% Check the difference on the source space and on the sensor space
if indFile > 1
    iTest = 1;
    while (iTest<=indFile -1)
        if sizeOfSourceSpace(iTest) == sizeOfSourceSpace(iTest+1)
            isSameSourceSpace(iTest) = 1;
        else
            isSameSourceSpace(iTest) = 0;
        end
        
        if sizeOfSensorSpace(iTest) == sizeOfSensorSpace(iTest+1)
            isSameSensorSpace(iTest) = 1;
        else
            isSameSensorSpace(iTest) = 0;
        end
        iTest  =  iTest  +1;
    end
    
    if sum(find(isSameSensorSpace == 0))
        isSameSensorSpace = 0;
        error('The overlay of models with different sensor location is not supported')
    else
        isSameSensorSpace = 1;
    end
    
    if sum(find(isSameSourceSpace == 0))
        isSameSourceSpace = 0;
        warning('The overlay of models with different source space location is not recommended');
        warning('Brainstrom will display only the source space of the first selected subject ')
        [res, isCancel] =java_dialog('confirm', ['<HTML><B> The overlay of models with different cortex is not recommended </B> <BR>' ...
            '<B>Brainstrom will display only the cortex of the first selected subject<BR>' ]);
        if res == 0
            return;
        end
    else
        isSameSourceSpace = 1;
    end
else
    isSameSourceSpace = 1;
    isSameSensorSpace = 1;
end

%% Ask the user for the modality to display
selectedModality =[];
selectModality()
if isempty(selectedModality)
    return;
end
%%% Get Channel index and location per modalities:
% Assuming that all the data has the same channeles ,
%%% Load only one file for sensor
indFile = 1; 
getLeadField()

%%Ask the user for the reference for the reference electrode to use
ref_mode = []; iref =[];
selectReference()

%% Plotting
% Start from here the display of the lead field
hFig = [];
SurfAlpha = 0.5;
SurfColor = [0.5 0.5 0.5] ;
% add a warning about the surface files if they are not the same
hFig = view_surface(SurfaceFile{1}, SurfAlpha, SurfColor, hFig);
h = zeros(length(LF),1);
LeadField = cell(length(LF),1);
if isempty(hFig)
    error('No reference surface available');
end
hold on
% Set orientation: left
figure_3d('SetStandardView', hFig, 'left');
% Update figure name
set(hFig, 'Name', ['Display Lead FIeld : ' HeadModelFileNames{indFile}]);
% Get axes handles
hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

%% ===== Hack keyboard callback =====
KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
set(hFig, 'KeyPressFcn', @KeyPress_Callback);
% Create legend
hLabel = uicontrol('Style',               'text', ...
    'String',              '...', ...
    'Units',               'Pixels', ...
    'Position',           [6 20 400 18], ...
    'HorizontalAlignment', 'left', ...
    'FontUnits',           'points', ...
    'FontSize',            bst_get('FigFont'), ...
    'ForegroundColor',     [.3 1 .3], ...
    'BackgroundColor',     [0 0 0], ...
    'Parent',              hFig);


if length(Channel) > 10
    markersLocs   = cell2mat(cellfun(@(c)c(:,1), {Channel.Loc}, 'UniformOutput', 0))';
end
%% ===== DISPLAY SENSORS =====
% Current sensor
iChannel = 1;
DrawArrows()

%% ===== KEYBOARD CALLBACK =====
    function KeyPress_Callback(h, keyEvent)
        switch (keyEvent.Key)
            % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow  ===
            case {'leftarrow', 'space', 'uparrow'}
                iChannel = iChannel - 1;
            case 'pagedown'
                iChannel = iChannel - 10;
            case {'rightarrow', 'downarrow'}
                iChannel = iChannel + 1;
            case 'pageup'
                iChannel = iChannel + 10;
            case 'r' %% not for MEG
                selectReference()
            case 'v'
                if ~isempty(findobj(h, 'Tag', 'SetVertices'))
                    delete(findobj(h, 'Tag', 'SetVertices'))
                else
                    hold on;
                    h = plot3(X{1},Y{1},Z{1},'r.','Parent', hAxes, 'Tag', 'SetVertices');
                end
            case 'c'
                hold on;
                % Plot sensors
                if ~isempty(findobj(hAxes, 'Tag', 'allChannel'))
                    delete(findobj(hAxes, 'Tag', 'allChannel'))
                else
                    if length(Channel) > 10
                        hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
                        set(hSensors, 'LineWidth', 1, 'MarkerSize', 5,'Tag','allChannel');
                    end
                end
            case 'm'
                selectModality()
                getLeadField()
                if length(Channel) > 10
                    markersLocs   = cell2mat(cellfun(@(c)c(:,1), {Channel.Loc}, 'UniformOutput', 0))';
                end
                if ~isempty(findobj(hAxes, 'Tag', 'allChannel'))
                    delete(findobj(hAxes, 'Tag', 'allChannel'))
                end
            case 'h'
                disp('Keyboard shortcut help')
                java_dialog('msgbox', ['<HTML><B> Lead Field Arrow : keyboard shortcut help </B> <BR>' ...
                    '<B>left arrow,  space or up arrow :</B> highlight previous channel<BR>' ....
                    '<B>right arrow, down arrow :</B> highlight next channel<BR>'....
                    '<B>page down :</B> highlight next 10th channel<BR>'....
                    '<B>page up :</B> highlight previous 10th channel<BR>'....
                    '<B>R :</B> change the <B>R</B>eference electrode<BR>'....
                    '<B>V :</B> display or hide the cortex <B>V</B>ertices<BR>'....
                    '<B>C :</B> display or hide the <B>C</B>hannels<BR>'....
                    '<B>M :</B> change/select <B>M</B>odality (MEG, EEG, SEEG, ECOG)<BR>'....
                    '<B>H :</B> display this <B>H</B>elp :)<BR>']);
            otherwise
                KeyPressFcn_bak(h, keyEvent);
                return;
        end
        % Redraw Channel
        if (iChannel <= 0)
            iChannel = length(Channel);
        end
        if (iChannel > length(Channel))
            iChannel = 1;
        end
        DrawArrows()
    end

%% ===== DRAW CURRENT CHANNEL =====
    function DrawArrows()
        % Delete previous Channels and sensors
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'lfArrows'));
        %         % Draw current LF
        %         ref_mode
        for imodel = 1 : length(LF_finale)
            hold on
            if ~strcmp(selectedModality,'MEG')
                switch ref_mode % {'avgref','ref'}
                    case 'ref'
                        LeadField{imodel} = LF_finale{imodel}(iChannel,:) - LF_finale{imodel}(iref,:); %  leadfield row
                        if strcmpi(selectedModality,'EEG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality  ' LF vectors, ' LFnames(imodel).EEGMethod ' / Ref : ' Channel(iref).Name ];
                        end
                        if strcmpi(selectedModality,'ECOG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality ' LF vectors, ' LFnames(imodel).ECOGMethod ' / Ref : ' Channel(iref).Name ];
                        end
                        if strcmpi(selectedModality,'SEEG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality  ' LF vectors, ' LFnames(imodel).EEGMethod ' / Ref : ' Channel(iref).Name ];
                        end
                    case 'avgref'
                        AvgRef = mean(LF_finale{imodel},1);
                        LeadField{imodel} = LF_finale{imodel}(iChannel,:) - AvgRef; %  leadfield row
                        if strcmpi(selectedModality,'EEG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality  ' LF vectors, ' LFnames(imodel).EEGMethod  ' / Ref : Avrg' ];
                        end
                        if strcmpi(selectedModality,'ECOG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality ' LF vectors, ' LFnames(imodel).ECOGMethod  ' / Ref : Avrg' ];
                        end
                        if strcmpi(selectedModality,'SEEG')
                            strLegend{imodel} = [pathparts{1} ' : ' selectedModality ' LF vectors, ' LFnames(imodel).EEGMethod  ' / Ref : Avrg' ];
                        end
                end
            else % case MEG
                LeadField{imodel} = LF_finale{imodel}(iChannel,:);
                strLegend{imodel} = [pathparts{1} ' : ' selectedModality  ' LF vectors, ' LFnames(imodel).MEGMethod ];
                if ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'))
                    delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
                end
            end
            LeadField{imodel} = reshape(LeadField{imodel},3,[]); % each column is a vector
            U = LeadField{imodel}(1,:);
            V = LeadField{imodel}(2,:);
            W =LeadField{imodel}(3,:); % convenient
            h(imodel) = quiver3(X{imodel},Y{imodel},Z{imodel},U,V,W, 5);
            set(h(imodel),'linewidth',1,'color',LFcolor{imodel},'linewidth',1);
        end
        
        set(h, 'Parent',    hAxes, ...
            'LineWidth', 1, ...
            'Tag',       'lfArrows');
        % Remove previous selected sensor
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelChannel'));
        % Plot selected sensor
        if ~isempty(Channel(iChannel).Loc) && ~ismember(Channel(iChannel).Name, {'EEG','MEG','MEG MAG', 'MEG GRAD'})
            line(Channel(iChannel).Loc(1,1), Channel(iChannel).Loc(2,1), Channel(iChannel).Loc(3,1), ...
                'Parent',          hAxes, ...
                'LineWidth',       2, ...
                'LineStyle',       'none', ...
                'Marker',          'o', ...
                'MarkerFaceColor', [1 0 0], ...
                'MarkerEdgeColor', [.4 .4 .4], ...
                'MarkerSize',      8, ...
                'Tag',             'SelChannel');
        end
        if ~strcmp(selectedModality,'MEG')
            switch ref_mode
                case 'ref'
                    % Plot the reference electrode
                    if ~isempty(Channel(iref).Loc) && ~ismember(Channel(iref).Name, {'EEG','MEG','MEG MAG', 'MEG GRAD'})
                        line(Channel(iref).Loc(1,1), Channel(iref).Loc(2,1), Channel(iref).Loc(3,1), ...
                            'Parent',          hAxes, ...
                            'LineWidth',       2, ...
                            'LineStyle',       'none', ...
                            'Marker',          '*', ...
                            'MarkerFaceColor', [0 1 1], ...
                            'MarkerEdgeColor', [.4 .8 .4], ...
                            'MarkerSize',      8, ...
                            'Tag',             'RefChannel');
                    end
                case 'avgref'
                    % Remove previous selected reference
                    delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
            end
        end
        % Update legend
        newLegend = sprintf('Channel #%d/%d  (%s)', iChannel, length(Channel), Channel(iChannel).Name);
        if (iChannel == 1) && (length(Channel) > 1)
            newLegend = [newLegend, '       [Press arrows for next/previous Channel... (or H for help)]'];
        end
        set(hLabel, 'String', newLegend,'Position',[10 1 1200 35]);
        legend(h,strLegend, 'TextColor','w','fontsize',12,'interpreter','none');  legend('boxoff')
    end

%% Set the reference
    function selectReference
        if ~strcmp(selectedModality,'MEG')
            referenceMode =  {'avgref','ref'}; % ask the user
            modality = { ' Yes, use average reference'};
            [res, isCancel] = java_dialog('checkbox', ...
                ['<HTML><B> Do you want to use the average refence for the ' selectedModality ' ?'...
                '<BR>Otherwise you will choose one reference electrode <B>'], ['Select Reference: ' selectedModality], [], ...
                modality, [ones(1, 1)]);
            if isCancel ==1
                return;
            end
            if res == 1
                ref_mode = referenceMode{1};
            else
                ref_mode = referenceMode{2};
                % Ask for the reference electrode
                [res, isCancel] =  java_dialog('input', ...
                    ['Set the reference electrode [1 , '  num2str(size(LF_finale{1},1)) ' ] : '], ...
                    ['Select Reference: ' selectedModality], [], '1');
                if isCancel ==1
                    return;
                end
                % This is the reference electrode
                iref = str2num(res);
            end
        end
    end

    function  selectModality
        allModalities = {'EEG', 'MEG','sEEG','ECOG',}; % 1: EEG, 2 : MEG, 3 : sEEG, 4 : ECOG
        notAvailable = [];
        if isEEG == 0; notAvailable = [notAvailable, 1];end
        if isMEG == 0; notAvailable = [notAvailable, 2] ;end
        if isSEEG == 0; notAvailable = [notAvailable, 3];end
        if isECOG == 0; notAvailable = [notAvailable, 4] ;end
        allModalities(notAvailable) = '';
        [selectedModality, isCancel] =  java_dialog('question', '<HTML><B> Select the modality <B>', ...
            'Display the Lead Field', [],allModalities, allModalities{1});
        if isCancel ==1
            return;
        end
    end

    function getLeadField
        channelModelData{indFile}  = load(ChannelFile{indFile});
        % cortexModelData{indFile}  = load(CortexModelFile{indFile});
        %%% Get only the good channels for the selected modality;
        if isMEG(indFile) && strcmpi(selectedModality,'MEG')
            iMeg{indFile}   = good_channel(channelModelData{indFile}.Channel,[],'MEG');
            % Get the 3D location of the channels
            megloc{indFile}  = cat(2, channelModelData{indFile}.Channel(iMeg{indFile} ).Loc)';
            goodChannel = iMeg;
            %     sensorLocalisation = megloc;
        end
        
        if isEEG(indFile) && strcmpi(selectedModality,'EEG')
            iEeg{indFile}   = good_channel(channelModelData{indFile}.Channel,[],'EEG');
            % Get the 3D location of the channels
            eegloc{indFile}  = cat(2, channelModelData{indFile}.Channel(iEeg{indFile} ).Loc)';
            goodChannel = iEeg;
            %     sensorLocalisation = eegloc;
        end
        
        if isECOG(indFile) && strcmpi(selectedModality,'ECOG')
            iEcog{indFile}  = good_channel(channelModelData{indFile}.Channel,[],'ECOG');
            % Get the 3D location of the channels
            ecogloc{indFile}  = cat(2, channelModelData{indFile}.Channel(iEcog{indFile} ).Loc)';
            goodChannel = iEcog;
            %     sensorLocalisation = ecogloc;
        end
        
        if isSEEG(indFile) && strcmpi(selectedModality,'SEEG')
            iSeeg{indFile}  = good_channel(channelModelData{indFile}.Channel,[],'SEEG');
            % Get the 3D location of the channels
            seegloc{indFile}  = cat(2, channelModelData{indFile}.Channel(iSeeg{indFile} ).Loc)';
            goodChannel = iSeeg;
            %     sensorLocalisation = seegloc;
        end
        
        % Load Channels
        Channel = channelModelData{indFile}.Channel;
        Channel = Channel(goodChannel{indFile});    
        
        % Update the LF according to the selected channels only
        for  indLF = 1 : length(LF)
            LF_finale{indLF} = LF{indLF}(goodChannel{indFile},:);
        end
    end
end
