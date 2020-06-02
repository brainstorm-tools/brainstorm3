function hFig = channel_align_manual( ChannelFile, Modality, isEdit, SurfaceType )
% CHANNEL_ALIGN_MANUAL: Align manually an electrodes net on the scalp surface of the subject.
% 
% USAGE:  hFig = channel_align_manual( ChannelFile, Modality, isEdit, SurfaceType='cortex')
%         hFig = channel_align_manual( ChannelFile, Modality, isEdit, SurfaceFile)
%
% INPUT:
%     - ChannelFile : full path to channel file
%     - Modality    : modality to display and to align
%     - isEdit      : Boolean - If one, add controls to edit the positions
%     - SurfaceType : Type of surface to use to align the sensors ('scalp', 'cortex', 'anatomy')

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
% Authors: Francois Tadel, 2008-2020

global GlobalData;

% Parse inputs
hFig = [];
if (nargin < 4) || isempty(SurfaceType)
    if ismember(Modality, {'SEEG'}) 
        SurfaceType = 'cortex';
    else 
        SurfaceType = 'scalp';
    end
    SurfaceFile = [];
% If passing a filename
else
    if ~isempty(strfind(SurfaceType, '.mat'))
        SurfaceFile = SurfaceType;
        SurfaceType = file_gettype(SurfaceFile);
    else
        SurfaceFile = [];
    end
end
if (nargin < 3) || isempty(isEdit)
    isEdit = 0;
end

% Is processing MEG?
isMeg  = ismember(Modality, {'MEG', 'MEG GRAD', 'MEG MAG', 'Vectorview306', 'CTF', '4D', 'KIT', 'KRISS', 'RICOH'});
isNirs = ismember(Modality, {'NIRS','NIRS-BRS'});
isEeg  = ~isMeg && ~isNirs;
% Get study
sStudy = bst_get('ChannelFile', ChannelFile);
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);


% ===== VIEW SURFACE =====
% If editing the channel file: Close all the windows before
if isEdit
    bst_memory('UnloadAll', 'Forced');
end
% Progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'Importing sensors', 'Loading sensors description...');
end
% View surface if available
switch lower(SurfaceType)
    case 'cortex'
        if ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
            if isempty(SurfaceFile)
                SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
            end
            switch (Modality)
                case 'SEEG',  SurfAlpha = .8;
                case 'ECOG',  SurfAlpha = .2;
                otherwise,    SurfAlpha = .1;
            end
            hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
        end
        isSurface = 1;
    case 'innerskull'
        if ~isempty(sSubject.iInnerSkull) && (sSubject.iInnerSkull <= length(sSubject.Surface))
            if isempty(SurfaceFile)
                SurfaceFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
            end
            switch (Modality)
                case 'SEEG',  SurfAlpha = .5;
                case 'ECOG',  SurfAlpha = .2;
                otherwise,    SurfAlpha = .1;
            end
            hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
        end
        isSurface = 1;
    case 'scalp'
        if ~isempty(sSubject.iScalp) && (sSubject.iScalp <= length(sSubject.Surface))
            if isempty(SurfaceFile)
                SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
            end
            switch (Modality)
                case 'SEEG',  SurfAlpha = .8;
                case 'ECOG',  SurfAlpha = .8;
                otherwise,    SurfAlpha = .1;
            end
            hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
        end
        isSurface = 1;
    case {'anatomy', 'subjectimage'}
        if ~isempty(sSubject.iAnatomy) && (sSubject.iAnatomy <= length(sSubject.Anatomy))
            if isempty(SurfaceFile)
                SurfaceFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            end
            SurfAlpha = .1;
            hFig = view_mri_3d(SurfaceFile, [], SurfAlpha, 'NewFigure');
        end
        isSurface = 0;
    otherwise
        error('Unsupported surface type.');
end
% Warning if no surface was found
if isempty(hFig)
    disp('BST> Warning: Cannot check the alignment sensors-MRI because no appropriate surface is available.');
    if isProgress
        bst_progress('stop');
    end
    return;
end

% Set figure title
set(hFig, 'Name', 'Registration scalp/sensors');
% View XYZ axis
figure_3d('ViewAxis', hFig, 1);
% Set view from left side
figure_3d('SetStandardView', hFig, 'left');


% ===== SHOW SENSORS =====
% MEG Helmet
if isMeg
    view_helmet(ChannelFile, hFig);
    hSensorsLabels = [];
    % Get sensors patch
    hSensorsPatch = findobj(hFig, 'Tag', 'SensorsPatch');
    hSensorsMarkers = findobj(hFig, 'Tag', 'SensorsMarkers');
% EEG Electrodes
elseif isEeg
    % View sensors
    view_channels(ChannelFile, Modality, 1, 1, hFig);
    % Hide sensors labels
    hSensorsLabels = findobj(hFig, 'Tag', 'SensorsLabels');
    set(hSensorsLabels, 'Visible', 'off');
    % Get sensors patch
    hSensorsPatch = findobj(hFig, 'Tag', 'SensorsPatch');
    hSensorsMarkers = findobj(hFig, 'Tag', 'SensorsMarkers');
% NIRS Optodes
elseif isNirs
    % View sensors
    view_channels(ChannelFile, Modality, 0, 0, hFig);
    % Get sensors patch
    hSensorsLabels = findobj(hFig, 'Tag', 'NirsCapText');
    hSensorsPatch = findobj(hFig, 'Tag', 'NirsCapPatch');
    hSensorsMarkers = [];
end
% Check that it was displayed correctly
if (isempty(hSensorsPatch) || (~isempty(hSensorsPatch) && ~ishandle(hSensorsPatch(1)))) && ...
   (isempty(hSensorsMarkers) || (~isempty(hSensorsMarkers) && ~ishandle(hSensorsMarkers(1))))
    bst_error('Cannot display sensors patch', 'Align electrode contacts', 0);
    return
end
% Get sensors locations from patch
SensorsVertices = GetSensorsVertices(hSensorsPatch, hSensorsMarkers);
% Get helmet patch
hHelmetPatch = findobj(hFig, 'Tag', 'HelmetPatch');
if isempty(hHelmetPatch)
    HelmetVertices = [];
else
    HelmetVertices = get(hHelmetPatch, 'Vertices');
end


