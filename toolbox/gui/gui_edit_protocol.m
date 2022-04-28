function [ iProtocol ] = gui_edit_protocol(action, iProtocol)
% GUI_EDIT_PROTOCOL: Open a dialog to create, load or edit a protocol.
%
% USAGE:  [iProtocol] = gui_edit_protocol('create');           : create a new protocol and return its index
%         [iProtocol] = gui_edit_protocol('load');             : load an existing protocol and return its index
%         [iProtocol] = gui_edit_protocol('edit', iProtocol);  : edit an existing protocol (index #iProtocol in ProtocolsListInfo)

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
% Authors: Francois Tadel, 2008-2017

global GlobalData;

%% ===== PARSE INPUTS =====
% Get ProtocolsListInfo structure 
sProtocolsListInfo = GlobalData.DataBase.ProtocolInfo;
nbProtocols = length(sProtocolsListInfo);
% Switch between actions
switch (action)
    case 'create'
        iProtocol = nbProtocols + 1;
        panelTitle = 'Create new protocol';
    case 'load'
        iProtocol = nbProtocols + 1;
        panelTitle = 'Load existing protocol';
    case 'edit'
        if (nargin < 2)
            error('Usage:  [iProtocol] = gui_edit_protocol(''edit'', iProtocol)');
        end
        if ((iProtocol <= 0) || (iProtocol > nbProtocols))
            error('Protocol #%d does not exist.', iProtocol);
        end
        panelTitle = sprintf('Editing protocol #%d',iProtocol);
end


%% ===== CREATE PROTOCOL EDITOR WINDOW =====
% Create Protocol editor panel
panelProtocolEditor = panel_protocol_editor('CreatePanel', action);
% Get handles to panel objects
ctrl = get(panelProtocolEditor, 'sControls');

% === ACTION: EDIT ===
if strcmpi(action, 'edit')
    % Fill text areas with existing data
    ctrl.jTextProtocolName.setText(sProtocolsListInfo(iProtocol).Comment);
    ctrl.jTextSubjectsPath.setText(sProtocolsListInfo(iProtocol).SUBJECTS);
    ctrl.jTextStudiesPath.setText(sProtocolsListInfo(iProtocol).STUDIES);
    % Cannot change directories or name after creation
    ctrl.jTextProtocolName.setEditable(0);
    ctrl.jTextSubjectsPath.setEditable(0);
    ctrl.jTextStudiesPath.setEditable(0);
    ctrl.jButtonSelectSubjPath.setEnabled(0);
    ctrl.jButtonSelectStudiesPath.setEnabled(0);
    % Subjects defaults : Individual anatomy and Default channel file
    ctrl.jRadioAnatomyIndividual.setSelected(sProtocolsListInfo(iProtocol).UseDefaultAnat == 0);
    ctrl.jRadioAnatomyDefault.setSelected(   sProtocolsListInfo(iProtocol).UseDefaultAnat == 1);
    ctrl.jRadioChannelIndividual.setSelected(    sProtocolsListInfo(iProtocol).UseDefaultChannel == 0);
    ctrl.jRadioChannelDefaultSubject.setSelected(sProtocolsListInfo(iProtocol).UseDefaultChannel == 1);
    ctrl.jRadioChannelDefaultGlobal.setSelected( sProtocolsListInfo(iProtocol).UseDefaultChannel == 2);
end

% === ACTION: CREATE ===
if strcmpi(action, 'create')
    % Default protocol name
    ProtocolName = sprintf('Protocol%02d', iProtocol);
    % Set a default subject name
    ctrl.jTextProtocolName.setText(ProtocolName);
    % Can change directories at creation
    ctrl.jTextSubjectsPath.setEditable(1);
    ctrl.jTextStudiesPath.setEditable(1);
    ctrl.jButtonSelectSubjPath.setEnabled(1);
    ctrl.jButtonSelectStudiesPath.setEnabled(1);
    % Subjects defaults : Individual anatomy and Default channel file
    ctrl.jRadioAnatomyIndividual.setSelected(1);
    ctrl.jRadioChannelIndividual.setSelected(1);
    
    % Default directory for protocol
    BrainstormDbDir = bst_get('BrainstormDbDir');
    if ~isempty(BrainstormDbDir)
        ctrl.jTextSubjectsPath.setText(bst_fullfile(BrainstormDbDir, ProtocolName, 'anat'));
        ctrl.jTextStudiesPath.setText( bst_fullfile(BrainstormDbDir, ProtocolName, 'data'));
    end
end

% === ACTION: LOAD ===
if strcmpi(action, 'load')
    ctrl.jButtonSelectProtocol.setEnabled(1);
    ctrl.jButtonSelectSubjPath.setEnabled(0);
    ctrl.jButtonSelectStudiesPath.setEnabled(0);
end

% Set the 'Save' button callback
java_setcb(ctrl.jButtonSave, 'ActionPerformedCallback', @updateProtocolModificiations);
% Show panel
panelContainer = gui_show(panelProtocolEditor, 'JavaWindow', panelTitle, [], 1, 0, 0);
drawnow;
% Check that panel is not wider that 450px
InterfaceScaling = bst_get('InterfaceScaling');
MAX_WIDTH = round(450 * InterfaceScaling / 100);
if (panelContainer.handle{1}.getSize().getWidth() > MAX_WIDTH)
    newDim = java.awt.Dimension(MAX_WIDTH, panelContainer.handle{1}.getSize().getHeight());
    panelContainer.handle{1}.setSize(newDim);   
end


%% =================================================================================
%  === CALLBACKS  ==================================================================
%  =================================================================================
    % SAVE button : Update protocol modifications
    function updateProtocolModificiations(varargin)       
        % ===== INPUT VERIFICATIONS =====
        % Get default protocol structure
        sProtocol = db_template('ProtocolInfo');
        % Get inputs : Protocol name, SUBJECTS and STUDIES directories
        sProtocol.Comment  = char(ctrl.jTextProtocolName.getText());
        sProtocol.SUBJECTS = char(ctrl.jTextSubjectsPath.getText());
        sProtocol.STUDIES  = char(ctrl.jTextStudiesPath.getText());
        % Do not accept a blank protocol name
        if isempty(sProtocol.Comment)
            bst_error('You must specify a protocol name.', 'Protocol editor', 0);
            return
        end
        % Check the existence of the SUBJECTS directory
        if isempty(sProtocol.SUBJECTS)
            bst_error('Error : You must specify the anatomies directory.', 'Protocol editor', 0);
            return
        end
        % Check the existence of the STUDIES directory
        if isempty(sProtocol.STUDIES)
            bst_error('Error : You must specify a datasets directory.', 'Protocol editor', 0);
            return
        end
        % ===== SUBJECT DEFAULTS =====
        if strcmpi(action, 'edit') || strcmpi(action, 'create')
            % Anatomy class (defaults or individual)
            sProtocol.UseDefaultAnat = ctrl.jRadioAnatomyDefault.isSelected();
            % Channel/Headmodel class (defaults or individual)
            if ctrl.jRadioChannelIndividual.isSelected()
                sProtocol.UseDefaultChannel = 0;
            elseif ctrl.jRadioChannelDefaultSubject.isSelected()
                sProtocol.UseDefaultChannel = 1;
            elseif ctrl.jRadioChannelDefaultGlobal.isSelected()
                sProtocol.UseDefaultChannel = 2;
            end
        end
        % ===== APPLY ACTION =====
        % Load protocol: close now
        if strcmpi(action, 'load')
            gui_hide('panel_protocol_editor');
        end
        % Apply action
        iProtocol = db_edit_protocol(action, sProtocol, iProtocol);
        % If an error occured, don't close the editor
        if (iProtocol <= 0)
            return
        end
        % Close 'Protocol Editor' panel
        if ~strcmpi(action, 'load')
            gui_hide('panel_protocol_editor');
        end

        % ===== SELECT NEW PROTOCOL =====
        gui_brainstorm('SetCurrentProtocol', iProtocol);
        
        % === BRAINSTORM TEMPLATE ===
        bst_progress('start', 'Creating new protocol', 'Copying default anatomy...');
        % If a template is selected 
        isTemplate = strcmpi(action, 'create');
        if isTemplate
            % Copy ICBM152 anatomy to the default anatomy for this protocol
            sTemplate = bst_get('AnatomyDefaults', 'ICBM152');
            if ~isempty(sTemplate)
                db_set_template(0, sTemplate(1), 0);
            end
        end
        % Hide progress bar (if it wasn't done before)
        bst_progress('stop');
    end
end

