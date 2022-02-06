function tess_align_fiducials( RefFile, SurfaceFiles )
% TESS_ALIGN_FIDUCIALS: Align a list of surfaces according to one reference surface.
%
% USAGE:  tess_align_fiducials( RefFile, SurfaceFiles )
% 
% INPUT:
%     - RefFile      : full path to reference surface file
%     - SurfaceFiles : cell array of strings, full path to all the surfaces files to align

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
% Authors: Francois Tadel, 2008-2013

%% ===== INITIALIZATION =====
% Initializations
global gAlignFid;
gAlignFid = [];
gAlignFid.SurfaceFiles = SurfaceFiles;
% Save current scouts modifications
panel_scout('SaveModifications');
% Get all the subject's surfaces:
sSubject = bst_get('SurfaceFile', RefFile);
% Get MRI 
if isempty(sSubject.Anatomy)
    bst_error('You need to import the subject''s MRI before aligning anything with it.', 'Align surfaces', 0);
    return
end
gAlignFid.MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
% Get initial positions
sMri = load(file_fullpath(gAlignFid.MriFile), 'SCS');
gAlignFid.SCSold = sMri.SCS;
% Convert from MRI to SCS
if isempty(sMri.SCS) || isempty(sMri.SCS.R) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) 
    bst_error('You need to define the fiducials in the MRI before editing them with this interface.', 'Align surfaces', 0);
    return
end
gAlignFid.SCS.NAS = cs_convert(sMri, 'mri', 'scs', sMri.SCS.NAS ./ 1000);
gAlignFid.SCS.LPA = cs_convert(sMri, 'mri', 'scs', sMri.SCS.LPA ./ 1000);
gAlignFid.SCS.RPA = cs_convert(sMri, 'mri', 'scs', sMri.SCS.RPA ./ 1000);
gAlignFid.isModified = 0;
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== GUI =====
% View original surface
gAlignFid.hFig = view_surface(RefFile);
% Configure created figure
if isempty(gAlignFid.hFig)
    return
end
set(gAlignFid.hFig, 'Name', 'Align surfaces');
% Get scalp surface handle
TessInfo = getappdata(gAlignFid.hFig, 'Surface');
gAlignFid.hPatchRef = TessInfo(1).hPatch;
% Set some transparency
panel_surface('SetSurfaceTransparency', gAlignFid.hFig, 1, .2);


% === ADAPT GUI TO ALIGNMENT ====
% Save figure callback functions
gAlignFid.WindowButtonDownFcn_Bak = get(gAlignFid.hFig, 'WindowButtonUpFcn');
gAlignFid.CloseRequestFcn_Bak     = get(gAlignFid.hFig, 'CloseRequestFcn');
% Replace figure callbacks
set(gAlignFid.hFig, 'CloseRequestFcn',   @CloseRequest_Callback);
set(gAlignFid.hFig, 'WindowButtonUpFcn', @WindowButtonUp_Callback);
% Add toolbar to window
hToolbar = uitoolbar(gAlignFid.hFig, 'Tag', 'AlignToolbar');
% Fiducials buttons
gAlignFid.hButtonNAS = uitoggletool(hToolbar, 'CData', java_geticon('ICON_FID_NAS_OK'), 'ClickedCallback', @ButtonFiducial_Callback, 'TooltipString', 'Select Nasion on scalp surface');
gAlignFid.hButtonLPA = uitoggletool(hToolbar, 'CData', java_geticon('ICON_FID_LPA_OK'), 'ClickedCallback', @ButtonFiducial_Callback, 'TooltipString', 'Select Left Pre-Auricular point on scalp surface');
gAlignFid.hButtonRPA = uitoggletool(hToolbar, 'CData', java_geticon('ICON_FID_RPA_OK'), 'ClickedCallback', @ButtonFiducial_Callback, 'TooltipString', 'Select Right Pre-Auricular point on scalp surface');
% Initialize other variables
gAlignFid.hPointNas = [];
gAlignFid.hPointRpa = [];
gAlignFid.hPointLpa = [];
gAlignFid.hTextNas  = [];
gAlignFid.hTextRpa  = [];
gAlignFid.hTextLpa  = [];
% Plot existing fiducials
PlotFiducials();
% Update figure localization
gui_layout('Update');

end


%% ===== CLOSE REQUEST CALLBACK =====
function CloseRequest_Callback(h, ev)
    global gAlignFid;
    % Check if modifications were performed
    if gAlignFid.isModified
        isSave = java_dialog('confirm', ['Fiducials were changed.' 10 10 'Save modifications and update all the surfaces?'], 'Save changed');
        % Call "OK" button function
        if isSave
            SaveModifications();
        end
    end
    % Call initial close function
    gAlignFid.CloseRequestFcn_Bak(h, ev);
    % Reset gAlignFid field
    gAlignFid = [];
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
end