% ===== DISPLAY HEAD POINTS =====
% Display head points
figure_3d('ViewHeadPoints', hFig, 1);
% Get patch and vertices
hHeadPointsMarkers = findobj(hFig, 'Tag', 'HeadPointsMarkers');
hHeadPointsLabels  = findobj(hFig, 'Tag', 'HeadPointsLabels');
hHeadPointsFid     = findobj(hFig, 'Tag', 'HeadPointsFid');
hHeadPointsHpi     = findobj(hFig, 'Tag', 'HeadPointsHpi');
isHeadPoints = ~isempty(hHeadPointsMarkers);
HeadPointsLabelsLoc  = [];
HeadPointsMarkersLoc = [];
HeadPointsFidLoc     = [];
HeadPointsHpiLoc     = [];
if isHeadPoints
    % Get markers positions
    HeadPointsMarkersLoc = [get(hHeadPointsMarkers, 'XData')', ...
                            get(hHeadPointsMarkers, 'YData')', ...
                            get(hHeadPointsMarkers, 'ZData')'];
    % Hide HeadPoints when looking at EEG and number of EEG channels is the same as headpoints
    if isEeg && ~isempty(HeadPointsMarkersLoc) && ~isempty(SensorsVertices) && (length(SensorsVertices) == length(HeadPointsMarkersLoc)) && (max(abs(SensorsVertices(:) - HeadPointsMarkersLoc(:))) < 0.001)
        set(hHeadPointsMarkers, 'Visible', 'off');
    end
    % Get labels positions
    tmpLoc = get(hHeadPointsLabels,'Position');
    if ~isempty(tmpLoc)
        if iscell(tmpLoc)
            HeadPointsLabelsLoc = cat(1, tmpLoc{:});
        else
            HeadPointsLabelsLoc = tmpLoc;
        end
    end
    % Get fiducials positions
    HeadPointsFidLoc = [get(hHeadPointsFid, 'XData')', ...
                        get(hHeadPointsFid, 'YData')', ...
                        get(hHeadPointsFid, 'ZData')'];
    % Get fiducials positions
    HeadPointsHpiLoc = [get(hHeadPointsHpi, 'XData')', ...
                        get(hHeadPointsHpi, 'YData')', ...
                        get(hHeadPointsHpi, 'ZData')'];
end
    
% ===== DISPLAY MRI FIDUCIALS =====
% Get the fiducials positions defined in the MRI volume
sMri = load(file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName), 'SCS');
if ~isempty(sMri.SCS.NAS) && ~isempty(sMri.SCS.LPA) && ~isempty(sMri.SCS.RPA)
    % Convert coordinates MRI => SCS
    MriFidLoc = [cs_convert(sMri, 'mri', 'scs', sMri.SCS.NAS ./ 1000); ...
                 cs_convert(sMri, 'mri', 'scs', sMri.SCS.LPA ./ 1000); ...
                 cs_convert(sMri, 'mri', 'scs', sMri.SCS.RPA ./ 1000)];
    % Display fiducials
    line(MriFidLoc(:,1), MriFidLoc(:,2), MriFidLoc(:,3), ...
        'Parent',          findobj(hFig, 'Tag', 'Axes3D'), ...
        'LineWidth',       2, ...
        'LineStyle',       'none', ...
        'MarkerFaceColor', [.3 .3 1], ...
        'MarkerEdgeColor', [.4 .4 1], ...
        'MarkerSize',      7, ...
        'Marker',          'o', ...
        'Tag',             'MriPointsFid');
end

% ===== CONFIGURE HEAD SURFACE =====
% Get scalp patch
TessInfo = getappdata(hFig, 'Surface');
hSurfacePatch = TessInfo(1).hPatch;
% If no edition of channel file: exit now
if ~isEdit
    % Close progress bar
    if isProgress
        bst_progress('stop');
    end
    return
end

% ===== EDIT ONLY: GLOBAL DATA =====
global gChanAlign;
gChanAlign = [];
gChanAlign.ChannelFile     = file_fullpath(ChannelFile);
gChanAlign.Modality        = Modality;
gChanAlign.isMeg           = isMeg;
gChanAlign.isNirs          = isNirs;
gChanAlign.isEeg           = isEeg;
gChanAlign.FinalTransf     = eye(4);
gChanAlign.hFig            = hFig;
gChanAlign.hSurfacePatch   = hSurfacePatch;
gChanAlign.hSensorsLabels  = hSensorsLabels;
gChanAlign.SensorsLabels   = {};
gChanAlign.hSensorsPatch   = hSensorsPatch;
gChanAlign.hSensorsMarkers = hSensorsMarkers;
gChanAlign.SensorsVertices = SensorsVertices;
gChanAlign.hHelmetPatch    = hHelmetPatch;
gChanAlign.HelmetVertices  = HelmetVertices;
gChanAlign.isHeadPoints         = isHeadPoints;
gChanAlign.hHeadPointsMarkers   = hHeadPointsMarkers;
gChanAlign.hHeadPointsLabels    = hHeadPointsLabels;
gChanAlign.hHeadPointsFid       = hHeadPointsFid;
gChanAlign.hHeadPointsHpi       = hHeadPointsHpi;
gChanAlign.HeadPointsMarkersLoc = HeadPointsMarkersLoc;
gChanAlign.HeadPointsLabelsLoc  = HeadPointsLabelsLoc;
gChanAlign.HeadPointsFidLoc     = HeadPointsFidLoc;
gChanAlign.HeadPointsHpiLoc     = HeadPointsHpiLoc;

% ===== CONFIGURE FIGURE =====
% Get figure description in GlobalData structure
[gChanAlign.hFig, gChanAlign.iFig, gChanAlign.iDS] = bst_figures('GetFigure', gChanAlign.hFig);
if isempty(gChanAlign.iDS)
    return
end
% Compute a vector to convert: global indices (channel file) -> local indices (vertices)
Channel = GlobalData.DataSet(gChanAlign.iDS).Channel;
iChan = good_channel(Channel, [], Modality);
gChanAlign.iGlobal2Local = zeros(1, length(Channel));
if isNirs
    gChanAlign.iGlobal2Local(iChan) = 1:size(iChan,2);
    gChanAlign.SensorsLabels(iChan) = {GlobalData.DataSet(gChanAlign.iDS).Channel(iChan).Name};
else    
    gChanAlign.iGlobal2Local(iChan) = 1:size(gChanAlign.SensorsVertices,1);
end    
% EEG: Get the labels of the electrodes
if isEeg
    iTextChan = length(gChanAlign.hSensorsLabels) - (1:length(iChan)) + 1;
    gChanAlign.SensorsLabels(iTextChan) = {GlobalData.DataSet(gChanAlign.iDS).Channel(iChan).Name};
end


% ===== HACK NORMAL 3D CALLBACKS =====
% Save figure callback functions
gChanAlign.Figure3DButtonDown_Bak   = get(gChanAlign.hFig, 'WindowButtonDownFcn');
gChanAlign.Figure3DButtonMotion_Bak = get(gChanAlign.hFig, 'WindowButtonMotionFcn');
gChanAlign.Figure3DButtonUp_Bak     = get(gChanAlign.hFig, 'WindowButtonUpFcn');
gChanAlign.Figure3DCloseRequest_Bak = get(gChanAlign.hFig, 'CloseRequestFcn');
gChanAlign.Figure3DKeyPress_Bak     = get(gChanAlign.hFig, 'KeyPressFcn');
% Set new callbacks
set(gChanAlign.hFig, 'WindowButtonDownFcn',   @AlignButtonDown_Callback);
set(gChanAlign.hFig, 'WindowButtonMotionFcn', @AlignButtonMotion_Callback);
set(gChanAlign.hFig, 'WindowButtonUpFcn',     @AlignButtonUp_Callback);
set(gChanAlign.hFig, 'CloseRequestFcn',       @AlignClose_Callback);
set(gChanAlign.hFig, 'KeyPressFcn',           @AlignKeyPress_Callback);

% ===== CUSTOMIZE FIGURE =====
% Add toolbar to window
hToolbar = uitoolbar(gChanAlign.hFig, 'Tag', 'AlignToolbar');

% Initializations
gChanAlign.selectedButton = '';
gChanAlign.isChanged = 0;
gChanAlign.mouseClicked = 0;
gChanAlign.isFirstAddWarning = 1;
gChanAlign.isFirstRmWarning = 1;

% Rotation/Translation buttons
gChanAlign.hButtonLabels = [];
gChanAlign.hButtonEditLabel = [];
gChanAlign.hButtonHelmet = [];
if gChanAlign.isMeg
    gChanAlign.hButtonHelmet = uitoggletool(hToolbar, 'CData', java_geticon('ICON_DISPLAY'), 'TooltipString', 'Show/Hide MEG helmet', 'ClickedCallback', @ToggleHelmet, 'State', 'on');
elseif gChanAlign.isEeg
    gChanAlign.hButtonLabels    = uitoggletool(hToolbar, 'CData', java_geticon('ICON_LABELS'), 'TooltipString', 'Show/Hide electrodes labels', 'ClickedCallback', @ToggleLabels);
    gChanAlign.hButtonEditLabel = uipushtool(  hToolbar, 'CData', java_geticon('ICON_EDIT'),   'TooltipString', 'Edit selected channel label', 'ClickedCallback', @EditLabel);
end
gChanAlign.hButtonTransX   = uitoggletool(hToolbar, 'CData', java_geticon('ICON_TRANSLATION_X'), 'TooltipString', 'Translation/X: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation, 'separator', 'on');
gChanAlign.hButtonTransY   = uitoggletool(hToolbar, 'CData', java_geticon('ICON_TRANSLATION_Y'), 'TooltipString', 'Translation/Y: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
gChanAlign.hButtonTransZ   = uitoggletool(hToolbar, 'CData', java_geticon('ICON_TRANSLATION_Z'), 'TooltipString', 'Translation/Z: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
gChanAlign.hButtonRotX     = uitoggletool(hToolbar, 'CData', java_geticon('ICON_ROTATION_X'),    'TooltipString', 'Rotation/X: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation, 'separator', 'on');
gChanAlign.hButtonRotY     = uitoggletool(hToolbar, 'CData', java_geticon('ICON_ROTATION_Y'),    'TooltipString', 'Rotation/Y: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation);
gChanAlign.hButtonRotZ     = uitoggletool(hToolbar, 'CData', java_geticon('ICON_ROTATION_Z'),    'TooltipString', 'Rotation/Z: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation);

if gChanAlign.isMeg
    gChanAlign.hButtonRefine   = uipushtool(hToolbar, 'CData', java_geticon('ICON_ALIGN_CHANNELS'), 'TooltipString', 'Refine registration using head points', 'ClickedCallback', @RefineWithHeadPoints, 'separator', 'on');
    gChanAlign.hButtonMoveChan = [];
    gChanAlign.hButtonProject = [];
elseif gChanAlign.isNirs
    gChanAlign.hButtonProject = uipushtool(  hToolbar, 'CData', java_geticon('ICON_PROJECT_ELECTRODES'), 'TooltipString', 'Project electrodes on surface', 'ClickedCallback', @ProjectElectrodesOnSurface, 'separator', 'on');
    gChanAlign.hButtonRefine   = uipushtool(hToolbar, 'CData', java_geticon('ICON_ALIGN_CHANNELS'), 'TooltipString', 'Refine registration using head points', 'ClickedCallback', @RefineWithHeadPoints, 'separator', 'on');
    gChanAlign.hButtonMoveChan = [];
    gChanAlign.hButtonProject = [];
else
    gChanAlign.hButtonResizeX  = uitoggletool(hToolbar, 'CData', java_geticon('ICON_RESIZE_X'),      'TooltipString', 'Resize/X: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation, 'separator', 'on');
    gChanAlign.hButtonResizeY  = uitoggletool(hToolbar, 'CData', java_geticon('ICON_RESIZE_Y'),      'TooltipString', 'Resize/Y: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation);
    gChanAlign.hButtonResizeZ  = uitoggletool(hToolbar, 'CData', java_geticon('ICON_RESIZE_Z'),      'TooltipString', 'Resize/Z: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation);
    gChanAlign.hButtonResize   = uitoggletool(hToolbar, 'CData', java_geticon('ICON_RESIZE'),        'TooltipString', 'Resize: Press right button and move mouse up/down',        'ClickedCallback', @SelectOperation);
    if isSurface
        gChanAlign.hButtonMoveChan = uitoggletool(hToolbar, 'CData', java_geticon('ICON_MOVE_CHANNEL'),  'TooltipString', 'Move an electrode: Select electrode, then press right button and move mouse', 'ClickedCallback', @SelectOperation, 'separator', 'on');
        gChanAlign.hButtonProject = uipushtool(  hToolbar, 'CData', java_geticon('ICON_PROJECT_ELECTRODES'), 'TooltipString', 'Project electrodes on surface', 'ClickedCallback', @ProjectElectrodesOnSurface);
    else
        gChanAlign.hButtonMoveChan = [];
        gChanAlign.hButtonProject = [];
    end
    gChanAlign.hButtonRefine   = uipushtool(hToolbar, 'CData', java_geticon('ICON_ALIGN_CHANNELS'), 'TooltipString', 'Refine registration using head points', 'ClickedCallback', @RefineWithHeadPoints);
end
if gChanAlign.isEeg && isSurface
    gChanAlign.hButtonAdd    = uitoggletool(hToolbar, 'CData', java_geticon('ICON_SCOUT_NEW'), 'TooltipString', 'Add a new electrode',        'ClickedCallback', @ButtonAddElectrode_Callback, 'separator', 'on');
    gChanAlign.hButtonDelete = uipushtool(hToolbar, 'CData', java_geticon('ICON_DELETE'), 'TooltipString', 'Remove selected electrodes', 'ClickedCallback', @RemoveElectrodes);
else
    gChanAlign.hButtonAdd = [];
    gChanAlign.hButtonDelete = [];
end
% if strcmpi(Modality, 'ECOG')
%     gChanAlign.hButtonAlign = uipushtool(hToolbar, 'CData', java_geticon('ICON_ECOG'), 'TooltipString', ['Operations specific to ' Modality ' electrodes'], 'ClickedCallback', @(h,ev)ShowElectrodeMenu(hFig, Modality), 'separator', 'on');
% elseif strcmpi(Modality, 'SEEG') 
%     gChanAlign.hButtonAlign = uipushtool(hToolbar, 'CData', java_geticon('ICON_SEEG'), 'TooltipString', ['Operations specific to ' Modality ' electrodes'], 'ClickedCallback', @(h,ev)ShowElectrodeMenu(hFig, Modality), 'separator', 'on');
% else
    gChanAlign.hButtonAlign = [];
% end
gChanAlign.hButtonOk = uipushtool(  hToolbar, 'CData', java_geticon( 'ICON_OK'), 'separator', 'on', 'ClickedCallback', @buttonOk_Callback);% Update figure localization
gui_layout('Update');
% Move a bit the figure to refresh it on all systems
pos = get(gChanAlign.hFig, 'Position');
set(gChanAlign.hFig, 'Position', pos + [0 0 0 1]);
drawnow;
set(gChanAlign.hFig, 'Position', pos);
% Close progress bar
if isProgress
    bst_progress('stop');
end
    
end



%% ===== MOUSE CALLBACKS =====  
%% ===== MOUSE DOWN =====
function AlignButtonDown_Callback(hObject, ev)
    global gChanAlign;
    SelectionType = get(gChanAlign.hFig, 'SelectionType');
    % Right-click if a button is selected
    if strcmpi(SelectionType, 'alt') && ~isempty(gChanAlign.selectedButton)
        gChanAlign.mouseClicked = 1;
        % Record click position
        setappdata(gChanAlign.hFig, 'clickPositionFigure', get(gChanAlign.hFig, 'CurrentPoint'));
    % Left-click if "Add electrode" is selected
    elseif gChanAlign.isEeg && strcmpi(get(gChanAlign.hButtonAdd, 'State'), 'on')
        gChanAlign.mouseClicked = 1;
        AddElectrode();
    else
        % Call the default mouse down handle
        gChanAlign.Figure3DButtonDown_Bak(hObject, ev);
    end
end
    
%% ===== MOUSE MOVE =====
function AlignButtonMotion_Callback(hObject, ev)
    global gChanAlign;
    if isfield(gChanAlign, 'mouseClicked') && gChanAlign.mouseClicked && ~isempty(gChanAlign.selectedButton)
        % Get current mouse location
        curptFigure = get(gChanAlign.hFig, 'CurrentPoint');
        motionFigure = (curptFigure - getappdata(gChanAlign.hFig, 'clickPositionFigure')) / 1000;
        % Update click point location
        setappdata(gChanAlign.hFig, 'clickPositionFigure', curptFigure);
        % Compute transformation
        ComputeTransformation(motionFigure(2));
    else
        % Call the default mouse motion handle
        gChanAlign.Figure3DButtonMotion_Bak(hObject, ev);
    end
end

%% ===== GET SELECTED CHANNELS =====
function iSelChan = GetSelectedChannels()
    global gChanAlign;
    % Get channels to modify (ONLY FOR EEG: Cannot deform a MEG helmet)
    [SelChan, iSelChan] = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    if isempty(iSelChan) || gChanAlign.isMeg || gChanAlign.isNirs
        iSelChan = 1:size(gChanAlign.SensorsVertices,1);
    else
        % Convert local sensors indices in global indices (channel file)
        iSelChan = gChanAlign.iGlobal2Local(iSelChan);
    end
end


%% ===== COMPUTE TRANSFORMATION ======
function ComputeTransformation(val)
    global gChanAlign;
    % Get channels to modify
    iSelChan = GetSelectedChannels();
    % Initialize the transformations that are done
    Rnew = [];
    Tnew = [];
    Rescale = [];
    % Selected button
    switch (gChanAlign.selectedButton)
        case gChanAlign.hButtonTransX
            Tnew = [val / 5, 0, 0];
        case gChanAlign.hButtonTransY
            Tnew = [0, val / 5, 0];
        case gChanAlign.hButtonTransZ
            Tnew = [0, 0, val / 5];
        case gChanAlign.hButtonRotX
            a = val;
            Rnew = [1,       0,      0; 
                    0,  cos(a), sin(a);
                    0, -sin(a), cos(a)];
        case gChanAlign.hButtonRotY
            a = val;
            Rnew = [cos(a), 0, -sin(a); 
                         0, 1,       0;
                    sin(a), 0,  cos(a)];
        case gChanAlign.hButtonRotZ
            a = val;
            Rnew = [cos(a), -sin(a), 0; 
                    sin(a),  cos(a), 0;
                         0,  0,      1];
        case gChanAlign.hButtonResize
            Rescale = repmat(1 + val, [1 3]);
        case gChanAlign.hButtonResizeX
            Rescale = [1 + val, 0, 0];
        case gChanAlign.hButtonResizeY
            Rescale = [0, 1 + val, 0];
        case gChanAlign.hButtonResizeZ
            Rescale = [0, 0, 1 + val];
        case gChanAlign.hButtonMoveChan
            % Works only iif one channel is selected
            if (length(iSelChan) ~= 1)
                return
            end
            % Select the nearest sensor from the mouse
            [p, v, vi] = select3d(gChanAlign.hSurfacePatch);
            % If sensor index is valid
            if ~isempty(vi) && (vi > 0) && (norm(p' - gChanAlign.SensorsVertices(iSelChan,:)) < 0.01)
                gChanAlign.SensorsVertices(iSelChan,:) = p';
            end
        otherwise 
            return;
    end
    % Apply transformation
    ApplyTransformation(iSelChan, Rnew, Tnew, Rescale);
    % Update display 
    UpdatePoints(iSelChan);
end


%% ===== APPLY TRANSFORMATION =====
function ApplyTransformation(iSelChan, Rnew, Tnew, Rescale)
    global gChanAlign;
    % Mark the channel file as modified
    gChanAlign.isChanged = 1;
    % Apply rotation
    if ~isempty(Rnew)
        % Update sensors positions
        gChanAlign.SensorsVertices(iSelChan,:) = gChanAlign.SensorsVertices(iSelChan,:) * Rnew';
        % Update helmet position
        if ~isempty(gChanAlign.HelmetVertices)
            gChanAlign.HelmetVertices(iSelChan,:) = gChanAlign.HelmetVertices(iSelChan,:) * Rnew';
        end
        % Update head points positions
        if gChanAlign.isHeadPoints
            % Move markers
            gChanAlign.HeadPointsMarkersLoc = gChanAlign.HeadPointsMarkersLoc * Rnew';
            % Move fiducials
            if ~isempty(gChanAlign.HeadPointsFidLoc)
                gChanAlign.HeadPointsFidLoc = gChanAlign.HeadPointsFidLoc * Rnew';
            end
            % Move HPIs
            if ~isempty(gChanAlign.HeadPointsHpiLoc)
                gChanAlign.HeadPointsHpiLoc = gChanAlign.HeadPointsHpiLoc * Rnew';
            end
            % Move labels
            if ~isempty(gChanAlign.HeadPointsLabelsLoc)
                gChanAlign.HeadPointsLabelsLoc = gChanAlign.HeadPointsLabelsLoc * Rnew';
            end
        end
        % Add this transformation to the final transformation
        newTransf = eye(4);
        newTransf(1:3,1:3) = Rnew;
        gChanAlign.FinalTransf = newTransf * gChanAlign.FinalTransf;
    end
    % Apply Translation
    if ~isempty(Tnew)
        % Update sensors positions
        gChanAlign.SensorsVertices(iSelChan,:) = bst_bsxfun(@plus, gChanAlign.SensorsVertices(iSelChan,:), Tnew);
        % Update helmet position
        if ~isempty(gChanAlign.HelmetVertices)
            gChanAlign.HelmetVertices(iSelChan,:) = bst_bsxfun(@plus, gChanAlign.HelmetVertices(iSelChan,:), Tnew);
        end
        % Update head points positions
        if gChanAlign.isHeadPoints
            % Markers
            gChanAlign.HeadPointsMarkersLoc = bst_bsxfun(@plus, gChanAlign.HeadPointsMarkersLoc, Tnew);
            % Fiducials
            if ~isempty(gChanAlign.HeadPointsFidLoc)
                gChanAlign.HeadPointsFidLoc = bst_bsxfun(@plus, gChanAlign.HeadPointsFidLoc, Tnew);
            end
            % Fiducials
            if ~isempty(gChanAlign.HeadPointsHpiLoc)
                gChanAlign.HeadPointsHpiLoc = bst_bsxfun(@plus, gChanAlign.HeadPointsHpiLoc, Tnew);
            end
            % Labels
            if ~isempty(gChanAlign.HeadPointsLabelsLoc)
                gChanAlign.HeadPointsLabelsLoc = bst_bsxfun(@plus, gChanAlign.HeadPointsLabelsLoc, Tnew);
            end
        end
        % Add this transformation to the final transformation
        newTransf = eye(4);
        newTransf(1:3,4) = Tnew;
        gChanAlign.FinalTransf = newTransf * gChanAlign.FinalTransf;
    end
    % Apply rescale
    if ~isempty(Rescale)
        for iDim = 1:3
            if (Rescale(iDim) ~= 0)
                % Resize sensors
                gChanAlign.SensorsVertices(iSelChan,iDim) = gChanAlign.SensorsVertices(iSelChan,iDim) * Rescale(iDim);
                % Resize head points
                if gChanAlign.isHeadPoints
                    % Move markers
                    gChanAlign.HeadPointsMarkersLoc(:,iDim) = gChanAlign.HeadPointsMarkersLoc(:,iDim) * Rescale(iDim);
                    % Move fiducials
                    if ~isempty(gChanAlign.HeadPointsFidLoc)
                        gChanAlign.HeadPointsFidLoc(:,iDim)  = gChanAlign.HeadPointsFidLoc(:,iDim)  * Rescale(iDim);
                    end
                    % Move HPIs
                    if ~isempty(gChanAlign.HeadPointsHpiLoc)
                        gChanAlign.HeadPointsHpiLoc(:,iDim)  = gChanAlign.HeadPointsHpiLoc(:,iDim)  * Rescale(iDim);
                    end
                    % Move labels
                    if ~isempty(gChanAlign.HeadPointsLabelsLoc)
                        gChanAlign.HeadPointsLabelsLoc(:,iDim)  = gChanAlign.HeadPointsLabelsLoc(:,iDim)  * Rescale(iDim);
                    end
                end
            end
        end
    end
end

%% ===== UPDATE POINTS =====
function UpdatePoints(iSelChan)
    global gChanAlign;
    % Update sensor patch vertices
    SetSensorsVertices(gChanAlign.hSensorsPatch, gChanAlign.hSensorsMarkers, gChanAlign.SensorsVertices);
    if ~isempty(gChanAlign.hSensorsLabels)
        if gChanAlign.isNirs
            VertexLabels = get(gChanAlign.hSensorsPatch, 'UserData');
            for i = 1:length(gChanAlign.hSensorsLabels)
                iVert = find(strcmpi(VertexLabels, get(gChanAlign.hSensorsLabels(i), 'String')));
                if ~isempty(iVert)
                    set(gChanAlign.hSensorsLabels(i), 'Position', 1.08 .* mean(gChanAlign.SensorsVertices(iVert,:)));
                end
            end
        else
            for i = 1:length(iSelChan)
                iTextChan = length(gChanAlign.hSensorsLabels) - iSelChan(i) + 1;
                set(gChanAlign.hSensorsLabels(iTextChan), 'Position', ...
                    [1.05, 1.05, 1.03] .* gChanAlign.SensorsVertices(iSelChan(i),:));
            end
        end
    end
    % Update helmet patch vertices
    set(gChanAlign.hHelmetPatch, 'Vertices', gChanAlign.HelmetVertices);
    % Update headpoints markers and labels
    if gChanAlign.isHeadPoints
        % Extra head points
        set(gChanAlign.hHeadPointsMarkers, ...
            'XData', gChanAlign.HeadPointsMarkersLoc(:,1), ...
            'YData', gChanAlign.HeadPointsMarkersLoc(:,2), ...
            'ZData', gChanAlign.HeadPointsMarkersLoc(:,3));
        % Fiducials
        if ~isempty(gChanAlign.hHeadPointsFid)
            set(gChanAlign.hHeadPointsFid, ...
                'XData', gChanAlign.HeadPointsFidLoc(:,1), ...
                'YData', gChanAlign.HeadPointsFidLoc(:,2), ...
                'ZData', gChanAlign.HeadPointsFidLoc(:,3));
        end
        % HPI
        if ~isempty(gChanAlign.hHeadPointsHpi)
            set(gChanAlign.hHeadPointsHpi, ...
                'XData', gChanAlign.HeadPointsHpiLoc(:,1), ...
                'YData', gChanAlign.HeadPointsHpiLoc(:,2), ...
                'ZData', gChanAlign.HeadPointsHpiLoc(:,3));
        end
        % Labels
        for i = 1:size(gChanAlign.hHeadPointsLabels, 1)
            set(gChanAlign.hHeadPointsLabels(i), 'Position', ...
                [1.05, 1.05, 1.03] .* gChanAlign.HeadPointsLabelsLoc(i,:));
        end
    end
end


%% ===== MOUSE UP =====
function AlignButtonUp_Callback(hObject, ev)
    global gChanAlign;
    % Catch only the events if the motion is currently processed
    if gChanAlign.mouseClicked
        gChanAlign.mouseClicked = 0;
    else
        % Call the default mouse up handle
        gChanAlign.Figure3DButtonUp_Bak(hObject, ev);
    end
end


%% ===== KEY PRESS =====
function AlignKeyPress_Callback(hFig, keyEvent)
    global gChanAlign;
    switch (keyEvent.Key)
        case {'uparrow', 'rightarrow'} 
            ComputeTransformation(0.001);
        case {'downarrow', 'leftarrow'}
            ComputeTransformation(-0.001);
        case 'e'
            if strcmpi(get(gChanAlign.hButtonLabels, 'State'), 'on')
                set(gChanAlign.hButtonLabels, 'State', 'off');
            else
                set(gChanAlign.hButtonLabels, 'State', 'on');
            end
            ToggleLabels();
        otherwise
            % Call the default keypress handle
            gChanAlign.Figure3DKeyPress_Bak(hFig, keyEvent);
    end
end


%% ===== GET CURRENT CHANNELMAT =====
function [ChannelMat, newtransf, iChanModified] = GetCurrentChannelMat(isAll)
    global GlobalData gChanAlign;
    % Parse inputs
    if (nargin < 1) || isempty(isAll)
        isAll = [];
    end
    % Load ChannelFile
    ChannelMat = in_bst_channel(gChanAlign.ChannelFile);
    ChannelMat.Channel = GlobalData.DataSet(gChanAlign.iDS).Channel;
    % Get final rotation and translation
    Rfinal = gChanAlign.FinalTransf(1:3,1:3);
    Tfinal = gChanAlign.FinalTransf(1:3,4);
    % Create 4x4 transformation matrix
    newtransf = eye(4);
    newtransf(1:3,1:3) = Rfinal;
    newtransf(1:3,4)   = Tfinal;
    % Do not apply transformation to other sensors if nothing changed
    if isequal(Rfinal, eye(3)) && isequal(Tfinal, [0;0;0])
        isAll = 0;
    end
    % Get the channels
    iMeg  = good_channel(ChannelMat.Channel, [], 'MEG');
    iRef  = good_channel(ChannelMat.Channel, [], 'MEG REF');
    iNirs = good_channel(ChannelMat.Channel, [], 'NIRS');
    if gChanAlign.isMeg || gChanAlign.isNirs
        iEeg = sort([good_channel(ChannelMat.Channel, [], 'EEG'), good_channel(ChannelMat.Channel, [], 'SEEG'), good_channel(ChannelMat.Channel, [], 'ECOG')]);
        iChanModified = [iMeg iRef iNirs];
    else
        iEeg = good_channel(ChannelMat.Channel, [], gChanAlign.Modality);
        iChanModified = iEeg;
    end
    % Ask if needed to update also the other modalities
    if isempty(isAll)
        if (gChanAlign.isMeg || gChanAlign.isNirs) && (length(iEeg) > 10)
            isAll = java_dialog('confirm', 'Do you want to apply the same transformation to the EEG electrodes ?', 'Align sensors');
        elseif ~gChanAlign.isMeg && ~isempty(iMeg)
            isAll = java_dialog('confirm', 'Do you want to apply the same transformation to the MEG sensors ?', 'Align sensors');
        elseif ~gChanAlign.isNirs && ~isempty(iNirs)
            isAll = java_dialog('confirm', 'Do you want to apply the same transformation to the NIRS sensors ?', 'Align sensors');
        else
            isAll = 0;
        end
    end
    
    % Update EEG electrodes locations
    if gChanAlign.isEeg
        % Align each channel
        for i=1:length(iEeg)
            % Position
            ChannelMat.Channel(iEeg(i)).Loc(:,1) = gChanAlign.SensorsVertices(i,:)';
            % Name
            iTextChan = length(gChanAlign.hSensorsLabels) - gChanAlign.iGlobal2Local(iEeg(i)) + 1;
            ChannelMat.Channel(iEeg(i)).Name = gChanAlign.SensorsLabels{iTextChan};
        end
    end

    % List of sensors to apply the Rotation and Translation to
    if gChanAlign.isMeg && isAll 
        iChan = unique([iMeg, iRef, iEeg]);
    elseif (gChanAlign.isMeg && ~isAll) || (~gChanAlign.isMeg && isAll)
        iChan = union(iMeg, iRef);
    elseif (gChanAlign.isNirs && ~isAll) || (~gChanAlign.isNirs && isAll)
        iChan = iNirs;
    else
        iChan = [];
    end
    iChanModified = union(iChanModified, iChan);

    % Apply the rotation and translation to selected sensors
    for i=1:length(iChan)
        Loc = ChannelMat.Channel(iChan(i)).Loc;
        Orient = ChannelMat.Channel(iChan(i)).Orient;
        nCoils = size(Loc, 2);
        % Update location
        if ~isempty(Loc) && ~isequal(Loc, [0;0;0])
            ChannelMat.Channel(iChan(i)).Loc = Rfinal * Loc + Tfinal * ones(1, nCoils);
        end
        % Update orientation
        if ~isempty(Orient) && ~isequal(Orient, [0;0;0])
            ChannelMat.Channel(iChan(i)).Orient = Rfinal * Orient;
        end
    end
    % If needed: transform the digitized head points
    if gChanAlign.isHeadPoints
        % Update points positions
        iExtra = get(gChanAlign.hHeadPointsMarkers, 'UserData');
        ChannelMat.HeadPoints.Loc(:,iExtra) = gChanAlign.HeadPointsMarkersLoc';
        % Fiducials
        if ~isempty(gChanAlign.hHeadPointsFid)
            iFid = get(gChanAlign.hHeadPointsFid, 'UserData');
            ChannelMat.HeadPoints.Loc(:,iFid) = gChanAlign.HeadPointsFidLoc';
        end
        % HPI
        if ~isempty(gChanAlign.hHeadPointsHpi)
            iHpi = get(gChanAlign.hHeadPointsHpi, 'UserData');
            ChannelMat.HeadPoints.Loc(:,iHpi) = gChanAlign.HeadPointsHpiLoc';
        end
    end

    % If a TransfMeg field with translations/rotations available
    if gChanAlign.isMeg || isAll
        if ~isfield(ChannelMat, 'TransfMeg') || ~iscell(ChannelMat.TransfMeg)
            ChannelMat.TransfMeg = {};
        end
        if ~isfield(ChannelMat, 'TransfMegLabels') || ~iscell(ChannelMat.TransfMegLabels) || (length(ChannelMat.TransfMeg) ~= length(ChannelMat.TransfMegLabels))
            ChannelMat.TransfMegLabels = cell(size(ChannelMat.TransfMeg));
        end
        % Add a new transform to the list
        ChannelMat.TransfMeg{end+1} = newtransf;
        ChannelMat.TransfMegLabels{end+1} = 'manual correction';
    end
    % If also need to apply it to the EEG
    if gChanAlign.isEeg || isAll
        if ~isfield(ChannelMat, 'TransfEeg') || ~iscell(ChannelMat.TransfEeg)
            ChannelMat.TransfEeg = {};
        end
        if ~isfield(ChannelMat, 'TransfEegLabels') || ~iscell(ChannelMat.TransfEegLabels) || (length(ChannelMat.TransfEeg) ~= length(ChannelMat.TransfEegLabels))
            ChannelMat.TransfEegLabels = cell(size(ChannelMat.TransfEeg));
        end
        ChannelMat.TransfEeg{end+1} = newtransf;
        ChannelMat.TransfEegLabels{end+1} = 'manual correction';
    end

    % Add number of channels to the comment
    ChannelMat.Comment = str_remove_parenth(ChannelMat.Comment, '(');
    ChannelMat.Comment = [ChannelMat.Comment, sprintf(' (%d)', length(ChannelMat.Channel))];

    % History: Align channel files manually
    ChannelMat = bst_history('add', ChannelMat, 'align', 'Align channels manually:');
    % History: Rotation + translation
    ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', Rfinal'));
    ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', Tfinal));
    if gChanAlign.isEeg
        ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('+ Possible other non-recordable operations on EEG electrodes'));
    end
end


%% ===== FIGURE CLOSE REQUESTED =====
function AlignClose_Callback(varargin)
    global gChanAlign;
    if gChanAlign.isChanged
        % Ask user to save changes (only if called as a callback)
        if (nargin == 3)
            SaveChanged = 1;
        else
            SaveChanged = java_dialog('confirm', ['The sensors locations changed.' 10 10 ...
                                           'Would you like to save changes? ' 10 10], 'Align sensors');
        end
        % Progress bar
        bst_progress('start', 'Align sensors', 'Updating channel file...');
        % Save changes and close figure
        if SaveChanged
            % Restore standard close callback for 3DViz figures
            set(gChanAlign.hFig, 'CloseRequestFcn', gChanAlign.Figure3DCloseRequest_Bak);
            drawnow;
            % Get new positions
            [ChannelMat, Transf, iChannels] = GetCurrentChannelMat();
            % Load original channel file
            ChannelMatOrig = in_bst_channel(gChanAlign.ChannelFile);
            % Save new electrodes positions in ChannelFile
            bst_save(gChanAlign.ChannelFile, ChannelMat, 'v7');
            % Get study associated with channel file
            [sStudy, iStudy] = bst_get('ChannelFile', gChanAlign.ChannelFile);
            % Reload study file
            db_reload_studies(iStudy);
        end
        bst_progress('stop');
    else
        SaveChanged = 0;
    end
    % Only close figure
    gChanAlign.Figure3DCloseRequest_Bak(varargin{1:2});
    % Apply to other recordings in the same subject
    if SaveChanged
        CopyToOtherFolders(ChannelMatOrig, iStudy, Transf, iChannels);
    end
end


%% ===== COPY TO OTHER FOLDERS =====
function CopyToOtherFolders(ChannelMatSrc, iStudySrc, Transf, iChannels)
    % Confirmation: ask the first time
    isConfirm = [];
    % Get subject
    sStudySrc = bst_get('Study', iStudySrc);
    [sSubject, iSubject] = bst_get('Subject', sStudySrc.BrainStormSubject);
    % If the subject is configured to share its channel files, nothing to do
    if (sSubject.UseDefaultChannel >= 1)
        return;
    end
    % Get positions of all the sensors
    locSrc = [ChannelMatSrc.Channel.Loc];
    % Get all the dependent studies
    [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
    % List of channel files to update
    ChannelFiles = {};
    strMsg = '';
    % Loop on the other folders
    for i = 1:length(sStudies)
        % Skip original study
        if (iStudies(i) == iStudySrc)
            continue;
        end
        % Skip studies without channel files
        if isempty(sStudies(i).Channel) || isempty(sStudies(i).Channel(1).FileName)
            continue;
        end
        % Load channel file
        ChannelMatDest = in_bst_channel(sStudies(i).Channel(1).FileName);
        % Get positions of all the sensors
        locDest = [ChannelMatDest.Channel.Loc];
        % Check if the channel files are similar
        if (length(ChannelMatDest.Channel) ~= length(ChannelMatSrc.Channel)) || (size(locDest,2) ~= size(locSrc,2))
            continue;
        end
        % Check if the positions of the sensors are similar
        distLoc = sqrt((locDest(1,:) - locSrc(1,:)).^2 + (locDest(2,:) - locSrc(2,:)).^2 + (locDest(3,:) - locSrc(3,:)).^2);
        % If the sensors are more than 5mm apart in average: skip
        if any(distLoc > 0.005) 
            continue;
        end
        % Ask confirmation to the user
        if isempty(isConfirm)
            isConfirm = java_dialog('confirm', 'Apply the same transformation to all the other datasets in the same subject?', 'Align sensors');
            if ~isConfirm
                return;
            end
        end
        % Add channel file to list of files to process
        ChannelFiles{end+1} = sStudies(i).Channel(1).FileName;
        strMsg = [strMsg, sStudies(i).Channel(1).FileName, 10];
    end
    % Apply transformation
    if ~isempty(ChannelFiles)
        % Progress bar
        bst_progress('start', 'Align sensors', 'Updating other datasets...');
        % Update files
        channel_apply_transf(ChannelFiles, Transf, iChannels, 1);
        % Give report to the user
        bst_progress('stop');
        java_dialog('msgbox', sprintf('Updated %d additional file(s):\n%s', length(ChannelFiles), strMsg));
    end
end


%% ===== SELECT ONE CHANNEL =====
function SelectOneChannel()
    global gChanAlign;
    % Get selected channels
    SelChan = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    % If there is more than one selected channels: select only one
    if iscell(SelChan) && (length(SelChan) > 1)
        bst_figures('SetSelectedRows', SelChan(1));
    end
end


%% ===== SHOW/HIDE LABELS =====
function ToggleLabels(varargin)
    global gChanAlign;
    % Update button color
    gui_update_toggle(gChanAlign.hButtonLabels);
    if strcmpi(get(gChanAlign.hButtonLabels, 'State'), 'on')
        set(gChanAlign.hSensorsLabels, 'Visible', 'on');
    else
        set(gChanAlign.hSensorsLabels, 'Visible', 'off');
    end
end

%% ===== SHOW/HIDE HELMET =====
function ToggleHelmet(varargin)
    global gChanAlign;
    % Update button color
    gui_update_toggle(gChanAlign.hButtonHelmet);
    if strcmpi(get(gChanAlign.hButtonHelmet, 'State'), 'on')
        set(gChanAlign.hHelmetPatch, 'Visible', 'on');
    else
        set(gChanAlign.hHelmetPatch, 'Visible', 'off');
    end
end


%% ===== EDIT LABEL =====
function EditLabel(varargin)
    global GlobalData gChanAlign;
    % Get selected channels
    SelChan = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    % No channel selected: return
    if isempty(SelChan)
        return
    elseif (length(SelChan) > 1)
        % Select only one channel
        SelectOneChannel();
    end
    % Edit label
    [SelChan, iSelChan] = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    % Ask user for a new Cluster Label
    newLabel = java_dialog('input', sprintf('Please enter a new label for channel "%s":', SelChan{1}), ...
                             'Rename selected channel', [], SelChan{1});
    if isempty(newLabel) || strcmpi(newLabel, SelChan{1})
        return
    end
    % Check that sensor name does not already exist
    if any(strcmpi(newLabel, {GlobalData.DataSet(gChanAlign.iDS).Channel.Name}))
        bst_error(['Electrode "' newLabel '" already exists.'], 'Rename electrode', 0);
        return;
    end
    % Update GlobalData
    GlobalData.DataSet(gChanAlign.iDS).Channel(iSelChan).Name = newLabel;
    % Update label graphically
    iTextChan = length(gChanAlign.hSensorsLabels) - gChanAlign.iGlobal2Local(iSelChan) + 1;
    set(gChanAlign.hSensorsLabels(iTextChan), 'String', newLabel);
    gChanAlign.SensorsLabels{iTextChan} = newLabel;
    gChanAlign.isChanged = 1;
end


%% ===== SELECT OPERATION =====
function SelectOperation(hObject, ev)
    global gChanAlign;
    % Update button color
    gui_update_toggle(hObject);
    % Get the list of valid buttons
    hButtonList = [gChanAlign.hButtonTransX,  gChanAlign.hButtonTransY,  gChanAlign.hButtonTransZ, ...
                   gChanAlign.hButtonRotX,    gChanAlign.hButtonRotY,    gChanAlign.hButtonRotZ];
    if gChanAlign.isEeg
        hButtonList = [hButtonList, gChanAlign.hButtonResizeX, gChanAlign.hButtonResizeY, gChanAlign.hButtonResizeZ, ...
                       gChanAlign.hButtonResize, gChanAlign.hButtonMoveChan];
    end
    % Unselect all buttons excepted the selected one
    hButtonsUnsel = setdiff(hButtonList, hObject);
    hButtonsUnsel = hButtonsUnsel(strcmpi(get(hButtonsUnsel, 'State'), 'on'));
    if ~isempty(hButtonsUnsel)
        set(hButtonsUnsel, 'State', 'off');
        gui_update_toggle(hButtonsUnsel(1));
    end
    
    % If button was unselected: nothing to do
    if strcmpi(get(hObject, 'State'), 'off')
        gChanAlign.selectedButton = [];
    else
        gChanAlign.selectedButton = hObject;
    end
    % If moving channels: keep only one selected channels
    UniqueChannelSelection = gChanAlign.isEeg && isequal(gChanAlign.selectedButton, gChanAlign.hButtonMoveChan);
    setappdata(gChanAlign.hFig, 'UniqueChannelSelection', UniqueChannelSelection);
    if UniqueChannelSelection
        SelectOneChannel();
    end
end

%% ===== PROJECT ELECTRODES =====
function ProjectElectrodesOnSurface(varargin)
    global gChanAlign;
    % NIRS: Need to close the current figure and reopen it
    if gChanAlign.isNirs
        bst_progress('start', 'Project sensors', 'Saving modifications...');
        AlignClose_Callback(gChanAlign.hFig, [], 1);
        bst_progress('start', 'Project sensors', 'Projecting sensors...');
        process_channel_project('Compute', gChanAlign.ChannelFile, 'NIRS');
        bst_progress('start', 'Project sensors', 'Opening results...');
        channel_align_manual(gChanAlign.ChannelFile, gChanAlign.Modality, 1);
        bst_progress('stop');
        return;
    end
    % Get the list of valid buttons
    hButtonList = [gChanAlign.hButtonTransX, gChanAlign.hButtonTransY, gChanAlign.hButtonTransZ, gChanAlign.hButtonLabels, ...
                   gChanAlign.hButtonRotX,   gChanAlign.hButtonRotY,   gChanAlign.hButtonRotZ,   gChanAlign.hButtonRefine, gChanAlign.hButtonOk];
    if gChanAlign.isEeg
        hButtonList = [hButtonList, gChanAlign.hButtonResizeX, gChanAlign.hButtonResizeY, gChanAlign.hButtonResizeZ, gChanAlign.hButtonAlign, ...
                       gChanAlign.hButtonProject, gChanAlign.hButtonResize, gChanAlign.hButtonMoveChan, gChanAlign.hButtonAdd, ...
                       gChanAlign.hButtonEditLabel, gChanAlign.hButtonDelete];
    end
    % Wait mode
    bst_progress('start', 'Align electrode contacts', 'Projecting electrodes on scalp...');
    set(hButtonList, 'Enable', 'off');
    drawnow();
    
    % Get surface patch
    TessInfo = getappdata(gChanAlign.hFig, 'Surface');
    gChanAlign.hSurfacePatch = TessInfo(1).hPatch;
    % Get coordinates of vertices for each face
    Vertices = get(gChanAlign.hSurfacePatch, 'Vertices');
    % For cortex surface: take the convex hull instead of the surface itself
    if strcmpi(TessInfo.Name, 'Cortex')
        Faces = convhulln(Vertices);
        Vertices = Vertices(unique(Faces(:)), :);
    end
    
    % Get channels to modify 
    [ChanToProject, iChanToProject] = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    if isempty(iChanToProject)
        iChanToProject = 1:size(gChanAlign.SensorsVertices,1);
    else
        % Convert local sensors indices in global indices (channel file)
        iChanToProject = gChanAlign.iGlobal2Local(iChanToProject);
    end

    % Process each sensor
    gChanAlign.SensorsVertices(iChanToProject,:) = channel_project_scalp(Vertices, gChanAlign.SensorsVertices(iChanToProject,:));
    % Copy modification to the head points
    if gChanAlign.isEeg && ~isempty(gChanAlign.SensorsVertices) && ~isempty(gChanAlign.HeadPointsMarkersLoc) && (length(gChanAlign.SensorsVertices) == length(gChanAlign.HeadPointsMarkersLoc))
        gChanAlign.HeadPointsMarkersLoc = gChanAlign.SensorsVertices;
        set(gChanAlign.hHeadPointsMarkers, 'XData', gChanAlign.HeadPointsMarkersLoc(:,1), ...
                                           'YData', gChanAlign.HeadPointsMarkersLoc(:,2), ...
                                           'ZData', gChanAlign.HeadPointsMarkersLoc(:,3));
    end
    % Mark current channel file as modified
    gChanAlign.isChanged = 1;
   
    % Update Sensors display
    SetSensorsVertices(gChanAlign.hSensorsPatch, gChanAlign.hSensorsMarkers, gChanAlign.SensorsVertices);
    for i=1:length(iChanToProject)
        iTextChan = length(gChanAlign.hSensorsLabels) - iChanToProject(i) + 1;
        set(gChanAlign.hSensorsLabels(iTextChan), 'Position', 1.08 * gChanAlign.SensorsVertices(iChanToProject(i),:));
    end
    drawnow();
    % Restore GUI
    bst_progress('stop');
    set(hButtonList, 'Enable', 'on');
end


%% ===== REFINE USING HEAD POINTS =====
function RefineWithHeadPoints(varargin)
    global gChanAlign;
    % Get current channel file
    ChannelMat = GetCurrentChannelMat(1);
    % Refine positions using head points
    [ChannelMat, Rnew, Tnew] = channel_align_auto(gChanAlign.ChannelFile, ChannelMat, 1, 0);
    if isempty(Rnew) && isempty(Tnew)
        return;
    end
    % Get channels to modify
    iSelChan = GetSelectedChannels();
    % Apply transformation
    ApplyTransformation(iSelChan, Rnew, Tnew(:)', []);
    % Update display
    UpdatePoints(iSelChan);
end


%% ===== VALIDATION BUTTONS =====
function buttonOk_Callback(varargin)
    global gChanAlign;
    % Close 3DViz figure
    close(gChanAlign.hFig);
end


%% ===== REMOVE ELECTRODES =====
function RemoveElectrodes(varargin)
    global GlobalData gChanAlign;
    % Display warning message
    if gChanAlign.isFirstRmWarning
        res = java_dialog('confirm', ['You are about to change the number of electrodes.', 10 ...
                           'This may cause some trouble while importing recordings.' 10 10, ...
                           'Are you sure you want to remove these electrodes ?' 10 10], 'Align sensors');
        if ~res
            return
        end
        gChanAlign.isFirstRmWarning = 0;
    end
    % Get selected channels
    [SelChan, iSelChan] = figure_3d('GetFigSelectedRows', gChanAlign.hFig);
    if isempty(SelChan)
        return
    end
    % Get indices
    iLocalChan = gChanAlign.iGlobal2Local(iSelChan);
    iTextChan = length(gChanAlign.hSensorsLabels) - iLocalChan + 1;
    % Remove them from everywhere
    bst_figures('SetSelectedRows', []);
    GlobalData.DataSet(gChanAlign.iDS).Channel(iSelChan) = [];
    delete(gChanAlign.hSensorsLabels(iTextChan));
    gChanAlign.hSensorsLabels(iTextChan) = [];
    gChanAlign.SensorsLabels(iTextChan) = [];
    gChanAlign.SensorsVertices(iLocalChan, :) = [];
    
    % Update correspondence Global/Local
    for i = 1:length(iLocalChan)
        indInc = (gChanAlign.iGlobal2Local >= iLocalChan(i));
        gChanAlign.iGlobal2Local(indInc) = gChanAlign.iGlobal2Local(indInc) - 1;
    end
    gChanAlign.iGlobal2Local(iSelChan) = [];

    % Remove from sensors patch
    if ~isempty(gChanAlign.hSensorsPatch)
        Vertices = get(gChanAlign.hSensorsPatch, 'Vertices');
        Faces    = get(gChanAlign.hSensorsPatch, 'Faces');
        FaceVertexCData = get(gChanAlign.hSensorsPatch, 'FaceVertexCData');
        [Vertices, Faces] = tess_remove_vert(Vertices, Faces, iLocalChan);
        FaceVertexCData(iLocalChan, :) = [];
        set(gChanAlign.hSensorsPatch, 'Vertices', Vertices, 'Faces', Faces, 'FaceVertexCData', FaceVertexCData);
        gChanAlign.isChanged = 1;
    elseif ~isempty(gChanAlign.hSensorsMarkers)
        UserData = get(gChanAlign.hSensorsMarkers, 'UserData');
        if iscell(UserData)
            iVertices = [UserData{:}];
        else
            iVertices = UserData;
        end
        iRemove = [];
        for i = 1:length(iLocalChan)
            iRemove = [iRemove, find(iLocalChan(i) == iVertices)];
        end
        delete(gChanAlign.hSensorsMarkers(iRemove));
        gChanAlign.hSensorsMarkers(iRemove) = [];
    end
end
        

%% ===== BUTTON: ADD ELECTRODE =====
function ButtonAddElectrode_Callback(hObject, ev)
    global gChanAlign;
    % Display warning message
    if gChanAlign.isFirstAddWarning
        res = java_dialog('confirm', ['You are about to change the number of electrodes.', 10 ...
                           'This may cause some trouble while importing recordings.' 10 10, ...
                           'Are you sure you want to add an electrode ?' 10 10], 'Align sensors');
        if ~res
            set(hObject, 'State', 'off');
            return
        end
        gChanAlign.isFirstAddWarning = 0;
    end
    % Change figure cursor
    if strcmpi(get(hObject, 'State'), 'on')
        set(gChanAlign.hFig, 'Pointer', 'cross');
    else
        set(gChanAlign.hFig, 'Pointer', 'arrow');
    end
end

%% ===== ADD ELECTRODE =====
function AddElectrode(hObject, ev)
    global GlobalData gChanAlign;
    % Select the nearest sensor from the mouse
    [p, v, vi] = select3d(gChanAlign.hSurfacePatch);
    % If sensor index is not valid
    if isempty(vi) || (vi <= 0)
        return
    end
    bst_figures('SetSelectedRows', []);
    
    % Find the closest electrodes
    nbElectrodes = size(gChanAlign.SensorsVertices,1);
    % Get closest point to the clicked position
    [mindist, iClosestLocal] = min(sqrt(sum(bst_bsxfun(@minus, gChanAlign.SensorsVertices, p') .^ 2, 2)));
    % Get the correspondence in global listing
    iClosestGlobal = find(gChanAlign.iGlobal2Local == iClosestLocal);
    
    % Add channel to global list
    iNewGlobal = length(GlobalData.DataSet(gChanAlign.iDS).Channel) + 1;
    sChannel = GlobalData.DataSet(gChanAlign.iDS).Channel(iClosestGlobal);
    sChannel.Name = sprintf('E%d', iNewGlobal);
    sChannel.Loc = p;
    GlobalData.DataSet(gChanAlign.iDS).Channel(iNewGlobal) = sChannel;

    % Add channel to local list
    iNewLocal = nbElectrodes + 1;
    gChanAlign.SensorsVertices(iNewLocal,:) = p';
    gChanAlign.iGlobal2Local(iNewGlobal) = iNewLocal;

    % Add new vertex
    if ~isempty(gChanAlign.hSensorsPatch)
        Vertices = [get(gChanAlign.hSensorsPatch, 'Vertices'); p'];
        Faces = channel_tesselate(Vertices);
        FaceVertexCData = [get(gChanAlign.hSensorsPatch, 'FaceVertexCData'); 1 1 1];
        set(gChanAlign.hSensorsPatch, 'Vertices', Vertices, 'Faces', Faces, 'FaceVertexCData', FaceVertexCData);
    elseif ~isempty(gChanAlign.hSensorsMarkers)
        hNew = line(p(1), p(2), p(3), ...
                    'Parent',          get(gChanAlign.hSurfacePatch, 'Parent'), ...
                    'LineWidth',       2, ...
                    'LineStyle',       'none', ...
                    'MarkerFaceColor', [1 1 1], ...
                    'MarkerEdgeColor', [.4 .4 .4], ...
                    'MarkerSize',      6, ...
                    'Marker',          'o', ...
                    'Tag',             'SensorsMarkers');
        gChanAlign.hSensorsMarkers(end+1) = hNew;
    end
    % Add channel to figure selected channels
    GlobalData.DataSet(gChanAlign.iDS).Figure(gChanAlign.iFig).SelectedChannels(end + 1) = iNewGlobal;
    
    % Copy existing label object
    gChanAlign.SensorsLabels = cat(2, {sChannel.Name}, gChanAlign.SensorsLabels);
    iTextClosest = length(gChanAlign.hSensorsLabels) - iClosestLocal + 1;
    hClosestLabel = gChanAlign.hSensorsLabels(iTextClosest);
    hNewLabel = copyobj(hClosestLabel, get(hClosestLabel, 'Parent'));
    set(hNewLabel, 'String', sChannel.Name, 'Position', 1.08 * p');
    gChanAlign.hSensorsLabels = [hNewLabel; gChanAlign.hSensorsLabels];

    % Unselect "Add electrode" button
    set(gChanAlign.hButtonAdd, 'State', 'off');
    ButtonAddElectrode_Callback(gChanAlign.hButtonAdd, []);
    % Select new electrode
    bst_figures('SetSelectedRows', {sChannel.Name});
    % Set modified flag
    gChanAlign.isChanged = 1;
end

%% ===== GET SENSORS VERTICES =====
function SensorsVertices = GetSensorsVertices(hSensorsPatch, hSensorsMarkers)
    if ~isempty(hSensorsPatch)
        SensorsVertices = get(hSensorsPatch, 'Vertices');
    else
        XData = get(hSensorsMarkers, 'XData');
        YData = get(hSensorsMarkers, 'YData');
        ZData = get(hSensorsMarkers, 'ZData');
        UserData = get(hSensorsMarkers, 'UserData');
        if iscell(UserData)
            [tmp,I] = sort([UserData{:}]);
            SensorsVertices = [XData{I}; YData{I}; ZData{I}]';
        else
            SensorsVertices = [XData; YData; ZData]';
        end
    end
end

%% ===== SET SENSORS VERTICES =====
function SetSensorsVertices(hSensorsPatch, hSensorsMarkers, SensorsVertices)
    if ~isempty(hSensorsPatch)
        set(hSensorsPatch, 'Vertices', SensorsVertices);
    else
        for i = 1:length(hSensorsMarkers)
            iVertex = get(hSensorsMarkers(i), 'UserData');
            set(hSensorsMarkers(i), 'XData', SensorsVertices(iVertex, 1));
            set(hSensorsMarkers(i), 'YData', SensorsVertices(iVertex, 2));
            set(hSensorsMarkers(i), 'ZData', SensorsVertices(iVertex, 3));
        end
    end
end


