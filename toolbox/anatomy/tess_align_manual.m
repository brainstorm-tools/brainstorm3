function tess_align_manual( RefFile, SurfaceFile )
% TESS_ALIGN_MANUAL: Align manually a surface on a MRI or on another surface.
% 
% USAGE:  tess_align_manual( RefFile, SurfaceFile )
%
% INPUT:
%     - RefFile     : full path to the reference file (surface or MRI)
%     - SurfaceFile : full path to the surface to align

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
% Authors: Francois Tadel, 2008-2021

global gTessAlign;
gTessAlign = [];
gTessAlign.SurfaceFile = SurfaceFile;
gTessAlign.FinalTransf = eye(4);
% Save current scouts modifications
panel_scout('SaveModifications');

% ===== VIEW REFERENCE FILE =====
% Get reference type (MRI or surface)
switch file_gettype(RefFile)
    case {'cortex','scalp','innerskull','outerskull','tess'}
        gTessAlign.hFig = view_surface(RefFile, .3);
    case 'fem'
        gTessAlign.hFig = view_surface_fem(RefFile, .3);
    case 'subjectimage'
        gTessAlign.hFig = view_mri_3d(RefFile, [], 0);
    otherwise
        error('Invalid reference for surface realignment');
end
% Check that figure was created
if isempty(gTessAlign.hFig)
    return
end

% ===== VIEW SURFACE TO ALIGN =====
% Get reference type (MRI or surface)
switch file_gettype(SurfaceFile)
    case {'cortex','scalp','innerskull','outerskull','tess'}
        % Display surface
        gTessAlign.hFig = view_surface(SurfaceFile, .3, [1 .6 0], gTessAlign.hFig);
        % Get handle to the surface to align
        TessInfo = getappdata(gTessAlign.hFig, 'Surface');
        iTess = find(file_compare(file_short(SurfaceFile), {TessInfo.SurfaceFile}));
        if isempty(iTess) || (length(iTess) > 1)
            error('Target surface file was not displayed.');
        end
    case 'fem'
        % Display all FEM layers
        gTessAlign.hFig = view_surface_fem(SurfaceFile, .3, [1 .6 0], [0 0 0], gTessAlign.hFig);
        % Find all the FEM layers
        TessInfo = getappdata(gTessAlign.hFig, 'Surface');
        iTessAll = find(~cellfun(@(c)isempty(strfind(file_short(c), file_short(SurfaceFile))), {TessInfo.SurfaceFile}));
        % Remove all of them but the first one
        for i = length(iTessAll):-1:2
            panel_surface('RemoveSurface', gTessAlign.hFig, iTessAll(i));
        end
        panel_surface('UpdatePanel');
        % Update info structures
        TessInfo = getappdata(gTessAlign.hFig, 'Surface');
        iTess = iTessAll(1);
        % Update the color of the first layer
        panel_surface('SetSurfaceColor', gTessAlign.hFig, iTess, [1 .6 0]);
    otherwise
        error('Invalid surface type');
end
% Get vertex locations from patch
gTessAlign.hSurfPatch = TessInfo(iTess).hPatch;
gTessAlign.SurfVertices = get(gTessAlign.hSurfPatch, 'Vertices');

% ===== CONFIGURE FIGURE =====
% Set figure title
set(gTessAlign.hFig, 'Name', 'Align surface');
% View XYZ axis
figure_3d('ViewAxis', gTessAlign.hFig, 1);
% Set view from left side
figure_3d('SetStandardView', gTessAlign.hFig, 'left');
% Get figure description in GlobalData structure
[gTessAlign.hFig, iFig, gTessAlign.iDS] = bst_figures('GetFigure', gTessAlign.hFig);
if isempty(gTessAlign.iDS)
    return
end

% ===== HACK NORMAL 3D CALLBACKS =====
% Save figure callback functions
gTessAlign.Figure3DButtonDown_Bak   = get(gTessAlign.hFig, 'WindowButtonDownFcn');
gTessAlign.Figure3DButtonMotion_Bak = get(gTessAlign.hFig, 'WindowButtonMotionFcn');
gTessAlign.Figure3DButtonUp_Bak     = get(gTessAlign.hFig, 'WindowButtonUpFcn');
gTessAlign.Figure3DCloseRequest_Bak = get(gTessAlign.hFig, 'CloseRequestFcn');
% Set new callbacks
set(gTessAlign.hFig, 'WindowButtonDownFcn',   @AlignButtonDown_Callback);
set(gTessAlign.hFig, 'WindowButtonMotionFcn', @AlignButtonMotion_Callback);
set(gTessAlign.hFig, 'WindowButtonUpFcn',     @AlignButtonUp_Callback);
set(gTessAlign.hFig, 'CloseRequestFcn',       @AlignClose_Callback);

