function varargout = panel_dipinfo(varargin)
% PANEL_DIPINFO: Create a panel to display info about selected dipoles in a 3DViz figure.

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
% Authors: Francois Tadel, 2016-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Dipinfo';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % CONSTANTS 
    TEXT_HEIGHT = java_scaled('value', 20);
    TEXT_WIDTH  = java_scaled('value', 40);
    jFontText = bst_get('Font', 11);
    % Create tools panel
    jPanelNew = gui_component('Panel');

    % ===== CREATE TOOLBAR =====
    jToolbar = gui_component('Toolbar', jPanelNew, BorderLayout.NORTH);
    jToolbar.setPreferredSize(java_scaled('dimension', 100,25));
        jToolbar.add(JLabel('     '));
        % Button "View in MRI Viewer"
        gui_component('ToolbarButton', jToolbar, [], 'View/MRI', IconLoader.ICON_VIEW_SCOUT_IN_MRI, 'Center MRI Viewer on dipole', @ViewInMriViewer);
        % Button "View/3D"
        gui_component('ToolbarButton', jToolbar, [], 'View/3D', IconLoader.ICON_VIEW_SCOUT_IN_MRI, 'Center 3D view on dipole', @ViewIn3D);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'Reset', IconLoader.ICON_DELETE, 'Remove point selection', @RemoveSelection);
                  
    % ===== Main panel =====
    jPanelMain = gui_river();
        % ===== Coordinates =====
        jPanelCoordinates = gui_river('Coordinates (millimeters)');
        %jPanelCoordinates.setPreferredSize(java_scaled('dimension', 240,125));
            % Coordinates
            gui_component('label', jPanelCoordinates, '', '  ');
            gui_component('label', jPanelCoordinates, 'tab', '       X');
            gui_component('label', jPanelCoordinates, 'tab', '       Y');
            gui_component('label', jPanelCoordinates, 'tab', '       Z');
            % === MRI ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'MRI: '));
            jLabelCoordMriX = JLabel('-');
            jLabelCoordMriY = JLabel('-');
            jLabelCoordMriZ = JLabel('-');
            jLabelCoordMriX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMriY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMriZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMriX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMriY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMriZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMriX.setFont(jFontText);
            jLabelCoordMriY.setFont(jFontText);
            jLabelCoordMriZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordMriX);
            jPanelCoordinates.add('tab', jLabelCoordMriY);
            jPanelCoordinates.add('tab', jLabelCoordMriZ);
            % === SCS ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'SCS: '));
            jLabelCoordScsX = JLabel('-');
            jLabelCoordScsY = JLabel('-');
            jLabelCoordScsZ = JLabel('-');
            jLabelCoordScsX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsX.setFont(jFontText);
            jLabelCoordScsY.setFont(jFontText);
            jLabelCoordScsZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordScsX);
            jPanelCoordinates.add('tab', jLabelCoordScsY);
            jPanelCoordinates.add('tab', jLabelCoordScsZ);
            % === WORLD ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'World: '));
            jLabelCoordWrlX = JLabel('-');
            jLabelCoordWrlY = JLabel('-');
            jLabelCoordWrlZ = JLabel('-');
            jLabelCoordWrlX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlX.setFont(jFontText);
            jLabelCoordWrlY.setFont(jFontText);
            jLabelCoordWrlZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordWrlX);
            jPanelCoordinates.add('tab', jLabelCoordWrlY);
            jPanelCoordinates.add('tab', jLabelCoordWrlZ);
            % === MNI ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'MNI: '));
            jLabelCoordMniX = JLabel('-');
            jLabelCoordMniY = JLabel('-');
            jLabelCoordMniZ = JLabel('-');
            jLabelCoordMniX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniX.setFont(jFontText);
            jLabelCoordMniY.setFont(jFontText);
            jLabelCoordMniZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordMniX);
            jPanelCoordinates.add('tab', jLabelCoordMniY);
            jPanelCoordinates.add('tab', jLabelCoordMniZ);
        jPanelMain.add('hfill', jPanelCoordinates);
        
        % ===== Coordinates =====
        jPanelInfo = gui_river([3,9], [5 10 20 10], 'Dipole properties');
            % Index
            jTitleInd = gui_component('label', jPanelInfo, '', 'Index: ');
            jLabelInd = gui_component('label', jPanelInfo, 'tab', '-');
            % Time
            jTitleTime = gui_component('label', jPanelInfo, 'br', 'Time: ');
            jLabelTime = gui_component('label', jPanelInfo, 'tab', '-');
            
            % Performance of fit
            jTitlePerf = gui_component('label', jPanelInfo, 'br',  'Performance: ');
            jLabelPerf = gui_component('label', jPanelInfo, 'tab', '-');
            
            % Goodness of fit
            jTitleGof = gui_component('label', jPanelInfo, 'br',  'Goodness: ');
            jLabelGof = gui_component('label', jPanelInfo, 'tab', '-');
            
            % ConfVol
            jTitleVol = gui_component('label', jPanelInfo, 'br',  'Conf volume: ');
            jLabelVol = gui_component('label', jPanelInfo, 'tab', '-');
                       
            % Amplitude
            jTitleAmp = gui_component('label', jPanelInfo, 'br',  'Amplitude: ');
            jLabelAmp = gui_component('label', jPanelInfo, 'tab', '-');
            
            % Orientation
            jTitleOrient = gui_component('label', jPanelInfo, 'br',  'Orientation: ');
            jLabelOrient = gui_component('label', jPanelInfo, 'tab', '-');            
            
            % Scalar Amplitude
            jTitleSAmp = gui_component('label', jPanelInfo, 'br',  'Intensity: ');
            jLabelSAmp = gui_component('label', jPanelInfo, 'tab', '-');            
            
            % Chi2
            jTitleChi2 = gui_component('label', jPanelInfo, 'br',  'Chi-square: ');
            jLabelChi2 = gui_component('label', jPanelInfo, 'tab', '-');

            % DOF
            jTitleDof = gui_component('label', jPanelInfo, 'br',  'DOF: ');
            jLabelDof = gui_component('label', jPanelInfo, '', '-');
            % DOF
            jTitleRChi2 = gui_component('label', jPanelInfo, 'br',  'Reduced Chi-square: ');
            jLabelRChi2 = gui_component('label', jPanelInfo, '', '-');
        jPanelMain.add('br hfill', jPanelInfo); 
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);
       
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelCoordinates', jPanelCoordinates, ...
                                  'jLabelCoordMriX',   jLabelCoordMriX, ...
                                  'jLabelCoordMriY',   jLabelCoordMriY, ...
                                  'jLabelCoordMriZ',   jLabelCoordMriZ, ...
                                  'jLabelCoordScsX',   jLabelCoordScsX, ...
                                  'jLabelCoordScsY',   jLabelCoordScsY, ...
                                  'jLabelCoordScsZ',   jLabelCoordScsZ, ...
                                  'jLabelCoordWrlX',   jLabelCoordWrlX, ...
                                  'jLabelCoordWrlY',   jLabelCoordWrlY, ...
                                  'jLabelCoordWrlZ',   jLabelCoordWrlZ, ...
                                  'jLabelCoordMniX',   jLabelCoordMniX, ...
                                  'jLabelCoordMniY',   jLabelCoordMniY, ...
                                  'jLabelCoordMniZ',   jLabelCoordMniZ, ...
                                  'jLabelInd',         jLabelInd, ...
                                  'jLabelTime',        jLabelTime, ...
                                  'jLabelPerf',        jLabelPerf, ...
                                  'jLabelGof',         jLabelGof, ...
                                  'jLabelAmp',         jLabelAmp, ...
                                  'jLabelSAmp',        jLabelSAmp, ...
                                  'jLabelOrient',      jLabelOrient, ...
                                  'jLabelVol',         jLabelVol, ...
                                  'jLabelChi2',        jLabelChi2, ...
                                  'jLabelRChi2',       jLabelRChi2, ...
                                  'jLabelDof',         jLabelDof));
                                                            
