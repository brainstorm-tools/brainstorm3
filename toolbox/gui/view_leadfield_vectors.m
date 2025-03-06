function hFig = view_leadfield_vectors(HeadmodelFiles, Modality)
% VIEW_LEADFIELD_VECTORS: Show all the leadfield vectors from a "Gain matrix" of the forward model.
% 
% USAGE:  hFig = view_leadfield_vectors(HeadmodelFiles, Modality=[ask])
%
% DOCUMENTATION:
%    - https://www.researchgate.net/publication/260603026_Biomagnetism
%    - http://www.bem.fi/book/11/11x/1119x.htm   

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
% Authors: John Mosher, Takfarinas Medani, Francois Tadel, 2020
%               Juan Garcia-Prieto : add logarithmic scale for LF vectors  

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(Modality)
    Modality = [];
end
if ischar(HeadmodelFiles)
    HeadmodelFiles = {HeadmodelFiles};
end

%% ===== GET DATA =====
LF_finale = [];
HeadmodelMat = cell(1, length(HeadmodelFiles));
SubjectName = cell(1, length(HeadmodelFiles));
CortexSurface = [];
ChannelMat = [];
Channels = [];
iChannels = [];
allModalities = {'EEG', 'MEG', 'SEEG', 'ECOG'};
markersLocs = [];
bst_progress('start', 'View leadfields', 'Loading headmodels...');
for iFile = 1:length(HeadmodelFiles)
    % Get study description
    [sStudy, iStudy, iHeadModel] = bst_get('HeadModelFile', HeadmodelFiles{iFile});
    % Load lead field matrix
    HeadmodelMat{iFile} = in_bst_headmodel(HeadmodelFiles{iFile});
    % Check the dimensions of the leadfield
    if (iFile >= 2)
        if (size(HeadmodelMat{iFile}.Gain,1) ~= size(HeadmodelMat{1}.Gain,1))
            error('The files have different numbers of sensors.');
        elseif (size(HeadmodelMat{iFile}.Gain,2) ~= size(HeadmodelMat{1}.Gain,2))
            warning(['The overlay of models with different source spaces is not recommended.' 10 ...
                'Only the source space of the first file will be displayed.']);
        end
    end

    % Get the modalities used in this study
    if isempty(sStudy.HeadModel(iHeadModel).EEGMethod)
        allModalities = setdiff(allModalities, 'EEG');
    end
    if isempty(sStudy.HeadModel(iHeadModel).MEGMethod)
        allModalities = setdiff(allModalities, 'MEG');
    end
    if isempty(sStudy.HeadModel(iHeadModel).SEEGMethod)
        allModalities = setdiff(allModalities, 'SEEG');
    end
    if isempty(sStudy.HeadModel(iHeadModel).ECOGMethod)
        allModalities = setdiff(allModalities, 'ECOG');
    end

    % Load channel file
    if (iFile == 1)
        ChannelMat = in_bst_channel(sStudy.Channel.FileName, 'Channel');
    else
        newChanMat = in_bst_channel(sStudy.Channel.FileName, 'Channel');
        if ~isequal({ChannelMat.Channel.Name}, {newChanMat.Channel.Name})
            error('The files have different lists of channels.');
        end
    end
    SubjectName{iFile} = bst_fileparts(bst_fileparts(sStudy.Channel.FileName));

    % Get surface file to display in the figure
    if isempty(CortexSurface) && ~isempty(HeadmodelMat{iFile}.SurfaceFile)
        CortexSurface = HeadmodelMat{iFile}.SurfaceFile;
    end
    % Load the source space
    if isempty(HeadmodelMat{iFile}.GridLoc)
        TessMat = in_tess_bst(HeadmodelMat{iFile}.SurfaceFile);
        HeadmodelMat{iFile}.GridLoc = TessMat.Vertices;
    end
end
if isempty(allModalities)
    error('No modality available for all the files.');
end


%% ===== SELECT MODALITY/REFERENCE =====
% Ask modality + EEG reference
selectedModality = [];
isAvgRef = 1; 
iRef = [];
if ~SelectModality(Modality)
    bst_progress('stop');
    return;
end
% Update current lead fields
GetLeadField();


%% ===== DISPLAY =====
% Display cortex surface
SurfAlpha = 0.5;
SurfColor = [0.5 0.5 0.5] ;
hFig = view_surface(CortexSurface, SurfAlpha, SurfColor, 'NewFigure');
if isempty(hFig)
    error('No reference surface available');
