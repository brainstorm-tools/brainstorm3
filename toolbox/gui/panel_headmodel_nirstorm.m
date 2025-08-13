function varargout = panel_headmodel_nirstorm(varargin)
% panel_headmodel_nirstorm: Options for the construction of nirs headmodel (GUI).
% 
% USAGE:  bstPanelNew = panel_headmodel_nirstorm('CreatePanel')
%                   s = panel_headmodel_nirstorm('GetPanelContents')

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
% Authors: Edouard Delaire, 2025

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'HeadModelNirsOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create main main panel
    jPanelNew = gui_river();
    % Default  options
    if nargin >= 1 && isfield(sProcess,'options') && ~isempty(sProcess.options) && isfield(sProcess.options, 'nirstorm') && ~isempty(sProcess.options.nirstorm)
        OPTIONS = sProcess.options.nirstorm.Value;
    else
        OPTIONS = GetDefaultOption();
    end
    jPanelOptions = gui_river([4,4], [3,15,10,10], 'Options');
    % Fluence data source
    gui_component('label', jPanelOptions, '', '<HTML><B>Fluence data source (path or URL)</B></HTML>', [], [], [], []);
    jDataSource = gui_component('text', jPanelOptions, 'tab', OPTIONS.FluenceFolder, [], [], [], []);
    jPanelOptions.add('br hfill', jDataSource);
    gui_component('label', jPanelOptions, 'br');
    gui_component('label', jPanelOptions, 'br');
    % Smoothing method
    gui_component('label', jPanelOptions, 'br', '<HTML><B>Smoothing method</B></HTML>', [], [], [], []);
    jGroupRadio = ButtonGroup();
    jRadioGeodesic = gui_component('radio', jPanelOptions, 'br', '<HTML>Geodesic (recommended)</HTML>', jGroupRadio, [], [], []);
    jRadioGeodesic.setSelected(strcmp(OPTIONS.smoothing_method, 'geodesic_dist'))
    jRadioSurfstat = gui_component('radio', jPanelOptions, 'br', '<HTML><FONT color="#777777">Before 2023 (not recommended)</FONT></HTML>', jGroupRadio, [], [], []);
    jRadioSurfstat.setSelected(strcmp(OPTIONS.smoothing_method, 'surfstat_before_2023'))
    gui_component('label', jPanelOptions, 'br');
    gui_component('label', jPanelOptions, 'br');
    % Spatial smoothing
    gui_component('label', jPanelOptions, 'br', '<HTML><B>Spatial smoothing FWHM</B></HTML>', [], [], [], []);
    jSmoothingFwhm = gui_component('text', jPanelOptions, 'tab', num2str(OPTIONS.smoothing_fwhm), [], [], [], []);
    jPanelOptions.add('br hfill', jSmoothingFwhm);

    jPanelNew.add('br hfill', jPanelOptions);

    % ===== VALIDATION BUTTONS =====
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    ctrl = struct('jDataSource',    jDataSource, ...
                  'jSmoothingFwhm', jSmoothingFwhm, ...
                  'jRadioGeodesic', jRadioGeodesic, ...
                  'jRadioSurfstat', jRadioSurfstat );
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);

   
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)       
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)

    end
end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET DEFAULT OPTIONS =====
function s = GetDefaultOption()
    % Use defined options
    s = struct();
    s.FluenceFolder    = 'https://neuroimage.usc.edu/resources/nst_data/fluence/';
    s.smoothing_method = 'geodesic_dist';
    s.smoothing_fwhm   = 10;
end


%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'HeadModelNirsOptions');
    s = GetDefaultOption();
    % Fluence data source
    s.FluenceFolder = char(ctrl.jDataSource.getText());
    % Smoothing method
    if ctrl.jRadioGeodesic.isSelected()
        s.smoothing_method = 'geodesic_dist';
    elseif ctrl.jRadioSurfstat.isSelected()
        s.smoothing_method = 'surfstat_before_2023';
    else
        error('You must select a smoothing method');
    end
    % Spatial smoothing
    s.smoothing_fwhm = str2double(ctrl.jSmoothingFwhm.getText());
end