end
                   
            
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== UPDATE CALLBACK =====
function UpdatePanel(hFig)
    % Get current figure
    if (nargin < 1) || isempty(hFig)
        hFig = bst_figures('GetCurrentFigure', '3D');
        if isempty(hFig)
            return;
        end
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipinfo');
    if isempty(ctrl)
        return
    end
    % Get Dipoles description for current figure
    DipolesInfo = panel_dipoles('GetDipolesForFigure', hFig);
    if isempty(DipolesInfo) || isempty(DipolesInfo.Dipole)
        return
    end
    % Get selected dipole in figure
    iDipole = getappdata(hFig, 'iDipoleSelected');
    % Select dipole structure
    if ~isempty(iDipole) && (iDipole <= length(DipolesInfo.Dipole))
        sDip = DipolesInfo.Dipole(iDipole);
    else
        sDip = [];
    end

    % ===== GET COORDINATES =====
    % Get subject 
    SubjectFile = getappdata(hFig, 'SubjectFile');
    sSubject = bst_get('Subject', SubjectFile);
    if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(sSubject.iAnatomy).FileName)
        error('No anatomy available for this subject.');
    end
    % Load MRI
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    sMri = bst_memory('LoadMri', MriFile);
    % Convert corrdinates
    if ~isempty(sDip)
        SCS = sDip.Loc;
        MRI = cs_convert(sMri, 'scs', 'mri', SCS);
        MNI = cs_convert(sMri, 'scs', 'mni', SCS);
        World = cs_convert(sMri, 'scs', 'world', SCS);
    else
        SCS = [];
        MRI = [];
        MNI = [];
        World = [];
    end

    % Update coordinates (text fields)
    % MRI
    if ~isempty(MRI)
        ctrl.jLabelCoordMriX.setText(sprintf('%3.1f', 1000 * MRI(1)));
        ctrl.jLabelCoordMriY.setText(sprintf('%3.1f', 1000 * MRI(2)));
        ctrl.jLabelCoordMriZ.setText(sprintf('%3.1f', 1000 * MRI(3)));
    else
        ctrl.jLabelCoordMriX.setText('-');
        ctrl.jLabelCoordMriY.setText('-');
        ctrl.jLabelCoordMriZ.setText('-');
    end
    % SCS
    if ~isempty(SCS)
        ctrl.jLabelCoordScsX.setText(sprintf('%3.1f', 1000 * SCS(1)));
        ctrl.jLabelCoordScsY.setText(sprintf('%3.1f', 1000 * SCS(2)));
        ctrl.jLabelCoordScsZ.setText(sprintf('%3.1f', 1000 * SCS(3)));
    else
        ctrl.jLabelCoordScsX.setText('-');
        ctrl.jLabelCoordScsY.setText('-');
        ctrl.jLabelCoordScsZ.setText('-');
    end
    % World
    if ~isempty(World)
        ctrl.jLabelCoordWrlX.setText(sprintf('%3.1f', 1000 * World(1)));
        ctrl.jLabelCoordWrlY.setText(sprintf('%3.1f', 1000 * World(2)));
        ctrl.jLabelCoordWrlZ.setText(sprintf('%3.1f', 1000 * World(3)));
    else
        ctrl.jLabelCoordWrlX.setText('-');
        ctrl.jLabelCoordWrlY.setText('-');
        ctrl.jLabelCoordWrlZ.setText('-');
    end
    % MNI
    if ~isempty(MNI)
        ctrl.jLabelCoordMniX.setText(sprintf('%3.1f', 1000 * MNI(1)));
        ctrl.jLabelCoordMniY.setText(sprintf('%3.1f', 1000 * MNI(2)));
        ctrl.jLabelCoordMniZ.setText(sprintf('%3.1f', 1000 * MNI(3)));
    else
        ctrl.jLabelCoordMniX.setText('-');
        ctrl.jLabelCoordMniY.setText('-');
        ctrl.jLabelCoordMniZ.setText('-');
    end
    
    % Index
    if ~isempty(sDip) && ~isempty(sDip.Index)
        ctrl.jLabelInd.setText(num2str(sDip.Index));
    else
        ctrl.jLabelInd.setText('-');
    end
    % Time
    if ~isempty(sDip) && ~isempty(sDip.Time)
        if (abs(sDip.Time) > 2)
            ctrl.jLabelTime.setText(sprintf('%1.4f s', sDip.Time));
        else
            ctrl.jLabelTime.setText(sprintf('%1.2f ms', sDip.Time * 1000));
        end
    else
        ctrl.jLabelTime.setText('-');
    end
    
    % Performance
    if ~isempty(sDip) && ~isempty(sDip.Perform)
        ctrl.jLabelPerf.setText(sprintf('%0.1f', sDip.Perform));
    else
        ctrl.jLabelPerf.setText('-');
    end
    
    % Goodness
    if ~isempty(sDip) && ~isempty(sDip.Goodness)
        ctrl.jLabelGof.setText(sprintf('%3.2f %%', sDip.Goodness * 100));
    else
        ctrl.jLabelGof.setText('-');
    end
    
    % ConfVol
    if ~isempty(sDip) && ~isempty(sDip.ConfVol)
        ctrl.jLabelVol.setText(sprintf('%1.2f mm^3', sDip.ConfVol * 1e9));
    else
        ctrl.jLabelVol.setText('-');
    end
    % Khi2
    if ~isempty(sDip) && ~isempty(sDip.Khi2)
        ctrl.jLabelChi2.setText(num2str(sDip.Khi2));
    else
        ctrl.jLabelChi2.setText('-');
    end
    % Amplitude
    if ~isempty(sDip) && ~isempty(sDip.Amplitude)
        ctrl.jLabelAmp.setText(sprintf('%1.2e ', sDip.Amplitude));
    else
        ctrl.jLabelAmp.setText('-');
    end
    
    % Orientation
    if ~isempty(sDip) && ~isempty(sDip.Amplitude)
        ctrl.jLabelOrient.setText(sprintf('%0.2f ', sDip.Amplitude/norm(sDip.Amplitude)));
    else
        ctrl.jLabelOrient.setText('-');
    end
    
    % Scalar Amplitude
    if ~isempty(sDip) && ~isempty(sDip.Amplitude)
        ctrl.jLabelSAmp.setText(sprintf('%0.1f nA-m',norm( sDip.Amplitude)*1e9));
    else
        ctrl.jLabelSAmp.setText('-');
    end
    
    % DOF 
    if ~isempty(sDip) && ~isempty(sDip.DOF)
        ctrl.jLabelDof.setText(num2str(sDip.DOF));
    else
        ctrl.jLabelDof.setText('-');
    end
    
    % Reduced Chi2
    if ~isempty(sDip) && ~isempty(sDip.Khi2) && ~isempty(sDip.DOF)
        ctrl.jLabelRChi2.setText(num2str(sDip.Khi2 ./ sDip.DOF));
    else
        ctrl.jLabelRChi2.setText('-');
    end