end
hold on
% Hide scouts
scoutsOptions = panel_scout('GetScoutsOptions');
panel_scout('SetScoutsOptions', scoutsOptions.overlayScouts, scoutsOptions.overlayConditions, scoutsOptions.displayAbsolute, 'none');
% Set orientation: left
figure_3d('SetStandardView', hFig, 'left');
% Update figure name
set(hFig, 'Name', ['Leadfield: ' HeadmodelFiles{1}]);
% Get axes handles
hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
ColorOrder = get(hAxes, 'ColorOrder');
% Initialize list of quiver objects
hQuiver = zeros(length(HeadmodelFiles),1);
% Hack keyboard callback
KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
set(hFig, 'KeyPressFcn', @KeyPress_Callback);

% Create legend
hLabel = uicontrol('Style', 'text', ...
    'String',              '...', ...
    'Units',               'Pixels', ...
    'Position',            [6 20 400 18], ...
    'HorizontalAlignment', 'left', ...
    'FontUnits',           'points', ...
    'FontSize',            bst_get('FigFont'), ...
    'ForegroundColor',     [.3 1 .3], ...
    'BackgroundColor',     [0 0 0], ...
    'Parent',              hFig);

%% ===== DISPLAY LEADFIELD =====
% Current sensor
useLogScale = false;
useLogScaleLegendMsg = 'Off';
iChannel = 1;
% initial value for the quiver display
quiverSize = 1;
quiverWidth = 1;
thresholdAmplitude = 1; % ratio of the amplitude
thresholdBalance = 0; % orientation of the threshold "<" or " >"
DrawArrows();
bst_progress('stop');

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================