% ===== CUSTOMIZE FIGURE =====
% Add toolbar to window
hToolbar = uitoolbar(gTessAlign.hFig, 'Tag', 'AlignToolbar');

% Initializations
gTessAlign.selectedButton = '';
gTessAlign.isChanged = 0;
gTessAlign.mouseClicked = 0;
gTessAlign.isClosing = 0;

% Rotation/Translation buttons
gTessAlign.hButtonTransX   = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_X'), 'TooltipString', 'Translation/X: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation, 'separator', 'on');
gTessAlign.hButtonTransY   = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_Y'), 'TooltipString', 'Translation/Y: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
gTessAlign.hButtonTransZ   = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_Z'), 'TooltipString', 'Translation/Z: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
gTessAlign.hButtonRotX     = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_ROTATION_X'),    'TooltipString', 'Rotation/X: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation, 'separator', 'on');
gTessAlign.hButtonRotY     = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_ROTATION_Y'),    'TooltipString', 'Rotation/Y: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation);
gTessAlign.hButtonRotZ     = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_ROTATION_Z'),    'TooltipString', 'Rotation/Z: Press right button and move mouse up/down',    'ClickedCallback', @SelectOperation);
gTessAlign.hButtonResizeX  = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_RESIZE_X'),      'TooltipString', 'Resize/X: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation, 'separator', 'on');
gTessAlign.hButtonResizeY  = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_RESIZE_Y'),      'TooltipString', 'Resize/Y: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation);
gTessAlign.hButtonResizeZ  = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_RESIZE_Z'),      'TooltipString', 'Resize/Z: Press right button and move mouse up/down',      'ClickedCallback', @SelectOperation);
gTessAlign.hButtonResize   = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_RESIZE'),        'TooltipString', 'Resize: Press right button and move mouse up/down',        'ClickedCallback', @SelectOperation);
gTessAlign.hButtonOk       = uipushtool(  hToolbar, 'CData', java_geticon( 'ICON_OK'), 'separator', 'on', 'ClickedCallback', @buttonOk_Callback);
% Update figure localization
gui_layout('Update');

end



%% ===== MOUSE CALLBACKS =====  
% ===== MOUSE DOWN =====
function AlignButtonDown_Callback(hObject, ev)
    global gTessAlign;
    % Catch only the clicks with the right button
    if strcmpi(get(gTessAlign.hFig, 'SelectionType'), 'alt') && ~isempty(gTessAlign.selectedButton)
        gTessAlign.mouseClicked = 1;
        % Record click position
        setappdata(gTessAlign.hFig, 'clickPositionFigure', get(gTessAlign.hFig, 'CurrentPoint'));
    else
        % Call the default mouse down handle
        gTessAlign.Figure3DButtonDown_Bak(hObject, ev);
    end
end

