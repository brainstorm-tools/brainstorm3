function hFig = view_leadfield_sensitivity(HeadmodelFile, Modality, DisplayMode)
% VIEW_LEADFIELD_SENTIVITY: Show the leadfield sensitivity on the MRI slices.
% 
% USAGE:  hFig = view_leadfield_sensitivity(HeadmodelFile, Modality, DisplayMode='Mri3D')
%
% INPUTS:
%    - HeadmodelFile : Relative file path to Brainstorm forward model
%    - Modality      : {'MEG', 'EEG', 'ECOG', 'SEEG'}
%    - DisplayMode   : {'Mri3D', 'MriViewer', 'Surface', 'Isosurface'}

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
% Authors: Francois Tadel, 2022
%          Takfarinas Medani, 2022

global GlobalData;

% Parse inputs
if (nargin < 3) || isempty(DisplayMode)
    DisplayMode = 'Mri3D';
end
hFig = [];

% Isosurface display : Requires ISO2MESH
if strcmpi(DisplayMode, 'isosurface')
    [isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', 1);
    if ~isInstalled
        error(errMsg);
    end
end

% ===== LOAD DATA =====
bst_progress('start', 'View leadfields', 'Loading headmodel...');
% Load channel file
[sStudy, iStudy, iHeadModel] = bst_get('HeadModelFile', HeadmodelFile);
ChannelFile = sStudy.Channel.FileName;
ChannelMat = in_bst_channel(sStudy.Channel.FileName, 'Channel');
% Get modality channels
iModChannels = good_channel(ChannelMat.Channel, [], Modality);
if isempty(iModChannels)
    error(['No channels "' Modality '" in channel file: ' ChannelFile]);
end
Channels = ChannelMat.Channel(iModChannels);
markersLocs = cell2mat(cellfun(@(c)c(:,1), {Channels.Loc}, 'UniformOutput', 0))';
isMeg = ismember(Modality, {'MEG', 'MEG MAG', 'MEG GRAD'});
% Load leadfield matrix
HeadmodelMat = in_bst_headmodel(HeadmodelFile);
GainMod = HeadmodelMat.Gain(iModChannels, :);
isVolumeGrid = ismember(HeadmodelMat.HeadModelType, {'volume', 'mixed'});
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMri = in_mri_bst(MriFile);

% ===== CREATE FIGURE =====
is3D = 0;
grid2mri_interp = [];
switch (HeadmodelMat.HeadModelType)
    % === VOLUME ===
    case {'volume', 'mixed'}
        % Isosurface
        if strcmpi(DisplayMode, 'isosurface')
            % Compute Delaunay tesselation of the grid
            dt = delaunayTriangulation(HeadmodelMat.GridLoc);
            % Open 3D MRI view
            [hFig, iDS, iFig] = view_mri_3d(MriFile, [], [], 'NewFigure');
            is3D = 1;
        else
            % Compute interpolation
            sMri.FileName = MriFile;
            ComputeMriInterp();
            % Create figure
            switch lower(DisplayMode)
                case 'mri3d'
                    [hFig, iDS, iFig] = view_mri_3d(MriFile, HeadmodelFile, [], 'NewFigure');
                    is3D = 1;
                case 'mriviewer'
                    [hFig, iDS, iFig] = view_mri(MriFile, HeadmodelFile, Modality, 1);
                otherwise
                    error(['Unknown display mode: "' DisplayMode '"']);
            end
            % Save update callback (for external calls, e.g. when changing the interpolation properties)
            setappdata(hFig, 'UpdateCallback', @UpdateMriInterp);
        end
    % === SURFACE ===
    case 'surface'
        [hFig, iDS, iFig] = view_surface_data(HeadmodelMat.SurfaceFile, HeadmodelFile, Modality, 'NewFigure', 0);
        is3D = 1;
end
if isempty(hFig)
    error('No anatomy could be displayed.');
end

% ===== CONFIGURE FIG ======
% By default: average reference
isAvgRef = 1;
iRef = [];
% By default: the target is the first channel available
iChannel = 1;
% Isosurface threshold
Thresh = [];
% Update figure name
set(hFig, 'Name', ['Leadfield: ' HeadmodelFile]);
% Save channel file in dataset
GlobalData.DataSet(iDS).ChannelFile = ChannelFile;
GlobalData.DataSet(iDS).Channel = Channels;
if isfield(ChannelMat, 'IntraElectrodes') && ~isempty(ChannelMat.IntraElectrodes)
    GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
end
% Hack keyboard callback
KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
set(hFig, 'KeyPressFcn', @KeyPress_Callback);
% 3D figure: Add label and display dots
if is3D
    % Set orientation: left
    figure_3d('SetStandardView', hFig, 'left');
    % Get axes handles
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
end
% Create legend
hLabel = uicontrol('Style', 'text', ...
    'String',              '...', ...
    'Units',               'Pixels', ...
    'Position',            [6 0 400 38], ...
    'HorizontalAlignment', 'left', ...
    'FontUnits',           'points', ...
    'FontSize',            bst_get('FigFont'), ...
    'ForegroundColor',     [.3 1 .3], ...
    'BackgroundColor',     [0 0 0], ...
    'Parent',              hFig);
% Update colormap units
ColormapInfo = getappdata(hFig, 'Colormap');
switch (Modality)
    case {'MEG', 'MEG MAG', 'MEG GRAD'}
        ColormapInfo.DisplayUnits = 'fT/nAm';  % ~ 1e-6
        dispFactor = 1e6;
    case {'EEG', 'SEEG', 'ECOG'}
        ColormapInfo.DisplayUnits = '\muV/nAm';  % ~ 1e3
        dispFactor = 1e-3;
end
setappdata(hFig, 'Colormap', ColormapInfo);
% Display SEEG/ECOG electrodes
if ismember(Modality, {'SEEG', 'ECOG'})
    switch lower(DisplayMode)
        case {'isosurface', 'mri3d', 'surface'}
            view_channels(ChannelFile, Modality, 1, 0, hFig, 1);
        case 'mriviewer'
            figure_mri('LoadElectrodes', hFig, ChannelFile, Modality);
            gui_brainstorm('ShowToolTab', 'iEEG');
    end
end
% Update display
UpdateLeadfield();
% Reset thresholds
panel_surface('SetDataThreshold', hFig, 1, 0);
panel_surface('SetSizeThreshold', hFig, 1, 1);



%% ==================================================================================================
%  ===== INTERFACE CALLBACKS ========================================================================
%  ==================================================================================================

%% ===== KEYBOARD CALLBACK =====
    function KeyPress_Callback(hFig, keyEvent)
        isUpdate = 0;
        switch (keyEvent.Key)
            % === LEFT, RIGHT, UP, DOWN: CHANGE CHANNEL ===
            case 'leftarrow'
                iChannel = iChannel - 1;
                if ~isempty(iRef) && (iChannel == iRef)
                    iChannel = iChannel - 1;
                end
                if (iChannel < 0)
                    if ~isempty(iRef) && (iRef == length(Channels))
                        iChannel = length(Channels) - 1;
                    else
                        iChannel = length(Channels);
                    end
                end
                isUpdate = 1;
            case 'rightarrow'
                iChannel = iChannel + 1;
                if ~isempty(iRef) && (iChannel == iRef)
                    iChannel = iChannel + 1;
                end
                if (iChannel > length(Channels))
                    iChannel = 0;   % Sum of all channels
                end
                isUpdate = 1;
            case 'downarrow'
                if ~isMeg
                    if isempty(iRef)
                        iRef = length(Channels) + 1;
                    end
                    iRef = iRef - 1;
                    if (iRef == iChannel)
                        iRef = iRef - 1;
                    end
                    if (iRef < 1)
                        iRef = [];
                        isAvgRef = 1;
                    else
                        isAvgRef = 0;
                    end
                    isUpdate = 1;
                end
            case 'uparrow'
                if ~isMeg
                    if isempty(iRef)
                        iRef = 0;
                    end
                    iRef = iRef + 1;
                    if (iRef == iChannel)
                        iRef = iRef + 1;
                    end
                    if (iRef > length(Channels))
                        iRef = [];
                        isAvgRef = 1;
                    else
                        isAvgRef = 0;
                    end
                    isUpdate = 1;
                end
            case 'i'
                if strcmpi(DisplayMode, 'isosurface') && SelectThreshold()
                    isUpdate = 1;
                end
            case 'r' % not for MEG
                if SelectReference()
                    isUpdate = 1;
                end
            case 't'
                if SelectTarget()
                    isUpdate = 1;
                end
            case 'l'
                if strcmp(get(hLabel, 'Visible'), 'on')
                    set (hLabel, 'Visible', 'off');
                else
                    set (hLabel, 'Visible', 'on');
                end
            case 'h'
                if is3D
                    strHelp3D = [...
                        '<TR><TD><B>Shift + E</B></TD><TD>Show/hide the sensors labels</TD></TR>' ...
                        '<TR><TD><B>0 to 9</B></TD><TD>Change view</TD></TR>'];
                else
                    strHelp3D = '';
                end
                if strcmpi(DisplayMode, 'isosurface')
                    strIso = '<TR><TD><B>I</B></TD><TD>Select the <B>I</B>sosurface threshold</TD></TR>';
                else
                    strIso = [];
                end
                java_dialog('msgbox', ['<HTML><TABLE>' ...
                    '<TR><TD><B>Left arrow</B></TD><TD>Previous target channel (red color)</TD></TR>' ...
                    '<TR><TD><B>Right arrow</B></TD><TD>Next target channel (red color)</TD></TR>' ...
                    '<TR><TD><B>Up arrow</B></TD><TD>Previous ref channel (green color)</TD></TR>' ...
                    '<TR><TD><B>Down arrow</B></TD><TD>Next ref channel (green color)</TD></TR>' ...
                    strIso ...
                    '<TR><TD><B>L</B></TD><TD>Show/hide legend</TD></TR>' ...
                    '<TR><TD><B>R</B></TD><TD>Select the <B>R</B>eference channel</TD></TR>' ...
                    '<TR><TD><B>T</B></TD><TD>Select the <B>T</B>arget channel</TD></TR>' ...
                    strHelp3D ...
                    '</TABLE>'], 'Keyboard shortcuts');      
            otherwise
                KeyPressFcn_bak(hFig, keyEvent); 
                return;
        end
        % Recompute leadfields and update figure
        if isUpdate
            UpdateLeadfield();
        end
    end


%% ===== EXTERNAL UPDATE =====
    function UpdateMriInterp()
        ComputeMriInterp();
        UpdateLeadfield();
    end


%% ===== COMPUTE MRI INTERPOLATION =====
    function ComputeMriInterp()
        MriOptions = bst_get('MriOptions');
        GridSmooth = 1;
        grid2mri_interp = grid_interp_mri(HeadmodelMat.GridLoc, sMri, [], 1, MriOptions.InterpDownsample, MriOptions.DistanceThresh, GridSmooth);
    end


%% ===== UPDATE LEADFIELD =====
    function UpdateLeadfield()
        % Compute sensitivity
        bst_progress('start', 'View leadfields', 'Computing sensitivity...');
        % Sum all the channels
        if (iChannel == 0)
            if isAvgRef
                LeadField = bst_bsxfun(@minus, GainMod, mean(GainMod,1));
            elseif ~isempty(iRef)
                LeadField = bst_bsxfun(@minus, GainMod, GainMod(iRef,:));
            end
            LeadField = reshape(LeadField, size(LeadField,1), 3, []); % each column is a vector
            normLF = permute(sum(sqrt(LeadField(:,1,:).^2 + LeadField(:,2,:).^2 + LeadField(:,3,:).^2), 1), [3 2 1]);
        % Compute the sensitivity for one sensor
        else
            if isAvgRef
                LeadField = GainMod(iChannel,:) - mean(GainMod,1);
            elseif ~isempty(iRef)
                LeadField = GainMod(iChannel,:) - GainMod(iRef,:);
            end
            LeadField = reshape(LeadField,3,[])'; % each column is a vector
            normLF = sqrt(LeadField(:,1).^2 + LeadField(:,2).^2 + LeadField(:,3).^2);
        end
        % Surface or volume
        switch lower(DisplayMode)
            case {'mriviewer', 'mri3d'}
                FigData = tess_interp_mri_data(grid2mri_interp, size(sMri.Cube), normLF, isVolumeGrid);
                OverlayCube = FigData;
            case 'surface'
                FigData = normLF;
                OverlayCube = [];
            case 'isosurface'
                FigData = [];
                if isempty(Thresh)
                    Thresh = 0.1 * max(normLF);
                end
                PlotBlob(hAxes, HeadmodelMat.GridLoc, dt, normLF, Thresh);
        end

        % Update surface or MRI slices
        if ~isempty(FigData)
            % Compute min/max
            minVol = min(FigData(:));
            maxVol = max(FigData(:));
            if (minVol == maxVol)
                error('No data to be displayed.');
            end
    
            % Get displayed objects description
            TessInfo = getappdata(hFig, 'Surface');
            % Add overlay cube
            TessInfo(1).DataSource.Type      = 'Source';
            TessInfo(1).DataSource.FileName  = HeadmodelFile;
            TessInfo(1).Data                 = FigData;
            TessInfo(1).OverlayCube          = OverlayCube;
            TessInfo(1).DataLimitValue       = [minVol, maxVol];
            TessInfo(1).DataMinMax           = [minVol, maxVol];
            % Update structures
            setappdata(hFig, 'Surface', TessInfo);
            % Update figure
            switch lower(DisplayMode)
                case 'mriviewer'
                    figure_mri('UpdateMriDisplay', hFig);
                case {'mri3d', 'surface'}
                    panel_surface('UpdateSurfaceColormap', hFig);
            end
        end

        % Update legend
        UpdateLegend();
        if is3D
            UpdateMarkers();
        end
        % Close progress bar
        bst_progress('stop');
    end


%% ===== UPDATE LEGEND =====
    function UpdateLegend()
        if (iChannel == 0)
            strTarget = 'Sum of all channels';
        else
            strTarget = sprintf('Target channel #%d/%d : %s (red)', iChannel, length(Channels), Channels(iChannel).Name);
        end
        if isMeg
            strTitle = strTarget;
        elseif isAvgRef
            strTitle = [strTarget '  |  Average reference'];
        else
            strTitle = [strTarget, sprintf('  |  Reference #%d/%d : %s (green)', iRef, length(Channels), Channels(iRef).Name)];
        end
        if (iChannel == 1) && (length(Channels) > 1)
            strTitle = [strTitle, 10 '[Press arrows for next/previous channel (or H for help)]'];
        end
        set(hLabel, 'String', strTitle);
    end


%% ===== UPDATE CHANNEL MARKES =====
    function UpdateMarkers()
        % Remove previous selected sensor
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelChannel'));
        % Plot selected sensor
        if (iChannel > 0)
            line(Channels(iChannel).Loc(1,1), Channels(iChannel).Loc(2,1), Channels(iChannel).Loc(3,1), ...
                'Parent',          hAxes, ...
                'LineWidth',       2, ...
                'LineStyle',       'none', ...
                'Marker',          'o', ...
                'MarkerFaceColor', [1 0 0], ...
                'MarkerEdgeColor', [.4 .4 .4], ...
                'MarkerSize',      8, ...
                'Tag',             'SelChannel');
        end
        % Remove previous selected reference
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
        % Plot the reference electrode
        if ~isMeg && ~isAvgRef
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
    end


%% ===== SELECT REFERENCE =====
    function isOk = SelectReference()
        isOk = 0;
        if ~isMeg
            % Ask for the reference electrode
            refChan = java_dialog('combo', '<HTML>Select the reference channel:<BR><BR>', [Modality ' reference'], [], {'Average Ref', Channels.Name});
            if isempty(refChan)
                return;
            end
            iRefTmp = find(strcmpi({Channels.Name}, refChan));
            if (iRefTmp == iChannel)
                bst_error(['Channel ' refChan ' is currently selected as the target.'], 'Select reference', 0);
                return;
            end
            iRef = iRefTmp;
            if isempty(iRef)
                isAvgRef = 1;
            else
                isAvgRef = 0;
            end
            isOk = 1;
        end
    end

%% ===== SELECT TARGET =====
    function isOk = SelectTarget()
        isOk = 0;
        % Ask for the target electrode
        trgChan = java_dialog('combo', '<HTML>Select the target channel (red color):<BR><BR>', [Modality ' Target'], [], {Channels.Name});
        if isempty(trgChan)
            return;
        end
        iChannelTmp = find(strcmpi({Channels.Name}, trgChan));
        if ~isempty(iRef) && (iChannelTmp == iRef)
            bst_error(['Channel ' trgChan ' is currently selected as the reference.'], 'Select target channel', 0);
            return;
        end
        iChannel = iChannelTmp;
        isOk = 1;
    end

%% ===== SELECT ISOSURFACE THRESHOLD =====
    function isOk = SelectThreshold()
        isOk = 0;
        % Ask for the target electrode
        res = java_dialog('input', ['<HTML>Enter the isosurface threshold (' strrep(ColormapInfo.DisplayUnits, '\mu', 'µ') '):<BR><BR>'], 'Isosurface threshold', [], num2str(Thresh * dispFactor));
        if isempty(res)
            return;
        end
        val = str2num(res);
        if isempty(val) || (val <= 0)
            bst_error('Invalid value.', 'Isosurface threshold', 0);
            return;
        end
        Thresh = val ./ dispFactor;
        isOk = 1;
    end
end


%% ===== PLOT BLOB =====
function PlotBlob(hAxes, GridLoc, dt, V, Thresh)
    % Compute isosurface with iso2mesh
    try
        % Compute isosurface
        [P,v,fc] = qmeshcut(dt.ConnectivityList, GridLoc, V, Thresh);
        % Convert quads into triangles
        Faces = [fc(:,[1,2,3]); fc(:,[1,3,4])];
        % Remove duplicate nodes
        [P,Faces] = meshcheckrepair(P, Faces, 'dup');

        % TODO: The surfaces must be closed using the boundaries of the brain
        % Maybe adding to the displayed patch the convhull of the full grid?

        % The block below computes the VTA: 
        % - it is quite slow 
        % - it requires the old TETGEN binaries to be kept in Iso2mesh (+2Mb in the binary package)
        % => Kept commented until further evaluated
        % =================================================
        % % Separate different blobs (possibly one around each active contact)
        % splitFaces = finddisconnsurf(Faces);
        % % Process each disconnected element separately
        % VTA = 0;
        % nodes = cell(2,length(splitFaces));
        % for i = 1:length(splitFaces)
        %     % Generate a closed surface
        %     [nodes{1,i}, nodes{2,i}] = meshcheckrepair(P, splitFaces{i}, 'meshfix');
        %     % Test if the surface is water-tight
        %     % [nodes{1,i}, nodes{2,i}] = s2m(nodes{1,i}, nodes{2,i}, 1, 0.001);
        %     % Compute its volume
        %     VTA = VTA + surfvolume(nodes{1,i}, nodes{2,i});
        % end
        % % Display VTA
        % disp(sprintf('BST> VTA = %f cm2', VTA * 1e6));
        % % Concatenate all the fixed blobs together
        % [P, Faces] = mergesurf(nodes{:});
        % ==================================================
    catch
        disp(['Error trying to compute the isosurface with Iso2mesh: ' lasterr]);
        Faces = [];
    end
    % Compute boundaries
    if isempty(Faces)
        iSel = find(V >= Thresh);
        P = GridLoc(iSel,:);
        if (length(iSel) > 2)
            Faces = boundary(P, 1);
        end
    end

    % Remove previous dots
    delete(findobj(hAxes, '-depth', 1, 'Tag', 'ptIso'));
    % Display selected grid points
    if isempty(Faces)
        % Plot grid points
        line(P(:,1), P(:,2), P(:,3), ...
            'LineStyle',   'none', ...
            'Color',       [0 1 0], ...
            'MarkerSize',  2, ...
            'Marker',      '.', ...
            'Tag',         'ptIso', ...
            'Parent',      hAxes);
    end

    % Display patch
    if ~isempty(Faces)
        % Configure patch
        patchColor = [0, .8, 0];
        patchAlpha = 0.4;
        % If patch does not exist yet : create it
        hPatch = findobj(hAxes, '-depth', 1, 'Tag', 'patchIso');
        if ~isempty(Faces)
            if isempty(hPatch)
                hPatch = patch(...
                    'Faces',            Faces, ...
                    'Vertices',         P, ...
                    'FaceVertexCData',  patchColor, ...
                    'FaceColor',        patchColor, ...
                    'EdgeColor',        'none',...
                    'FaceAlpha',        patchAlpha, ...
                    'BackFaceLighting', 'lit', ...
                    'Tag',              'patchIso', ...
                    'Parent',           hAxes, ...
                    'AmbientStrength',  0.5, ...
                    'DiffuseStrength',  0.5, ...
                    'SpecularStrength', 0.2, ...
                    'SpecularExponent', 1, ...
                    'SpecularColorReflectance', 0.5, ...
                    'FaceLighting',     'none', ...
                    'EdgeLighting',     'none');
            % Else : only update vertices and faces
            else
                set(hPatch, 'Faces', Faces, 'Vertices', P);
            end
        elseif ~isempty(hPatch)
            delete(hPatch);
        end
%         % Compute VTA
%         VTA = surfvolume(P, Faces);
%         strVta = sprintf('VTA=%f', VTA);

%         vtaThreshold = 99;
%         find(vq>prctile(vq,vtaThreshold))
%         vtaNode = brainNode(vq>=prctile(vq,vtaThreshold),:);
%         DT = delaunay(vtaNode); % later we need to sommth this surface and diplay is with better options
%         [openface,elemid]=volface(DT)
%         [vtaNode, vtaFace] = removeisolatednode(vtaNode, openface);
%         volVTA = surfvolume(vtaNode, vtaFace);
    end
end