%% ===== FIGURE CLICK: SELECT FIDUCIALS =====
function WindowButtonUp_Callback(hFig, ev)
    global gAlignFid;
    % Check if the mouse moved
    hasMoved = getappdata(hFig, 'hasMoved');
    % Find surface vertex that was clicked
    [pout, vout] = select3d(gAlignFid.hPatchRef);
    % Process click
    if isempty(vout) || hasMoved
        isPointSelected = 0;
    elseif strcmpi(get(gAlignFid.hButtonNAS, 'State'), 'on')
        gAlignFid.SCS.NAS = vout';
        isPointSelected = 1;
        gAlignFid.isModified = 1;
    elseif strcmpi(get(gAlignFid.hButtonLPA, 'State'), 'on')
        gAlignFid.SCS.LPA = vout';
        isPointSelected = 1;
        gAlignFid.isModified = 1;
    elseif strcmpi(get(gAlignFid.hButtonRPA, 'State'), 'on')
        gAlignFid.SCS.RPA = vout';
        isPointSelected = 1;
        gAlignFid.isModified = 1;
    else
        isPointSelected = 0;
    end
    % Point selected: Re-plot fiducials
    if isPointSelected
        PlotFiducials();
    end
    % Call owner callback
    gAlignFid.WindowButtonDownFcn_Bak(hFig, ev);
end


%% ===== BUTTON CLICK =====
% User click on a toolbar button
function ButtonFiducial_Callback(hObject, varargin)
    global gAlignFid;
    % Handles of other buttons
    hOtherButtons = setdiff([gAlignFid.hButtonNAS, gAlignFid.hButtonLPA, gAlignFid.hButtonRPA], hObject);
    % If button was selected: Unselect other buttons
    if strcmpi(get(hObject,'State'), 'on')
        set(hOtherButtons, 'State', 'off');
    end
end


%% ===== PLOT ALL FIDUCIALS =====
function PlotFiducials()
    global gAlignFid;
    % Delete all objects
    delete([gAlignFid.hPointNas, gAlignFid.hTextNas, gAlignFid.hPointLpa, gAlignFid.hTextLpa, gAlignFid.hPointRpa, gAlignFid.hTextRpa]);
    % Plot each fiducial
    if ~isempty(gAlignFid.SCS.NAS)
        [gAlignFid.hPointNas, gAlignFid.hTextNas] = PlotPoint(gAlignFid.SCS.NAS, 'NAS');
    end
    if ~isempty(gAlignFid.SCS.LPA)
        [gAlignFid.hPointLpa, gAlignFid.hTextLpa] = PlotPoint(gAlignFid.SCS.LPA, 'LPA');
    end
    if ~isempty(gAlignFid.SCS.RPA)
        [gAlignFid.hPointRpa, gAlignFid.hTextRpa] = PlotPoint(gAlignFid.SCS.RPA, 'RPA');
    end
end


%% ===== PLOT POINT =====
% Plot fiducial marker
function [hPoint, hText] = PlotPoint(ptLoc, ptName)
    % Plot fiducial marker
    hPoint = line(1.01*ptLoc(1), 1.01*ptLoc(2), 1.01*ptLoc(3), ...
                  'Marker',          'o', ...
                  'MarkerFaceColor', [0 .5 0], ...
                  'MarkerEdgeColor', [.8 .8 .8], ...
                  'MarkerSize',      7, ...
                  'Tag',             'FiducialMarker');
    % Plot fiducial legend
    hText = text(1.08*ptLoc(1), 1.08*ptLoc(2), 1.08*ptLoc(3), ...
                 ptName, ...
                 'Fontname',   'helvetica', ...
                 'FontUnits',  'Point', ...
                 'FontSize',   10, ...
                 'FontWeight', 'normal', ...
                 'Color',      [.5 1 .5], ...
                 'Tag',        'FiducialLabel', ...
                 'Interpreter','none');
end


%% ===== SAVE MODIFICATIONS =====
function SaveModifications()
    global gAlignFid;
    % Get previous coordinates
    sMriOld.SCS = gAlignFid.SCSold;
    % Convert new coordinates back to MRI coordinates
    sMriNew.SCS.NAS = cs_convert(sMriOld, 'scs', 'mri', gAlignFid.SCS.NAS) * 1000;
    sMriNew.SCS.LPA = cs_convert(sMriOld, 'scs', 'mri', gAlignFid.SCS.LPA) * 1000;
    sMriNew.SCS.RPA = cs_convert(sMriOld, 'scs', 'mri', gAlignFid.SCS.RPA) * 1000;
    % Calculate again the SCS transformation, with those new fiducials
    [Transf, sMriNew] = cs_compute(sMriNew, 'scs');
    % Check if the structures are identical
    if isequal(sMriOld, sMriNew)
        disp('BST> No modifications: Saving canceled.');
        return;
    end
    % Process surfaces
    figure_mri('UpdateSurfaceCS', gAlignFid.SurfaceFiles, sMriOld, sMriNew);
    % Save MRI
    s.SCS = sMriNew.SCS;
    bst_save(file_fullpath(gAlignFid.MriFile), s, 'v7', 1);
end

        
        
        