% ===== MOUSE MOVE =====
function AlignButtonMotion_Callback(hObject, ev)
    global gTessAlign;
    if gTessAlign.mouseClicked
        % Get current mouse location
        curptFigure = get(gTessAlign.hFig, 'CurrentPoint');
        motionFigure = (curptFigure - getappdata(gTessAlign.hFig, 'clickPositionFigure')) ./ 1000;
        % Update click point location
        setappdata(gTessAlign.hFig, 'clickPositionFigure', curptFigure);
        % Initialize the transformations that are done
        Rnew = [];
        Tnew = [];
        RescaleNew = [];
        % Selected button
        switch (gTessAlign.selectedButton)
            case gTessAlign.hButtonTransX
                Tnew = [motionFigure(2) / 25, 0, 0];
            case gTessAlign.hButtonTransY
                Tnew = [0, motionFigure(2) / 25, 0];
            case gTessAlign.hButtonTransZ
                Tnew = [0, 0, motionFigure(2) / 25];
            case gTessAlign.hButtonRotX
                a = motionFigure(2);
                Rnew = [1,      0,       0; 
                        0, cos(a), -sin(a);
                        0, sin(a),  cos(a)];
            case gTessAlign.hButtonRotY
                a = motionFigure(2);
                Rnew = [ cos(a), 0, sin(a); 
                              0, 1,      0;
                        -sin(a), 0, cos(a)];
            case gTessAlign.hButtonRotZ
                a = motionFigure(2);
                Rnew = [ cos(a), sin(a), 0; 
                        -sin(a), cos(a), 0;
                              0, 0,      1];
            case gTessAlign.hButtonResize
                RescaleNew = repmat(1 + motionFigure(2), [1 3]);
            case gTessAlign.hButtonResizeX
                RescaleNew = [1 + motionFigure(2), 1, 1];
            case gTessAlign.hButtonResizeY
                RescaleNew = [1, 1 + motionFigure(2), 1];
            case gTessAlign.hButtonResizeZ
                RescaleNew = [1, 1, 1 + motionFigure(2)];
            otherwise 
                return;
        end
        gTessAlign.isChanged = 1;
        % Apply Translation
        if ~isempty(Tnew)
            % Update sensors positions
            gTessAlign.SurfVertices = bst_bsxfun(@plus, gTessAlign.SurfVertices, Tnew);
            % Add this transformation to the final transformation
            newTransf = eye(4);
            newTransf(1:3,4) = Tnew;
            gTessAlign.FinalTransf = newTransf * gTessAlign.FinalTransf;
        end
        % Apply rotation
        if ~isempty(Rnew)
            % Update sensors positions
            gTessAlign.SurfVertices = gTessAlign.SurfVertices * Rnew;
            % Add this transformation to the final transformation
            newTransf = eye(4);
            newTransf(1:3,1:3) = Rnew';
            gTessAlign.FinalTransf = newTransf * gTessAlign.FinalTransf;
        end
        % Apply rescale
        if ~isempty(RescaleNew)
            % Update sensors positions
            gTessAlign.SurfVertices = bst_bsxfun(@times, gTessAlign.SurfVertices, RescaleNew);
            % Add this transformation to the final transformation
            newTransf = diag([RescaleNew, 1]);
            gTessAlign.FinalTransf = newTransf * gTessAlign.FinalTransf;
        end
        % Update sensor patch vertices
        set(gTessAlign.hSurfPatch, 'Vertices', gTessAlign.SurfVertices);
    else
        % Call the default mouse motion handle
        gTessAlign.Figure3DButtonMotion_Bak(hObject, ev);
    end
end

% ===== MOUSE UP =====
function AlignButtonUp_Callback(hObject, ev)
    global gTessAlign;
    % Catch only the events if the motion is currently processed
    if gTessAlign.mouseClicked
        gTessAlign.mouseClicked = 0;
    else
        % Call the default mouse up handle
        gTessAlign.Figure3DButtonUp_Bak(hObject, ev);
    end
end

% ===== FIGURE CLOSE REQUESTED =====
function AlignClose_Callback(varargin)
    global gTessAlign;
    if isempty(gTessAlign)
        delete(varargin{1}); 
    elseif gTessAlign.isClosing
        return
    else
        gTessAlign.isClosing = 1;
    end
    if gTessAlign.isChanged
        % Ask user to save changes
        SaveChanged = java_dialog('confirm', ['The surface changed.' 10 10 ...
                                       'Would you like to save changes? ' 10 10], 'Align surface');
        % Save changes and close figure
        if SaveChanged
            %set(gTessAlign.hFig, 'CloseRequestFcn', gTessAlign.Figure3DCloseRequest_Bak);
            %drawnow;
            buttonOk_Callback();
            return
        end
    end
    % Only close figure
    gTessAlign.Figure3DCloseRequest_Bak(varargin{:});       
end



