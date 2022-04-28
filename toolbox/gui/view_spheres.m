function hFig = view_spheres(HeadModelFile, ChannelFile, sSubject)
% VIEW_SPHERES: Show all the spheres from a "overlapping spheres" forward model.
%
% USAGE:  hFig = view_spheres(HeadModelFile, ChannelFile, sSubject)

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
% Authors: Francois Tadel, 2008-2011

%% ===== PARSE INPUTS =====
% Get reference surface
if ~isempty(sSubject.iScalp)
    sScalp = in_tess_bst(sSubject.Surface(sSubject.iScalp).FileName);
else
    sScalp = [];
end
if ~isempty(sSubject.iInnerSkull)
    sInnerSkull = in_tess_bst(sSubject.Surface(sSubject.iInnerSkull).FileName);
elseif ~isempty(sSubject.iCortex)
    CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    sInnerSkull = tess_envelope(CortexFile, 'convhull', 1082, .003);
else    
    sInnerSkull = [];
end
hFig = [];

%% ===== LOAD DATA =====
% Load HeadModel ('Param' field only)
HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'Param', 'MEGMethod', 'EEGMethod');
Spheres = HeadModelMat.Param;
% Load Channels
ChannelMat = in_bst_channel(ChannelFile);
Channel = ChannelMat.Channel;

%% ===== SELECT SPHERES TO DISPLAY =====
iSel = [];
if ~isempty(HeadModelMat.MEGMethod)
    iMeg = good_channel(Channel, [], 'MEG');
    if ismember(HeadModelMat.MEGMethod, {'meg_sphere', 'singlesphere'})
        iSel = [iSel, iMeg(1)];
    elseif ismember(HeadModelMat.MEGMethod, {'os_meg', 'localspheres'})
        iSel = [iSel, iMeg];
    end
end
if ismember(HeadModelMat.EEGMethod, {'eeg_3sphereberg', 'singlesphere', 'concentricspheres'})
    iEeg = good_channel(Channel, [], 'EEG');
    iSel = [iSel, iEeg(1)];
    Channel(iEeg(1)).Name = 'EEG';
end
Spheres = Spheres(iSel);
Channel = Channel(iSel);


%% ===== DISPLAY SURFACES =====
hFig = [];
% Display scalp
if ~isempty(sScalp)
    hFig = view_surface_matrix(sScalp.Vertices, sScalp.Faces, .9, []);
end
% Display inner skull (or inflated cortex envelope)
if ~isempty(sInnerSkull)
    if isempty(hFig)
        hFig = view_surface_matrix(sInnerSkull.Vertices, sInnerSkull.Faces, .2, []);
    else
        view_surface_matrix(sInnerSkull.Vertices, sInnerSkull.Faces, .2, [], hFig);
    end
end
% No figure create: error
if isempty(hFig)
    error('No reference surface available');
end
% Set orientation: left
figure_3d('SetStandardView', hFig, 'left');
% Update figure name
set(hFig, 'Name', ['Check spheres: ' HeadModelFile]);
% Get axes handles
hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');


%% ===== DISPLAY SPHERES+SENSORS =====
% Hack keyboard callback
KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
set(hFig, 'KeyPressFcn', @KeyPress_Callback);
% Create legend (Sphere)
hLabel = uicontrol('Style',               'text', ...
                   'String',              '...', ...
                   'Units',               'Pixels', ...
                   'Position',            [6 0 400 18], ...
                   'HorizontalAlignment', 'left', ...
                   'FontUnits',           'points', ...
                   'FontSize',            bst_get('FigFont'), ...
                   'ForegroundColor',     [.3 1 .3], ...
                   'BackgroundColor',     [0 0 0], ...
                   'Parent',              hFig);
% Plot sensors
if length(Channel) > 10
    markersLocs   = cell2mat(cellfun(@(c)c(:,1), {Channel.Loc}, 'UniformOutput', 0))';
    hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
    set(hSensors, 'LineWidth', 1, 'MarkerSize', 2);
end

% Base of spheres
[X,Y,Z] = sphere(20);
XYZ = tess_sphere(812);
[TH,PHI,R] = cart2sph(X,Y,Z);

% Current sphere
iSphere = 1;
% Draw first sphere
DrawSphere();


%% ===== KEYBOARD CALLBACK =====
    function KeyPress_Callback(h, keyEvent)
        switch (keyEvent.Key)
            % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow  ===
            case {'leftarrow', 'space', 'uparrow'}
                iSphere = iSphere - 1;
            case 'pagedown'
                iSphere = iSphere - 10;
            case {'rightarrow', 'downarrow'}
                iSphere = iSphere + 1;
            case 'pageup'
                iSphere = iSphere + 10;
            otherwise
                KeyPressFcn_bak(h, keyEvent);
                return;
        end
        % Redraw sphere
        if (iSphere <= 0)
            iSphere = length(Spheres);
        end
        if (iSphere > length(Spheres))
            iSphere = 1;
        end
        DrawSphere();
    end
    
       
%% ===== DRAW CURRENT SPHERE =====
    function DrawSphere()
        % Delete previous spheres and sensors
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'OverlapSphere'));
        % Draw current sphere
        [X,Y,Z] = sph2cart(TH, PHI, R * Spheres(iSphere).Radii(end));
        hSphere = patch(surf2patch(X + Spheres(iSphere).Center(1),...
                                   Y + Spheres(iSphere).Center(2),...
                                   Z + Spheres(iSphere).Center(3),...
                                   Z + Spheres(iSphere).Center(3))); 
        set(hSphere, 'Parent',    hAxes, ...
                     'Facecolor', 'none', ...
                     'EdgeColor', [.8 .8 .8], ...
                     'EdgeAlpha', 1, ...
                     'LineWidth', 1, ...
                     'Tag',       'OverlapSphere');

        % Remove previous selected sensor
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelSphereChannel'));
        % Plot selected sensor
        if ~isempty(Channel(iSphere).Loc) && ~ismember(Channel(iSphere).Name, {'EEG','MEG','MEG MAG', 'MEG GRAD'})
            line(Channel(iSphere).Loc(1,1), Channel(iSphere).Loc(2,1), Channel(iSphere).Loc(3,1), ...
                 'Parent',          hAxes, ...
                 'LineWidth',       2, ...
                 'LineStyle',       'none', ...
                 'Marker',          'o', ...
                 'MarkerFaceColor', [1 0 0], ...
                 'MarkerEdgeColor', [.4 .4 .4], ...
                 'MarkerSize',      8, ...
                 'Tag',             'SelSphereChannel');
        end

         % Update legend
        newLegend = sprintf('Sphere #%d/%d  (%s)', iSphere, length(Spheres), Channel(iSphere).Name);
        if (iSphere == 1) && (length(Spheres) > 1)
            newLegend = [newLegend, '       [Press arrows for next/previous sphere...]'];
        end
        set(hLabel, 'String', newLegend);
    end


end