%% ===== KEYBOARD CALLBACK =====
    function KeyPress_Callback(hFig, keyEvent)
        switch (keyEvent.Key)
            % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow  ===
            case {'leftarrow',} 
                if ismember('shift', keyEvent.Modifier)
                    quiverSize = quiverSize /1.2;
                elseif ismember('control', keyEvent.Modifier)
                    quiverWidth = quiverWidth /1.2;
                elseif ismember('alt', keyEvent.Modifier)
                    thresholdAmplitude = thresholdAmplitude - 0.01;
                else
                    iChannel = iChannel - 1; 
                end
            case {'rightarrow'}
                 if ismember('shift', keyEvent.Modifier)
                    quiverSize = quiverSize * 1.2;
                 elseif ismember('control', keyEvent.Modifier)
                     quiverWidth = quiverWidth * 1.2;
                elseif ismember('alt', keyEvent.Modifier)
                    thresholdAmplitude = thresholdAmplitude + 0.01;
                 else
                     iChannel = iChannel + 1;
                 end
            case 'uparrow'
                if ismember('shift', keyEvent.Modifier)
                    quiverSize = quiverSize * 1.2;
                elseif ismember('control', keyEvent.Modifier)
                    quiverWidth = quiverWidth * 1.2;
                elseif ismember('alt', keyEvent.Modifier)
                    thresholdAmplitude = thresholdAmplitude + 0.01;
                 else                   
                    if ~isempty(iRef)
                        iRef = iRef + 1;
                    end
                end
            case 'downarrow'
                if ismember('shift', keyEvent.Modifier)
                    quiverSize = quiverSize / 1.2;
                 elseif ismember('control', keyEvent.Modifier)
                    quiverWidth = quiverWidth / 1.2;
                elseif ismember('alt', keyEvent.Modifier)
                    thresholdAmplitude = thresholdAmplitude - 0.01;
                 else
                    if ~isempty(iRef)
                        iRef = iRef - 1;
                    end
                end
            case 'r' %% not for MEG
                SelectReference();
            case 't' %% not for MEG
                SelectTarget();
            case 's'
                if ~isempty(findobj(hFig, 'Tag', 'SetVertices'))
                    delete(findobj(hFig, 'Tag', 'SetVertices'))
                else
                    plot3(HeadmodelMat{1}.GridLoc(:,1), HeadmodelMat{1}.GridLoc(:,2), HeadmodelMat{1}.GridLoc(:,3), 'r.', ...
                        'Parent', hAxes, ...
                        'Tag', 'SetVertices');
                end
            case 'e'
                if ~ismember('shift', keyEvent.Modifier)
                    % Plot sensors
                    if ~isempty(findobj(hAxes, 'Tag', 'allChannel'))
                        delete(findobj(hAxes, 'Tag', 'allChannel'))
                    else
                        if length(Channels) > 10
                            hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
                            set(hSensors, 'LineWidth', 1, 'MarkerSize', 5,'Tag','allChannel');
                        end
                    end
                else
                    % Plot sensors name
                    if ~isempty(findobj(hAxes, 'Tag', 'allChannelName'))
                        delete(findobj(hAxes, 'Tag', 'allChannelName'))
                    else
                        if length(Channels) > 10
                            %hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
                            %set(hSensors,'Tag','allChannelName');
                            channelAllName = cell(length(Channels),1);
                            for iChan = 1 : length(Channels)
                                channelAllName{iChan} = Channels(iChan).Name;
                            end
                            text(markersLocs(:,1), markersLocs(:,2), markersLocs(:,3),channelAllName,...
                                'color','y',...
                                'Parent', hAxes, ...
                                'Tag', 'allChannelName');
                        end
                    end
                end
            case 'm'
                if ~SelectModality()
                    return;
                end
                GetLeadField();
                if ~isempty(findobj(hAxes, 'Tag', 'allChannel'))
                    delete(findobj(hAxes, 'Tag', 'allChannel'))
                end
           
            case 'l'
                if ismember('shift', keyEvent.Modifier)
                    useLogScale = ~useLogScale;
                    if (useLogScale)
                        useLogScaleLegendMsg = 'On';
                    else
                        useLogScaleLegendMsg = 'Off';
                    end
                end
                
             case 'return'
                if ismember('shift', keyEvent.Modifier)
                    useLogScale = ~useLogScale;
                    if (useLogScale)
                        useLogScaleLegendMsg = 'On';
                    else
                        useLogScaleLegendMsg = 'Off';
                    end
                elseif ismember('alt', keyEvent.Modifier)
                     thresholdBalance = ~thresholdBalance;
                else
                    return;    
                end
            case 'h'
                java_dialog('msgbox', ['<HTML><TABLE>' ...
                    '<TR><TD><B>Left arrow</B></TD><TD>Previous target channel (red color)</TD></TR>' ....
                    '<TR><TD><B>Right arrow</B></TD><TD>Next target channel (red color)</TD></TR>'....
                    '<TR><TD><B>Up arrow</B></TD><TD>Previous ref channel (green color)</TD></TR>'....
                    '<TR><TD><B>Down arrow</B></TD><TD>Next ref channel (green color)</TD></TR>'....
                    '<TR><TD><B>Shift + uparrow</B></TD><TD>Increase the vector length</TD></TR>'...
                    '<TR><TD><B>Shift + downarrow</B></TD><TD>Decrease the vector length</TD></TR>'...                   
                    '<TR><TD><B>Shift + L</B></TD><TD>Toggle on/off logarithmic scale</TD></TR>'...
                    '<TR><TD><B>Control + uparrow</B></TD><TD>Increase the vector width</TD></TR>'...
                    '<TR><TD><B>Control + downarrow</B></TD><TD>Decrease the vector width</TD></TR>'... 
                    '<TR><TD><B>Alt + Enter </B></TD><TD>Toggle to superior/inferior for LF threshold</TD></TR>'...
                    '<TR><TD><B>Alt + uparrow </B></TD><TD>Increase Amplitude threshold</TD></TR>'...
                    '<TR><TD><B>Alt + downarrow </B></TD><TD>Decrease Amplitude threshold</TD></TR>'...
                    '<TR><TD><B>M</B></TD><TD>Change the <B>M</B>odality (MEG, EEG, SEEG, ECOG)</TD></TR>'....
                    '<TR><TD><B>R</B></TD><TD>Select the <B>R</B>eference channel</TD></TR>'....
                    '<TR><TD><B>T</B></TD><TD>Select the <B>T</B>arget channel</TD></TR>'....
                    '<TR><TD><B>S</B></TD><TD>Show/hide the source grid</TR>'....
                    '<TR><TD><B>E</B></TD><TD>Show/hide the sensors</TD></TR>'...
                    '<TR><TD><B>Shift + E</B></TD><TD>Show/hide the sensors labels</TD></TR>'...
                    '<TR><TD><B>0 to 9</B></TD><TD>Change view</TD></TR>'...
                    '</TABLE>'], 'Keyboard shortcuts', [], 0);
            otherwise
                KeyPressFcn_bak(hFig, keyEvent); 
                return;
        end
        % Redraw arrows
        if (iChannel <= 0)
            iChannel = length(Channels);
        end
        if (iChannel > length(Channels))
            iChannel = 1;
        end
        % Redraw arrows
        if (iRef <= 0)
            iRef = length(Channels);
        end
        if (iRef > length(Channels))
            iRef = 1;
        end
        
        if thresholdAmplitude <= 0
            thresholdAmplitude = 0;
        end        
        if thresholdAmplitude >= 1
            thresholdAmplitude = 1;
        end
        
        DrawArrows();
    end