%% ===== SELECT OPERATION =====
function SelectOperation(hObject, ev)
    global gTessAlign;
    % Update button color
    gui_update_toggle(hObject);
    % If button was unselected: nothing to do
    if strcmpi(get(hObject, 'State'), 'off')
        gTessAlign.selectedButton = [];
        return
    else
        gTessAlign.selectedButton = hObject;
    end
    % Unselect all buttons excepted the selected one
    hButtonsUnsel = setdiff([gTessAlign.hButtonTransX,  gTessAlign.hButtonTransY,  gTessAlign.hButtonTransZ, ...
                             gTessAlign.hButtonRotX,    gTessAlign.hButtonRotY,    gTessAlign.hButtonRotZ, ...
                             gTessAlign.hButtonResizeX, gTessAlign.hButtonResizeY, gTessAlign.hButtonResizeZ, ...
                             gTessAlign.hButtonResize], hObject);
    hButtonsUnsel = hButtonsUnsel(strcmpi(get(hButtonsUnsel, 'State'), 'on'));
    if ~isempty(hButtonsUnsel)
        set(hButtonsUnsel, 'State', 'off');
        gui_update_toggle(hButtonsUnsel(1));
    end
end

%% ===== VALIDATION BUTTONS =====
function buttonOk_Callback(varargin)
    global gTessAlign;
    % === GET THE SURFACES TO PROCESS ===
    % Get subject in database
    sSubject = bst_get('SurfaceFile', gTessAlign.SurfaceFile);
    % If there are more than one surface in this subject
    if (length(sSubject.Surface) > 1)
        % Ask if we should apply the transformation to all the surfaces
        isAll = java_dialog('confirm', ['Apply the same transformation to all the surfaces ?' 10 10], 'Align surfaces');
        % Take all the subjects surfaces
        if isAll
            SurfaceFiles = cellfun(@(c)file_fullpath(c), {sSubject.Surface.FileName}, 'UniformOutput', 0);
        else
            SurfaceFiles = {gTessAlign.SurfaceFile};
        end
    else
        SurfaceFiles = {gTessAlign.SurfaceFile};
    end
    % Close 3DViz figure
    if ~gTessAlign.isClosing
        % Restore normal closing handle and close figure
        set(gTessAlign.hFig, 'CloseRequestFcn', gTessAlign.Figure3DCloseRequest_Bak);
        close(gTessAlign.hFig);
    end
    
    % === APPLY TRANSFORMATION ===
    bst_progress('start', 'Align surfaces', 'Processing surfaces...', 0, 2*length(SurfaceFiles));
    % Process each surface
    for i = 1:length(SurfaceFiles)
        % Increment progress bar
        bst_progress('inc', 1);
        % Initialize new structure
        newMat = db_template('surfacemat');
        % Load old SurfaceFile (FEM or mesh)
        if isequal(file_gettype(SurfaceFiles{i}), 'fem')
            oldMat = load(file_fullpath(SurfaceFiles{i}));
            % Copy FEM fields
            newMat.Elements = oldMat.Elements;
            newMat.Tissue = oldMat.Tissue;
            newMat.TissueLabels = oldMat.TissueLabels;
            newMat.Tensors = oldMat.Tensors;
        else
            oldMat = in_tess_bst(SurfaceFiles{i}, 0);
            % Copy mesh fields
            newMat.Faces = oldMat.Faces;
        end
        % Copy basic fields
        newMat.Vertices = oldMat.Vertices;
        newMat.Comment  = oldMat.Comment;

        % Get final rotation, translation and rescale
        Rfinal = gTessAlign.FinalTransf(1:3,1:3);  % This matrix includes the scalings
        Tfinal = gTessAlign.FinalTransf(1:3,4);
        % Apply transformation
        newMat.Vertices = bst_bsxfun(@plus, newMat.Vertices * Rfinal', Tfinal');
       
        % History: Copy previous field
        if isfield(oldMat, 'History') && ~isempty(oldMat.History)
            newMat.History = oldMat.History;
        end
        % History: Align manually 
        newMat = bst_history('add', newMat, 'align', 'Align surface manually:');
        % History: Rotation + translation
        newMat = bst_history('add', newMat, 'transform', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', Rfinal'));
        newMat = bst_history('add', newMat, 'transform', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', Tfinal));
        % Copy atlases
        if isfield(oldMat, 'Atlas') && isfield(oldMat, 'iAtlas')
            newMat.Atlas  = oldMat.Atlas;
            newMat.iAtlas = oldMat.iAtlas;
        end
        % Copy registered spheres
        if isfield(oldMat, 'Reg') && ~isempty(oldMat.Reg)
            newMat.Reg = oldMat.Reg;
        end

        % Save new electrodes positions in ChannelFile
        bst_save(SurfaceFiles{i}, newMat, 'v7');
        % Increment progress bar
        bst_progress('inc', 1);
    end
    % Close progress bar
    bst_progress('stop');
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
end