end


%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    if ~isFocused
        RemoveSelection();
    end
end


%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback() %#ok<DEFNU>
    UpdatePanel();
end


%% ===============================================================================
%  ====== POINTS SELECTION =======================================================
%  ===============================================================================

%% ===== SELECT DIPOLES =====
function SelectDipole(hFig, iDipole)
    % Get all the dipoles from the figure
    hDipoles = findobj(hFig, 'Tag', 'DipolesLoc');
    % Restore their initial aspect
    if ~isempty(hDipoles)
        set(hDipoles, 'MarkerEdgeColor', [.4 .4 .4], 'LineWidth', 1);
    end
    % If there is a new dipole to select
    if ~isempty(iDipole)
        % Get the selected dipoles object
        hDip = findobj(hDipoles, 'UserData', iDipole);
        if isempty(hDip)
            return;
        end
        % Highlight the border of the marker
        set(hDip, 'MarkerEdgeColor', [1 0 0], 'LineWidth', 2);
    end
    % Update figure
    drawnow;
    % Display dipoles info panel
    if ~gui_brainstorm('isTabVisible', 'Dipinfo')
        gui_show('panel_dipinfo', 'JavaWindow', 'Dipole info', [], 0, 1, 0);
    end
    % Save selected dipole
    setappdata(hFig, 'iDipoleSelected', iDipole);
    % Update panel to show details
    UpdatePanel(hFig);