%% ===== DRAW CURRENT CHANNEL =====
    function DrawArrows()
        % Delete previous Channels and sensors
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'lfArrows'));
        if isprop(hAxes, 'ColorOrderIndex')
            set(hAxes, 'ColorOrderIndex', 1);
        else
            set(hAxes, 'NextPlot', 'new');
        end
        % Draw current LF
        for iLF = 1:length(LF_finale)
            % EEG
            if ismember(selectedModality, {'EEG','ECOG','SEEG'})
                if isAvgRef
                    LeadField = LF_finale{iLF}(iChannel,:) - mean(LF_finale{iLF},1);
                    strRef = ' / Ref: Avg';
                else
                    LeadField = LF_finale{iLF}(iChannel,:) - LF_finale{iLF}(iRef,:);
                    strRef = Channels(iRef).Name;
                end
            else % MEG
                LeadField = LF_finale{iLF}(iChannel,:);
                strRef = '';
                if ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'))
                    delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
                end
            end
            % Display arrows
            LeadField = reshape(LeadField,3,[])'; % each column is a vector
            if(useLogScale)
                LeadField = LogScaleLeadfield(LeadField);
            end
            
            % thresholding
            normLF = sqrt((LeadField(:,1) ).^2 +(LeadField(:,2) ).^2 + (LeadField(:,3)).^2);
            [col1, ind] = sort(normLF, 'ascend');
            LeadFieldReordered = LeadField(ind,:);
            cdf = cumsum(col1); % Compute cdf
            cdf = cdf/cdf(end); % Normalize
            % Find index bellow or above the thresholding
            if thresholdBalance == 0 % 0 ==> inferior and 1 is superior 
                index = find(cdf <= thresholdAmplitude);
                iSymbole = '<=';
            else
                index = find(cdf > thresholdAmplitude);   
                iSymbole = '>';
            end
            dataValue = zeros(size(LeadFieldReordered));
            dataValue(index,:) = LeadFieldReordered(index,:);

            hQuiver(iLF) = quiver3(...
                ...HeadmodelMat{iLF}.GridLoc(:,1), HeadmodelMat{iLF}.GridLoc(:,2), HeadmodelMat{iLF}.GridLoc(:,3), ... % These two line are remaining in order to check if the thresholding display is correct
                ...LeadField(:,1), LeadField(:,2), LeadField(:,3), ...
                HeadmodelMat{iLF}.GridLoc(ind,1), HeadmodelMat{iLF}.GridLoc(ind,2), HeadmodelMat{iLF}.GridLoc(ind,3), ...
                dataValue(:,1), dataValue(:,2), dataValue(:,3), ...
                quiverSize, ...
                'Parent',    hAxes, ...
                'LineWidth', quiverWidth, ...
                'Color',     ColorOrder(mod(iLF-1, length(ColorOrder)) + 1, :), ...
                'Tag',       'lfArrows');
            % Arrow legends
            strLegend{iLF} = [SubjectName{iLF} ' : ' selectedModality  ' ' HeadmodelMat{iLF}.Comment];
        end

        % Remove previous selected sensor
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelChannel'));
        % Plot selected sensor
        if ~isempty(Channels(iChannel).Loc) && ~ismember(Channels(iChannel).Name, {'EEG','MEG','MEG MAG', 'MEG GRAD'})
            % Center of mass of all coordinates
            line(mean(Channels(iChannel).Loc(1,:),2), mean(Channels(iChannel).Loc(2,:),2), mean(Channels(iChannel).Loc(3,:),2), ...
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
            % Remove previous selected reference
            delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
            % Plot the reference electrode
            if ~isAvgRef && ~isempty(Channels(iRef).Loc)
                line(Channels(iRef).Loc(1,1), Channels(iRef).Loc(2,1), Channels(iRef).Loc(3,1), ...
                    'Parent',          hAxes, ...
                    'LineWidth',       2, ...
                    'LineStyle',       'none', ...
                    'Marker',          '*', ...
                    'MarkerFaceColor', [0 1 1], ...
                    'MarkerEdgeColor', [.4 .8 .4], ...
                    'MarkerSize',      8, ...
                    'Tag',             'RefChannel');
            end
            % Title bar (channel name)
            if isAvgRef
                strTitle = sprintf('Target channel(red) #%d/%d  (%s) | %s Ref Channel(green) = AvgRef  | Amp threshold %s %s %%| Log. scale %s', iChannel, length(Channels), Channels(iChannel).Name,selectedModality, iSymbole,  num2str(thresholdAmplitude*100),useLogScaleLegendMsg);
            else
                strTitle = sprintf('Target channel(red) #%d/%d  (%s) | %s Ref Channel(green) = %s| Amp threshold %s %s %%| Log. scale %s', iChannel, length(Channels), Channels(iChannel).Name,selectedModality,Channels(iRef).Name, iSymbole, num2str(thresholdAmplitude*100),useLogScaleLegendMsg);
            end
        else
            strTitle = sprintf('Target channel (red) #%d/%d  (%s) | Amp threshold %s %s %%|Log. scale %s', iChannel, length(Channels), Channels(iChannel).Name, iSymbole,num2str(thresholdAmplitude*100),useLogScaleLegendMsg);
        end
        
        if (iChannel == 1) && (length(Channels) > 1)
            strTitle = [strTitle, '       [Press arrows for next/previous channel (or H for help)]'];
        end
        set(hLabel, 'String', strTitle, 'Position', [10 1 1600 35],'ForegroundColor', [1 1 1]);
        % Arrows legend
        legend(hQuiver, strLegend, ...
            'TextColor',   'w', ...
            'fontsize',    bst_get('FigFont'), ...
            'Interpreter', 'None', ...
            'Location',    'NorthEast', ...
            'Tag',         'LegendOverlay');
        legend('boxoff');
    end


%% ===== SET MODALITY =====
    function isOk = SelectModality(inputMod)
        % Ask modality if there is more than one
        if (nargin == 1) && ~isempty(inputMod) && ismember(inputMod, allModalities)
            selectedModality = inputMod;
        elseif (length(allModalities) > 1)
            selectedModality = java_dialog('question', 'Select the modality:', ...
                'Display the Lead Field', [], allModalities, allModalities{1});
            if isempty(selectedModality)
                isOk = 0;
                return;
            end
        elseif (length(allModalities) == 1)
            selectedModality = allModalities{1};
        end
        % Get the corresponding channels
        iChannels = good_channel(ChannelMat.Channel, [], selectedModality);
        Channels = ChannelMat.Channel(iChannels);
        % Get channels locations
        if length(Channels) > 10
            % Center of mass of all coordinates for each sensor
            markersLocs = cell2mat(cellfun(@(c) mean(c,2), {Channels.Loc}, 'UniformOutput', 0))';
        end
        % Ask to select reference
        isOk = SelectReference();
    end


%% ===== SET REFERENCE =====
    function isOk = SelectReference()
        isOk = 1;
        if ~strcmp(selectedModality,'MEG')
            % Ask for the reference electrode
            refChan = java_dialog('combo', '<HTML>Select the reference channel (green color):<BR><BR>', [selectedModality ' reference'], [], {'Average Ref', Channels.Name});
            if isempty(refChan)
                isOk = 0;
                return;
            end
            iRef = find(strcmpi({Channels.Name}, refChan));
            if isempty(iRef)
                isAvgRef = 1;
            else
                isAvgRef = 0;
            end
        end
    end

%% ===== SET TARGET =====
    function isOk = SelectTarget()
        isOk = 1;
        % Ask for the target electrode
        trgChan = java_dialog('combo', '<HTML>Select the target channel (red color):<BR><BR>', [selectedModality ' Target'], [], {Channels.Name});
        if isempty(trgChan)
            isOk = 0;
            return;
        end
        iChannel = find(strcmpi({Channels.Name}, trgChan));
    end

%% ===== GET LEADFIELD =====
    function GetLeadField       
        % Update the LF according to the selected channels only
        for iLF = 1:length(HeadmodelFiles)
            LF_finale{iLF} = HeadmodelMat{iLF}.Gain(iChannels,:);
        end
    end

%% ===== LEADFIELD TO LOG SPACE =====
    function lf_log = LogScaleLeadfield(lf)
        lf_2 = lf.^2;
        r = sqrt(sum(lf_2,2));
        rho = sqrt(lf_2(:,1) + lf_2(:,2));
        t = atan2(rho,lf(:,3));
        f = atan2(lf(:,2),lf(:,1));
        lf_log = [ log10(r) .* sin(t) .* cos(f) ...
                   log10(r) .* sin(t) .* sin(f) ...
                   log10(r) .* cos(t)];
    end
end