end


%% ===== REMOVE SELECTION =====
function RemoveSelection(varargin)
    % Get current figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return;
    end
    % Empty selection
    SelectDipole(hFig, []);
end


%% ===== VIEW IN MRI VIEWER =====
function ViewInMriViewer(varargin)
    global GlobalData;
    % Get current 3D figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get selected dipole in figure
    iDipole = getappdata(hFig, 'iDipoleSelected');
    if isempty(iDipole)
        return;
    end
    % Get Dipoles description for current figure
    DipolesInfo = panel_dipoles('GetDipolesForFigure', hFig);
    if isempty(DipolesInfo) || isempty(DipolesInfo.Dipole) || isempty(iDipole) || (iDipole > length(DipolesInfo.Dipole))
        return
    end
    % Select dipole structure
    sDip = DipolesInfo.Dipole(iDipole);
    % Get subject and subject's MRI
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    if isempty(sSubject) || isempty(sSubject.iAnatomy)
        return 
    end
    % Display subject's anatomy in MRI Viewer
    hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    % Select the required point
    figure_mri('SetLocation', 'scs', hFig, [], sDip.Loc);
end


%% ===== VIEW IN 3D =====
function ViewIn3D(varargin)
    % Get current 3D figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get selected dipole in figure
    iDipole = getappdata(hFig, 'iDipoleSelected');
    if isempty(iDipole)
        return;
    end
    % Get Dipoles description for current figure
    DipolesInfo = panel_dipoles('GetDipolesForFigure', hFig);
    if isempty(DipolesInfo) || isempty(DipolesInfo.Dipole) || isempty(iDipole) || (iDipole > length(DipolesInfo.Dipole))
        return
    end
    % Select dipole structure
    sDip = DipolesInfo.Dipole(iDipole);
    % Select the required point
    figure_3d('SetLocationMri', hFig, 'scs', sDip.Loc);
end


