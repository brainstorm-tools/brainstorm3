function jPopup = tree_callbacks( varargin )
% TREE_CALLBACKS: Perform an action on a given BstNode, or return a popup menu.
%
% USAGE:  tree_callbacks(bstNodes, action);
%
% INPUT:
%     - bstNodes : Array of BstNode java handle target
%                  Most of the functions will only use the first node
%                  Array of nodes is useful only for some popup functions
%     - action   : action that was performed {'popup', 'click', 'doubleclick'}
%
% OUTPUT: 
%     - jPopup   : handle to a JPopupMenu (or [] if no popup is created)

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
% Authors: Francois Tadel, 2008-2023
%          Raymundo Cassani, 2023-2024
%          Chinmay Chinara, 2023-2024

import org.brainstorm.icon.*;
import java.awt.event.KeyEvent;
import javax.swing.KeyStroke;


%% ===== PARSE INPUTS =====
if (nargin == 0)
    % Nothing to do... just to force the compilation of the file
    return
elseif (nargin == 2)
    if (isa(varargin{1}(1), 'org.brainstorm.tree.BstNode') && ischar(varargin{2}))
        bstNodes = varargin{1};
        action  = varargin{2};
    else
        error('Usage : tree_callbacks(bstNodes, action)');
    end
else
    error('Usage : tree_callbacks(bstNodes, action)');
end
% Initialize return variable
jPopup = [];
% Is Matlab running (if not it is a compiled version)
isCompiled = bst_iscompiled();


%% ===== GET ALL THE NEEDED OBJECTS =====
% Get current Protocol description
ProtocolInfo = bst_get('ProtocolInfo');
% Node type
nodeType = char(bstNodes(1).getType());
% Get node information
filenameRelative = char(bstNodes(1).getFileName());
% Build full filename (depends on the file type)
switch lower(nodeType)
    case {'surface', 'scalp', 'cortex', 'outerskull', 'innerskull', 'fibers', 'fem', 'other', 'subject', 'studysubject', 'anatomy', 'volatlas', 'volct'}
        filenameFull = bst_fullfile(ProtocolInfo.SUBJECTS, filenameRelative);
    case {'study', 'condition', 'rawcondition', 'channel', 'headmodel', 'data','rawdata', 'datalist', 'results', 'kernel', 'pdata', 'presults', 'ptimefreq', 'pspectrum', 'image', 'video', 'videolink', 'noisecov', 'ndatacov', 'dipoles','timefreq', 'spectrum', 'matrix', 'matrixlist', 'pmatrix', 'spike'}
        filenameFull = bst_fullfile(ProtocolInfo.STUDIES, filenameRelative);
    case 'link'
        filenameFull = filenameRelative;
    otherwise
        filenameFull = '';
end
% Is special node (starting with '(')
if (bstNodes(1).getComment().length() > 0)
    isSpecialNode = ismember(char(bstNodes(1).getType()), {'subject','defaultstudy'}) && (bstNodes(1).getComment().charAt(0) == '(');
else
    isSpecialNode = 0;
end
iStudy = [];
iSubject = [];
 
%% ===== CLICK =====
switch (lower(action))  
    case {'click', 'popup'}
        nodeStudy  = [];
        conditionTypes = {'condition', 'rawcondition', 'studysubject', 'study', 'defaultstudy'};
        % Select the Study (subject/condition) closest to the node that was clicked
        switch lower(nodeType)
            % Selecting a condition
            case conditionTypes
                % If selected node is a Study node
                if (bstNodes(1).getStudyIndex() ~= 0)
                    nodeStudy = bstNodes(1);
                % Else : try to find a Study node in the children nodes
                elseif (bstNodes(1).getChildCount() > 0)
                    % If first child is a study node : select it
                    if (bstNodes(1).getChildAt(0).getStudyIndex() ~= 0)
                        nodeStudy = bstNodes(1).getChildAt(0);
                        % Else look it 2nd levels of children
                    elseif (bstNodes(1).getChildAt(0).getChildCount() > 0) && (bstNodes(1).getChildAt(0).getChildAt(0).getStudyIndex() ~= 0)
                        nodeStudy = bstNodes(1).getChildAt(0).getChildAt(0);
                    end
                end
                % If not is not generated: Create node contents
                if ~isempty(nodeStudy)
                    panel_protocols('CreateStudyNode', nodeStudy);
                end
            % Selecting a file in a condition
            case {'data', 'rawdata', 'datalist', 'channel', 'headmodel', 'noisecov', 'ndatacov', 'results', 'kernel', 'matrix', 'matrixlist', 'dipoles', 'timefreq', 'spectrum', 'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix', 'link', 'image', 'video', 'videolink'}
                nodeStudy = bstNodes(1);
                % Go up in the ancestors, until we get a study file
                while ~isempty(nodeStudy) && ~any(strcmpi(nodeStudy.getType(), conditionTypes))
                    nodeStudy = nodeStudy.getParent();
                end
        end
                
        % If study selected changed 
        if ~isempty(nodeStudy) && (isempty(ProtocolInfo.iStudy) || (double(nodeStudy.getStudyIndex()) ~= ProtocolInfo.iStudy))
            panel_protocols('SelectStudyNode', nodeStudy);
        end
end
 

%% ===== DOUBLE CLICK =====
switch (lower(action))  
    case 'doubleclick'       
        % Switch between node types
        % Existing node types : root, loading, subjectdb, studydbsubj, studydbcond, 
        %                       surface, scalp, cortex, outerskull, innerskull, other,
        %                       subject, anatomy, study, studysubject, condition, 
        %                       channel, headmodel, data, results, link
        switch lower(nodeType)       
            % ===== SUBJECT DB ===== 
            case {'subjectdb', 'studydbsubj', 'studydbcond'}
                % Edit protocol
                iProtocol = bst_get('iProtocol');
                gui_edit_protocol('edit', iProtocol);
                
            % === SUBJECT ===
            case 'subject'
                % If clicked subject is not the default subject (ie. index=0)
                if (bstNodes(1).getStudyIndex() > 0)
                	db_edit_subject(bstNodes(1).getStudyIndex());
                end
            % === SUBJECT ===
            case 'studysubject'
                % If clicked subject is not the default subject (ie. index=0)
                if (bstNodes(1).getItemIndex() > 0)
                    % Edit subject
                	db_edit_subject(bstNodes(1).getItemIndex());
                end
                
            % ===== ANATOMY =====
            % Mark/unmark (items selected : 1)
            case 'anatomy'
                % Get subject
                iSubject = bstNodes(1).getStudyIndex();
                sSubject = bst_get('Subject', iSubject);
                % MRI: Display in MRI viewer
                view_mri(filenameRelative);
                
            % ===== VOLUME ATLAS AND VOLUME CT=====
            case {'volatlas', 'volct'}
                % Get subject
                iSubject = bstNodes(1).getStudyIndex();
                iAnatomy = bstNodes(1).getItemIndex();
                sSubject = bst_get('Subject', iSubject);
                % Atlas/CT: display as overlay on the default MRI
                if (iAnatomy ~= sSubject.iAnatomy)
                    view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, filenameRelative);
                else
                    view_mri(filenameRelative);
                end

            % ===== SURFACE ===== 
            % Mark/unmark (items selected : 1/category)
            case {'scalp', 'outerskull', 'innerskull', 'cortex', 'fibers', 'fem'}
                iSubject = bstNodes(1).getStudyIndex();
                sSubject = bst_get('Subject', iSubject);
                iSurface = bstNodes(1).getItemIndex();
                % If surface is not selected yet
                switch lower(nodeType)
                    case 'scalp',      SurfaceType = 'Scalp';
                    case 'innerskull', SurfaceType = 'InnerSkull';
                    case 'outerskull', SurfaceType = 'OuterSkull';
                    case 'cortex',     SurfaceType = 'Cortex';
                    case 'fibers',     SurfaceType = 'Fibers';
                    case 'fem',        SurfaceType = 'FEM';
                    case 'other',      SurfaceType = 'Other';
                end
                if (~ismember(iSurface, sSubject.(['i' SurfaceType])) || ~bstNodes(1).isMarked())
                    % Set it as subject default
                    db_surface_default(iSubject, SurfaceType, iSurface);
                % Else, this item is already marked : display it in surface viewer
                else
                    if strcmpi(nodeType, 'fem')
                        view_surface_fem(filenameRelative, [], [], [], 'NewFigure');
                    else
                        view_surface(filenameRelative);
                    end
                end
            % Other surface: display it
            case 'other'
                % Display mesh with 3D orthogonal slices of the default MRI only if it is an isosurface
                if ~isempty(regexp(filenameRelative, 'isosurface', 'match'))
                    iSubject = bstNodes(1).getStudyIndex();
                    sSubject = bst_get('Subject', iSubject);
                    MriFile = sSubject.Anatomy(1).FileName;
                    hFig = view_mri_3d(MriFile, [], 0.3, []);
                    view_surface(filenameRelative, [], [], hFig, []);
                else
                    view_surface(filenameRelative);
                end
                
            % ===== CHANNEL =====
            % If one and only one modality available : display sensors
            % Else : Edit channel file
            case 'channel'
                % Get displayable modalities for this file
                [tmp, DisplayMod] = bst_get('ChannelModalities', filenameRelative);
                DisplayMod = intersect(DisplayMod, {'EEG','MEG','MEG GRAD','MEG MAG','ECOG','SEEG','ECOG+SEEG','NIRS'});
                % If only one modality
                if ~isempty(DisplayMod)
                    if strcmpi(DisplayMod{1}, 'ECOG+SEEG') || (length(DisplayMod) >= 2) && all(ismember({'SEEG','ECOG'}, DisplayMod))
                        DisplayChannels(bstNodes, 'ECOG+SEEG', 'cortex', 1);
                    elseif strcmpi(DisplayMod{1}, 'SEEG')
                        DisplayChannels(bstNodes, DisplayMod{1}, 'anatomy', 1, 0);
                    elseif strcmpi(DisplayMod{1}, 'ECOG')
                        DisplayChannels(bstNodes, DisplayMod{1}, 'cortex', 1);
                    elseif ismember(DisplayMod{1}, {'MEG','MEG GRAD','MEG MAG'})
                        channel_align_manual(filenameRelative, DisplayMod{1}, 0);
                    elseif strcmpi(DisplayMod{1}, 'NIRS')
                        DisplayChannels(bstNodes, 'NIRS-BRS', 'scalp', [], 1);
                    else
                        DisplayChannels(bstNodes, DisplayMod{1}, 'scalp');
                    end
                else
                    % Open file in the "Channel Editor"
                    gui_edit_channel( filenameRelative );
                end               
                
            % ===== HEADMODEL =====
            % Mark/unmark (items selected : 1)
            case 'headmodel'
                iStudy     = bstNodes(1).getStudyIndex();
                sStudy     = bst_get('Study', iStudy);
                iHeadModel = bstNodes(1).getItemIndex();
                % If item is not marked yet : mark it (and unmark all the other nodes)
                if (~ismember(iHeadModel, sStudy.iHeadModel) || ~bstNodes(1).isMarked())
                    % Select this node (and unselect all the others)
                    panel_protocols('MarkUniqueNode', bstNodes(1));
                    % Save in database selected file
                    sStudy.iHeadModel = iHeadModel;
                    bst_set('Study', iStudy, sStudy);
                % Else, this item is already marked : keep it marked
                end
                
            % ===== NOISE COV =====
            case {'noisecov', 'ndatacov'}
                view_noisecov(filenameRelative);

            % ===== DATA =====
            % View data file (MEG and EEG)
            case {'data', 'pdata', 'rawdata'}
                view_timeseries(filenameRelative);

            % ===== DATA/MATRIX LIST =====
            % Expand node
            case {'datalist', 'matrixlist'}
                panel_protocols('ExpandPath', bstNodes(1), 1);
                
            % ===== RESULTS =====
            % View results on cortex
            case {'results', 'link'}
                % Get file pointer
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                iResult = bstNodes(1).getItemIndex();
                % Volume: MRI Viewer
                if strcmpi(sStudy.Result(iResult).HeadModelType, 'volume')
                    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                    view_mri(MriFile, filenameRelative);
                % Otherwise: 3D display
                else
                    view_surface_data([], filenameRelative);
                end
                
            % ===== STAT/RESULTS =====
            case 'presults'
                % Get study structure
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                % Read the head model from the file
                ResultsMat = in_bst_results(filenameRelative, 0, 'HeadModelType');
                % Volume: MRI Viewer
                if strcmpi(ResultsMat.HeadModelType, 'volume')
                    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                    view_mri(MriFile, filenameRelative);
                % Otherwise: 3D display
                else
                    view_surface_data([], filenameRelative);
                end
                
            % ===== DIPOLES =====
            case 'dipoles'
                % Display on existing figures
                view_dipoles(filenameFull);
                
            % ===== SPIKES =====
            case 'spike'
                panel_spikes('OpenSpikeFile', filenameRelative);

            % ===== TIME-FREQUENCY =====
            case {'timefreq', 'ptimefreq'}
                % Get study
                iStudy = bstNodes(1).getStudyIndex();
                iTimefreq = bstNodes(1).getItemIndex();
                sStudy = bst_get('Study', iStudy);
                % Get data type
                if strcmpi(char(bstNodes(1).getType()), 'ptimefreq')
                    TimefreqMat = in_bst_timefreq(filenameRelative, 0, 'DataType');
                    if ~isempty(TimefreqMat.DataType)
                        DataType = TimefreqMat.DataType;
                    else
                        DataType = 'matrix';
                    end
                    DataFile = [];
                else
                    DataType = sStudy.Timefreq(iTimefreq).DataType;
                    DataFile = sStudy.Timefreq(iTimefreq).DataFile;
                end
                % PAC and DPAC
                if ~isempty(strfind(filenameRelative, '_pac_fullmaps'))
                    view_pac(filenameRelative);
                    return;
                elseif ~isempty(strfind(filenameRelative, '_dpac_fullmaps'))
                    view_pac(filenameRelative, [], 'DynamicPAC');
                    return;
                end
                % Get subject 
                sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                switch DataType
                    % Results: display on cortex or MRI
                    case 'results'
                        % Connect NxN: Graph
                        if ~isempty(strfind(filenameRelative, '_connectn'))
                            % view_connect(filenameRelative, 'GraphFull');
                            view_connect(filenameRelative, 'Image');
                        % Else: Try to display on the brain
                        else
                            % Get head model type for the sources file
                            if ~isempty(DataFile)
                                [sStudyData, iStudyData, iResult] = bst_get('AnyFile', DataFile);
                                if ~isempty(sStudyData)
                                    isVolume = strcmpi(sStudyData.Result(iResult).HeadModelType, 'volume');
                                else
                                    disp('BST> Error: This file was linked to a source file that was deleted.');
                                    isVolume = 0;
                                end
                            % Else, read from the file if there is a GridLoc field
                            else
                                wloc    = whos('-file', filenameFull, 'GridLoc');
                                worient = whos('-file', filenameFull, 'GridAtlas');
                                isVolume = (prod(wloc.size) > 0) && (isempty(worient) || (prod(worient.size) == 0));                 
                            end
                            % Cortex
                            if ~isVolume && ~isempty(sSubject) && ~isempty(sSubject.iCortex)
                                view_surface_data([], filenameRelative);
                            % MRI
                            elseif isVolume && ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                                MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                                % view_surface_data(MriFile, filenameRelative);
                                view_mri(MriFile, filenameRelative);
                            % Else: single sensor
                            else
                                view_timefreq(filenameRelative, 'SingleSensor');
                            end
                        end
                    % Else
                    case {'data', 'cluster', 'scout', 'matrix'}
                        if ismember(nodeType, {'timefreq', 'ptimefreq'})
                            if ~isempty(strfind(filenameRelative, '_pac')) || ~isempty(strfind(filenameRelative, '_dpac'))
                                if strcmpi(DataType, 'data')
                                    view_topography(filenameRelative, [], '2DSensorCap', [], 0);
                                else
                                    view_struct(filenameFull);
                                end
                            elseif ~isempty(strfind(filenameRelative, '_connect1_cohere')) || ~isempty(strfind(filenameRelative, '_connect1_spgranger')) || ~isempty(strfind(filenameRelative, '_connect1_henv'))
                                view_spectrum(filenameRelative, 'Spectrum');
                            elseif ~isempty(strfind(filenameRelative, '_connect1')) && strcmpi(DataType, 'data')
                                view_topography(filenameRelative, [], '2DSensorCap', [], 0);
                            elseif ~isempty(strfind(filenameRelative, '_connect1'))
                                view_connect(filenameRelative, 'Image');
                            elseif ~isempty(strfind(filenameRelative, '_connectn'))
                                %view_connect(filenameRelative, 'GraphFull');
                                view_connect(filenameRelative, 'Image');
                            else
                                view_timefreq(filenameRelative, 'SingleSensor');
                            end
                        else
                            view_spectrum(filenameRelative, 'Spectrum');
                        end
                        
                    otherwise
                        error(['Invalid data type: ' DataType]);
                end
                
            % ===== SPECTRUM =====
            case {'spectrum', 'pspectrum'}
                % Get study
                iStudy = bstNodes(1).getStudyIndex();
                iTimefreq = bstNodes(1).getItemIndex();
                sStudy = bst_get('Study', iStudy);
                % Get data type
                if strcmpi(nodeType, 'pspectrum')
                    TimefreqMat = in_bst_timefreq(filenameRelative, 0, 'DataType');
                    if ~isempty(TimefreqMat.DataType)
                        DataType = TimefreqMat.DataType;
                    else
                        DataType = 'matrix';
                    end
                    DataFile = [];
                else
                    DataType = sStudy.Timefreq(iTimefreq).DataType;
                    DataFile = sStudy.Timefreq(iTimefreq).DataFile;
                end
                % Get subject 
                sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                switch (DataType)
                    % Results: display on cortex or MRI
                    case 'results'
                        % Get head model type for the sources file
                        if ~isempty(DataFile)
                            [sStudyData, iStudyData, iResult] = bst_get('AnyFile', DataFile);
                            isVolume = strcmpi(sStudyData.Result(iResult).HeadModelType, 'volume');
                        % Get the default head model
                        else
                            wloc    = whos('-file', filenameFull, 'GridLoc');
                            worient = whos('-file', filenameFull, 'GridAtlas');
                            isVolume = (prod(wloc.size) > 0) && (isempty(worient) || (prod(worient.size) == 0));
                        end
                        % Cortex / MRI
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                            view_surface_data([], filenameRelative);
                        elseif ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                            MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                            %view_surface_data(MriFile, filenameRelative);
                            view_mri(MriFile, filenameRelative);
                        else
                            view_timefreq(filenameRelative, 'SingleSensor');
                        end
                    % Else
                    case {'data', 'cluster', 'scout', 'matrix'}
                        view_spectrum(filenameRelative, 'Spectrum');

                    otherwise
                        error(['Invalid data type: ' DataType]);
                end

            % ===== MATRIX =====
            case {'matrix', 'pmatrix'}
                if ~isempty(strfind(filenameRelative, '_temporalgen'))
                    % Decoding with temporal generalization should be opened as images
                    view_matrix( filenameRelative, 'Image');
                else
                    view_matrix( filenameRelative, 'TimeSeries');
                end
                
            % ===== IMAGE =====
            case 'image'
                view_image(filenameFull);
            % ===== VIDEO =====
            case 'video'
                if ispc
                    % Get list of ActiveX controls
                    bst_progress('start', 'Open video', 'Getting installed ActiveX controls...');
                    actxList = actxcontrollist;
                    bst_progress('stop');
                    % Default if available: VLC
                    if ismember('VideoLAN.VLCPlugin.2', actxList(:,2))
                        PlayerType = 'VLC';
                    else
                        % PlayerType = 'WMPlayer';
                        PlayerType = 'VideoReader';
                    end
                else
                    PlayerType = 'VideoReader';
                end
                view_video(filenameFull, PlayerType, 1);
        end
        % Repaint tree
        panel_protocols('RepaintTree');
        
        
        
%% ===== POPUP =====
% Existing node types : root, loading, subjectdb, studydbsubj, studydbcond, 
%                       surface, scalp, cortex, outerskull, innerskull, other,
%                       subject, anatomy, study, studysubject, condition, 
%                       channel, headmodel, data, results, pdata, presults, ptimefreq
    case 'popup'
        % Create popup menu
        jPopup = java_create('javax.swing.JPopupMenu');
        jMenuExport = [];
        jMenuFileOther = [];
        
        switch lower(nodeType)
%% ===== POPUP: SUBJECTDB =====
            case 'subjectdb'
                if ~bst_get('ReadOnly')
                    iProtocol = bst_get('iProtocol');
                    gui_component('MenuItem', jPopup, [], 'Edit protocol', IconLoader.ICON_EDIT,        [], @(h,ev)gui_edit_protocol('edit', iProtocol));
                    gui_component('MenuItem', jPopup, [], 'New subject',   IconLoader.ICON_SUBJECT_NEW, [], @(h,ev)db_edit_subject);
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Import BIDS dataset', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)panel_process_select('ShowPanel', {}, 'process_import_bids'));
                end
                % Export menu (added later)
                jMenuExport = gui_component('MenuItem', [], [], 'Export',   IconLoader.ICON_SAVE, [], @(h,ev)export_protocol);

%% ===== POPUP: STUDIESDB =====
            case {'studydbsubj', 'studydbcond'}
                if ~bst_get('ReadOnly')
                    iProtocol = bst_get('iProtocol');
                    gui_component('MenuItem', jPopup, [], 'Edit protocol', IconLoader.ICON_EDIT,        [], @(h,ev)gui_edit_protocol('edit', iProtocol));
                    gui_component('MenuItem', jPopup, [], 'New subject',   IconLoader.ICON_SUBJECT_NEW, [], @(h,ev)db_edit_subject);
                    % If does not exist yet: create group analysis subject
                    if isempty(bst_get('Subject', bst_get('NormalizedSubjectName')))
                        gui_component('MenuItem', jPopup, [], 'New group analysis',   IconLoader.ICON_SUBJECT_NEW, [], @(h,ev)NewGroupAnalysis);
                    end
                    gui_component('MenuItem', jPopup, [], 'New folder', IconLoader.ICON_FOLDER_NEW,  [], @(h,ev)db_add_condition('*'));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Import BIDS dataset', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)panel_process_select('ShowPanel', {}, 'process_import_bids'));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Review raw file', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_call(@import_raw));
                    gui_component('MenuItem', jPopup, [], 'Import MEG/EEG',  IconLoader.ICON_EEG_NEW,  [], @(h,ev)bst_call(@import_data));
                    AddSeparator(jPopup);
                    % === IMPORT CHANNEL / COMPUTE HEADMODEL ===
                    fcnPopupImportChannel(bstNodes, jPopup, 0);
                    fcnPopupMenuGoodBad();
                    fcnPopupComputeHeadmodel();
                    %fncPopupMenuNoiseCov(0);
                    % === SOURCES/TIMEFREQ ===
                    fcnPopupComputeSources();
                    % fcnPopupProjectSources(0);
                end
                % Export menu (added later)
                jMenuExport = gui_component('MenuItem', [], [], 'Export',   IconLoader.ICON_SAVE, [], @(h,ev)export_protocol);


%% ===== POPUP: SUBJECT =====
            case 'subject'
                % Get subject
                iSubject = bstNodes(1).getStudyIndex(); 
                sSubject = bst_get('Subject', iSubject);
                % === EDIT SUBJECT ===
                % If subject is not default subject (if subject index is not 0)
                if ~bst_get('ReadOnly') && (iSubject > 0)
                    gui_component('MenuItem', jPopup, [], 'Edit subject', IconLoader.ICON_EDIT, [], @(h,ev)db_edit_subject(iSubject));
                end
                % If subject node is not a node linked to "Default anatomy"
                if ~bst_get('ReadOnly') && ((iSubject == 0) || ~sSubject.UseDefaultAnat)
                    AddSeparator(jPopup);
                    % === IMPORT ===
                    gui_component('MenuItem', jPopup, [], 'Import anatomy folder', IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@import_anatomy, iSubject, 0));
                    gui_component('MenuItem', jPopup, [], 'Import anatomy folder (auto)', IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@import_anatomy, iSubject, 1));
                    gui_component('MenuItem', jPopup, [], 'Import MRI', IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@import_mri, iSubject, [], [], 1));
                    gui_component('MenuItem', jPopup, [], 'Import CT', IconLoader.ICON_VOLCT, [], @(h,ev)bst_call(@import_mri, iSubject, [], [], 1, 1, 'Import CT'));
                    gui_component('MenuItem', jPopup, [], 'Import surfaces', IconLoader.ICON_SURFACE, [], @(h,ev)bst_call(@import_surfaces, iSubject));
                    gui_component('MenuItem', jPopup, [], 'Import fibers', IconLoader.ICON_FIBERS, [], @(h,ev)bst_call(@import_fibers, iSubject));
                    gui_component('MenuItem', jPopup, [], 'Convert DWI to DTI', IconLoader.ICON_FIBERS, [], @(h,ev)bst_call(@process_dwi2dti, 'ComputeInteractive', iSubject));
                    AddSeparator(jPopup);
                    
                    % === ANATOMY TEMPLATE ===
                    % Get registered Brainstorm anatomy defaults
                    sTemplates = bst_get('AnatomyDefaults');
                    % Create menus
                    jMenuDefaults   = gui_component('Menu', jPopup, [], 'Use template', IconLoader.ICON_ANATOMY, [], []);
                    jMenuDefMni     = gui_component('Menu', jMenuDefaults, [], 'MNI', IconLoader.ICON_ANATOMY, [], []);
                    jMenuDefUsc     = gui_component('Menu', jMenuDefaults, [], 'USC', IconLoader.ICON_ANATOMY, [], []);
                    jMenuDefFs      = gui_component('Menu', jMenuDefaults, [], 'FsAverage', IconLoader.ICON_ANATOMY, [], []);
                    jMenuDefInfants = gui_component('Menu', jMenuDefaults, [], 'Infants', IconLoader.ICON_ANATOMY, [], []);
                    jMenuDefOthers  = gui_component('Menu', jMenuDefaults, [], 'Others', IconLoader.ICON_ANATOMY, [], []);
                    % Add an item per Template available
                    for i = 1:length(sTemplates)
                        % Local or download?
                        if ~isempty(strfind(sTemplates(i).FilePath, 'http://')) || ~isempty(strfind(sTemplates(i).FilePath, 'https://')) || ~isempty(strfind(sTemplates(i).FilePath, 'ftp://'))
                            Comment = ['Download: ' sTemplates(i).Name];
                        else
                            Comment = sTemplates(i).Name;
                        end
                        % Sub-group
                        if ~isempty(strfind(lower(sTemplates(i).Name), 'icbm')) || ~isempty(strfind(lower(sTemplates(i).Name), 'colin'))
                            jParent = jMenuDefMni;
                        elseif ~isempty(strfind(lower(sTemplates(i).Name), 'usc')) || ~isempty(strfind(lower(sTemplates(i).Name), 'bci-dni'))
                            jParent = jMenuDefUsc;
                        elseif ~isempty(strfind(lower(sTemplates(i).Name), 'fsaverage'))
                            jParent = jMenuDefFs;
                        elseif ~isempty(strfind(lower(sTemplates(i).Name), 'oreilly')) || ~isempty(strfind(lower(sTemplates(i).Name), 'kabdebon')) || ~isempty(strfind(lower(sTemplates(i).Name), 'infant'))
                            jParent = jMenuDefInfants;
                        else
                            jParent = jMenuDefOthers;
                        end
                        % Create item
                        gui_component('MenuItem', jParent, [], Comment, IconLoader.ICON_ANATOMY, [], @(h,ev)db_set_template(iSubject, sTemplates(i), 1));
                    end
                    % Create new template
                    AddSeparator(jMenuDefaults);
                    gui_component('MenuItem', jMenuDefaults, [], 'Create new template', IconLoader.ICON_ANATOMY, [], @(h,ev)export_default_anat(iSubject));
                    gui_component('MenuItem', jMenuDefaults, [], 'Online help', IconLoader.ICON_EXPLORER, [], @(h,ev)web('https://neuroimage.usc.edu/brainstorm/Tutorials/DefaultAnatomy', '-browser'));
                    
                    % === MNI ATLASES ===
                    % Get list of templates registered in Brainstorm
                    sMniAtlases = bst_get('MniAtlasDefaults');
                    jMenuSchaefer = [];
                    % Add MNI parcellation
                    jMenuMniVol = gui_component('Menu', jPopup, [], 'Add MNI parcellation', IconLoader.ICON_ANATOMY, [], []);
                    for i = 1:length(sMniAtlases)
                        % Local or download?
                        if ~isempty(strfind(sMniAtlases(i).FilePath, 'http://')) || ~isempty(strfind(sMniAtlases(i).FilePath, 'https://')) || ~isempty(strfind(sMniAtlases(i).FilePath, 'ftp://'))
                            Comment = ['Download: ' sMniAtlases(i).Name];
                        else
                            Comment = sMniAtlases(i).Name;
                        end
                        % Submenus
                        if ~isempty(strfind(Comment, 'Schaefer2018_'))
                            if isempty(jMenuSchaefer)
                                jMenuSchaefer = gui_component('Menu', jMenuMniVol, [], 'Schaefer2018', IconLoader.ICON_ANATOMY, [], []);
                            end
                            jMenuMniSub = jMenuSchaefer;
                        else
                            jMenuMniSub = jMenuMniVol;
                        end
                        % Create item
                        gui_component('MenuItem', jMenuMniSub, [], Comment, IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@import_mniatlas, iSubject, sMniAtlases(i), 1));
                    end
                    AddSeparator(jMenuMniVol);
                    gui_component('MenuItem', jMenuMniVol, [], 'Import from file', IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@import_mniatlas, iSubject));

                    % === MRI SEGMENTATION ===
                    fcnMriSegment(jPopup, sSubject, iSubject, [], 0, 0);
                    % Export menu (added later)
                    if (iSubject ~= 0)
                        jMenuExport{1} = gui_component('MenuItem', [], [], 'Export subject',  IconLoader.ICON_SAVE, [], @(h,ev)export_protocol(bst_get('iProtocol'), iSubject));
                        jMenuExport{2} = 'separator';
                    end
                end
                
%% ===== POPUP: STUDYSUBJECT =====
            case 'studysubject'
                % Get subject
                iStudy = bstNodes(1).getStudyIndex();
                iSubject = bstNodes(1).getItemIndex();
                sSubject = bst_get('Subject', iSubject);
                % If node is a directory node
                isDirNode = (bstNodes(1).getStudyIndex() == 0);
                % === EDIT SUBJECT ===
                if ~bst_get('ReadOnly')
                    gui_component('MenuItem', jPopup, [], 'Edit subject', IconLoader.ICON_EDIT, [], @(h,ev)db_edit_subject(iSubject));
                end
                % === ADD CONDITION ===
                if ~bst_get('ReadOnly') && isDirNode
                    gui_component('MenuItem', jPopup, [], 'New folder', IconLoader.ICON_FOLDER_NEW, [], @(h,ev)db_add_condition(sSubject.Name));
                end
                % === IMPORT DATA ===
                if ~bst_get('ReadOnly')
                    AddSeparator(jPopup);
                    if isDirNode
                        gui_component('MenuItem', jPopup, [], 'Review raw file', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_call(@import_raw, [], [], iSubject));
                    end
                    gui_component('MenuItem', jPopup, [], 'Import MEG/EEG', IconLoader.ICON_EEG_NEW, [], @(h,ev)bst_call(@import_data, [], [], [], iStudy, iSubject));
                    AddSeparator(jPopup);
                end
                % === IMPORT CHANNEL / COMPUTE HEADMODEL ===
                % If not global default Channel + Headmodel
                if ~bst_get('ReadOnly')
                    if (sSubject.UseDefaultChannel ~= 2)
                        fcnPopupImportChannel(bstNodes, jPopup, 0);
                        fcnPopupMenuGoodBad();
                        fcnPopupClusterTimeSeries();
                        fcnPopupComputeHeadmodel();
                        fncPopupMenuNoiseCov(0);
                    else
                        fcnPopupMenuGoodBad();
                        fcnPopupClusterTimeSeries();
                        AddSeparator(jPopup);
                    end
                end
                % === SOURCES/TIMEFREQ ===
                if ~bst_get('ReadOnly')
                    fcnPopupComputeSources();
                    % fcnPopupProjectSources(0);
                end
                fcnPopupScoutTimeSeries(jPopup);
                % Export menu (added later)
                jMenuExport = gui_component('MenuItem', [], [], 'Export subject', IconLoader.ICON_SAVE, [], @(h,ev)export_protocol(bst_get('iProtocol'), iSubject));
                
%% ===== POPUP: CONDITION =====
            case {'condition', 'rawcondition'}
                if ~bst_get('ReadOnly')
                    isRaw = strcmpi(nodeType, 'rawcondition');
                    % If it is a study node
                    if (bstNodes(1).getStudyIndex() ~= 0) 
                        iStudy   = bstNodes(1).getStudyIndex();
                        iSubject = bstNodes(1).getItemIndex();
                        sSubject = bst_get('Subject', iSubject);
                        % === IMPORT DATA/DIPOLES ===
                        if (length(bstNodes) == 1) && ~isRaw
                            gui_component('MenuItem', jPopup, [], 'Import MEG/EEG', IconLoader.ICON_EEG_NEW, [], @(h,ev)bst_call(@import_data, [], [], [], iStudy, iSubject));
                            gui_component('MenuItem', jPopup, [], 'Import dipoles', IconLoader.ICON_DIPOLES, [], @(h,ev)bst_call(@import_dipoles, iStudy));
                            AddSeparator(jPopup);
                        end
                        % If not Default Channel
                        if (sSubject.UseDefaultChannel == 0)
                            % === IMPORT CHANNEL / COMPUTE HEADMODEL ===
                            fcnPopupImportChannel(bstNodes, jPopup, 0);
                            fcnPopupMenuGoodBad();
                            fcnPopupClusterTimeSeries();
                            fcnPopupComputeHeadmodel();
                            if ~isRaw || (length(bstNodes) == 1)
                                fncPopupMenuNoiseCov(0);
                            end
                        else
                            fcnPopupMenuGoodBad();
                            fcnPopupClusterTimeSeries();
                            % Separator
                            AddSeparator(jPopup);
                        end
                    else
                        fcnPopupMenuGoodBad();
                        fcnPopupClusterTimeSeries();
                        % Separator
                        AddSeparator(jPopup);
                    end
                    % === SOURCES/TIMEFREQ ===
                    fcnPopupComputeSources();
                    fcnPopupProjectSources(0);
                    fcnPopupScoutTimeSeries(jPopup);
                    % === GROUP CONDITIONS ===
                    if ~isRaw && (length(bstNodes) >= 2)
                        % Get conditions name list
                        ConditionsPaths = {};
                        for i = 1:length(bstNodes)
                            ConditionsPaths{i} = char(bstNodes(i).getFileName());
                        end
                        % Add separator
                        AddSeparator(jPopup);
                        % Menu "Group conditions"
                        gui_component('MenuItem', jPopup, [], 'Group folders', IconLoader.ICON_FUSION, [], @(h,ev)db_group_conditions(ConditionsPaths));
                    end
                    % === SIMULATIONS ===
                    if (length(bstNodes) == 1) && ~isRaw
                        AddSeparator(jPopup);
                        gui_component('MenuItem', jPopup, [], 'Simulate signals: SimMEEG', IconLoader.ICON_EEG_NEW, [], @(h,ev)bst_call(@bst_simmeeg, 'GUI', iStudy));
                    end
                    % === EXPORT RAW FILE ===
                    if isRaw
                        % Get all raw files contained in these folders
                        RawFiles = {};
                        for i = 1:length(bstNodes)
                            sStudy = bst_get('Study', bstNodes(i).getStudyIndex());
                            if ~isempty(sStudy) && (length(sStudy.Data) == 1) && strcmpi(sStudy.Data(1).DataType, 'raw')
                                RawFiles{end+1} = sStudy.Data(1).FileName;
                            end
                        end
                        jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)export_data(RawFiles));
                    end
                end
                
%% ===== POPUP: STUDY =====
            case 'study'
                if ~bst_get('ReadOnly')
                    iStudy   = bstNodes(1).getStudyIndex();
                    iSubject = bstNodes(1).getItemIndex();
                    sSubject = bst_get('Subject', iSubject);
                    % Get inter-subject study
                    [sInterStudy, iInterStudy] = bst_get('AnalysisInterStudy');
                    % === IMPORT DATA ===
                    if ~isSpecialNode
                        gui_component('MenuItem', jPopup, [], 'Import MEG/EEG', IconLoader.ICON_EEG_NEW, [], @(h,ev)bst_call(@import_data, [], [], [], iStudy, iSubject));
                    end
                    % If not Default Channel
                    if (sSubject.UseDefaultChannel == 0) && (iStudy ~= iInterStudy)
                        % === IMPORT CHANNEL / COMPUTE HEADMODEL ===
                        fcnPopupImportChannel(bstNodes, jPopup, 0);
                        fcnPopupMenuGoodBad();
                        fcnPopupClusterTimeSeries();
                        fcnPopupComputeHeadmodel();
                        %fncPopupMenuNoiseCov(0);
                    elseif ~isSpecialNode
                        fcnPopupMenuGoodBad();
                        fcnPopupClusterTimeSeries();
                        AddSeparator(jPopup);
                    end
                    % === SOURCES/TIMEFREQ ===
                    fcnPopupComputeSources();
                    fcnPopupProjectSources(0);
                    fcnPopupScoutTimeSeries(jPopup);
                end
                
%% ===== POPUP: DEFAULT STUDY =====
            case 'defaultstudy'
                iSubject = bstNodes(1).getItemIndex();
                if (iSubject == 0)
                    iStudy = -3;
                else
                    iStudy = bstNodes(1).getStudyIndex();
                end
                if ~bst_get('ReadOnly')
                    % === IMPORT CHANNEL / COMPUTE HEADMODEL ===
                    fcnPopupImportChannel(bstNodes, jPopup, 0);
                    fcnPopupComputeHeadmodel();
                    fncPopupMenuNoiseCov(0);
                    % === COMPUTE SOURCES ===
                    fcnPopupComputeSources();
                    AddSeparator(jPopup);
                end
                
%% ===== POPUP: CHANNEL =====
            case 'channel'
                % === DISPLAY SENSORS ===
                % Get study index
                iStudy = bstNodes(1).getStudyIndex();
                % Get subject structure
                sStudy = bst_get('Study', iStudy);
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                % Get avaible modalities for this data file
                [AllMod, DisplayMod] = bst_get('ChannelModalities', filenameRelative);
                Device = bst_get('ChannelDevice', filenameRelative);
                % Replace SEEG+ECOG with iEEG
                if ~isempty(AllMod) && all(ismember({'SEEG','ECOG'}, AllMod))
                    AllMod = cat(2, {'ECOG+SEEG'}, setdiff(AllMod, {'SEEG','ECOG'}));
                    if ~isempty(DisplayMod)
                        DisplayMod = cat(2, {'ECOG+SEEG'}, setdiff(DisplayMod, {'SEEG','ECOG'}));
                    end
                end
                % Find anatomy volumes (exclude atlases)
                if ~isempty(sSubject.Anatomy)
                    iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                else
                    iVolAnat = [];
                end
                % If only one modality
                if (length(DisplayMod) == 1) && ((length(bstNodes) ~= 1) || isempty(Device)) && ~ismember(Device, {'Vectorview306', 'CTF', '4D', 'KIT', 'KRISS', 'BabyMEG', 'RICOH'}) && ~ismember(DisplayMod, {'EEG','ECOG','SEEG','ECOG+SEEG','NIRS'})
                    gui_component('MenuItem', jPopup, [], 'Display sensors', IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{1}, 'scalp'));
                % More than one modality
                elseif (length(DisplayMod) >= 1)
                    jMenuDisplay = gui_component('Menu', jPopup, [], 'Display sensors', IconLoader.ICON_DISPLAY, [], []);
                    % Only if one item selected
                    if (length(bstNodes) == 1) && ismember(Device, {'Vectorview306', 'CTF', '4D', 'KIT', 'KRISS', 'BabyMEG', 'RICOH'})
                        gui_component('MenuItem', jMenuDisplay, [], [Device ' helmet'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayHelmet(iStudy, filenameFull));
                        if ismember(Device, {'CTF', 'KIT', 'KRISS', '4D', 'BabyMEG', 'RICOH'})
                            gui_component('MenuItem', jMenuDisplay, [], [Device ' coils (MEG)'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 0));
                            gui_component('MenuItem', jMenuDisplay, [], [Device ' coils (ALL)'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 1));
                        elseif strcmpi(Device, 'Vectorview306')
                            gui_component('MenuItem', jMenuDisplay, [], [Device ' coils (MAG)'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 0));
                            gui_component('MenuItem', jMenuDisplay, [], [Device ' coils (ALL)'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 1));
                        else
                            gui_component('MenuItem', jMenuDisplay, [], [Device ' coils'], IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 0));
                        end
                        AddSeparator(jMenuDisplay);
                    end
                    % === ITEM: MODALITIES ===
                    % For each displayable sensor type, display an item in the "display" submenu
                    for iType = 1:length(DisplayMod)
                        channelTypeDisplay = getChannelTypeDisplay(DisplayMod{iType}, DisplayMod);
                        if ismember(DisplayMod{iType}, {'EEG','ECOG','SEEG','ECOG+SEEG'}) && (length(bstNodes) == 1) && (~isempty(sSubject.iScalp) || ~isempty(sSubject.iInnerSkull) || ~isempty(sSubject.iCortex) || ~isempty(sSubject.iAnatomy))
                            if ~isempty(sSubject.iScalp)
                                gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (Head)'],     IconLoader.ICON_SURFACE_SCALP,  [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, 'scalp', 1));
                            end
                            if ~isempty(sSubject.iInnerSkull)
                                gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (Inner skull)'],   IconLoader.ICON_SURFACE_INNERSKULL, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, 'innerskull', 1));
                            end
                            if ~isempty(sSubject.iCortex)
                                gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (Cortex)'],   IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, 'cortex', 1));
                            end
                            % MRI 3D
                            if (length(iVolAnat) == 1)
                                gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (MRI 3D)'], IconLoader.ICON_ANATOMY, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, 'anatomy', iVolAnat(1)));
                            elseif (length(iVolAnat) > 1)
                                for iAnat = 1:length(iVolAnat)
                                    gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (MRI 3D: ' sSubject.Anatomy(iVolAnat(iAnat)).Comment ')'], IconLoader.ICON_ANATOMY, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, sSubject.Anatomy(iVolAnat(iAnat)).FileName, 1));
                                end
                            end
                            % MRI Viewer
                            if (length(iVolAnat) == 1)
                                gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (MRI Viewer)'], IconLoader.ICON_ANATOMY, [], @(h,ev)panel_ieeg('DisplayChannelsMri', filenameRelative, DisplayMod{iType}, iVolAnat(1), 0));
                            elseif (length(iVolAnat) > 1)
                                for iAnat = 1:length(iVolAnat)
                                    gui_component('MenuItem', jMenuDisplay, [], [channelTypeDisplay '   (MRI Viewer: ' sSubject.Anatomy(iVolAnat(iAnat)).Comment ')'], IconLoader.ICON_ANATOMY, [], @(h,ev)panel_ieeg('DisplayChannelsMri', filenameRelative, DisplayMod{iType}, iVolAnat(iAnat), 0));
                                end
                            end
                        elseif ismember('NIRS', DisplayMod{iType})
                            gui_component('MenuItem', jMenuDisplay, [], 'NIRS (scalp)', IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 0));
                            gui_component('MenuItem', jMenuDisplay, [], 'NIRS (pairs)', IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, Device, 'scalp', 0, 1));
                        else
                            gui_component('MenuItem', jMenuDisplay, [], channelTypeDisplay, IconLoader.ICON_CHANNEL, [], @(h,ev)DisplayChannels(bstNodes, DisplayMod{iType}, 'scalp'));
                        end
                    end
                end
                % === EDIT CHANNEL FILE ===
                if (length(bstNodes) == 1) && ~bst_get('ReadOnly')
                    gui_component('MenuItem', jPopup, [], 'Edit channel file', IconLoader.ICON_EDIT, [], @(h,ev)gui_edit_channel(filenameRelative));
                end
                % === RENAME CHANNELS BIOSEMI ===
                if ~isempty(regexp(lower(char(bstNodes(1).getComment())), 'bdf')) || ~isempty(regexp(lower(char(bstNodes(1).getComment())), 'biosemi'))
                    gui_component('MenuItem', jPopup, [], 'BioSemi channels names to 10-10 system', IconLoader.ICON_EDIT, [], @(h,ev)process_channel_biosemi('ComputeInteractive', filenameRelative));
                end
  
                % === ADD EEG POSITIONS ===
                if ismember('EEG', AllMod)
                    fcnPopupImportChannel(bstNodes, jPopup, 2);
                elseif ~isempty(AllMod) && any(ismember({'SEEG','ECOG','ECOG+SEEG','NIRS'}, AllMod))
                    fcnPopupImportChannel(bstNodes, jPopup, 1);
                end
                % === SEEG IMPLANTATION ===
                if (length(bstNodes) == 1) && ((isempty(AllMod) && strcmpi(sStudy.Name, 'implantation')) || any(ismember({'SEEG','ECOG','ECOG+SEEG'}, AllMod)))
                        gui_component('MenuItem', jPopup, [], 'SEEG/ECOG implantation', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)DisplayChannels(bstNodes, 'SEEG', 'anatomy', 1, 0));
                end
                % === SEEG CONTACT LABELLING ===
                if (length(bstNodes) == 1) && ~isempty(AllMod) && any(ismember({'SEEG','ECOG','ECOG+SEEG'}, AllMod))
                    gui_component('MenuItem', jPopup, [], 'iEEG atlas labels', IconLoader.ICON_VOLATLAS, [], @(h,ev)bst_call(@export_channel_atlas, filenameRelative, 'ECOG+SEEG'));
                end
                
                % === NIRS CHANNEL LABELLING ===
                if (length(bstNodes) == 1) && ~isempty(AllMod) && any(ismember({'NIRS'}, AllMod))
                    gui_component('MenuItem', jPopup, [], 'NIRS atlas labels', IconLoader.ICON_VOLATLAS, [], @(h,ev)bst_call(@export_channel_nirs_atlas, filenameRelative));
                end
                
                % === ONLY ONE FILE SELECTED ===
                if (length(bstNodes) == 1)
                    AddSeparator(jPopup);
                    % === MENU "ALIGN" ===
                    jMenuAlign = gui_component('Menu', jPopup, [], 'MRI registration', IconLoader.ICON_ALIGN_CHANNELS, [], []);
                    DisplayModReg = union(intersect(DisplayMod, {'MEG','EEG','SEEG','ECOG','ECOG+SEEG','NIRS'}), intersect(AllMod, {'SEEG','ECOG','ECOG+SEEG'}));
                    if isempty(DisplayModReg) && isempty(DisplayMod) && isempty(AllMod)
                        DisplayModReg = {'SEEG'};
                    end
                    for iMod = 1:length(DisplayModReg)
                        % Display sensor type there is there are multiple possibilities
                        if (length(DisplayModReg) > 1)
                            strType = [DisplayModReg{iMod} ': '];
                        else
                            strType = '';
                        end
                        % MEG/EEG: Check and edit on scalp
                        if ismember(DisplayModReg{iMod}, {'MEG', 'EEG', 'NIRS'})
                            gui_component('MenuItem', jMenuAlign, [], [strType 'Check'], IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 0));
                            if ~bst_get('ReadOnly')
                                gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...'], IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1));
                            end
                            AddSeparator(jMenuAlign);
                        % ECOG/SEEG: More options
                        elseif ismember(DisplayModReg{iMod}, {'SEEG', 'ECOG', 'ECOG+SEEG'}) && ~bst_get('ReadOnly')
                            % Only if the electrodes already have 3D positions
                            if ismember(DisplayModReg{iMod}, DisplayMod)
                                if ~isempty(sSubject.iScalp)
                                    gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (Head)'],       IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1, 'scalp'));
                                end
                                if ~isempty(sSubject.iInnerSkull)
                                    gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (Inner skull)'],IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1, 'innerskull'));
                                end
                                if ~isempty(sSubject.iCortex)
                                    gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (Cortex)'],     IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1, 'cortex'));
                                end
                                if (length(iVolAnat) == 1)
                                    gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (MRI 3D)'], IconLoader.ICON_ANATOMY, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1, sSubject.Anatomy(iVolAnat(1)).FileName));
                                elseif (length(iVolAnat) > 1)
                                    for iAnat = 1:length(iVolAnat)
                                        gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (MRI 3D: ' sSubject.Anatomy(iVolAnat(iAnat)).Comment ')'], IconLoader.ICON_ANATOMY, [], @(h,ev)channel_align_manual(filenameRelative, DisplayModReg{iMod}, 1, sSubject.Anatomy(iVolAnat(iAnat)).FileName));
                                    end
                                end
                            end
                            % Allow edition in MRI even if there is not location available for any electrode
                            if (length(iVolAnat) == 1)
                                gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (MRI Viewer)'], IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)panel_ieeg('DisplayChannelsMri', filenameRelative, DisplayModReg{iMod}, iVolAnat(1), 1));
                            elseif (length(iVolAnat) > 1)
                                for iAnat = 1:length(iVolAnat)
                                    gui_component('MenuItem', jMenuAlign, [], [strType 'Edit...    (MRI Viewer: ' sSubject.Anatomy(iVolAnat(iAnat)).Comment ')'], IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)panel_ieeg('DisplayChannelsMri', filenameRelative, DisplayModReg{iMod}, iVolAnat(iAnat), 1));
                                end
                            end
                            AddSeparator(jMenuAlign);
                        end
                    end
                    % Auto MRI registration 
                    if ~bst_get('ReadOnly')
                        gui_component('MenuItem', jMenuAlign, [], 'Refine using head points', IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)channel_align_auto(filenameRelative, [], 1, 0));
                    end
                    
                    % === MENU: EXTRA HEAD POINTS ===
                    jMenuHeadPoints = gui_component('Menu', jPopup, [], 'Digitized head points', IconLoader.ICON_CHANNEL, [], []);
                    % View head points
                    gui_component('MenuItem', jMenuHeadPoints, [], 'View head points', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)view_headpoints(filenameFull, [], 0));
                    % Edit head points
                    if ~bst_get('ReadOnly')
                        % Add head points
                        gui_component('MenuItem', jMenuHeadPoints, [], 'Add points...', IconLoader.ICON_CHANNEL, [], @(h,ev)ChannelAddHeadpoints(filenameRelative));
                        % Remove all head points
                        gui_component('MenuItem', jMenuHeadPoints, [], 'Remove all points', IconLoader.ICON_DELETE, [], @(h,ev)ChannelRemoveHeadpoints(filenameRelative));
                        % Remove points below the nasion
                        gui_component('MenuItem', jMenuHeadPoints, [], 'Remove points below nasion', IconLoader.ICON_DELETE, [], @(h,ev)ChannelRemoveHeadpoints(filenameRelative, 0));
                        % WARP
                        AddSeparator(jMenuHeadPoints);
                        jMenuWarp = gui_component('Menu', jMenuHeadPoints, [], 'Warp', IconLoader.ICON_ALIGN_CHANNELS, [], []);
                        gui_component('MenuItem', jMenuWarp, [], 'Deform default anatomy to fit these points', IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)bst_warp_prepare(filenameFull));
                    end
                    % === LOAD SSP PROJECTORS ===
                    if ~bst_get('ReadOnly')
                        gui_component('MenuItem', jPopup, [], 'Load SSP projectors', IconLoader.ICON_CONDITION, [], @(h,ev)LoadSSP(filenameFull));
                    end
                    % === COMPUTE HEAD MODEL ===
                    if ~bst_get('ReadOnly')
                        fcnPopupComputeHeadmodel();
                    end

                    % ===== PROJECT SENSORS =====
                    if ~bst_get('ReadOnly') && ~isempty(DisplayMod) && ~any(ismember(DisplayMod, {'MEG', 'MEG MAG', 'MEG GRAD'}))
                        AddSeparator(jPopup);
                        if (iSubject == 0) || sSubject.UseDefaultAnat
                            gui_component('MenuItem', jPopup, [], 'Project to subject...', IconLoader.ICON_PROJECT_ELECTRODES, [], @(h,ev)bst_project_channel(filenameRelative, []));
                        else
                            gui_component('MenuItem', jPopup, [], 'Project to default anatomy', IconLoader.ICON_PROJECT_ELECTRODES, [], @(h,ev)bst_project_channel(filenameRelative, 0));
                        end
                    end

                    % === MENU: EXPORT ===
                    % Export menu (added later)
                    jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_channel, filenameFull));
                end
                
%% ===== POPUP: ANATOMY =====
            case {'anatomy', 'volatlas', 'volct'}
                iSubject = bstNodes(1).getStudyIndex();
                sSubject = bst_get('Subject', iSubject);
                iAnatomy = [];
                for iFile = 1:length(bstNodes)
                    iAnatomy(iFile) = bstNodes(iFile).getItemIndex();
                end
                mriComment = lower(char(bstNodes(1).getComment()));
                isAtlas = strcmpi(nodeType, 'volatlas') || ~isempty(strfind(mriComment, 'tissues')) || ~isempty(strfind(mriComment, 'aseg')) || ~isempty(strfind(mriComment, 'atlas'));
                isCt    = strcmpi(nodeType, 'volct');
                    
                if (length(bstNodes) == 1)
                    % MENU : DISPLAY
                    jMenuDisplay = gui_component('Menu', jPopup, [], 'Display', IconLoader.ICON_ANATOMY, [], []);
                        % Display
                        if isAtlas
                            gui_component('MenuItem', jMenuDisplay, [], 'MRI Viewer',           IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(filenameRelative, filenameRelative));
                            gui_component('MenuItem', jMenuDisplay, [], '3D orthogonal slices', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri_3d(filenameRelative, filenameRelative));
                        else
                            gui_component('MenuItem', jMenuDisplay, [], 'MRI Viewer',           IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(filenameRelative));
                            gui_component('MenuItem', jMenuDisplay, [], '3D orthogonal slices', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri_3d(filenameRelative));
                        end
                        AddSeparator(jMenuDisplay);
                        % Display as overlay
                        if ~bstNodes(1).isMarked()
                            % Get subject structure
                            sSubject = bst_get('MriFile', filenameRelative);
                            MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                            % Overlay menus
                            gui_component('MenuItem', jMenuDisplay, [], 'Overlay on default MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                            gui_component('MenuItem', jMenuDisplay, [], 'Overlay on default MRI (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri_3d(MriFile, filenameRelative));
                            AddSeparator(jMenuDisplay);
                        end
                        gui_component('MenuItem', jMenuDisplay, [], 'Axial slices',    IconLoader.ICON_SLICES,  [], @(h,ev)view_mri_slices(filenameRelative, 'axial', 20));
                        gui_component('MenuItem', jMenuDisplay, [], 'Coronal slices',  IconLoader.ICON_SLICES,  [], @(h,ev)view_mri_slices(filenameRelative, 'coronal', 20));
                        gui_component('MenuItem', jMenuDisplay, [], 'Sagittal slices', IconLoader.ICON_SLICES,  [], @(h,ev)view_mri_slices(filenameRelative, 'sagittal', 20));
                        if ~isAtlas
                            AddSeparator(jMenuDisplay);
                            gui_component('MenuItem', jMenuDisplay, [], 'Histogram', IconLoader.ICON_HISTOGRAM, [], @(h,ev)view_mri_histogram(filenameFull));
                        end
                    % === MENU: EDIT MRI ===
                    if ~bst_get('ReadOnly') && ~isAtlas && ~isCt
                        gui_component('MenuItem', jPopup, [], 'Edit MRI...', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(filenameRelative, 'EditMri'));
                    end
                    % === MENU: SET AS DEFAULT ===
                    if ~bst_get('ReadOnly') && (~ismember(iAnatomy, sSubject.iAnatomy) || ~bstNodes(1).isMarked()) && ~isAtlas && ~isCt
                        gui_component('MenuItem', jPopup, [], 'Set as default MRI', IconLoader.ICON_GOOD, [], @(h,ev)SetDefaultSurf(iSubject, 'Anatomy', iAnatomy));
                    end
                    % === MENU: CREATE SURFACES ===
                    if ~bst_get('ReadOnly') && isAtlas && isempty(strfind(mriComment, 'tissues'))
                        gui_component('MenuItem', jPopup, [], 'Create surfaces', IconLoader.ICON_VOLATLAS, [], @(h,ev)bst_call(@import_surfaces, iSubject, filenameFull, 'MRI-MASK', 0, [], [], mriComment));
                    end
                end
                
                if ~bst_get('ReadOnly')
                    % === REGISTRATION ===
                    % Get file comment
                    if ~isAtlas && (length(bstNodes) == 1)
                        AddSeparator(jPopup);
                        gui_component('MenuItem', jPopup, [], 'MNI normalization', IconLoader.ICON_ANATOMY, [], @(h,ev)process_mni_normalize('ComputeInteractive', filenameRelative));
                        gui_component('MenuItem', jPopup, [], 'Resample volume...', IconLoader.ICON_ANATOMY, [], @(h,ev)ResampleMri(filenameRelative));
                        if ~bstNodes(1).isMarked()
                            jMenuRegister = gui_component('Menu', jPopup, [], 'Register with default MRI', IconLoader.ICON_ANATOMY);
                            gui_component('MenuItem', jMenuRegister, [], 'SPM: Register + reslice', IconLoader.ICON_ANATOMY, [], @(h,ev)MriCoregister(filenameRelative, [], 'spm', 1));
                            gui_component('MenuItem', jMenuRegister, [], 'SPM: Register only',      IconLoader.ICON_ANATOMY, [], @(h,ev)MriCoregister(filenameRelative, [], 'spm', 0));
                            AddSeparator(jMenuRegister);
                            gui_component('MenuItem', jMenuRegister, [], 'Reslice / normalized coordinates (MNI)', IconLoader.ICON_ANATOMY, [], @(h,ev)MriReslice(filenameRelative, [], 'ncs', 'ncs'));
                            gui_component('MenuItem', jMenuRegister, [], 'Reslice / subject coordinates (SCS)',    IconLoader.ICON_ANATOMY, [], @(h,ev)MriReslice(filenameRelative, [], 'scs', 'scs'));
                            gui_component('MenuItem', jMenuRegister, [], 'Reslice / world coordinates (.nii)',     IconLoader.ICON_ANATOMY, [], @(h,ev)MriReslice(filenameRelative, [], 'vox2ras', 'vox2ras'));
                            AddSeparator(jMenuRegister);
                            gui_component('MenuItem', jMenuRegister, [], 'Copy fiducials from default MRI',    IconLoader.ICON_ANATOMY, [], @(h,ev)MriCoregister(filenameRelative, [], 'vox2ras', 0));
                        end
                    end
                    % === MRI SEGMENTATION ===
                    fcnMriSegment(jPopup, sSubject, iSubject, iAnatomy, isAtlas, isCt);
                end
                % === MENU: EXPORT ===
                % Export menu (added later)
                if (length(bstNodes) == 1)
                    jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_mri, filenameFull));
                end

%% ===== POPUP: SURFACE =====
            case {'scalp', 'cortex', 'outerskull', 'innerskull', 'other'}
                % Get subject
                iSubject = bstNodes(1).getStudyIndex();
                sSubject = bst_get('Subject', iSubject);
                
                % === DISPLAY ===
                gui_component('MenuItem', jPopup, [], 'Display', IconLoader.ICON_DISPLAY, [], @(h,ev)view_surface(filenameRelative));

                % === SET SURFACE TYPE ===
                if ~bst_get('ReadOnly') && (length(bstNodes) == 1)
                    jItemSetSurfType = gui_component('Menu', jPopup, [], 'Set surface type', IconLoader.ICON_SURFACE, [], []);
                    jItemSetSurfTypeScalp      = gui_component('MenuItem', jItemSetSurfType, [], 'Scalp',       IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)node_set_type(bstNodes(1), 'Scalp'));
                    jItemSetSurfTypeCortex     = gui_component('MenuItem', jItemSetSurfType, [], 'Cortex',      IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)node_set_type(bstNodes(1), 'Cortex'));
                    jItemSetSurfTypeOuterSkull = gui_component('MenuItem', jItemSetSurfType, [], 'Outer skull', IconLoader.ICON_SURFACE_OUTERSKULL, [], @(h,ev)node_set_type(bstNodes(1), 'OuterSkull'));
                    jItemSetSurfTypeInnerSkull = gui_component('MenuItem', jItemSetSurfType, [], 'Inner skull', IconLoader.ICON_SURFACE_INNERSKULL, [], @(h,ev)node_set_type(bstNodes(1), 'InnerSkull'));
                    jItemSetSurfTypeFibers     = gui_component('MenuItem', jItemSetSurfType, [], 'Fibers',      IconLoader.ICON_FIBERS, [], @(h,ev)node_set_type(bstNodes(1), 'Fibers'));
                    jItemSetSurfTypeOther      = gui_component('MenuItem', jItemSetSurfType, [], 'Other',       IconLoader.ICON_SURFACE, [], @(h,ev)node_set_type(bstNodes(1), 'Other'));
                    % Check current type
                    switch (nodeType)
                        case 'scalp'
                            jItemSetSurfTypeScalp.setSelected(1);
                        case 'cortex'
                            jItemSetSurfTypeCortex.setSelected(1);
                        case 'outerskull'
                            jItemSetSurfTypeOuterSkull.setSelected(1);
                        case 'innerskull'
                            jItemSetSurfTypeInnerSkull.setSelected(1);
                        case 'fibers'
                            jItemSetSurfTypeFibers.setSelected(1);
                        case 'other'
                            jItemSetSurfTypeOther.setSelected(1);
                    end
                end
                
                % SET AS DEFAULT SURFACE
                if ~bst_get('ReadOnly') && (length(bstNodes) == 1)
                    iSurface = bstNodes(1).getItemIndex();
                    switch lower(nodeType)
                        case 'scalp',      SurfaceType = 'Scalp';
                        case 'innerskull', SurfaceType = 'InnerSkull';
                        case 'outerskull', SurfaceType = 'OuterSkull';
                        case 'cortex',     SurfaceType = 'Cortex';
                        case 'other',      SurfaceType = 'Other';
                    end
                    if (~ismember(iSurface, sSubject.(['i' SurfaceType])) || ~bstNodes(1).isMarked()) && ~strcmpi(nodeType, 'other')
                        gui_component('MenuItem', jPopup, [], ['Set as default ' lower(nodeType)], IconLoader.ICON_GOOD, [], @(h,ev)SetDefaultSurf(iSubject, SurfaceType, iSurface));
                    end
                    % Separator
                    AddSeparator(jPopup);
                end
                % NUMBER OF SELECTED FILES
                if (length(bstNodes) >= 2)
                    if ~bst_get('ReadOnly')
                        gui_component('MenuItem', jPopup, [], 'Less vertices...', IconLoader.ICON_DOWNSAMPLE, [], @(h,ev)tess_downsize(GetAllFilenames(bstNodes)));
                        gui_component('MenuItem', jPopup, [], 'Merge surfaces',   IconLoader.ICON_FUSION, [], @(h,ev)SurfaceConcatenate(GetAllFilenames(bstNodes)));
                        gui_component('MenuItem', jPopup, [], 'Average surfaces', IconLoader.ICON_SURFACE_ADD, [], @(h,ev)SurfaceAverage(GetAllFilenames(bstNodes)));
                    end
                else
                    % === MENU: "ALIGN WITH MRI" ===
                    jMenuAlign = gui_component('Menu', jPopup, [], 'MRI registration', IconLoader.ICON_ALIGN_SURFACES, [], []);
                        % === CHECK ALIGNMENT WITH MRI ===
                        gui_component('MenuItem', jMenuAlign, [], 'Check MRI/surface registration...', IconLoader.ICON_CHECK_ALIGN, [], @(h,ev)SurfaceCheckAlignment_Callback(bstNodes(1)));
                        % No read-only
                        if ~bst_get('ReadOnly')
                            AddSeparator(jMenuAlign);
                            % === ALIGN ALL SURFACES ===
                            gui_component('MenuItem', jMenuAlign, [], 'Edit fiducials...', IconLoader.ICON_ALIGN_SURFACES, [], @(h,ev)tess_align_fiducials(filenameRelative, {sSubject.Surface.FileName}));
                            % === MENU: ALIGN SURFACE MANUALLY ===
                            fcnPopupAlign();
                            % === MENU: LOAD FREESURFER SPHERE ===
                            AddSeparator(jMenuAlign);
                            gui_component('MenuItem', jMenuAlign, [], 'Load FreeSurfer sphere...', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)TessAddSphere(filenameRelative));
                            gui_component('MenuItem', jMenuAlign, [], 'Load BrainSuite square...', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)TessAddSquare(filenameRelative));
                            gui_component('MenuItem', jMenuAlign, [], 'Display registration sphere/square', IconLoader.ICON_DISPLAY, [], @(h,ev)view_surface_sphere(filenameRelative, 'orig'));
                            gui_component('MenuItem', jMenuAlign, [], '2D projection (Mollweide)', IconLoader.ICON_DISPLAY, [], @(h,ev)view_surface_sphere(filenameRelative, 'mollweide'));
                        end
                
                    % No read-only
                    if ~bst_get('ReadOnly')
                        gui_component('MenuItem', jPopup, [], 'Less vertices...', IconLoader.ICON_DOWNSAMPLE, [], @(h,ev)tess_downsize(filenameFull, [], []));
                        gui_component('MenuItem', jPopup, [], 'Remesh...', IconLoader.ICON_FLIP, [], @(h,ev)bst_call(@tess_remesh, filenameFull));
                        gui_component('MenuItem', jPopup, [], 'Swap faces', IconLoader.ICON_FLIP, [], @(h,ev)SurfaceSwapFaces_Callback(filenameFull));
                        if strcmpi(nodeType, 'scalp')
                            gui_component('MenuItem', jPopup, [], 'Fill holes', IconLoader.ICON_RECYCLE, [], @(h,ev)SurfaceFillHoles_Callback(filenameFull));
                        end
                        if strcmpi(nodeType, 'cortex')
                            gui_component('MenuItem', jPopup, [], 'Extract envelope', IconLoader.ICON_SURFACE_INNERSKULL, [], @(h,ev)SurfaceEnvelope_Callback(filenameFull));
                            if ~isempty(sSubject.iInnerSkull)
                                gui_component('MenuItem', jPopup, [], 'Force inside skull', IconLoader.ICON_SURFACE_INNERSKULL, [], @(h,ev)tess_force_envelope(filenameFull, sSubject.Surface(sSubject.iInnerSkull).FileName));
                            end
                        end
                        gui_component('MenuItem', jPopup, [], 'Remove interpolations', IconLoader.ICON_RECYCLE, [], @(h,ev)SurfaceClean_Callback(filenameFull, 0));
                        gui_component('MenuItem', jPopup, [], 'Clean surface',         IconLoader.ICON_RECYCLE, [], @(h,ev)SurfaceClean_Callback(filenameFull, 1));
                        AddSeparator(jPopup);
                        gui_component('MenuItem', jPopup, [], 'Import texture', IconLoader.ICON_RESULTS, [], @(h,ev)import_sources([], filenameFull));
                    end
                end
                % Generate FEM mesh
                if ~bst_get('ReadOnly')
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Generate FEM mesh', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_fem_mesh, 'ComputeInteractive', iSubject, [], GetAllFilenames(bstNodes)));
                end
                % === MENU: EXPORT ===
                % Export menu (added later)
                jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)export_surfaces(filenameFull));
             
                
%% ===== POPUP: FIBERS =====
            case 'fibers'             
                % === DISPLAY ===
                gui_component('MenuItem', jPopup, [], 'Display', IconLoader.ICON_DISPLAY, [], @(h,ev)view_surface(filenameRelative));
                % === SUBSAMPLE ===
                if ~bst_get('ReadOnly')
                    gui_component('MenuItem', jPopup, [], 'Less fibers...', IconLoader.ICON_DOWNSAMPLE, [], @(h,ev)fibers_downsample(filenameFull));
                    gui_component('MenuItem', jPopup, [], 'Interpolate points...', IconLoader.ICON_FLIP, [], @(h,ev)fibers_interp(filenameFull));
                end
              
%% ===== POPUP: FEM HEAD MODEL =====
            case 'fem'
                iSubject = bstNodes(1).getStudyIndex();
                if (length(bstNodes) == 1)
                    gui_component('MenuItem', jPopup, [], 'Display', IconLoader.ICON_DISPLAY, [], @(h,ev)view_surface_fem(filenameRelative, [], [], [], 'NewFigure'));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Extract surfaces', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@import_femlayers, iSubject, filenameFull, 'BSTFEM', 1));
                    gui_component('MenuItem', jPopup, [], 'Merge layers', IconLoader.ICON_FEM, [], @(h,ev)panel_femname('Edit', filenameFull));
                    gui_component('MenuItem', jPopup, [], 'Convert tetra/hexa', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_fem_mesh, 'SwitchHexaTetra', filenameRelative));
                    gui_component('MenuItem', jPopup, [], 'Compute mesh statistics', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@fem_meshstats, filenameRelative));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Resect neck', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@fem_resect, filenameFull));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Compute FEM tensors', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_fem_tensors, 'ComputeInteractive', iSubject, filenameFull));
                    % If there are tensors to display
                    varInfo = whos('-file', filenameFull, 'Tensors');
                    if ~isempty(varInfo) && all(varInfo.size >= 12)
                        jMenuFemDisp = gui_component('Menu', jPopup, [], 'Display FEM tensors', IconLoader.ICON_DISPLAY, [], []);
                        gui_component('MenuItem', jMenuFemDisp, [], 'Display as ellipsoids (MRI)', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@view_fem_tensors, filenameFull, 'ellipse'));
                        gui_component('MenuItem', jMenuFemDisp, [], 'Display as arrows (MRI)', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@view_fem_tensors, filenameFull, 'arrow'));
                        AddSeparator(jMenuFemDisp);
                        gui_component('MenuItem', jMenuFemDisp, [], 'Display as ellipsoids (FEM mesh)', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@view_fem_tensors, filenameFull, 'ellipse', [], filenameFull));
                        gui_component('MenuItem', jMenuFemDisp, [], 'Display as arrows (FEM mesh)', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@view_fem_tensors, filenameFull, 'arrow', [], filenameFull));
                        gui_component('MenuItem', jPopup, [], 'Clear FEM tensors', IconLoader.ICON_DELETE, [], @(h,ev)bst_call(@process_fem_tensors, 'ClearTensors', filenameFull));
                    end
                    
                    % === MENU: ALIGN SURFACE MANUALLY ===
                    % Get subject
                    iSubject = bstNodes(1).getStudyIndex();
                    sSubject = bst_get('Subject', iSubject);
                    % Menu: Align manually
                    AddSeparator(jPopup);
                    fcnPopupAlign();
                end
                
%% ===== POPUP: NOISECOV =====
            case {'noisecov', 'ndatacov'}
                if (length(bstNodes) == 1)
                    % Get modalities for first selected file
                    AllMod = intersect(bst_get('ChannelModalities', filenameRelative), {'MEG', 'MEG MAG', 'MEG GRAD', 'EEG', 'SEEG', 'ECOG'});
                    % Display as image
                    if (length(AllMod) == 1)
                        gui_component('MenuItem', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_noisecov(filenameRelative));
                    elseif (length(AllMod) > 1)
                        % All sensors
                        jMenuDisplay = gui_component('Menu', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], []);
                        gui_component('MenuItem', jMenuDisplay, [], 'All sensors', IconLoader.ICON_NOISECOV, [], @(h,ev)view_noisecov(filenameRelative));
                        AddSeparator(jMenuDisplay);
                        % Each sensor type independently
                        for i = 1:length(AllMod)
                            gui_component('MenuItem', jMenuDisplay, [], AllMod{i}, IconLoader.ICON_NOISECOV, [], @(h,ev)view_noisecov(filenameRelative, AllMod{i}));
                        end
                    end
                    % Apply 
                    if ~bst_get('ReadOnly')
                        isDataCov = strcmpi(file_gettype(filenameRelative), 'ndatacov');
                        % Apply to all conditions/subjects
                        AddSeparator(jPopup);
                        gui_component('MenuItem', jPopup, [], 'Copy to other folders', IconLoader.ICON_HEADMODEL, [], @(h,ev)db_set_noisecov(bstNodes(1).getStudyIndex(), 'AllConditions', isDataCov));
                        gui_component('MenuItem', jPopup, [], 'Copy to other subjects',   IconLoader.ICON_HEADMODEL, [], @(h,ev)db_set_noisecov(bstNodes(1).getStudyIndex(), 'AllSubjects', isDataCov));
                    end
                end

%% ===== POPUP: HEADMODEL =====
            case 'headmodel'
                % Get study description
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                iHeadModel = bstNodes(1).getItemIndex();
                % Get channel file
                if ~isempty(sStudy.Channel)
                    ChannelFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Channel.FileName);
                else
                    ChannelFile = [];
                end
                
                % === COMPUTE SOURCES ===
                if ~bst_get('ReadOnly') && isempty(strfind(filenameRelative, 'headmodel_grid_'))
                    % gui_component('MenuItem', jPopup, [], 'Compute sources [2009]', IconLoader.ICON_RESULTS, [], @(h,ev)selectHeadmodelAndComputeSources(bstNodes, '2009'));
                    % gui_component('MenuItem', jPopup, [], 'Compute sources [2016]', IconLoader.ICON_RESULTS, [], @(h,ev)selectHeadmodelAndComputeSources(bstNodes, '2016'));
                    gui_component('MenuItem', jPopup, [], 'Compute sources [2018]', IconLoader.ICON_RESULTS, [], @(h,ev)selectHeadmodelAndComputeSources(bstNodes, '2018'));
                end
                % === SET AS DEFAULT HEADMODEL ===
                if ~bst_get('ReadOnly') && (~ismember(iHeadModel, sStudy.iHeadModel) || ~bstNodes(1).isMarked())
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], ['Set as default ' lower(nodeType)], IconLoader.ICON_GOOD, [], @(h,ev)SetDefaultHeadModel(bstNodes(1), iHeadModel, iStudy, sStudy));
                end
                % === CHECK SPHERES ===
                MEGMethod = sStudy.HeadModel(iHeadModel).MEGMethod;
                EEGMethod = sStudy.HeadModel(iHeadModel).EEGMethod;
                isSepGain = 0;
                if ~isempty(ChannelFile) && ((~isempty(MEGMethod) && ismember(MEGMethod, {'os_meg', 'meg_sphere', 'singlesphere', 'localspheres'})) || (~isempty(EEGMethod) && ismember(EEGMethod, {'eeg_3sphereberg', 'singlesphere', 'concentricspheres'})))
                    if ~bst_get('ReadOnly')
                        isSepGain = 1;
                        AddSeparator(jPopup);
                    end
                    % Get subject
                    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                    gui_component('MenuItem', jPopup, [], 'Check spheres', IconLoader.ICON_HEADMODEL, [], @(h,ev)view_spheres(filenameFull, ChannelFile, sSubject));
                end
                
                % === CHECK SOURCE GRID ===
                if strcmpi(sStudy.HeadModel(iHeadModel).HeadModelType, 'volume') 
                    if ~bst_get('ReadOnly') && ~isSepGain
                        AddSeparator(jPopup);
                    end
                    gui_component('MenuItem', jPopup, [], 'Check source grid (Cortex)', IconLoader.ICON_HEADMODEL, [], @(h,ev)view_gridloc(filenameFull));
                    gui_component('MenuItem', jPopup, [], 'Check source grid (MRI)', IconLoader.ICON_HEADMODEL, [], @(h,ev)view_gridloc(filenameFull, 'V', 'MRI'));
                elseif strcmpi(sStudy.HeadModel(iHeadModel).HeadModelType, 'mixed')
                    if ~bst_get('ReadOnly') && ~isSepGain
                        AddSeparator(jPopup);
                    end
                    gui_component('MenuItem', jPopup, [], 'Check source grid (volume)', IconLoader.ICON_HEADMODEL, [], @(h,ev)view_gridloc(filenameFull, 'V'));
                    gui_component('MenuItem', jPopup, [], 'Check source grid (surface)', IconLoader.ICON_HEADMODEL, [], @(h,ev)view_gridloc(filenameFull, 'S'));
                end
                if isempty(strfind(filenameRelative, 'headmodel_grid_'))
                    AddSeparator(jPopup);
                    for mod = {'MEG', 'EEG', 'SEEG', 'ECOG'}
                        if isempty(sStudy.HeadModel(iHeadModel).([mod{1}, 'Method']))
                            continue;
                        end
                        gui_component('MenuItem', jPopup, [], ['View ' mod{1} ' leadfield vectors'], IconLoader.ICON_RESULTS, [], @(h,ev)bst_call(@view_leadfield_vectors, GetAllFilenames(bstNodes), mod{1}));
                        if strcmpi(sStudy.HeadModel(iHeadModel).HeadModelType, 'volume')
                            if ismember(mod, {'SEEG', 'ECOG'})
                                gui_component('MenuItem', jPopup, [], ['View ' mod{1} ' leadfield sensitivity (isosurface)'], IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@view_leadfield_sensitivity, filenameRelative, mod{1}, 'Isosurface'));
                            end
                            gui_component('MenuItem', jPopup, [], ['View ' mod{1} ' leadfield sensitivity (MRI 3D)'], IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@view_leadfield_sensitivity, filenameRelative, mod{1}, 'Mri3D'));
                            gui_component('MenuItem', jPopup, [], ['View ' mod{1} ' leadfield sensitivity (MRI Viewer)'], IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@view_leadfield_sensitivity, filenameRelative, mod{1}, 'MriViewer'));
                            AddSeparator(jPopup);
                            gui_component('MenuItem', jPopup, [], ['Apply ' mod{1} ' leadfield exclusion zone'], IconLoader.ICON_HEADMODEL, [], @(h,ev)process_headmodel_exclusionzone('ComputeInteractive', filenameRelative, mod{1}, iStudy));
                        elseif strcmpi(sStudy.HeadModel(iHeadModel).HeadModelType, 'surface')
                            gui_component('MenuItem', jPopup, [], ['View ' mod{1} ' leadfield sensitivity'], IconLoader.ICON_ANATOMY, [], @(h,ev)bst_call(@view_leadfield_sensitivity, filenameRelative, mod{1}, 'Surface'));
                        end
                    end
                end
                % Copy to other conditions/subjects 
                if ~bst_get('ReadOnly')
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Copy to other folders', IconLoader.ICON_HEADMODEL, [], @(h,ev)db_set_headmodel(filenameRelative, 'AllConditions'));
                    gui_component('MenuItem', jPopup, [], 'Copy to other subjects', IconLoader.ICON_HEADMODEL, [], @(h,ev)db_set_headmodel(filenameRelative, 'AllSubjects'));
                end
                
                
%% ===== POPUP: DATA =====
            case {'data', 'rawdata'}
                % Get study description
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                iData = bstNodes(1).getItemIndex();
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                % Data type
                DataType = sStudy.Data(iData).DataType;
                isStat = ~strcmpi(DataType, 'recordings') && ~strcmpi(DataType, 'raw');
                % Get modalities for first selected file
                [AllMod, DisplayMod] = bst_get('ChannelModalities', filenameRelative);
                % Remove EDF Annotation channels from the list
                % iEDF = find(strcmpi(AllMod, 'EDF') | strcmpi(AllMod, 'BDF'));
                iEDF = find(strcmpi(AllMod, 'EDF'));
                if ~isempty(iEDF)
                    AllMod(iEDF) = [];
                end
                % Add iEEG when SEEG+ECOG 
                if ~isempty(AllMod) && all(ismember({'SEEG','ECOG'}, AllMod))
                    AllMod = cat(2, {'ECOG+SEEG'}, AllMod);
                end
                if ~isempty(DisplayMod) && all(ismember({'SEEG','ECOG'}, DisplayMod))
                    DisplayMod = cat(2, {'ECOG+SEEG'}, DisplayMod);
                end
                % Find anatomy volumes (exclude atlases)
                if ~isempty(sSubject.Anatomy)
                    iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                else
                    iVolAnat = [];
                end
                % One data file selected only
                if (length(bstNodes) == 1)
                    % RAW continuous files
                    if ~bst_get('ReadOnly') && ~isStat
                        % Import in database
                        gui_component('MenuItem', jPopup, [], 'Import in database', IconLoader.ICON_EEG_NEW, [], @(h,ev)import_raw_to_db(filenameRelative));
                        % Load file descriptor
                        ChannelFile = bst_get('ChannelFileForStudy', filenameRelative);
                        if ~isempty(ChannelFile) && strcmpi(DataType, 'raw')
                            Device = bst_get('ChannelDevice', ChannelFile);
                            ChannelMat_Comment = in_bst_channel(ChannelFile,'Comment');
                            % If CTF file format
                            if strcmpi(Device, 'CTF') || ~isempty(strfind(ChannelMat_Comment.Comment, 'CTF'))
                                gui_component('MenuItem', jPopup, [], 'Switch epoched/continous', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_process('CallProcess', 'process_ctf_convert', filenameFull, [], 'rectype', 3, 'interactive', 1));
                            elseif ~isempty(strfind(ChannelMat_Comment.Comment, 'NWB')) % Check for NWB file format
                                gui_component('MenuItem', jPopup, [], 'Switch epoched/continous', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_process('CallProcess', 'process_nwb_convert', filenameFull, [], 'rectype', 3, 'interactive', 1, 'ChannelFile', ChannelFile));
                            end
                        end
                        % Separator
                        AddSeparator(jPopup);
                    end
                    % If some modalities defined
                    if ~isempty(AllMod)
                        % For each modality, display a menu
                        for iMod = 1:length(AllMod)
                            % Make the sensor type more user-friendly
                            channelTypeDisplay = getChannelTypeDisplay(AllMod{iMod}, AllMod);
                            % Create the menu
                            jMenuModality = gui_component('Menu', jPopup, [], channelTypeDisplay, IconLoader.ICON_DATA, [], []);
                            % === DISPLAY TIME SERIES ===
                            gui_component('MenuItem', jMenuModality, [], 'Display time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)bst_call(@view_timeseries, filenameRelative, AllMod{iMod}, [], 'NewFigure'));
                            gui_component('MenuItem', jMenuModality, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(filenameRelative, 'trialimage', AllMod{iMod}));
                            % == DISPLAY TOPOGRAPHY ==
                            if ismember(AllMod{iMod}, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'}) && ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                if ~isStat
                                    fcnPopupDisplayTopography(jMenuModality, filenameRelative, AllMod, AllMod{iMod}, isStat);
                                elseif ~(strcmpi(AllMod{iMod}, 'MEG') && all(ismember({'MEG MAG', 'MEG GRAD'}, AllMod)))
                                    fcnPopupTopoNoInterp(jMenuModality, filenameRelative, AllMod(iMod), 0, 0, 0);
                                end
                            elseif ismember(AllMod{iMod}, {'ECOG','SEEG','ECOG+SEEG'})
                                AddSeparator(jMenuModality);
                                gui_component('MenuItem', jMenuModality, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, filenameRelative, AllMod{iMod}, '2DLayout'));
                                gui_component('MenuItem', jMenuModality, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, filenameRelative, AllMod{iMod}, '2DElectrodes'));
                            end
                            % === DISPLAY ON SCALP ===
                            % => ONLY for EEG, and if a scalp is defined
                            if strcmpi(AllMod{iMod}, 'EEG') && ~isempty(sSubject) && ~isempty(sSubject.iScalp) && ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                AddSeparator(jMenuModality);
                                gui_component('MenuItem', jMenuModality, [], 'Display on scalp', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iScalp).FileName, filenameRelative, AllMod{iMod}));
                            end
                            % === DISPLAY ON CORTEX/MRI ===
                            % => ONLY for SEEG/ECOG, and if a cortex/MRI is defined
                            if ismember(AllMod{iMod}, {'SEEG','ECOG','ECOG+SEEG'}) && ~isempty(sSubject) && ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                AddSeparator(jMenuModality);
                                if ~isempty(sSubject.iCortex)
                                    gui_component('MenuItem', jMenuModality, [], 'Display on cortex', IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, filenameRelative, AllMod{iMod}));
                                end
                                if (length(iVolAnat) == 1)
                                    gui_component('MenuItem', jMenuModality, [], 'Display on MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, AllMod{iMod}));
                                    gui_component('MenuItem', jMenuModality, [], 'Display on MRI (3D)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, AllMod{iMod}));
                                elseif (length(iVolAnat) > 1)
                                    for iAnat = 1:length(iVolAnat)
                                        gui_component('MenuItem', jMenuModality, [], ['Display on MRI (MRI Viewer): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, AllMod{iMod}));
                                    end
                                    for iAnat = 1:length(iVolAnat)
                                        gui_component('MenuItem', jMenuModality, [], ['Display on MRI (3D): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, AllMod{iMod}));
                                    end
                                end
                            end
                        end
                                                
                        % === GOOD/BAD CHANNELS===
                        if ~bst_get('ReadOnly')
                            % MENU
                            jPopupMenuGoodBad = fcnPopupMenuGoodBad();
                            AddSeparator(jPopupMenuGoodBad);
                            % EDIT GOOD/BAD
                            gui_component('MenuItem', jPopupMenuGoodBad, [], 'Edit good/bad channels...', IconLoader.ICON_GOODBAD, [], @(h,ev)gui_edit_channelflag(filenameRelative));
                            % === GOOD/BAD TRIAL ===
                            if strcmpi(DataType, 'recordings')
                                if (bstNodes(1).getModifier() == 0)
                                    gui_component('MenuItem', jPopup, [], 'Reject trial', IconLoader.ICON_BAD, [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 1));
                                else
                                    gui_component('MenuItem', jPopup, [], 'Accept trial', IconLoader.ICON_GOOD, [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 0));
                                end
                            end
                        end
                    % Cannot access channel file => plot raw Data.F matrix
                    else
                        % === WARNING: NO CHANNEL ===
                        gui_component('MenuItem', jPopup, [], 'No channel file', IconLoader.ICON_WARNING, [], []);
                        AddSeparator(jPopup);
                        % === DISPLAY TIME SERIES ===
                        if ~strcmpi(DataType, 'raw')
                            gui_component('MenuItem', jPopup, [], 'Display time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(filenameRelative));
                        end
                    end
                    % === MENU: SET NUMBER OF TRIALS ===
                    if ~bst_get('ReadOnly') && strcmpi(DataType, 'recordings')
                        gui_component('MenuItem', jPopup, [], 'Set number of trials', IconLoader.ICON_DATA_LIST, [], @(h,ev)SetNavgData(filenameFull));
                    end
                    % === MENU: REVIEW AS RAW
                    if ~strcmpi(DataType, 'raw')
                        gui_component('MenuItem', jPopup, [], 'Review as raw', IconLoader.ICON_RAW_DATA, [], @(h,ev)import_raw(filenameFull, 'BST-DATA', iSubject));
                    end
                else
                    % Display of multiple files
                    if ~isempty(AllMod)
                        % === TIME SERIES / ERP IMAGE ===
                        jMenuTs = gui_component('Menu', jPopup, [], 'Display time series', IconLoader.ICON_TS_DISPLAY, [], []);
                        jMenuErp = gui_component('Menu', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], []);
                        % For each modality, display a menu
                        for iMod = 1:length(AllMod)
                            channelTypeDisplay = getChannelTypeDisplay(AllMod{iMod}, AllMod);
                            DataFilenames = GetAllFilenames(bstNodes, 'data');
                            gui_component('MenuItem', jMenuTs, [], channelTypeDisplay, IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(DataFilenames, AllMod{iMod}, [], 'NewFigure'));
                            gui_component('MenuItem', jMenuErp, [], channelTypeDisplay, IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(DataFilenames, 'erpimage', AllMod{iMod}));
                        end
                        % === 2DLAYOUT ===
                        mod2D = intersect(DisplayMod, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'});
                        if (length(mod2D) == 1)
                            channelTypeDisplay = getChannelTypeDisplay(mod2D{1}, AllMod);
                            gui_component('MenuItem', jPopup, [], ['2D Layout: ' channelTypeDisplay], IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'data', 1, 0), mod2D{1}, '2DLayout'));
                        elseif (length(mod2D) > 1)
                            jMenu2d = gui_component('Menu', jPopup, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], []);
                            for iMod = 1:length(mod2D)
                                channelTypeDisplay = getChannelTypeDisplay(mod2D{iMod}, AllMod);
                                gui_component('MenuItem', jMenu2d, [], channelTypeDisplay, IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'data', 1, 0), mod2D{iMod}, '2DLayout'));
                            end
                        end
                        AddSeparator(jPopup);
                    end
                    
                    % Good/bad channels
                    fcnPopupMenuGoodBad();
                    AddSeparator(jPopup);
                    % === GOOD/BAD TRIAL ===
                    if ~bst_get('ReadOnly') && strcmpi(DataType, 'recordings')
                        gui_component('MenuItem', jPopup, [], 'Reject trials', IconLoader.ICON_BAD,  [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 1));
                        gui_component('MenuItem', jPopup, [], 'Accept trials', IconLoader.ICON_GOOD, [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 0));
                    end
                end
                % === MENU: EXPORT ===
                jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_data, GetAllFilenames(bstNodes)));

                % === VIEW CLUSTERS ===
                if ~isempty(AllMod)
                    fcnPopupClusterTimeSeries();
                end

                % INVERSE SOLUTIONS
                if ~bst_get('ReadOnly') && ~isempty(AllMod) && ismember(DataType, {'raw', 'recordings'})
                    % Get subject and inter-subject study
                    [sInterStudy, iInterStudy] = bst_get('AnalysisInterStudy');
                    % === COMPUTE SOURCES ===
                    % If not Default Channel
                    if (sSubject.UseDefaultChannel == 0) && (iStudy ~= iInterStudy)
                        fcnPopupComputeHeadmodel();
                    else
                        AddSeparator(jPopup);    
                    end
                    if strcmpi(DataType, 'recordings') || (length(bstNodes) == 1)
                        fncPopupMenuNoiseCov(1);
                    end
                    fcnPopupComputeSources();
                    fcnPopupProjectSources(0);
                    fcnPopupScoutTimeSeries(jPopup);
                end
               
%% ===== POPUP: STAT/DATA =====
            case 'pdata'
                % Get protocol description
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                % Get avaible modalities for this data file
                [AllMod, DisplayMod] = bst_get('ChannelModalities', filenameRelative);
                % One data file selected only
                if (length(bstNodes) == 1)
                    % === VIEW RESULTS ===
                    % Get associated subject and surfaces, if it exists
                    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                    % If channel file is defined and at least one modality
                    if ~isempty(AllMod)
                        % For each modality, display a menu
                        for iMod = 1:length(AllMod)
                            % Make the sensor type more user-friendly
                            channelTypeDisplay = getChannelTypeDisplay(AllMod{iMod}, AllMod);
                            % Create menu
                            jMenuModality = gui_component('Menu', jPopup, [], channelTypeDisplay, IconLoader.ICON_DATA, [], []);
                            % === DISPLAY TIME SERIES ===
                            gui_component('MenuItem', jMenuModality, [], 'Display time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(filenameRelative, AllMod{iMod}));
                            gui_component('MenuItem', jMenuModality, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(filenameRelative, 'trialimage', AllMod{iMod}));
                            % == DISPLAY TOPOGRAPHY ==
                            if ismember(AllMod{iMod}, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'}) && ...
                                ~(strcmpi(AllMod{iMod}, 'MEG') && all(ismember({'MEG MAG', 'MEG GRAD'}, AllMod))) && ...
                                ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                %fcnPopupDisplayTopography(jMenuModality, filenameRelative, AllMod, AllMod{iMod}, 1);
                                fcnPopupTopoNoInterp(jMenuModality, filenameRelative, AllMod(iMod), 1, 0, 0);
                            elseif ismember(AllMod{iMod}, {'ECOG','SEEG','ECOG+SEEG'})
                                AddSeparator(jMenuModality);
                                gui_component('MenuItem', jMenuModality, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, filenameRelative, AllMod{iMod}, '2DLayout'));
                                gui_component('MenuItem', jMenuModality, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, filenameRelative, AllMod{iMod}, '2DElectrodes'));
                            end
                            % === DISPLAY ON SCALP ===
                            if strcmpi(AllMod{iMod}, 'EEG') && ~isempty(sSubject) && ~isempty(sSubject.iScalp) && ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                AddSeparator(jMenuModality);
                                gui_component('MenuItem', jMenuModality, [], 'Display on scalp', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iScalp).FileName, filenameRelative, AllMod{iMod}));
                            end
                            % === DISPLAY ON CORTEX ===
                            % => ONLY for SEEG/ECOG, and if a cortex is defined
                            if ismember(AllMod{iMod}, {'SEEG','ECOG','ECOG+SEEG'}) && ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isempty(DisplayMod) && ismember(AllMod{iMod}, DisplayMod)
                                AddSeparator(jMenuModality);
                                gui_component('MenuItem', jMenuModality, [], 'Display on cortex', IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, filenameRelative, AllMod{iMod}));
                            end
                        end
                        
                        % === STAT CLUSTERS ===
                        if ~isempty(strfind(filenameRelative, '_cluster'))
                            AddSeparator(jPopup);
                            jMenuCluster = gui_component('Menu', jPopup, [], 'Significant clusters', IconLoader.ICON_ATLAS, [], []);
                            gui_component('MenuItem', jMenuCluster, [], 'Cluster indices',   IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_statcluster(filenameRelative, 'clustindex_time', []));
                            gui_component('MenuItem', jMenuCluster, [], 'Cluster size', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_statcluster(filenameRelative, 'clustsize_time', []));
                            % Modality menus
                            topoMod = intersect(DisplayMod,{'MEG','MEG GRAD','MEG MAG','EEG','ECOG','SEEG','ECOG+SEEG','NIRS'});
                            if (length(topoMod) > 1)
                                jMenuModality = gui_component('Menu', jMenuCluster, [], 'Longest significance', IconLoader.ICON_TOPOGRAPHY, [], []);
                                for iMod = 1:length(topoMod)
                                    channelTypeDisplay = getChannelTypeDisplay(topoMod{iMod}, topoMod);
                                    gui_component('MenuItem', jMenuModality, [], channelTypeDisplay, IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_statcluster(filenameRelative, 'longest', topoMod{iMod}));
                                end
                            elseif (length(topoMod) == 1)
                                gui_component('MenuItem', jMenuCluster, [], 'Longest significance', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_statcluster(filenameRelative, 'longest', topoMod{1}));
                            end
                        end
                        % === VIEW CLUSTERS ===
                        fcnPopupClusterTimeSeries();
                        
                        % === GOOD/BAD CHANNELS===
                        if ~bst_get('ReadOnly') && (length(bstNodes) == 1)
                            % MENU
                            jPopupMenuGoodBad = fcnPopupMenuGoodBad();
                            AddSeparator(jPopupMenuGoodBad);
                            % EDIT GOOD/BAD
                            gui_component('MenuItem', jPopupMenuGoodBad, [], 'Edit good/bad channels...', IconLoader.ICON_GOODBAD, [], @(h,ev)gui_edit_channelflag(filenameRelative));
                        end
                    % Cannot access channel file => plot raw Data.F matrix
                    else
                        % === WARNING: NO CHANNEL ===
                        gui_component('MenuItem', jPopup, [], 'No channel file', IconLoader.ICON_WARNING, [], []);
                        AddSeparator(jPopup);
                        % === DISPLAY TIME SERIES ===
                        gui_component('MenuItem', jPopup, [], 'Display time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(filenameRelative));
                    end
                else
                    % === 2DLAYOUT ===
                    mod2D = intersect(DisplayMod, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'});
                    if (length(mod2D) == 1)
                        channelTypeDisplay = getChannelTypeDisplay(mod2D{1}, AllMod);
                        gui_component('MenuItem', jPopup, [], ['2D Layout: ' channelTypeDisplay], IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'pdata', 1, 0), mod2D{1}, '2DLayout'));
                    elseif (length(mod2D) > 1)
                        jMenu2d = gui_component('Menu', jPopup, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], []);
                        for iMod = 1:length(mod2D)
                            channelTypeDisplay = getChannelTypeDisplay(mod2D{iMod}, AllMod);
                            gui_component('MenuItem', jMenu2d, [], channelTypeDisplay, IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'pdata', 1, 0), mod2D{iMod}, '2DLayout'));
                        end
                    end
                end

                
%% ===== POPUP: DATA LIST =====
            case 'datalist'                
                if ~bst_get('ReadOnly')
                    % Get protocol description
                    iStudy = bstNodes(1).getStudyIndex();
                    sStudy = bst_get('Study', iStudy);
                    % Get avaible modalities for these data files
                    [AllMod, DisplayMod] = bst_get('ChannelModalities', sStudy.Data(1).FileName);
                    if ~isempty(AllMod)
                        % === ERP IMAGE ===
                        jMenuErp = gui_component('Menu', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], []);
                        % For each modality, display a menu
                        for iMod = 1:length(AllMod)
                            channelTypeDisplay = getChannelTypeDisplay(AllMod{iMod}, AllMod);
                            gui_component('MenuItem', jMenuErp, [], channelTypeDisplay, IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(GetAllFilenames(bstNodes, 'data'), 'erpimage', AllMod{iMod}));
                        end
                        % === 2DLAYOUT ===
                        mod2D = intersect(DisplayMod, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'});
                        if (length(mod2D) == 1)
                            channelTypeDisplay = getChannelTypeDisplay(mod2D{1}, AllMod);
                            gui_component('MenuItem', jPopup, [], ['2D Layout: ' channelTypeDisplay], IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'data', 1, 0), mod2D{1}, '2DLayout'));
                        elseif (length(mod2D) > 1)
                            jMenu2d = gui_component('Menu', jPopup, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], []);
                            for iMod = 1:length(mod2D)
                                channelTypeDisplay = getChannelTypeDisplay(mod2D{iMod}, AllMod);
                                gui_component('MenuItem', jMenu2d, [], channelTypeDisplay, IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes, 'data', 1, 0), mod2D{iMod}, '2DLayout'));
                            end
                        end
                        AddSeparator(jPopup);
                    end

                    % Good/bad channels
                    fcnPopupMenuGoodBad();
                    fcnPopupClusterTimeSeries();
                    AddSeparator(jPopup);
                    % Good/bad trials
                    gui_component('MenuItem', jPopup, [], 'Reject trials', IconLoader.ICON_BAD,  [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 1));
                    gui_component('MenuItem', jPopup, [], 'Accept trials', IconLoader.ICON_GOOD, [], @(h,ev)process_detectbad('SetTrialStatus', bstNodes, 0));
                    AddSeparator(jPopup);
                    % === NOISE COVARIANCE ===
                    fncPopupMenuNoiseCov(1);
                    % === MENU: EXPORT ===
                    jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)export_data(GetAllFilenames(bstNodes, 'data')));
                    fcnPopupScoutTimeSeries(jPopup);
                end
                
%% ===== POPUP: RESULTS =====
            case {'results', 'link'}
                isLink = strcmpi(nodeType, 'link');
                % Get study
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                iResult = bstNodes(1).getItemIndex();
                % Get associated subject
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                % FOR FIRST NODE: Get associated recordings (DataFile)
                DataFile = sStudy.Result(iResult).DataFile;
                isStat = ~isempty(strfind(filenameRelative, '_pthresh'));
                % Get type of data node
                isRaw = 0;
                if ~isempty(DataFile)
                    [tmp__, tmp__, iData] = bst_get('DataFile', DataFile, iStudy);
                    if ~isempty(iData)
                        isRaw = strcmpi(sStudy.Data(iData).DataType, 'raw');
                    end
                end
                
                % IF NOT A STAND-ALONE KERNEL-ONLY RESULTS NODE
                % === MENU: CORTICAL ACTIVATIONS ===
                jMenuActivations = gui_component('Menu', jPopup, [], 'Cortical activations', IconLoader.ICON_RESULTS, [], []);

                % ONE RESULTS FILE SELECTED
                if (length(bstNodes) == 1)
                    % === DISPLAY ON CORTEX ===
                    if ismember(sStudy.Result(iResult).HeadModelType, {'surface', 'mixed'})
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex)
                            gui_component('MenuItem', jMenuActivations, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                        else
                            gui_component('MenuItem', jMenuActivations, [], 'No cortex available', IconLoader.ICON_WARNING, [], []);
                        end
                    end
                    % === DISPLAY ON MRI ===
                    % Find anatomy volumes (exclude atlases)
                    if ~isempty(sSubject.Anatomy)
                        iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                    else
                        iVolAnat = [];
                    end
                    if (length(iVolAnat) == 1)
                        gui_component('MenuItem', jMenuActivations, [], 'Display on MRI (3D)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative));
                        gui_component('MenuItem', jMenuActivations, [], 'Display on MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative));
                    elseif (length(iVolAnat) > 1)
                        for iAnat = 1:length(iVolAnat)
                            gui_component('MenuItem', jMenuActivations, [], ['Display on MRI (3D): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative));
                        end
                        for iAnat = 1:length(iVolAnat)
                            gui_component('MenuItem', jMenuActivations, [], ['Display on MRI (MRI Viewer): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative));
                        end
                    end
                    % === DISPLAY ON SPHERE ===
                    if strcmpi(sStudy.Result(iResult).HeadModelType, 'surface') && ~isempty(sSubject) && ~isempty(sSubject.iCortex)
                        AddSeparator(jMenuActivations);
                        gui_component('MenuItem', jMenuActivations, [], 'Display on spheres/squares', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'orig'));
                        gui_component('MenuItem', jMenuActivations, [], '2D projection (Mollweide)', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'mollweide'));
                    end
                end

                % === VIEW SCOUTS ===
                fcnPopupScoutTimeSeries(jMenuActivations, 1);

                % === MENU: SIMULATE DATA ===
                [tmp__, iDefStudy]   = bst_get('DefaultStudy', iSubject);
                if ~bst_get('ReadOnly') && ~isRaw && ~ismember(iStudy, iDefStudy) && ~isStat    % && ~isempty(strfind(filenameRelative, '_wMNE')) && ~strcmpi(sStudy.Result(iResult).HeadModelType, 'mixed')
                    jMenuModality = gui_component('Menu', jPopup, [], 'Model evaluation', IconLoader.ICON_RESULTS, [], []);
                    gui_component('MenuItem', jMenuModality, [], 'Simulate recordings', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)bst_simulation(filenameRelative));
                    if ~isempty(DataFile)
                        gui_component('MenuItem', jMenuModality, [], 'Save whitened recordings', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)SaveWhitenedData(filenameRelative));
                    end
                end
                
                % === VIEW BAD CHANNELS ===
                if ~isStat
                    gui_component('MenuItem', jPopup, [], 'View bad channels', IconLoader.ICON_BAD, [], @(h,ev)tree_set_channelflag(bstNodes, 'ShowBad'));
                end
                
                % === PROJECT ON DEFAULT ANATOMY ===
                % If subject does not use default anatomy
                if ~bst_get('ReadOnly') && ~isRaw % && ismember(sStudy.Result(iResult).HeadModelType, {'surface','volume'})
                    fcnPopupProjectSources(1);
                end
                
                % === PLUG-INS ===
                if ~bst_get('ReadOnly') && ~isRaw && ~isLink && (length(bstNodes) == 1) && ~isStat
                    AddSeparator(jPopup);
                    jMenuPlugins = gui_component('Menu', jPopup, [], 'Plug-ins', IconLoader.ICON_CONDITION, [], []);
                        % === OPTICAL FLOW ===
                        if (sSubject.iCortex)
                            gui_component('MenuItem', jMenuPlugins, [], '[Experimental] Optical flow', IconLoader.ICON_CONDITION, [], @(h,ev)panel_opticalflow('Compute', filenameRelative));
                        end
                end
                
                % === MENU: EXPORT ===
                % Added later...
                jMenuExport{1} = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_result, filenameFull));
                if ~isRaw && (length(bstNodes) == 1)
                    jMenuExport{2} = gui_component('MenuItem', [], [], 'Export as 4D matrix', IconLoader.ICON_SAVE, [], @(h,ev)panel_process_select('ShowPanelForFile', {filenameFull}, 'process_export_spmvol'));
%                     if ~isVolumeGrid
%                         jMenuExport{3} = gui_component('MenuItem', [], [], 'Export to SPM12', IconLoader.ICON_SAVE, [], @(h,ev)panel_process_select('ShowPanelForFile', {filenameFull}, 'process_export_spmsurf'));
%                     end
                end

                
%% ===== POPUP: SHARED RESULTS KERNEL =====
            case 'kernel'
                gui_component('MenuItem', jPopup, [], 'Inversion kernel', IconLoader.ICON_WARNING, [], []);
                
                
%% ===== POPUP: STAT/RESULTS =====
            case 'presults'
                % ONE RESULTS FILE SELECTED
                if (length(bstNodes) == 1)
                    % Get study
                    iStudy = bstNodes(1).getStudyIndex();
                    sStudy = bst_get('Study', iStudy);
                    % Get associated subject and surfaces, if it exists
                    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                    isVolumeGrid = ~isempty(strfind(filenameRelative, '_volume_'));

                    % === MENU: CORTICAL ACTIVATIONS ===
                    jMenuActivations = gui_component('Menu', jPopup, [], 'Cortical activations', IconLoader.ICON_RESULTS, [], []);
                        % === DISPLAY ON CORTEX ===
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolumeGrid
                            gui_component('MenuItem', jMenuActivations, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                        end
                        % === DISPLAY ON MRI ===
                        % Find anatomy volumes (exclude atlases)
                        if ~isempty(sSubject.Anatomy)
                            iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                        else
                            iVolAnat = [];
                        end
                        if (length(iVolAnat) == 1)
                            gui_component('MenuItem', jMenuActivations, [], 'Display on MRI (3D)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative));
                            gui_component('MenuItem', jMenuActivations, [], 'Display on MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative));
                        elseif (length(iVolAnat) > 1)
                            for iAnat = 1:length(iVolAnat)
                                gui_component('MenuItem', jMenuActivations, [], ['Display on MRI (3D): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative));
                            end
                            for iAnat = 1:length(iVolAnat)
                                gui_component('MenuItem', jMenuActivations, [], ['Display on MRI (MRI Viewer): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative));
                            end
                        end
                        % === DISPLAY ON SPHERE ===
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolumeGrid
                            AddSeparator(jMenuActivations);
                            gui_component('MenuItem', jMenuActivations, [], 'Display on spheres/squares', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'orig'));
                            gui_component('MenuItem', jMenuActivations, [], '2D projection (Mollweide)', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'mollweide'));
                        end
                    % === STAT CLUSTERS ===
                    if ~isempty(strfind(filenameRelative, '_cluster'))
                        jMenuCluster = gui_component('Menu', jPopup, [], 'Significant clusters', IconLoader.ICON_ATLAS, [], []);
                        gui_component('MenuItem', jMenuCluster, [], 'Cluster size', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_statcluster(filenameRelative, 'clustsize_time', []));
                        gui_component('MenuItem', jMenuCluster, [], 'Longest significance', IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)view_statcluster(filenameRelative, 'longest'));
                    end
                    % === MENU: EXPORT ===
                    % Added later...
                    jMenuExport{1} = gui_component('MenuItem', [], [], 'Export as 4D matrix', IconLoader.ICON_SAVE, [], @(h,ev)panel_process_select('ShowPanelForFile', {filenameFull}, 'process_export_spmvol'));

                end
                % === VIEW SCOUTS ===
                fcnPopupScoutTimeSeries(jMenuActivations, 1);

                
                
%% ===== POPUP: DIPOLES =====
            case 'dipoles'
                % Get subject structure
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                % ONE DIPOLES FILE SELECTED
                if (length(bstNodes) == 1)
                    gui_component('MenuItem', jPopup, [], 'Display on MRI (3D)', IconLoader.ICON_DIPOLES, [], @(h,ev)view_dipoles(filenameRelative, 'Mri3D'));
                    gui_component('MenuItem', jPopup, [], 'Display on cortex',   IconLoader.ICON_DIPOLES, [], @(h,ev)view_dipoles(filenameRelative, 'Cortex'));
                    AddSeparator(jPopup);
                    gui_component('MenuItem', jPopup, [], 'Display density in MRI Viewer', IconLoader.ICON_DIPOLES, [], @(h,ev)view_dipoles(filenameRelative, 'MriViewer'));
                elseif ~bst_get('ReadOnly')
                    gui_component('MenuItem', jPopup, [], 'Merge dipoles', IconLoader.ICON_DIPOLES, [], @(h,ev)dipoles_merge(GetAllFilenames(bstNodes)));
                end
                % PROJECT DIPOLES
                if ~bst_get('ReadOnly')
                    AddSeparator(jPopup);
                    if (iSubject ~= 0) && ~sSubject.UseDefaultAnat
                        gui_component('MenuItem', jPopup, [], 'Project to default anatomy', IconLoader.ICON_PROJECT_ELECTRODES, [], @(h,ev)bst_project_dipoles(GetAllFilenames(bstNodes), 0));
                    end
                end

%% ===== POPUP: SPIKE =====
            case 'spike'
                gui_component('MenuItem', jPopup, [], 'Supervised spike sorting', IconLoader.ICON_SPIKE_SORTING, [], @(h,ev)panel_spikes('OpenSpikeFile', filenameRelative));

%% ===== POPUP: TIME-FREQ =====
            case {'timefreq', 'ptimefreq'}
                % Get study description
                iStudy    = bstNodes(1).getStudyIndex();
                iTimefreq = bstNodes(1).getItemIndex();
                sStudy    = bst_get('Study', iStudy);
                sSubject  = bst_get('Subject', sStudy.BrainStormSubject);
                DisplayMod= {};
                % Get data type
                isStat = strcmpi(char(bstNodes(1).getType()), 'ptimefreq');
                if isStat
                    TimefreqMat = in_bst_timefreq(filenameRelative, 0, 'DataType', 'Time');
                    if ~isempty(TimefreqMat.DataType)
                        DataType = TimefreqMat.DataType;
                    else
                        DataType = 'matrix';
                    end
                    DataFile = [];
                else
                    DataType = sStudy.Timefreq(iTimefreq).DataType;
                    DataFile = sStudy.Timefreq(iTimefreq).DataFile;
                end
                % Get source model
                if strcmpi(DataType, 'results')
                    % Get head model type for the sources file
                    if ~isempty(DataFile)
                        [sStudyData, iStudyData, iResult] = bst_get('AnyFile', DataFile);
                        if ~isempty(sStudyData)
                            isVolume = strcmpi(sStudyData.Result(iResult).HeadModelType, 'volume');
                        else
                            disp('BST> Error: This file was linked to a source file that was deleted.');
                            isVolume = 0;
                        end
                    % Else, read from the file if there is a GridLoc field
                    else
                        wloc    = whos('-file', filenameFull, 'GridLoc');
                        worient = whos('-file', filenameFull, 'GridAtlas');
                        isVolume = (prod(wloc.size) > 0) && (isempty(worient) || (prod(worient.size) == 0));
                    end
                % Get available modalities for this data file
                elseif strcmpi(DataType, 'data')
                    DisplayMod = bst_get('TimefreqDisplayModalities', filenameRelative);
                    % Add SEEG+ECOG 
                    if ~isempty(DisplayMod) && all(ismember({'SEEG','ECOG'}, DisplayMod))
                        DisplayMod = cat(2, {'ECOG+SEEG'}, DisplayMod);
                    end
                end
                % One file selected
                if (length(bstNodes) == 1)
                    % ===== CONNECTIVITY =====
                    if ~isempty(strfind(filenameRelative, '_connectn')) || ~isempty(strfind(filenameRelative, '_connect1'))
                        % Time defined Connectivity file or Stat Connectivity file
                        if isStat
                            cnxTimeDef = length(TimefreqMat.Time) > 1;
                        else
                            cnxTimeDef = ~isempty(strfind(sStudy.Timefreq(iTimefreq).Comment, '-time'));
                        end
                        % [NxN] only
                        if ~isempty(strfind(filenameRelative, '_connectn'))                           
                            gui_component('MenuItem', jPopup, [], 'Display as graph [NxN]',   IconLoader.ICON_CONNECTN, [], @(h,ev)view_connect(filenameRelative, 'GraphFull'));                               
                            gui_component('MenuItem', jPopup, [], 'Display as image [NxN]', IconLoader.ICON_NOISECOV, [], @(h,ev)view_connect(filenameRelative, 'Image'));
                            if ~isempty(sSubject) && isfield(sSubject, 'iFibers') && ~isempty(sSubject.iFibers)
                                gui_component('MenuItem', jPopup, [], 'Display fibers [experimental]',   IconLoader.ICON_FIBERS, [], @(h,ev)view_connect(filenameRelative, 'Fibers'));
                            end
                            jMenuConn1 = gui_component('Menu', [], [], 'Connectivity  [NxN]', IconLoader.ICON_CONNECTN, [], []);
                        else
                            jMenuConn1 = jPopup;
                        end
                        % Depending on the datatype
                        switch lower(DataType)
                            case 'data'
                                if ~isempty(strfind(filenameRelative, '_cohere')) || ~isempty(strfind(filenameRelative, '_spgranger'))  || ~isempty(strfind(filenameRelative, '_henv')) || ~isempty(strfind(filenameRelative, '_pte')) ...
                                        || ~isempty(strfind(filenameRelative, '_plv')) || ~isempty(strfind(filenameRelative, '_wpli')) || ~isempty(strfind(filenameRelative, '_ciplv')) ...
                                        || ~isempty(strfind(filenameRelative, '_plvt')) || ~isempty(strfind(filenameRelative, '_wplit')) || ~isempty(strfind(filenameRelative, '_ciplvt'))
                                    gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                                end
                                if ~isempty(strfind(filenameRelative, '_plvt')) || ~isempty(strfind(filenameRelative, '_corr_time')) || ~isempty(strfind(filenameRelative, '_cohere_time')) ...
                                        || ~isempty(strfind(filenameRelative, '_wplit')) || ~isempty(strfind(filenameRelative, '_ciplvt')) ...
                                        || (cnxTimeDef && (~isempty(strfind(filenameRelative, '_corr')) || ~isempty(strfind(filenameRelative, '_cohere'))))
                                    gui_component('MenuItem', jPopup,     [], 'Time series', IconLoader.ICON_DATA,     [], @(h,ev)view_spectrum(filenameRelative, 'TimeSeries'));
                                    gui_component('MenuItem', jMenuConn1, [], 'One row',     IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                    gui_component('MenuItem', jMenuConn1, [], 'All rows',    IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'AllSensors'));
                                end
                                if isempty(strfind(filenameRelative, '_connectn'))
                                    gui_component('MenuItem', jMenuConn1, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_connect(filenameRelative, 'Image'));
                                end
                                if (length(jMenuConn1.getSubElements()) > 0)
                                    AddSeparator(jMenuConn1);
                                end
                                % Topography
                                if ~isempty(DisplayMod)
                                    fcnPopupTopoNoInterp(jMenuConn1, filenameRelative, DisplayMod, 0, 0, 0);
                                end
                            case 'results'
                                % One channel
                                if ~isempty(strfind(filenameRelative, '_plvt')) || ~isempty(strfind(filenameRelative, '_corr_time')) || ~isempty(strfind(filenameRelative, '_cohere_time'))...
                                        || ~isempty(strfind(filenameRelative, '_wplit')) || ~isempty(strfind(filenameRelative, '_ciplvt')) ...
                                        || (cnxTimeDef && (~isempty(strfind(filenameRelative, '_corr')) || ~isempty(strfind(filenameRelative, '_cohere'))))
                                    gui_component('MenuItem', jMenuConn1, [], 'One channel', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                    AddSeparator(jMenuConn1);
                                end
                                % Cortex
                                if isempty(strfind(filenameRelative, '_connectn')) && ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                                    gui_component('MenuItem', jMenuConn1, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                                end
                                % MRI
                                if isempty(strfind(filenameRelative, '_connectn')) && ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                                    gui_component('MenuItem', jMenuConn1, [], 'Display on MRI   (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(MriFile, filenameRelative));
                                    gui_component('MenuItem', jMenuConn1, [], 'Display on MRI   (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                                end
                            otherwise
                                if ~isempty(strfind(filenameRelative, '_cohere')) || ~isempty(strfind(filenameRelative, '_spgranger')) || ~isempty(strfind(filenameRelative, '_henv')) || ~isempty(strfind(filenameRelative, '_pte')) ...
                                        || ~isempty(strfind(filenameRelative, '_plv')) || ~isempty(strfind(filenameRelative, '_wpli')) || ~isempty(strfind(filenameRelative, '_ciplv')) ...
                                        || ~isempty(strfind(filenameRelative, '_plvt')) || ~isempty(strfind(filenameRelative, '_wplit')) || ~isempty(strfind(filenameRelative, '_ciplvt'))
                                    gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                                end
                                if ~isempty(strfind(filenameRelative, '_plvt')) || ~isempty(strfind(filenameRelative, '_corr_time')) || ~isempty(strfind(filenameRelative, '_cohere_time')) ...
                                        || ~isempty(strfind(filenameRelative, '_wplit')) || ~isempty(strfind(filenameRelative, '_ciplvt')) ...
                                        || (cnxTimeDef && (~isempty(strfind(filenameRelative, '_corr')) || ~isempty(strfind(filenameRelative, '_cohere'))))
                                    gui_component('MenuItem', jPopup,     [], 'Time series', IconLoader.ICON_DATA,     [], @(h,ev)view_spectrum(filenameRelative, 'TimeSeries'));
                                    gui_component('MenuItem', jMenuConn1, [], 'One row',     IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                    gui_component('MenuItem', jMenuConn1, [], 'All rows',    IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'AllSensors'));
                                end
                                if isempty(strfind(filenameRelative, '_connectn'))
                                    gui_component('MenuItem', jMenuConn1, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_connect(filenameRelative, 'Image'));
                                end
                        end
                        % Add menu [1xN] if not empty
                        if ~isempty(strfind(filenameRelative, '_connectn')) && (length(jMenuConn1.getSubElements()) > 0)
                            AddSeparator(jPopup);
                            jPopup.add(jMenuConn1);
                        end
                        % Export to file
                        if strcmpi(nodeType, 'timefreq')
                            jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_timefreq, filenameFull));
                        end
                        
                    % ===== PAC: FULL MAPS =====
                    elseif ~isempty(strfind(filenameRelative, '_pac_fullmaps'))
                        if ~isStat
                            gui_component('MenuItem', jPopup, [], 'DirectPAC maps', IconLoader.ICON_PAC, [], @(h,ev)view_pac(filenameRelative));
                            AddSeparator(jPopup);
                            % Depending on the datatype
                            switch lower(DataType)
                                case 'data'
                                    % Topography
                                    fcnPopupTopoNoInterp(jPopup, filenameRelative, DisplayMod, 0, 0, 0);
                                case 'results'
                                    gui_component('MenuItem', jPopup, [], 'One channel', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                    AddSeparator(jPopup);
                                    % Cortex
                                    if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                                        gui_component('MenuItem', jPopup, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                                    end
                                    % MRI
                                    if ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                                        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                                        gui_component('MenuItem', jPopup, [], 'Display on MRI   (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(MriFile, filenameRelative));
                                        gui_component('MenuItem', jPopup, [], 'Display on MRI   (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                                    end
                                otherwise
                            end
                        end
                        
                    % ===== DPAC: FULL MAPS =====
                    elseif ~isempty(strfind(filenameRelative, '_dpac_fullmaps'))
                        if ~isStat
                            jMenuPac = gui_component('Menu', jPopup, [], 'DynamicPAC maps', IconLoader.ICON_PAC, [], []);
                                gui_component('MenuItem', jMenuPac, [], 'One channel', IconLoader.ICON_PAC, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', 'SingleSensor'));
                                if strcmpi(DataType, 'data') || strcmpi(DataType, 'matrix')
                                    gui_component('MenuItem', jMenuPac, [], 'All channels',   IconLoader.ICON_PAC,      [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', 'AllSensors'));
                                    gui_component('MenuItem', jMenuPac, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', 'Spectrum'));
                                    gui_component('MenuItem', jMenuPac, [], 'Time series',    IconLoader.ICON_DATA,     [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', 'TimeSeries'));
                                end
                                if strcmpi(DataType, 'data')
                                    AddSeparator(jMenuPac);
                                    gui_component('MenuItem', jMenuPac, [], '3D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', '3DSensorCap'));
                                    gui_component('MenuItem', jMenuPac, [], '2D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', '2DSensorCap'));
                                    gui_component('MenuItem', jMenuPac, [], '2D Disc',       IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicPAC', '2DDisc'));
                                end
                            jMenuPac = gui_component('Menu', jPopup, [], 'DynamicNesting maps', IconLoader.ICON_PAC, [], []);
                                gui_component('MenuItem', jMenuPac, [], 'One channel',  IconLoader.ICON_PAC, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', 'SingleSensor'));
                                if strcmpi(DataType, 'data') || strcmpi(DataType, 'matrix')
                                    gui_component('MenuItem', jMenuPac, [], 'All channels',   IconLoader.ICON_PAC,      [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', 'AllSensors'));
                                    gui_component('MenuItem', jMenuPac, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', 'Spectrum'));
                                    gui_component('MenuItem', jMenuPac, [], 'Time series',    IconLoader.ICON_DATA,     [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', 'TimeSeries'));
                                end
                                if strcmpi(DataType, 'data')
                                    AddSeparator(jMenuPac);
                                    gui_component('MenuItem', jMenuPac, [], '3D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', '3DSensorCap'));
                                    gui_component('MenuItem', jMenuPac, [], '2D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', '2DSensorCap'));
                                    gui_component('MenuItem', jMenuPac, [], '2D Disc',       IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)view_pac(filenameRelative, [], 'DynamicNesting', '2DDisc'));
                                end
                            AddSeparator(jPopup);
                            % Depending on the datatype
                            switch lower(DataType)
                                case 'data'
                                    % Topography
                                    fcnPopupTopoNoInterp(jPopup, filenameRelative, DisplayMod, 0, 0, 0);
                                case 'results'
                                    gui_component('MenuItem', jPopup, [], 'One channel', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                    AddSeparator(jPopup);
                                    % Cortex
                                    if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                                        gui_component('MenuItem', jPopup, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                                    end
                                    % MRI
                                    if ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                                        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                                        gui_component('MenuItem', jPopup, [], 'Display on MRI   (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(MriFile, filenameRelative));
                                        gui_component('MenuItem', jPopup, [], 'Display on MRI   (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                                    end
                                otherwise
                            end
                        end
                        
                    % ===== TIME-FREQUENCY =====
                    else
                        % Depending on the datatype
                        switch lower(DataType)
                            case 'data'
                                gui_component('MenuItem', jPopup, [], 'One channel',            IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                gui_component('MenuItem', jPopup, [], 'All channels',           IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'AllSensors'));
                                gui_component('MenuItem', jPopup, [], '2D Layout (maps)',       IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, '2DLayout'));
                                gui_component('MenuItem', jPopup, [], '2D Layout (no overlap)', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, '2DLayoutOpt'));
                                AddSeparator(jPopup);
                                gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                                gui_component('MenuItem', jPopup, [], 'Time series',    IconLoader.ICON_DATA,     [], @(h,ev)view_spectrum(filenameRelative, 'TimeSeries'));
                                gui_component('MenuItem', jPopup, [], 'Image [channels x time]', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(filenameRelative, 'trialimage'));
                                AddSeparator(jPopup);
                                % Topography
                                if ~isempty(DisplayMod)
                                    jSubMenus = fcnPopupTopoNoInterp(jPopup, filenameRelative, DisplayMod, 1, 1, 0);
                                    % Interpolate SEEG/ECOG on the anatomy
                                    for iMod = 1:length(DisplayMod)
                                        % Create submenu if there are multiple modalities
                                        if (length(DisplayMod) > 1)
                                            dispMod = getChannelTypeDisplay(DisplayMod{iMod}, DisplayMod);
                                            if (iMod <= length(jSubMenus))
                                                jMenuModality = jSubMenus(iMod);
                                                jMenuModality.addSeparator();
                                            else
                                                jMenuModality = gui_component('Menu', jPopup, [], dispMod, IconLoader.ICON_TOPOGRAPHY, [], []);
                                            end
                                        else
                                            jMenuModality = jPopup;
                                        end
                                        AddSeparator(jPopup);
                                        % EEG: Display on scalp
                                        if strcmpi(DisplayMod{iMod}, 'EEG') && ~isempty(sSubject) && ~isempty(sSubject.iScalp)
                                            gui_component('MenuItem', jPopup, [], 'Display on scalp', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iScalp).FileName, filenameRelative, 'EEG'));
                                        % SEEG/ECOG: Display on cortex or MRI
                                        elseif ismember(DisplayMod{iMod}, {'SEEG', 'ECOG', 'ECOG+SEEG'}) && ~isempty(sSubject)
                                            if ~isempty(sSubject.iCortex)
                                                gui_component('MenuItem', jMenuModality, [], 'Display on cortex', IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, filenameRelative, DisplayMod{iMod}));
                                            end
                                            % Find anatomy volumes (exclude atlases)
                                            if ~isempty(sSubject.Anatomy)
                                                iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                                            else
                                                iVolAnat = [];
                                            end
                                            if (length(iVolAnat) == 1)
                                                gui_component('MenuItem', jMenuModality, [], 'Display on MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, DisplayMod{iMod}));
                                                gui_component('MenuItem', jMenuModality, [], 'Display on MRI (3D)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, DisplayMod{iMod}));
                                            elseif (length(iVolAnat) > 1)
                                                for iAnat = 1:length(iVolAnat)
                                                    gui_component('MenuItem', jMenuModality, [], ['Display on MRI (MRI Viewer): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, DisplayMod{iMod}));
                                                end
                                                for iAnat = 1:length(iVolAnat)
                                                    gui_component('MenuItem', jMenuModality, [], ['Display on MRI (3D): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, DisplayMod{iMod}));
                                                end
                                            end
                                        end
                                    end
                                end
                                
                            case 'results'
                                gui_component('MenuItem', jPopup, [], 'One channel', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                AddSeparator(jPopup);
                                % Cortex
                                if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                                    gui_component('MenuItem', jPopup, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                                end
                                % MRI
                                if ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                                    gui_component('MenuItem', jPopup, [], 'Display on MRI   (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(MriFile, filenameRelative));
                                    gui_component('MenuItem', jPopup, [], 'Display on MRI   (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                                end
                                % Sphere
                                if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                                    AddSeparator(jPopup);
                                    gui_component('MenuItem', jPopup, [], 'Display on spheres/squares', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'orig'));
                                    gui_component('MenuItem', jPopup, [], '2D projection (Mollweide)', IconLoader.ICON_SURFACE, [], @(h,ev)view_surface_sphere(filenameRelative, 'mollweide'));
                                end
                                % MENU: EXPORT (Added later)
                                jMenuExport{2} = gui_component('MenuItem', [], [], 'Export as 4D matrix', IconLoader.ICON_SAVE, [], @(h,ev)panel_process_select('ShowPanelForFile', {filenameFull}, 'process_export_spmvol'));
                                
                            otherwise
                                strType = DataType;
                                if strcmpi(strType, 'matrix')
                                    strTypeS = 'matrices';
                                else
                                    strTypeS = [strType, 's'];
                                end
                                gui_component('MenuItem', jPopup, [], ['Time-freq: One ' strType],  IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'SingleSensor'));
                                gui_component('MenuItem', jPopup, [], ['Time-freq: All ' strTypeS], IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(filenameFull, 'AllSensors'));
                                AddSeparator(jPopup);
                                if isempty(strfind(filenameRelative, '_pac'))
                                    gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                                    gui_component('MenuItem', jPopup, [], 'Time series',    IconLoader.ICON_DATA,     [], @(h,ev)view_spectrum(filenameRelative, 'TimeSeries'));
                                    gui_component('MenuItem', jPopup, [], 'Image [signals x time]', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(filenameRelative, 'trialimage'));
                                end
                        end
                        % Export to file
                        if strcmpi(nodeType, 'timefreq')
                            jMenuExport{1} = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_timefreq, filenameFull));
                        end
                    end
                end
                % === STAT CLUSTERS ===
                if ~isempty(strfind(filenameRelative, 'ptimefreq_cluster'))
                    AddSeparator(jPopup);
                    jMenuCluster = gui_component('Menu', jPopup, [], 'Significant clusters', IconLoader.ICON_ATLAS, [], []);
                    gui_component('MenuItem', jMenuCluster, [], 'Cluster size', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_statcluster(filenameRelative, 'clustsize_time', []));
                end
                % Project sources
                if strcmpi(DataType, 'results') && isempty(strfind(filenameRelative, '_KERNEL_')) && isempty(strfind(filenameRelative, '_connectn')) 
                    fcnPopupProjectSources(1);
                end
                
                
%% ===== POPUP: SPECTRUM =====
            case {'spectrum', 'pspectrum'}
                % Get study description
                iStudy = bstNodes(1).getStudyIndex();
                iTimefreq = bstNodes(1).getItemIndex();
                sStudy = bst_get('Study', iStudy);
                % Get subject structure
                sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                % Get data type
                if strcmpi(nodeType, 'pspectrum')
                    TimefreqMat = in_bst_timefreq(filenameRelative, 0, 'DataType');
                    if ~isempty(TimefreqMat.DataType)
                        DataType = TimefreqMat.DataType;
                    else
                        DataType = 'matrix';
                    end
                    DataFile = [];
                else
                    DataType = sStudy.Timefreq(iTimefreq).DataType;
                    DataFile = sStudy.Timefreq(iTimefreq).DataFile;
                end
                if strcmpi(DataType, 'data')
                    % Get avaible modalities for this data file
                    DisplayMod = bst_get('TimefreqDisplayModalities', filenameRelative);
                    % Add SEEG+ECOG
                    if ~isempty(DisplayMod) && all(ismember({'SEEG','ECOG'}, DisplayMod))
                        DisplayMod = cat(2, {'ECOG+SEEG'}, DisplayMod);
                    end
                end
                % One file selected
                if (length(bstNodes) == 1)
                    % ===== RECORDINGS =====
                    if strcmpi(DataType, 'data')
                        % Power spectrum
                        gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                        AddSeparator(jPopup);
                        % Topography
                        isGradNorm = strcmpi(nodeType, 'spectrum');
                        jSubMenus = fcnPopupTopoNoInterp(jPopup, filenameRelative, DisplayMod, 1, isGradNorm, 0);
                        % Interpolate SEEG/ECOG on the anatomy
                        for iMod = 1:length(DisplayMod)
                            % Create submenu if there are multiple modalities
                            if (length(DisplayMod) > 1)
                                dispMod = getChannelTypeDisplay(DisplayMod{iMod}, DisplayMod);
                                if (iMod <= length(jSubMenus))
                                    jMenuModality = jSubMenus(iMod);
                                    jMenuModality.addSeparator();
                                else
                                    jMenuModality = gui_component('Menu', jPopup, [], dispMod, IconLoader.ICON_TOPOGRAPHY, [], []);
                                end
                            else
                                jMenuModality = jPopup;
                            end
                            AddSeparator(jPopup);
                            % EEG: Display on scalp
                            if strcmpi(DisplayMod{iMod}, 'EEG') && ~isempty(sSubject) && ~isempty(sSubject.iScalp)
                                gui_component('MenuItem', jMenuModality, [], 'Display on scalp', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iScalp).FileName, filenameRelative, 'EEG'));
                            % SEEG/ECOG: Display on cortex or MRI
                            elseif ismember(DisplayMod{iMod}, {'SEEG', 'ECOG', 'ECOG+SEEG'}) && ~isempty(sSubject)
                                if ~isempty(sSubject.iCortex)
                                    gui_component('MenuItem', jMenuModality, [], 'Display on cortex', IconLoader.ICON_SURFACE_CORTEX, [], @(h,ev)view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, filenameRelative, DisplayMod{iMod}));
                                end
                                % Find anatomy volumes (exclude atlases)
                                if ~isempty(sSubject.Anatomy)
                                    iVolAnat = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                                else
                                    iVolAnat = [];
                                end
                                if (length(iVolAnat) == 1)
                                    gui_component('MenuItem', jMenuModality, [], 'Display on MRI (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, DisplayMod{iMod}));
                                    gui_component('MenuItem', jMenuModality, [], 'Display on MRI (3D)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(1)).FileName, filenameRelative, DisplayMod{iMod}));
                                elseif (length(iVolAnat) > 1)
                                    for iAnat = 1:length(iVolAnat)
                                        gui_component('MenuItem', jMenuModality, [], ['Display on MRI (MRI Viewer): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, DisplayMod{iMod}));
                                    end
                                    for iAnat = 1:length(iVolAnat)
                                        gui_component('MenuItem', jMenuModality, [], ['Display on MRI (3D): ' sSubject.Anatomy(iVolAnat(iAnat)).Comment], IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(sSubject.Anatomy(iVolAnat(iAnat)).FileName, filenameRelative, DisplayMod{iMod}));
                                    end
                                end
                            end
                        end

                    % ===== SOURCES =====
                    elseif strcmpi(DataType, 'results')
                        AddSeparator(jPopup);
                        % Get head model type for the sources file
                        if ~isempty(DataFile)
                            [sStudyData, iStudyData, iResult] = bst_get('AnyFile', DataFile);
                            isVolume = strcmpi(sStudyData.Result(iResult).HeadModelType, 'volume');
                        % Get the default head model
                        else
                            wloc    = whos('-file', filenameFull, 'GridLoc');
                            worient = whos('-file', filenameFull, 'GridAtlas');
                            isVolume = (prod(wloc.size) > 0) && (isempty(worient) || (prod(worient.size) == 0));
                        end
                        % Cortex / MRI
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex) && ~isVolume
                            gui_component('MenuItem', jPopup, [], 'Display on cortex', IconLoader.ICON_CORTEX, [], @(h,ev)view_surface_data([], filenameRelative));
                        end
                        if ~isempty(sSubject) && ~isempty(sSubject.iAnatomy)
                            MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                            gui_component('MenuItem', jPopup, [], 'Display on MRI   (3D)',         IconLoader.ICON_ANATOMY, [], @(h,ev)view_surface_data(MriFile, filenameRelative));
                            gui_component('MenuItem', jPopup, [], 'Display on MRI   (MRI Viewer)', IconLoader.ICON_ANATOMY, [], @(h,ev)view_mri(MriFile, filenameRelative));
                        end
                        % MENU: EXPORT (Added later)
                        if strcmpi(nodeType, 'spectrum')
                            jMenuExport{2} = gui_component('MenuItem', [], [], 'Export as 4D matrix', IconLoader.ICON_SAVE, [], @(h,ev)panel_process_select('ShowPanelForFile', {filenameFull}, 'process_export_spmvol'));
                        end
                    % ===== CLUSTERS/SCOUTS =====
                    else
                        gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(filenameRelative, 'Spectrum'));
                    end
                else
                    % Display of multiple files
                    if ~isempty(DisplayMod)
                        % === 2DLAYOUT ===
                        mod2D = intersect(DisplayMod, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'});
                        if (length(mod2D) == 1)
                            gui_component('MenuItem', jPopup, [], ['2D Layout: ' mod2D{1}], IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes), mod2D{1}, '2DLayout'));
                        elseif (length(mod2D) > 1)
                            jMenu2d = gui_component('Menu', jPopup, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], []);
                            for iMod = 1:length(mod2D)
                                gui_component('MenuItem', jMenu2d, [], mod2D{iMod}, IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, GetAllFilenames(bstNodes), mod2D{iMod}, '2DLayout'));
                            end
                        end
                    end
                end
                % Project sources
                if strcmpi(DataType, 'results') && ~strcmpi(nodeType, 'ptimefreq') && isempty(strfind(filenameRelative, '_KERNEL_'))
                    fcnPopupProjectSources(1);
                end
                % Export to file
                if strcmpi(nodeType, 'spectrum')
                    jMenuExport{1} = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_timefreq, filenameFull));
                end
                
                
%% ===== POPUP: IMAGE =====
            case 'image'
                if (length(bstNodes) == 1)
                    gui_component('MenuItem', jPopup, [], 'View image', IconLoader.ICON_IMAGE, [], @(h,ev)view_image(filenameFull));
                end
               
%% ===== POPUP: VIDEO =====
            case 'video'
                if (length(bstNodes) == 1)
                    gui_component('MenuItem', jPopup, [], 'MATLAB VideoReader', IconLoader.ICON_VIDEO, [], @(h,ev)view_video(filenameFull, 'VideoReader', 1));
                    if ispc
                        gui_component('MenuItem', jPopup, [], 'VLC ActiveX plugin', IconLoader.ICON_VIDEO, [], @(h,ev)view_video(filenameFull, 'VLC', 1));
                        gui_component('MenuItem', jPopup, [], 'Windows Media Player', IconLoader.ICON_VIDEO, [], @(h,ev)view_video(filenameFull, 'WMPlayer', 1));
                    end
                    AddSeparator(jPopup);
                    if strcmpi(file_gettype(filenameRelative), 'videolink')
                        gui_component('MenuItem', jPopup, [], 'Set start time', IconLoader.ICON_VIDEO, [], @(h,ev)figure_video('SetVideoStart', filenameFull));
                    end
                end
                
%% ===== POPUP: MATRIX =====
            case {'matrix', 'pmatrix'}
                % Get subject structure
                iStudy = bstNodes(1).getStudyIndex();
                sStudy = bst_get('Study', iStudy);
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                % For only one file
                if (length(bstNodes) == 1)
                    % Basic displays
                    gui_component('MenuItem', jPopup, [], 'Display as time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_matrix(filenameFull, 'TimeSeries'));
                    gui_component('MenuItem', jPopup, [], 'Display as image',       IconLoader.ICON_NOISECOV,   [], @(h,ev)view_matrix(filenameFull, 'Image'));
                    gui_component('MenuItem', jPopup, [], 'Display as table',       IconLoader.ICON_MATRIX,     [], @(h,ev)view_matrix(filenameFull, 'Table'));
                    % === STAT CLUSTERS ===
                    if strcmpi(nodeType, 'pmatrix') && ~isempty(strfind(filenameRelative, '_cluster'))
                        AddSeparator(jPopup);
                        jMenuCluster = gui_component('Menu', jPopup, [], 'Significant clusters', IconLoader.ICON_ATLAS, [], []);
                        gui_component('MenuItem', jMenuCluster, [], 'Cluster indices', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_statcluster(filenameRelative, 'clustindex_time', []));
                    end
                    AddSeparator(jPopup);
		    gui_component('MenuItem', jPopup, [], 'Review as raw', IconLoader.ICON_RAW_DATA, [], @(h,ev)import_raw(filenameFull, 'BST-MATRIX', iSubject));
                else
                    gui_component('MenuItem', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(GetAllFilenames(bstNodes), 'erpimage', 'none'));
                end
                % Export to file
                if strcmpi(nodeType, 'matrix')
                    jMenuExport = gui_component('MenuItem', [], [], 'Export to file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_matrix, filenameFull));
                end
                
%% ===== POPUP: MATRIX LIST =====
            case 'matrixlist'
                gui_component('MenuItem', jPopup, [], 'Display as image', IconLoader.ICON_NOISECOV, [], @(h,ev)view_erpimage(GetAllFilenames(bstNodes, 'matrix'), 'erpimage', 'none'));
        end
        
%% ===== POPUP: COMMON MENUS =====
        % Add generic buttons, that can be applied to all nodes
        % If popup is not empty : add a separator
        AddSeparator(jPopup);
        % Properties of the selection
        isone = (length(bstNodes) == 1);
        isfile = ~isempty(filenameFull);
        isstudy = (ismember(nodeType, {'study', 'studysubject', 'defaultstudy', 'condition', 'rawcondition'}) && ~isempty(iStudy) && (iStudy ~= 0));
        issubject = strcmpi(nodeType, 'subject') && ~isempty(iSubject);
        
        % ===== MENU FILE =====
        jMenuFile = gui_component('Menu', [], [], 'File', IconLoader.ICON_MATLAB, [], []);
            % ===== VIEW FILE =====
            if isone && isfile && ~ismember(nodeType, {'subject', 'study', 'studysubject', 'condition', 'rawcondition', 'datalist', 'matrixlist', 'image'})
                gui_component('MenuItem', jMenuFile, [], 'View file contents', IconLoader.ICON_MATLAB, [], @(h,ev)view_struct(filenameFull));
                gui_component('MenuItem', jMenuFile, [], 'View file history', IconLoader.ICON_MATLAB, [], @(h,ev)bst_history('view', filenameFull));
            end
            % ===== VIEW HISTOGRAM =====
            if isfile && ~ismember(nodeType, {'subject', 'study', 'studysubject', 'condition', 'rawcondition', 'datalist', 'matrixlist', 'image', 'channel', 'rawdata', 'dipoles', 'mri', 'surface', 'cortex', 'anatomy', 'head', 'innerskull', 'outerskull', 'spike', 'other'})
                gui_component('MenuItem', jMenuFile, [], 'View histogram', IconLoader.ICON_HISTOGRAM, [], @(h,ev)view_histogram(GetAllFilenames(bstNodes)));
            end
            if (jMenuFile.getMenuComponentCount() > 0)
                AddSeparator(jMenuFile);
            end
            % ===== EXPORT SUBMENU =====
            if ~isempty(jMenuExport)
                if iscell(jMenuExport)
                    for i = 1:length(jMenuExport)
                        if ischar(jMenuExport{i}) && strcmpi(jMenuExport{i}, 'separator')
                            AddSeparator(jMenuFile);
                        else
                            jMenuFile.add(jMenuExport{i});
                        end
                    end 
                else
                    jMenuFile.add(jMenuExport);
                end
            end
            % ===== EXPORT TO MATLAB VARIABLE =====
            if isfile && ~isCompiled && ~ismember(nodeType, {'study', 'studysubject', 'defaultstudy', 'condition', 'rawcondition', 'subject', 'datalist', 'matrixlist', 'image'})
                gui_component('MenuItem', jMenuFile, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)export_matlab(bstNodes));
            end
            % ===== IMPORT FROM MATLAB VARIABLE =====
            if ~bst_get('ReadOnly') && isone && ~isCompiled
                if isstudy
                    gui_component('MenuItem', jMenuFile, [], 'Import from Matlab', IconLoader.ICON_MATLAB_IMPORT, [], @(h,ev)db_add(iStudy));
                    gui_component('MenuItem', jMenuFile, [], 'Import source maps', IconLoader.ICON_RESULTS, [], @(h,ev)import_sources(iStudy));
                    gui_component('MenuItem', jMenuFile, [], 'Import data matrix', IconLoader.ICON_MATRIX, [], @(h,ev)import_matrix(iStudy));
                elseif issubject
                    gui_component('MenuItem', jMenuFile, [], 'Import from Matlab', IconLoader.ICON_MATLAB_IMPORT, [], @(h,ev)db_add(iSubject));
                elseif isfile && ~ismember(nodeType, {'study', 'studysubject', 'defaultstudy', 'condition', 'rawcondition', 'subject', 'link', 'datalist', 'matrixlist', 'image'})
                    gui_component('MenuItem', jMenuFile, [], 'Import from Matlab', IconLoader.ICON_MATLAB_IMPORT, [], @(h,ev)node_import(bstNodes(1)));
                end
            end
            % Separator
            AddSeparator(jMenuFile);

            % ===== RAW FILE =====
            % Get continuous file link
            if strcmpi(nodeType, 'rawdata') && isone
                RawFile = filenameRelative;
            elseif (isstudy && strcmpi(nodeType, 'rawcondition')) && isone
                % Get study
                sStudy = bst_get('Study', iStudy);
                % Find raw data file in the condition
                iDataRaw = find(strcmpi({sStudy.Data.DataType}, 'raw'));
                if isempty(iDataRaw)
                    RawFile = [];
                else
                    RawFile = sStudy.Data(iDataRaw(1)).FileName;
                end
            else
                RawFile = [];
            end
            % Folders: set acquisition date
            if ~bst_get('ReadOnly') && (~isempty(RawFile) || isstudy)
                gui_component('MenuItem', jMenuFile, [], 'Set acquisition date', IconLoader.ICON_RAW_DATA, [], @(h,ev)panel_record('SetAcquisitionDate', iStudy));
            end
            % Raw file menus
            if ~isempty(RawFile) && isempty(strfind(RawFile, '_0ephys_'))
                % Files that are not saved in the database
                if isempty(dir(bst_fullfile(bst_fileparts(file_fullpath(RawFile)), '*.bst')))
                    if ~bst_get('ReadOnly')
                        gui_component('MenuItem', jMenuFile, [], 'Fix broken link', IconLoader.ICON_RAW_DATA, [], @(h,ev)panel_record('FixFileLink', RawFile));
                        gui_component('MenuItem', jMenuFile, [], 'Copy to database', IconLoader.ICON_RAW_DATA, [], @(h,ev)panel_record('CopyRawToDatabase', RawFile));
                        % gui_component('MenuItem', jMenuFile, [], 'Delete raw file', IconLoader.ICON_RAW_DATA, [], @(h,ev)panel_record('DeleteRawFile', RawFile));
                        % FIF: Anonymize
                        if strcmpi(nodeType, 'rawdata') && (strcmpi(Device, 'Vectorview306') || all(ismember({'MEG MAG', 'MEG GRAD'}, AllMod)))
                            gui_component('MenuItem', jMenuFile, [], 'Anonymize FIF file', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_call(@file_anonymize, filenameFull));
                        end
                    end
                    gui_component('Menu', jMenuFile, [], 'Extra acquisition files', IconLoader.ICON_RAW_DATA, [], @(h,ev)CreateMenuExtraFiles(ev.getSource(), RawFile));
                end
            end
            % Add video
            if ~bst_get('ReadOnly') && (~isempty(RawFile) || isstudy) 
                gui_component('MenuItem', jMenuFile, [], 'Add synchronized video', IconLoader.ICON_VIDEO, [], @(h,ev)import_video(iStudy));
                AddSeparator(jMenuFile);
            end

            % ===== OTHER MENUS =====
            if isone && ~isempty(jMenuFileOther)
                jMenuFile.add(jMenuFileOther);
                AddSeparator(jMenuFile);
            end

            % ===== COPY/CUT =====
            if ~bst_get('ReadOnly') && isfile && ~isSpecialNode && ~isstudy && ~issubject && ~ismember(nodeType, {'studysubject','condition','datalist', 'matrixlist','link','rawcondition','rawdata', 'image', 'video'})
                jItem = gui_component('MenuItem', jMenuFile, [], 'Copy', IconLoader.ICON_COPY, [], @(h,ev)panel_protocols('CopyNode', bstNodes, 0));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_C, KeyEvent.CTRL_MASK));
                jItem = gui_component('MenuItem', jMenuFile, [], 'Cut',  IconLoader.ICON_CUT, [], @(h,ev)panel_protocols('CopyNode', bstNodes, 1));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_X, KeyEvent.CTRL_MASK));
            end
            % ===== PASTE =====
            if ~bst_get('ReadOnly') && isone && (isstudy || issubject) && ~isempty(bst_get('Clipboard'))
                jItem = gui_component('MenuItem', jMenuFile, [], 'Paste',  IconLoader.ICON_PASTE, [], @(h,ev)panel_protocols('PasteNode', bstNodes));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_V, KeyEvent.CTRL_MASK));
            end
            % ===== DELETE =====
            if ~bst_get('ReadOnly') && ~isSpecialNode && ~ismember(nodeType, {'defaultstudy', 'link'})
                jItem = gui_component('MenuItem', jMenuFile, [], 'Delete', IconLoader.ICON_DELETE, [], @(h,ev)node_delete(bstNodes));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_DELETE, 0));
            end
            % ===== RENAME =====
            if ~bst_get('ReadOnly') && isone && isfile && ~isSpecialNode && ~ismember(nodeType, {'link', 'image', 'video'})
                jItem = gui_component('MenuItem', jMenuFile, [], 'Rename', IconLoader.ICON_EDIT, [], @(h,ev)EditNode_Callback(bstNodes(1)));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_F2, 0));
            end
            % ===== DUPLICATE =====
            if ~bst_get('ReadOnly') && isone && ~isSpecialNode
                if ismember(nodeType, {'data', 'results', 'timefreq', 'spectrum', 'matrix'})
                    gui_component('MenuItem', jMenuFile, [], 'Duplicate file', IconLoader.ICON_COPY, [], @(h,ev)process_duplicate('DuplicateData', filenameRelative, '_copy'));
                elseif ismember(nodeType, {'studysubject', 'subject'})
                    gui_component('MenuItem', jMenuFile, [], 'Duplicate subject', IconLoader.ICON_COPY, [], @(h,ev)process_duplicate('DuplicateSubject', bst_fileparts(filenameRelative), '_copy'));
                elseif strcmpi(nodeType, 'condition') && (bstNodes(1).getStudyIndex ~= 0)
                    gui_component('MenuItem', jMenuFile, [], 'Duplicate folder', IconLoader.ICON_COPY, [], @(h,ev)process_duplicate('DuplicateCondition', filenameRelative, '_copy'));
                end
            end
            % ===== SEND TO PROCESS ======
            if ~bst_get('ReadOnly') && ismember(nodeType, {'studydbsubj', 'studydbcond', 'study', 'studysubject', 'data', 'datalist', 'matrixlist', 'results', 'resultslist', 'link', 'timefreq', 'spectrum', 'matrix', 'rawdata', 'rawcondition'})
                AddSeparator(jMenuFile);
                jMenuProcess = gui_component('Menu', jMenuFile, [], 'Process', IconLoader.ICON_PROCESS, [], []);
                    gui_component('MenuItem', jMenuProcess, [], 'Add to Process1',    IconLoader.ICON_PROCESS, [], @(h,ev)panel_nodelist('AddNodes', 'Process1',  bstNodes));
                    gui_component('MenuItem', jMenuProcess, [], 'Add to Process2(A)', IconLoader.ICON_PROCESS, [], @(h,ev)panel_nodelist('AddNodes', 'Process2A', bstNodes));
                    gui_component('MenuItem', jMenuProcess, [], 'Add to Process2(B)', IconLoader.ICON_PROCESS, [], @(h,ev)panel_nodelist('AddNodes', 'Process2B', bstNodes));
            end
            % ===== LOCATE FILE/FOLDER =====
            if isone && isfile && ~ismember(nodeType, {'datalist', 'matrixlist'})
                AddSeparator(jMenuFile);
                % Target file
                if strcmpi(nodeType, 'link')
                    destfile = file_resolve_link(filenameFull);
                elseif any(filenameFull == '*')
                    istar = find(filenameFull == '*');
                    destfile = filenameFull(1:istar-1);
                else
                    destfile = filenameFull;
                end
                % Target folder
                if isdir(destfile)
                    destfolder = destfile;
                else
                    destfolder = bst_fileparts(destfile);
                end
                % ===== COPY TO CLIPBOARD =====
                gui_component('MenuItem', jMenuFile, [], 'Copy file path to clipboard', IconLoader.ICON_COPY, [], @(h,ev)clipboard('copy', filenameFull));

                % ===== GO TO THIS DIRECTORY ======
                if ~isCompiled
                    gui_component('MenuItem', jMenuFile, [], 'Go to this directory (Matlab)', IconLoader.ICON_MATLAB, [], @(h,ev)cd(destfolder));
                end
                % ===== LOCATE ON DISK =====
                % Open terminal in this folder
                if ~strncmp(computer, 'PC', 2)
                    gui_component('MenuItem', jMenuFile, [], 'Open terminal in this folder', IconLoader.ICON_TERMINAL, [], @(h,ev)bst_which(destfolder, 'terminal'));
                end
                % Select file in system's file explorer
                if ~strcmpi(nodeType, 'link')
                    gui_component('MenuItem', jMenuFile, [], 'Show in file explorer', IconLoader.ICON_EXPLORER, [], @(h,ev)bst_which(destfile, 'explorer'));
                end
            end
        % Add File menu to popup
        if (jMenuFile.getMenuComponentCount() > 0)
            jPopup.add(jMenuFile);
        end
        
        % ===== RELOAD =====
        if isone && ismember(nodeType, {'subjectdb', 'studydbsubj', 'studydbcond', 'subject', 'study', 'studysubject', 'condition', 'rawcondition', 'defaultstudy'})
            gui_component('MenuItem', jPopup, [], 'Reload', IconLoader.ICON_RELOAD, [], @(h,ev)panel_protocols('ReloadNode', bstNodes(1)));
        end
        

        
end % END SWITCH( ACTION )




%% ================================================================================================
%  ===== POPUP SHORTCUTS ==========================================================================
%  ================================================================================================

%% ===== MENU: GOOD/BAD CHANNELS =====
    function jMenu = fcnPopupMenuGoodBad()
        import org.brainstorm.icon.*;
        jMenu = gui_component('Menu', jPopup, [], 'Good/bad channels', IconLoader.ICON_GOODBAD, [], []);
        gui_component('MenuItem', jMenu, [], 'Mark some channels as good...', IconLoader.ICON_GOOD, [], @(h,ev)tree_set_channelflag(bstNodes, 'ClearBad'));
        gui_component('MenuItem', jMenu, [], 'Mark all channels as good',     IconLoader.ICON_GOOD, [], @(h,ev)tree_set_channelflag(bstNodes, 'ClearAllBad'));
        gui_component('MenuItem', jMenu, [], 'Mark some channels as bad...',  IconLoader.ICON_BAD,  [], @(h,ev)tree_set_channelflag(bstNodes, 'AddBad'));
        gui_component('MenuItem', jMenu, [], 'Mark flat channels as bad',     IconLoader.ICON_BAD,  [], @(h,ev)tree_set_channelflag(bstNodes, 'DetectFlat'));
        gui_component('MenuItem', jMenu, [], 'View all bad channels',         IconLoader.ICON_BAD,  [], @(h,ev)tree_set_channelflag(bstNodes, 'ShowBad'));
    end
%% ===== MENU: HEADMODEL =====
    function fcnPopupComputeHeadmodel()   
        import org.brainstorm.icon.*;
        AddSeparator(jPopup);
        gui_component('MenuItem', jPopup, [], 'Compute head model', IconLoader.ICON_HEADMODEL, [], @(h,ev)panel_protocols('TreeHeadModel', bstNodes));
        if ismember(nodeType, {'studysubject', 'defaultstudy'}) && strcmp(bst_fileparts(filenameRelative), bst_get('NormalizedSubjectName'))
            gui_component('MenuItem', jPopup, [], 'Generate source grid', IconLoader.ICON_HEADMODEL, [], @(h,ev)panel_protocols('TreeSourceGrid', bstNodes));
        end
    end
%% ===== MENU: NOISE COV =====
    function fncPopupMenuNoiseCov(isCompute)
        import org.brainstorm.icon.*;
        % Noise covariance
        jMenu = gui_component('Menu', jPopup, [], 'Noise covariance', IconLoader.ICON_NOISECOV, [], []);
        if isCompute
            gui_component('MenuItem', jMenu, [], 'Compute from recordings', IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, 'Compute', 0));
            AddSeparator(jMenu);
        end
        gui_component('MenuItem', jMenu, [], 'No noise modeling (identity matrix)', IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, 'Identity', 0));
        AddSeparator(jMenu);
        gui_component('MenuItem', jMenu, [], 'Import from file',   IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, [], 0));
        gui_component('MenuItem', jMenu, [], 'Import from Matlab', IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, 'MatlabVar', 0));
        % Data covariance
        jMenu = gui_component('Menu', jPopup, [], 'Data covariance', IconLoader.ICON_NOISECOV, [], []);
        if isCompute
            gui_component('MenuItem', jMenu, [], 'Compute from recordings', IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, 'Compute', 1));
            AddSeparator(jMenu);
        end
        gui_component('MenuItem', jMenu, [], 'Import from file',   IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, [], 1));
        gui_component('MenuItem', jMenu, [], 'Import from Matlab', IconLoader.ICON_NOISECOV, [], @(h,ev)tree_set_noisecov(bstNodes, 'MatlabVar', 1));
    end

%% ===== MENU: COMPUTE SOURCES =====
    function fcnPopupComputeSources()         
        import org.brainstorm.icon.*;
        % gui_component('MenuItem', jPopup, [], 'Compute sources [2009]', IconLoader.ICON_RESULTS, [], @(h,ev)panel_protocols('TreeInverse', bstNodes, '2009'));
        % gui_component('MenuItem', jPopup, [], 'Compute sources [2016]', IconLoader.ICON_RESULTS, [], @(h,ev)panel_protocols('TreeInverse', bstNodes, '2016'));
        gui_component('MenuItem', jPopup, [], 'Compute sources [2018]', IconLoader.ICON_RESULTS, [], @(h,ev)panel_protocols('TreeInverse', bstNodes, '2018'));
    end

%% ===== MENU: PROJECT ON DEFAULT ANATOMY =====
    % Offer the projection of the source files on the default anatomy, and if possible to a single subject
    function fcnPopupProjectSources(isSeparator)
        import org.brainstorm.icon.*;
        HeadModelType = 'unknown';
        % Get node type
        if ismember(nodeType, {'timefreq', 'spectrum'})
            for iNode = 1:length(bstNodes)
                ResultFiles{iNode} = char(bstNodes(iNode).getFileName());
                iStudies(iNode) = bstNodes(iNode).getStudyIndex();
            end
            % Get all the studies
            sStudies = bst_get('Study', iStudies);
            % Get first file in the datbase
            [sStudy,iStudy,iTf] = bst_get('TimefreqFile', ResultFiles{1});
            % Try to get source model type from the parent file
            if ~isempty(sStudy) && ~isempty(sStudy.Timefreq(iTf).DataFile) && strcmpi(sStudy.Timefreq(iTf).DataType, 'results')
                % Get parent source file
                [sStudy,iStudy,iRes] = bst_get('ResultsFile', sStudy.Timefreq(iTf).DataFile);
                if ~isempty(sStudy) && ~isempty(sStudy.Result(iRes).HeadModelType)
                    HeadModelType = sStudy.Result(iRes).HeadModelType;
                end
            end
        else
            % Get all the Results files that are classified in the input nodes
            [iStudies, iResults] = tree_dependencies(bstNodes, 'results');
            if isempty(iResults) 
                return;
            elseif isequal(iStudies, -10)
                disp('BST> Error in tree_dependencies.');
                return;
            end
            % Get all the studies
            sStudies = bst_get('Study', iStudies);
            % Build results files list
            for iRes = 1:length(iResults)
                ResultFiles{iRes} = sStudies(iRes).Result(iResults(iRes)).FileName;
                if isempty(HeadModelType) || strcmpi(HeadModelType, 'unknown')
                    HeadModelType = sStudies(iRes).Result(iResults(iRes)).HeadModelType;
                elseif ~isequal(HeadModelType, sStudies(iRes).Result(iResults(iRes)).HeadModelType)
                    % disp('PROJECT> Selected node contains different type of source files. Cannot be handled together.');
                    return;
                end
            end
        end
        % Get all the subjects
        SubjectFiles = unique({sStudies.BrainStormSubject});
        nCortex = 0;
        
        % ===== SINGLE SUBJECT =====
        sCortex = [];
        isGroupAnalysis = 0;
        % If only one subject: offer to reproject the sources on it
        if (length(SubjectFiles) == 1)
            % Get subject
            [sSubject, iSubject] = bst_get('Subject', SubjectFiles{1});
            % If not using default anat and there is more than one cortex
            if ~sSubject.UseDefaultAnat && ~isempty(sSubject.iCortex)
                % Get all cortex surfaces
                sCortex = bst_get('SurfaceFileByType', iSubject, 'Cortex', 0);
                nCortex = length(sCortex);
            end
            UseDefaultAnat = sSubject.UseDefaultAnat;
            % Is this the group analysis subject
            if strcmpi(sSubject.Name, bst_get('NormalizedSubjectName'))
                isGroupAnalysis = 1;
            end
        % If more than one subject: just check if the subjects are using default anatomy
        else
            for iSubj = 1:length(SubjectFiles)
                sSubjects(iSubj) = bst_get('Subject', SubjectFiles{iSubj});
            end
            UseDefaultAnat = any([sSubjects.UseDefaultAnat]);
        end

        % ===== DEFAULT ANATOMY =====
        % Get default subject
        sDefSubject = bst_get('Subject',0);
        % Get all cortex surfaces for default subject
        sDefCortex = bst_get('SurfaceFileByType', 0, 'Cortex', 0);
        nCortex = nCortex + length(sDefCortex);
        
        % ===== CREATE MENUS =====
        % SURFACE: Show a "Project sources" menu if there are more than one cortex avaiable
        % or if there is one default cortex and subjects do not use default anatomy
        if ismember(HeadModelType, {'unknown','surface','mixed'}) && (nCortex > 1) || ((nCortex == 1) && ~isempty(sDefCortex) && ~UseDefaultAnat)
            if isSeparator
                AddSeparator(jPopup);
            end
            % Project sub-menu
            if (length(ResultFiles) == 1)
                strMenu = 'Project sources';
            else
                strMenu = sprintf('Project sources (%d)', length(ResultFiles));
            end
            jMenu = gui_component('Menu', jPopup, [], strMenu, IconLoader.ICON_RESULTS_LIST, [], []);
            % === DEFAULT ANAT ===
            if ~isempty(sDefCortex)
                jMenuDef = gui_component('Menu', jMenu, [], 'Default anatomy', IconLoader.ICON_SUBJECT, [], []);
                % Loop on all the cortex surfaces
                for iCort = 1:length(sDefCortex)
                    gui_component('MenuItem', jMenuDef, [], sDefCortex(iCort).Comment, IconLoader.ICON_CORTEX, [], @(h,ev)bst_project_sources(ResultFiles, sDefCortex(iCort).FileName));
                end
            end
            % === INDIVIDUAL SUBJECT ===
            if ~isempty(sCortex)
                jMenuSubj = gui_component('Menu', jMenu, [], sSubject.Name, IconLoader.ICON_SUBJECT, [], []);
                % Loop on all the cortex surfaces
                for iCort = 1:length(sCortex)
                    gui_component('MenuItem', jMenuSubj, [], sCortex(iCort).Comment, IconLoader.ICON_CORTEX, [], @(h,ev)bst_project_sources(ResultFiles, sCortex(iCort).FileName));
                end
            end
            % === OTHER SUBJECTS ===
            if (bst_get('SubjectCount') > 1)
                gui_component('MenuItem', jMenu, [], 'Other subjects...', IconLoader.ICON_SUBJECT, [], @(h,ev)ProjectSourcesAll(ResultFiles));
            end
        end
        % VOLUME: Menu "project on template grid"
        if ismember(HeadModelType, {'unknown','volume'}) && ~isempty(sDefSubject) && ~isempty(sDefSubject.Anatomy)
            if isSeparator
                AddSeparator(jPopup);
            end
            % Subject: Project on template
            if ~isGroupAnalysis
                gui_component('MenuItem', jPopup, [], 'Project source grid', IconLoader.ICON_ANATOMY, [], @(h,ev)bst_project_grid(ResultFiles, [], 1));
            % Default anatomy: Project back on subjects
            elseif (bst_get('SubjectCount') > 1)
                gui_component('MenuItem', jPopup, [], 'Project source grid...', IconLoader.ICON_ANATOMY, [], @(h,ev)ProjectGridAll(ResultFiles));
            end
        end
    end
        
        
%% ===== MENU: CLUSTERS TIME SERIES =====
    function fcnPopupClusterTimeSeries()
        import org.brainstorm.icon.*;
        sClusters = panel_cluster('GetClusters');
        if ~isempty(sClusters)
            gui_component('MenuItem', jPopup, [], 'Clusters time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)tree_view_clusters(bstNodes));
        end
    end

%% ===== MENU: SCOUT TIME SERIES =====
    function fcnPopupScoutTimeSeries(jMenu, isSeparator)
        import org.brainstorm.icon.*;
        if (nargin < 2) || isempty(isSeparator)
            isSeparator = 0;
        end
        %if ~isempty(panel_scout('GetScouts'))
            if isSeparator
                AddSeparator(jMenu);
            end
            gui_component('MenuItem', jMenu, [], 'Scouts time series', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)tree_view_scouts(bstNodes));
        %end
    end

%% ===== MENU: ALIGN SURFACES MANUALLY =====
    function fcnPopupAlign()
        import org.brainstorm.icon.*;

        jMenuAlignManual = gui_component('Menu', jPopup, [], 'Align manually on...', IconLoader.ICON_ALIGN_SURFACES, [], []);
        % ADD ANATOMIES
        for iAnat = 1:length(sSubject.Anatomy)
            if isempty(strfind(sSubject.Anatomy(iAnat).FileName, '_volatlas')) && isempty(strfind(sSubject.Anatomy(iAnat).FileName, '_volct'))
                fullAnatFile = bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.Anatomy(iAnat).FileName);
                gui_component('MenuItem', jMenuAlignManual, [], sSubject.Anatomy(iAnat).Comment, IconLoader.ICON_ANATOMY, [], @(h,ev)tess_align_manual(fullAnatFile, filenameFull));
            end
        end
        % ADD SURFACES
        for iSurf = 1:length(sSubject.Surface)
            % Ignore itself
            fullSurfFile = bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.Surface(iSurf).FileName);
            if ~file_compare(fullSurfFile, filenameFull)
                gui_component('MenuItem', jMenuAlignManual, [], sSubject.Surface(iSurf).Comment, IconLoader.ICON_SURFACE, [], @(h,ev)tess_align_manual(fullSurfFile, filenameFull));
            end
        end
    end

end % END FUNCTION



%% ================================================================================================
%  === CALLBACKS ==================================================================================
%  ================================================================================================
%% ===== MENU: IMPORT CHANNEL =====
function fcnPopupImportChannel(bstNodes, jMenu, isAddLoc)
    import org.brainstorm.icon.*;
    % Get all studies
    iAllStudies = tree_channel_studies( bstNodes );
    % === IMPORT CHANNEL ===
    if (isAddLoc >= 1)  % isAddLoc=2 (EEG) or =1 (SEEG/ECOG)
        jMenu = gui_component('Menu', jMenu, [], 'Add EEG positions', IconLoader.ICON_CHANNEL, [], []);
        % Import from file
        gui_component('MenuItem', jMenu, [], 'Import from file', IconLoader.ICON_CHANNEL, [], @(h,ev)channel_add_loc(iAllStudies, [], 1));
        % From other Studies within same Subject
        sStudies = bst_get('Study', iAllStudies);
        % If adding locations to multiple channel files, they must be from the same subject
        if length(unique({sStudies.BrainStormSubject})) == 1
            sSubject = bst_get('Subject', sStudies(1).BrainStormSubject);
            if sSubject.UseDefaultChannel == 0
                % Only consider Studies with ChannelFile
                [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
                iChStudies = ~cellfun(@isempty, {sStudies.Channel});
                sStudies = sStudies(iChStudies);
                iStudies = iStudies(iChStudies);
                [~, ixDiff] = setdiff(iStudies, iAllStudies);
                if ~isempty(ixDiff)
                    % Create menu and entries
                    AddSeparator(jMenu);
                    jMenuStudy = gui_component('Menu', jMenu, [], 'From other studies', IconLoader.ICON_CHANNEL, [], []);
                    for ix = 1 : length(ixDiff)
                        conditionName = sStudies(ixDiff(ix)).Condition{1};
                        if strcmpi(conditionName(1:4), '@raw')
                            iconLoader = IconLoader.ICON_RAW_FOLDER_CLOSE;
                            conditionName(1:4) = '';
                        else
                            iconLoader = IconLoader.ICON_FOLDER_CLOSE;
                        end
                        % Menu entry
                        gui_component('MenuItem', jMenuStudy, [], conditionName, iconLoader, [], @(h,ev)channel_add_loc(iAllStudies, sStudies(ixDiff(ix)).Channel.FileName, 1));
                    end
                end
            end
        end
        % If only SEEG/ECOG, stop here (we do not want to offer the standard EEG caps, it doesn't make sense)
        if (isAddLoc < 2)
            return;
        end
        % Add separator before the menu with default EEGcaps
        AddSeparator(jMenu);
    else
        gui_component('MenuItem', jMenu, [], 'Import channel file', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@ImportChannelCheck, iAllStudies));
        jMenu = gui_component('Menu', jMenu, [], 'Use default EEG cap', IconLoader.ICON_CHANNEL, [], []);
    end
    % === USE DEFAULT CHANNEL FILE ===
    % Get registered Brainstorm EEG defaults
    bstDefaults = bst_get('EegDefaults');
    if ~isempty(bstDefaults)
        % Add a directory per template block available
        for iDir = 1:length(bstDefaults)
            jMenuDir = gui_component('Menu', jMenu, [], bstDefaults(iDir).name, IconLoader.ICON_FOLDER_CLOSE, [], []);
            isMni = strcmpi(bstDefaults(iDir).name, 'ICBM152');
            % Create subfolder for cap manufacturer
            jMenuOther = gui_component('Menu', [], [], 'Generic', IconLoader.ICON_FOLDER_CLOSE, [], []);
            jMenuAnt = gui_component('Menu', [], [], 'ANT', IconLoader.ICON_FOLDER_CLOSE, [], []);
            jMenuBs  = gui_component('Menu', [], [], 'BioSemi', IconLoader.ICON_FOLDER_CLOSE, [], []);
            jMenuBp  = gui_component('Menu', [], [], 'BrainProducts', IconLoader.ICON_FOLDER_CLOSE, [], []);
            jMenuEgi = gui_component('Menu', [], [], 'EGI', IconLoader.ICON_FOLDER_CLOSE, [], []);
            jMenuNs  = gui_component('Menu', [], [], 'NeuroScan', IconLoader.ICON_FOLDER_CLOSE, [], []);
            % Add an item per Template available
            fList = bstDefaults(iDir).contents;
            % Sort in natural order
            [tmp,I] = sort_nat({fList.name});
            fList = fList(I);
            % Create an entry for each default
            for iFile = 1:length(fList)
                % Define callback function
                if isAddLoc 
                    fcnCallback = @(h,ev)channel_add_loc(iAllStudies, fList(iFile).fullpath, 1, isMni);
                else
                    fcnCallback = @(h,ev)db_set_channel(iAllStudies, fList(iFile).fullpath, 1, 0);
                end
                % Find corresponding submenu
                if ~isempty(strfind(fList(iFile).name, 'ANT'))
                    jMenuType = jMenuAnt;
                elseif ~isempty(strfind(fList(iFile).name, 'BioSemi'))
                    jMenuType = jMenuBs;
                elseif ~isempty(strfind(fList(iFile).name, 'BrainProducts'))
                    jMenuType = jMenuBp;
                elseif ~isempty(strfind(fList(iFile).name, 'GSN')) || ~isempty(strfind(fList(iFile).name, 'U562'))
                    jMenuType = jMenuEgi;
                elseif ~isempty(strfind(fList(iFile).name, 'Neuroscan'))
                    jMenuType = jMenuNs;
                else
                    jMenuType = jMenuOther;
                end
                % Create item
                gui_component('MenuItem', jMenuType, [], fList(iFile).name, IconLoader.ICON_CHANNEL, [], fcnCallback);
            end
            % Add if not empty
            if (jMenuOther.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuOther);
            end
            if (jMenuAnt.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuAnt);
            end
            if (jMenuBs.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuBs);
            end
            if (jMenuBp.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuBp);
            end
            if (jMenuEgi.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuEgi);
            end
            if (jMenuNs.getMenuComponentCount() > 0)
                jMenuDir.add(jMenuNs);
            end
        end
    end
end

%% ===== EDIT NODE =====
function EditNode_Callback(node)
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
	ctrl.jTreeProtocols.startEditingAtPath(javax.swing.tree.TreePath(node.getPath()));
end

%% ===== ADD SEPARATOR =====
function AddSeparator(jMenu)
    if isa(jMenu, 'javax.swing.JPopupMenu')
        nmenu = jMenu.getComponentCount();
        if (nmenu > 0) && ~isa(jMenu.getComponent(nmenu-1), 'javax.swing.JSeparator')
            jMenu.addSeparator();
        end
    else
        nmenu = jMenu.getMenuComponentCount();
        if (nmenu > 0) && ~isa(jMenu.getMenuComponent(nmenu-1), 'javax.swing.JSeparator')
            jMenu.addSeparator();
        end
    end
end


%% ===== DISPLAY TOPOGRAPHY =====
function fcnPopupDisplayTopography(jMenu, FileName, AllMod, Modality, isStat)
    import org.brainstorm.icon.*;
    AddSeparator(jMenu);
    % Interpolation
    if ~ismember(Modality, {'SEEG','ECOG+SEEG'})
        gui_component('MenuItem', jMenu, [], '3D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DSensorCap'));
        if ~ismember(Modality, {'NIRS','ECOG'})
            gui_component('MenuItem', jMenu, [], '2D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '2DSensorCap'));
            gui_component('MenuItem', jMenu, [], '2D Disc',       IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '2DDisc'));
        end
    end
    gui_component('MenuItem', jMenu, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '2DLayout'));
    % 3D Electrodes
    if strcmpi(Modality, 'EEG')
        gui_component('MenuItem', jMenu, [], '3D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DElectrodes'));
    elseif strcmpi(Modality, 'ECOG')
        gui_component('MenuItem', jMenu, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '2DElectrodes'));
        gui_component('MenuItem', jMenu, [], '3D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DElectrodes'));
    elseif ismember(Modality, {'SEEG', 'ECOG+SEEG'})
        gui_component('MenuItem', jMenu, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '2DElectrodes'));
        gui_component('MenuItem', jMenu, [], '3D Electrodes (Head)',   IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DElectrodes-Scalp'));
        gui_component('MenuItem', jMenu, [], '3D Electrodes (Cortex)', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DElectrodes-Cortex'));
        gui_component('MenuItem', jMenu, [], '3D Electrodes (MRI 3D)', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DElectrodes-MRI'));
    elseif strcmpi(Modality, 'NIRS')
        gui_component('MenuItem', jMenu, [], '3D optodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, Modality, '3DOptodes'));
    end
    
    % === NO MAGNETIC INTERPOLATION ===
    % Only for NEUROMAG MEG data (and not "MEG (all)" = MAG+GRAD)
    if ~isStat && ismember(Modality, {'MEG', 'MEG MAG', 'MEG GRAD'}) && ~(strcmpi(Modality, 'MEG') && any(ismember(AllMod, {'MEG MAG', 'MEG GRAD'})))
        AddSeparator(jMenu);
        jMenuNoInterp = gui_component('Menu', jMenu, [], 'No magnetic interpolation', IconLoader.ICON_TOPO_NOINTERP, [], []);
        fcnPopupTopoNoInterp(jMenuNoInterp, FileName, {Modality}, 0, 1, 1);
    elseif ~isStat && strcmpi(Modality, 'EEG')
        AddSeparator(jMenu);
        jMenuNoInterp = gui_component('Menu', jMenu, [], 'No smoothing', IconLoader.ICON_TOPO_NOINTERP, [], []);
        fcnPopupTopoNoInterp(jMenuNoInterp, FileName, {Modality}, 0, 1, 1);
    end
end


%% ===== DISPLAY TOPOGRAPHY: NO INTERP =====
function jSubMenus = fcnPopupTopoNoInterp(jMenu, FileName, AllMod, is2DLayout, isGradNorm, AlwaysCreate)
    import org.brainstorm.icon.*;
    % Display defaults
    UseSmoothing = 0;
    % Remove "MEG" from the list if there is either "MEG MAG" or "MEG GRAD" also
    if ~isempty(AllMod) && (all(ismember({'MEG GRAD', 'MEG'}, AllMod)) || all(ismember({'MEG MAG', 'MEG'}, AllMod)))
        AllMod = setdiff(AllMod, 'MEG'); 
    end
    % Replace "MEG GRAD" with independant sensor types (MEG GRAD2, MEG GRAD3, GRADNORM)
    if ~isempty(AllMod) && ismember('MEG GRAD', AllMod)
        AllMod = setdiff(AllMod, 'MEG GRAD'); 
        if isGradNorm
            AllMod{end+1} = 'MEG GRADNORM';
        end
        AllMod{end+1} = 'MEG GRAD2';
        AllMod{end+1} = 'MEG GRAD3';       
    end
    % Force figure creation or not
    if AlwaysCreate
        hFig = 'NewFigure';
    else
        hFig = [];
    end
    % Loop on all the modalities
    if ~isempty(AllMod)
        for iMod = 1:length(AllMod)
            if (length(AllMod) > 1)
                dispMod = getChannelTypeDisplay(AllMod{iMod}, AllMod);
                jSubMenu = gui_component('Menu', jMenu, [], dispMod, IconLoader.ICON_TOPOGRAPHY, [], []);
                jSubMenus(iMod) = jSubMenu;
            else
                jSubMenu = jMenu;
                jSubMenus = [];
            end
            if ~ismember(AllMod{iMod}, {'SEEG','ECOG+SEEG'})
                gui_component('MenuItem', jSubMenu, [], '3D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DSensorCap', [], UseSmoothing, hFig));
                if ~ismember(AllMod{iMod}, {'NIRS','ECOG'})
                    gui_component('MenuItem', jSubMenu, [], '2D Sensor cap', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '2DSensorCap', [], UseSmoothing, hFig));
                    gui_component('MenuItem', jSubMenu, [], '2D Disc',       IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '2DDisc',      [], UseSmoothing, hFig));
                end
            end
            % 2D Layout
            if is2DLayout
                gui_component('MenuItem', jSubMenu, [], '2D Layout', IconLoader.ICON_2DLAYOUT, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '2DLayout'));
            end
            % 3D Electrodes
            if ~AlwaysCreate
                if strcmpi(AllMod{iMod}, 'EEG')
                    gui_component('MenuItem', jSubMenu, [], '3D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DElectrodes'));
                elseif strcmpi(AllMod{iMod}, 'ECOG')
                    gui_component('MenuItem', jSubMenu, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '2DElectrodes'));
                    gui_component('MenuItem', jSubMenu, [], '3D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DElectrodes'));
                elseif ismember(AllMod{iMod}, {'SEEG', 'ECOG+SEEG'})
                    gui_component('MenuItem', jSubMenu, [], '2D Electrodes', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '2DElectrodes'));
                    gui_component('MenuItem', jSubMenu, [], '3D Electrodes (Head)',   IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DElectrodes-Scalp'));
                    gui_component('MenuItem', jSubMenu, [], '3D Electrodes (Cortex)', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DElectrodes-Cortex'));
                    gui_component('MenuItem', jSubMenu, [], '3D Electrodes (MRI 3D)', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@view_topography, FileName, AllMod{iMod}, '3DElectrodes-MRI'));
                end
            end
        end
    else
        jSubMenus = [];
    end
end


%% ===== MRI SEGMENTATION =====
function fcnMriSegment(jPopup, sSubject, iSubject, iAnatomy, isAtlas, isCt)
    import org.brainstorm.icon.*;
    % No anatomy: nothing to do
    if isempty(sSubject.Anatomy)
        return;
    end
    % Using default anatomy
    if isempty(iAnatomy)
        if ~isempty(sSubject.iAnatomy) && (sSubject.iAnatomy <= length(sSubject.Anatomy))
            MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        else
            return
        end
    elseif (length(iAnatomy) == 1)
        MriFile = sSubject.Anatomy(iAnatomy).FileName;
    else
        MriFile = {sSubject.Anatomy(iAnatomy).FileName};
    end
    % Menu label
    volType = 'MRI';
    volIcon = 'ICON_ANATOMY';
    if isCt
        volType = 'CT';
        volIcon = 'ICON_VOLCT';
    end
    % Add menu separator
    AddSeparator(jPopup);

    % === MRI/CT ===
    if ~isAtlas
        % Create sub-menu
        jMenu = gui_component('Menu', jPopup, [], [volType, ' segmentation'], IconLoader.(volIcon));
        % === MESH FROM THRESHOLD CT ===
        if (length(iAnatomy) <= 1) && isCt
            gui_component('MenuItem', jMenu, [], 'Generate threshold mesh from CT', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)tess_isosurface(MriFile));
        end
        % === GENERATE HEAD/BEM ===
        if (length(iAnatomy) <= 1) && ~isCt
            gui_component('MenuItem', jMenu, [], 'Generate head surface', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)tess_isohead(MriFile));
            gui_component('MenuItem', jMenu, [], 'Generate BEM surfaces', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_generate_bem, 'ComputeInteractive', iSubject, iAnatomy));
        end
        % === GENERATE FEM ===
        if (length(iAnatomy) <= 2) && ~isCt  % T1 + optional T2
            jItemFem = gui_component('MenuItem', jMenu, [], 'Generate FEM mesh', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_fem_mesh, 'ComputeInteractive', iSubject, iAnatomy));
        end
        % === MRI SEGMENTATION ===
        if (length(iAnatomy) <= 1) && ~isCt
            AddSeparator(jMenu);
            % gui_component('MenuItem', jMenu, [], 'SPM12 canonical surfaces', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_generate_canonical, 'ComputeInteractive', iSubject, iAnatomy));
            gui_component('MenuItem', jMenu, [], '<HTML><B>CAT12</B>: Cortex, atlases, tissues', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_segment_cat12, 'ComputeInteractive', iSubject, iAnatomy));
            gui_component('MenuItem', jMenu, [], '<HTML><B>BrainSuite</B>: Cortex, atlases', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_segment_brainsuite, 'ComputeInteractive', iSubject, iAnatomy));
            if ~ispc
                gui_component('MenuItem', jMenu, [], '<HTML><B>FastSurfer</B>: Cortex, atlases', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_segment_fastsurfer, 'ComputeInteractive', iSubject, iAnatomy));
                gui_component('MenuItem', jMenu, [], '<HTML><B>FreeSurfer</B>: Cortex, atlases', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_segment_freesurfer, 'ComputeInteractive', iSubject, iAnatomy));
            end
            gui_component('MenuItem', jMenu, [], '<HTML><B>SPM12</B>: Tissues, MNI normalization', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_mni_normalize, 'ComputeInteractive', MriFile, 'segment'));
            gui_component('MenuItem', jMenu, [], '<HTML><B>FieldTrip</B>: Tissues, BEM surfaces', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_ft_volumesegment, 'ComputeInteractive', iSubject, iAnatomy));
            if ~ispc
                gui_component('MenuItem', jMenu, [], '<HTML><B>FSL/BET</B>: Extract head', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)bst_call(@process_segment_fsl, 'ComputeInteractive', iSubject, iAnatomy)); 
            end
        elseif (length(iAnatomy) == 2)   % T1 + T2
            if ~ispc
                AddSeparator(jMenu);
                gui_component('MenuItem', jMenu, [], '<HTML><B>FreeSurfer</B>: Cortex, atlases', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_segment_freesurfer, 'ComputeInteractive', iSubject, iAnatomy));
            end
        end
        % === DEFACE MRI ===
        if isempty(iAnatomy)
            gui_component('MenuItem', jPopup, [], 'Deface anatomy', IconLoader.ICON_ANATOMY, [], @(h,ev)process_mri_deface('Compute', iSubject, struct('isDefaceHead', 1)));
        else
            gui_component('MenuItem', jPopup, [], 'Deface volume', IconLoader.(volIcon), [], @(h,ev)process_mri_deface('Compute', MriFile, struct('isDefaceHead', 0)));
        end
        % === SEEG/ECOG ===
        if (length(iAnatomy) <= 1) && iSubject ~=0
            gui_component('MenuItem', jPopup, [], 'SEEG/ECOG implantation', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@panel_ieeg, 'CreateImplantation', MriFile));
        end
          
    % === TISSUE SEGMENTATION ===
    elseif (length(iAnatomy) == 1) && ~isempty(strfind(lower(sSubject.Anatomy(iAnatomy).Comment), 'tissues'))
        gui_component('MenuItem', jPopup, [], 'Generate triangular meshes', IconLoader.ICON_SURFACE_SCALP, [], @(h,ev)bst_call(@tess_meshlayer, sSubject.Anatomy(iAnatomy).FileName));
        gui_component('MenuItem', jPopup, [], 'Generate hexa mesh (FieldTrip)', IconLoader.ICON_FEM, [], @(h,ev)bst_call(@process_ft_prepare_mesh_hexa, 'ComputeInteractive', iSubject, iAnatomy));
    end
end

                    
%% ===== GET ALL FILENAMES =====
function FileNames = GetAllFilenames(bstNodes, targetType, isExcludeBad, isFullPath)
    % Parse inputs
    if (nargin < 4) || isempty(isFullPath)
        isFullPath = 1;
    end
    if (nargin < 3) || isempty(isExcludeBad)
        isExcludeBad = 1;
    end
    % Prepare list of the files to be concatenated
    FileNames = {};
    for iNode = 1:length(bstNodes)
        switch char(bstNodes(iNode).getType())
            case 'datalist'
                [iDepStudies, iDepItems] = tree_dependencies(bstNodes(iNode), targetType);
                if isequal(iDepStudies, -10)
                    disp('BST> Error in tree_dependencies.');
                    continue;
                end
                for i = 1:length(iDepStudies)
                    sStudy = bst_get('Study', iDepStudies(i));
                    if (~isExcludeBad || ~sStudy.Data(iDepItems(i)).BadTrial)
                        FileNames{end+1} = sStudy.Data(iDepItems(i)).FileName;
                        if isFullPath
                            FileNames{end} = file_fullpath(FileNames{end});
                        end
                    end
                end
            case 'matrixlist'
                [iDepStudies, iDepItems] = tree_dependencies(bstNodes(iNode), targetType);
                if isequal(iDepStudies, -10)
                    disp('BST> Error in tree_dependencies.');
                    continue;
                end
                for i = 1:length(iDepStudies)
                    sStudy = bst_get('Study', iDepStudies(i));
                    FileNames{end+1} = sStudy.Matrix(iDepItems(i)).FileName;
                    if isFullPath
                        FileNames{end} = file_fullpath(FileNames{end});
                    end
                end
            case 'link'
                FileNames{end+1} = char(bstNodes(iNode).getFileName());
            otherwise
                FileNames{end+1} = char(bstNodes(iNode).getFileName());
                if isFullPath
                    FileNames{end} = file_fullpath(FileNames{end});
                end
        end
    end
end

%% ===== CHECK SURFACE ALIGNMENT WITH MRI =====
function SurfaceCheckAlignment_Callback(bstNode)
    bst_progress('start', 'Check surface alignment', 'Loading MRI and surface...');
    % Get subject information 
    iSubject = bstNode.getStudyIndex();
    sSubject = bst_get('Subject', iSubject);
    % If no MRI is defined : cannot check alignment
    if isempty(sSubject.iAnatomy)
        bst_error('You must define a default MRI before checking alignment.', 'Check alignment MRI/surface', 0);
        return;
    end
    % Get default MRI and target surface
    MriFile     = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    SurfaceFile = char(bstNode.getFileName());
    % Load MRI
    sMri = bst_memory('LoadMri', MriFile);
    % If MRI is defined but not oriented
    if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R)
        bst_error('You must select MRI fiducials before aligning a surface on it', 'Check alignment MRI/surface', 0);
        return;
    end
    % Display MRI and Surface with MRIViewer
    view_mri(MriFile, SurfaceFile);
    bst_progress('stop');
end


%% ===== SWAP FACES =====
function SurfaceSwapFaces_Callback(TessFile)
    bst_progress('start', 'Swap faces', 'Processing file...');
    % Load surface file (Faces field)
    TessMat = load(TessFile);
    % Swap vertex order
    TessMat.Faces = TessMat.Faces(:,[2 1 3]);
    % Delete normals, which must be recomputed
    TessMat.VertNormals = [];
    TessMat.Curvature   = [];
    TessMat.SulciMap    = [];
    % History: Swap faces
    TessMat = bst_history('add', TessMat, 'swap', 'Swap faces');
    % Save surface file
    bst_save(TessFile, TessMat, 'v7');
    bst_progress('stop');
    % Unload surface file
    bst_memory('UnloadSurface', TessFile);
end


%% ===== CLEAN SURFACE =====
function SurfaceClean_Callback(TessFile, isRemove)
    % Unload surface file
    bst_memory('UnloadSurface', TessFile);
    bst_progress('start', 'Clean surface', 'Processing file...');
    % Save current scouts modifications
    panel_scout('SaveModifications');
    % Load surface file (Faces field)
    TessMat = in_tess_bst(TessFile, 0);
    % Clean surface
    if isRemove
        % Ask for user confirmation
        isConfirm = java_dialog('confirm', [...
            'Warning: This operation may remove vertices from the surface.' 10 10 ... 
            'If you run it, you have to delete and recalculate the' 10 ...
            'headmodels and source files calculated using this surface.' 10 10 ...
            'Run the surface cleaning now?' 10 10], ...
           'Clean surface');
        if ~isConfirm
            bst_progress('stop');
            return;
        end
        % Clean file
        [TessMat.Vertices, TessMat.Faces, remove_vertices, remove_faces, TessMat.Atlas] = tess_clean(TessMat.Vertices, TessMat.Faces, TessMat.Atlas);
    end
    % Create new surface
    newTessMat = db_template('surfacemat');
    newTessMat.Faces    = TessMat.Faces;
    newTessMat.Vertices = TessMat.Vertices;
    newTessMat.Comment  = TessMat.Comment;
    % Atlas
    newTessMat.Atlas  = TessMat.Atlas;
    newTessMat.iAtlas = TessMat.iAtlas;
    if isfield(TessMat, 'Reg')
        newTessMat.Reg = TessMat.Reg;
    end
    % History
    if isfield(TessMat, 'History')
        newTessMat = bst_history('add', newTessMat, 'clean', 'Remove interpolations');
    end
    % Save cleaned surface file
    bst_save(TessFile, newTessMat, 'v7');
    % Close progresss bar
    bst_progress('stop');
    % Display message
    if isRemove
        java_dialog('msgbox', sprintf('%d vertices and %d faces removed', length(remove_vertices), length(remove_faces)), 'Clean surface');
    else
        java_dialog('msgbox', 'Done.', 'Remove interpolations');
    end
end

%% ===== EXTRACT ENVELOPE =====
function SurfaceEnvelope_Callback(TessFile)
    % Ask user the new number of vertices
    res = java_dialog('input', {'Number of vertices: (max 10000)', 'Dilate factor: (negative value for erosion)'}, 'Extract envelope', [], {'5000', '1'});
    if isempty(res) || (length(res) < 2) || isnan(str2double(res{1})) || isnan(str2double(res{2}))
        return
    end
    % Read user input
    newNbVertices = str2double(res{1});
    dilateMask = str2double(res{2});
    % Validate user input
    if newNbVertices > 10000
        java_dialog('error', 'You cannot extract an envelope greater than 10000 vertices.', 'Extract envelope');
        return
    end
    % Progress bar
    bst_progress('start', 'Cortex envelope', 'Extracting envelope...');
    % Compute surface based on MRI mask
    [sSurf, sOrig] = tess_envelope(TessFile, 'mask_cortex', newNbVertices, [], [], 0, dilateMask);
    % Build new filename and Comment
    NewTessFile = file_unique(bst_fullfile(bst_fileparts(file_fullpath(TessFile)), sprintf('tess_innerskull_cortmask_%dV.mat', size(sSurf.Vertices,1))));
    sSurf.Comment = sprintf('innerskull_cortmask_%dV', size(sSurf.Vertices,1));
    % Copy history field
    if isfield(sOrig, 'History')
        sSurf.History = sOrig.History;
    end
    % History: Downsample surface
    sSurf = bst_history('add', sSurf, 'envelope', ['Extracted envelope from: ' TessFile]);
    % Save downsized surface file
    bst_save(NewTessFile, sSurf, 'v7');
    % Make output filename relative
    NewTessFile = file_short(NewTessFile);
    % Get subject
    [sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
    % Register this file in Brainstorm database
    db_add_surface(iSubject, NewTessFile, sSurf.Comment);
    % Close progress bar
    bst_progress('stop');
end


%% ===== FILL HOLES =====
function SurfaceFillHoles_Callback(TessFile)
    bst_progress('start', 'Fill holes', 'Processing file...');
    % ===== LOAD =====
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Load surface file (Faces field)
    sHead = in_tess_bst(TessFile, 0);
    % Get subject
    [sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
    if isempty(sSubject.Anatomy)
        bst_error('No MRI available.', 'Remove surface holes');
        return;
    end
    % Load MRI
    sMri = bst_memory('LoadMri', sSubject.Anatomy(sSubject.iAnatomy).FileName);
    
    % ===== PROCESS =====
    % Remove holes
    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces);
    % Create new surface
    sHeadNew.Faces    = sHead.Faces;
    sHeadNew.Vertices = sHead.Vertices;
    sHeadNew.Comment  = [sHead.Comment, '_fill'];
    
    % ===== SAVE FILE =====
    % Create output filenames
    NewTessFile = file_unique(strrep(TessFile, '.mat', '_fill.mat'));
    % Save head
    sHeadNew = bst_history('add', sHeadNew, 'clean', 'Filled holes');
    bst_save(NewTessFile, sHeadNew, 'v7');
    db_add_surface(iSubject, NewTessFile, sHeadNew.Comment);
    bst_progress('inc', 5);
    % Stop
    bst_progress('stop');
end


%% ===== CONCATENATE SURFACES =====
function SurfaceConcatenate(TessFiles)
    % Concatenate surface files
    NewFile = tess_concatenate(TessFiles);
    % Select new file in the tree
    if ~isempty(NewFile)
        panel_protocols('SelectNode', [], NewFile);
    end
end

%% ===== AVERAGE SURFACES =====
function SurfaceAverage(TessFiles)
    % Average surface files
    [NewFile, iSurf, errMsg] = tess_average(TessFiles);
    % Select new file in the tree
    if ~isempty(NewFile)
        panel_protocols('SelectNode', [], NewFile);
    elseif ~isempty(errMsg)
        bst_error(errMsg, 'Average surfaces', 0);
    end
end

%% ===== LOAD FREESURFER SPHERE =====
function TessAddSphere(TessFile)
    [TessMat, errMsg] = tess_addsphere(TessFile);
    if ~isempty(errMsg)
        bst_error(errMsg, 'Load FreeSurfer sphere', 0);
    end
end

%% ===== LOAD BRAINSUITE SQUARE =====
function TessAddSquare(TessFile)
    [TessMat, errMsg] = tess_addsquare(TessFile);
    if ~isempty(errMsg)
        bst_error(errMsg, 'Load BrainSuite square', 0);
    end
end


%% ===== COMPUTE SOURCES (HEADMODEL) =====
function selectHeadmodelAndComputeSources(bstNodes, Version)
    % Select node
    tree_callbacks(bstNodes, 'doubleclick');
    % Compute sources
    bst_call(@panel_protocols, 'TreeInverse', bstNodes, Version);
end


%% ===== DISPLAY CHANNELS (3D) =====
function [hFig, iDS, iFig] = DisplayChannels(bstNodes, varargin)
    % Get filenames
    FileNames = cell(1,length(bstNodes));
    for iFile = 1:length(FileNames)
        FileNames{iFile} = char(bstNodes(iFile).getFileName());
    end
    % Call the appropriate display functions
    [hFig, iDS, iFig] = view_channels_3d(FileNames, varargin{:});
end


%% ===== DISPLAY MEG HELMET =====
function [hFig, iDS, iFig] = DisplayHelmet(iStudy, ChannelFile)
    % Get study
    sStudy = bst_get('Study', iStudy);
    if isempty(sStudy)
        return
    end
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % View scalp surface if available
    if ~isempty(sSubject) && ~isempty(sSubject.iScalp)
        ScalpFile = sSubject.Surface(sSubject.iScalp).FileName;
        hFig = view_surface(ScalpFile, 0.2);
    else
        hFig = [];
    end    
    % Display helmet
    bst_progress('start', 'Display MEG helmet', 'Loading sensors...');
    [hFig, iDS, iFig] = view_helmet(ChannelFile, hFig);
    bst_progress('stop');
end


%% ===== GET CHANNEL DISPLAY NAME =====
% Make the "MEG", "MEG GRAD" and "MEG MAG" types more readable for the average user
function displayType = getChannelTypeDisplay(chType, allTypes)
    switch upper(chType)
        case 'MEG'
            % If mixture of GRAD and MAG
            if any(ismember(allTypes, {'MEG GRAD', 'MEG MAG'}))
                displayType = 'MEG (all)';
            else
                displayType = 'MEG';
            end
        case 'MEG GRAD'
            displayType = 'MEG (grad)';
        case 'MEG MAG'
            displayType = 'MEG (mag)';
        case 'MEG GRAD2'
            displayType = 'MEG (grad 2)';
        case 'MEG GRAD3'
            displayType = 'MEG (grad 3)';
        case 'MEG GRADNORM'
            displayType = 'MEG (grad norm)';
        otherwise
            displayType = chType;
    end
end


%% ===== SET DEFAULT SURFACE =====
function SetDefaultSurf(iSubject, SurfaceType, iSurface)
    % Progress bar
    bst_progress('start', 'Set default', 'Updating database...');
    % Update database
    db_surface_default(iSubject, SurfaceType, iSurface);
    % Repaint tree
    panel_protocols('RepaintTree');
    % Close progress bar
    bst_progress('stop');
end

%% ===== SET DEFAULT HEADMODEL =====
function SetDefaultHeadModel(bstNode, iHeadModel, iStudy, sStudy)
    % Select this node (and unselect all the others)
    panel_protocols('MarkUniqueNode', bstNode);
    % Save in database selected file
    sStudy.iHeadModel = iHeadModel;
    bst_set('Study', iStudy, sStudy);
    % Repaint tree
    panel_protocols('RepaintTree');
end
                

%% ===== SET NUMBER OF TRIALS =====
function SetNavgData(filenameFull)
    % Load file
    DataMat = in_bst_data(filenameFull, 'nAvg', 'History');
    % Ask factor to the user 
    res = java_dialog('input', ['Enter the number of trials that were used to compute this ' 10 ...
                                'averaged file (nAvg field in the file)'], 'Set number of trials', [], num2str(DataMat.nAvg));
    if isempty(res) 
        return
    end
    DataMat.nAvg = str2double(res);
    if isnan(DataMat.nAvg) || (length(DataMat.nAvg) > 1) || (DataMat.nAvg < 0) || (round(DataMat.nAvg) ~= DataMat.nAvg)
        bst_error('Invalid value', 'Set number of trials', 0);
        return;
    end
    DataMat.Leff = DataMat.nAvg;
    % History: Set number of trials
    DataMat = bst_history('add', DataMat, 'set_trials', ['Set number of trials: ' res]);
    % Save file
    bst_save(filenameFull, DataMat, 'v6', 1);
end


%% ===== CREATE MENU: EXTRA FILES =====
function CreateMenuExtraFiles(jMenu, DataFile)
    import org.brainstorm.icon.*;
    % If the menu was already created: skip
    if (jMenu.getItemCount() > 0)
        return;
    end
    % Load sFile structure
    DataMat = in_bst_data(DataFile, 'F');
    % Get folder containing the raw file
    RawFolder = bst_fileparts(DataMat.F.filename);
    if ~isdir(RawFolder)
        return;
    end
    % Find session log file
    nFiles = 0;
    listDir = dir(bst_fullfile(RawFolder, '*.txt'));
    for i = 1:length(listDir)
        SessionsFile = bst_fullfile(RawFolder, listDir(i).name);
        gui_component('MenuItem', jMenu, [], listDir(i).name, IconLoader.ICON_EDIT, [], @(h,ev)view_text(SessionsFile, listDir(i).name, 1));
        nFiles = nFiles + 1;
    end
    % Find image files
    listDir = [dir(bst_fullfile(RawFolder, '*.jpg')), dir(bst_fullfile(RawFolder, '*.gif')), dir(bst_fullfile(RawFolder, '*.png')), dir(bst_fullfile(RawFolder, '*.tif'))];
    if ~ispc
        listDir = [listDir, dir(bst_fullfile(RawFolder, '*.JPG')), dir(bst_fullfile(RawFolder, '*.GIF')), dir(bst_fullfile(RawFolder, '*.PNG')), dir(bst_fullfile(RawFolder, '*.TIF'))];
    end
    for i = 1:length(listDir)
        ImageFile = bst_fullfile(RawFolder, listDir(i).name);
        gui_component('MenuItem', jMenu, [], listDir(i).name, IconLoader.ICON_IMAGE, [], @(h,ev)view_image(ImageFile));
        nFiles = nFiles + 1;
    end
    % Add "empty" menu if there are no files to show
    if (nFiles == 0)
        jMenuEmpty = gui_component('MenuItem', jMenu, [], '<HTML><I>(empty)</I>', [], [], []);
        jMenuEmpty.setEnabled(0);
    end
end


%% ===== LOAD SSP PROJECTORS =====
function LoadSSP(filenameFull)
    [newproj, errMsg] = import_ssp(filenameFull);
    if ~isempty(errMsg)
        bst_error(errMsg, 'Load SSP projectors', 0);
    end
end


%% ===== RESAMPLE MRI =====
function ResampleMri(MriFile)
    % Unloading everything
    bst_memory('UnloadAll', 'Forced');
    % Call resampling function
    [newMriFile, Transf, errMsg] = mri_resample(MriFile);
    % Error handling
    if ~isempty(errMsg)
        bst_error(errMsg, 'Resample MRI', 0);
    end
end


%% ===== CHANNEL: ADD HEADPOINTS =====
function ChannelAddHeadpoints(ChannelFile)
    % Call the process function
    strMsg = process_headpoints_add('AddHeadpoints', ChannelFile);
    % Display output message
    if ~isempty(strMsg)
        java_dialog('msgbox', strMsg, 'Add head points');
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
end

%% ===== CHANNEL: REMOVE HEADPOINTS =====
function ChannelRemoveHeadpoints(ChannelFile, zLimit)
    % Parse inputs
    if (nargin < 2) || isempty(zLimit)
        zLimit = [];
    end
    % Call the process function
    strMsg = process_headpoints_remove('RemoveHeadpoints', ChannelFile, zLimit);
    % Display output message
    if ~isempty(strMsg)
        java_dialog('msgbox', strMsg, 'Remove head points');
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
end


%% ===== SAVE WHITENED DATA =====
function SaveWhitenedData(ResultsFile)
    % ===== LOAD DATA =====
    % Loading sources and data
    bst_progress('start', 'Model evaluation', 'Loading sources...');
    % Load source file
    ResultsMat = in_bst_results(ResultsFile, 0,  'DataFile', 'Whitener', 'Leff', 'GoodChannel');
    % Check the type of results file
    if isempty(ResultsMat) || isempty(ResultsMat.DataFile) || isempty(ResultsMat.Whitener) || isempty(ResultsMat.nAvg) || isempty(ResultsMat.GoodChannel)
        bst_error('The following fields must be available in the file: DataFile, Whitener, nAvg, Goodchannel.', 'Save whitened data', 0);
        return;
    end
    % Load data file
    DataMat = in_bst_data(ResultsMat.DataFile);
    
    % ===== COMPUTE WHITENED DATA =====
    % Update progress bar
    bst_progress('start', 'Model evaluation', 'Saving whitened recordings...');
    % Factor to balance for averaged files 
    Factor = sqrt(ResultsMat.Leff); % is unity if both equal.
    % Compute whitened recordings 
    F = DataMat.F * 0;
    F(ResultsMat.GoodChannel,:) = Factor * ResultsMat.Whitener * DataMat.F(ResultsMat.GoodChannel,:); % whitened data to be displayed, z-units
    DataMat.F = F;
    % Update file structure
    DataMat.Comment  = [DataMat.Comment, ' | whitened'];
    DataMat.DataType = 'zscore';
    DataMat.DisplayUnits = 'z';

    % ===== SAVE FILE =====
    % Save new file
    [fPath, fBase, fExt] = bst_fileparts(file_fullpath(ResultsMat.DataFile));
    newDataFile = file_unique(fullfile(fPath, [fBase, '_zscore_whitened', fExt]));
    bst_save(newDataFile, DataMat, 'v6');
    % Get study
    [sStudy, iStudy] = bst_get('DataFile', ResultsMat.DataFile);
    % Add to database
    [sStudy, iNewData] = db_add_data(iStudy, newDataFile, DataMat);
    % Update display
    panel_protocols('UpdateNode', 'Study', iStudy);
    % Select node
    panel_protocols('SelectNode', [], 'data', iStudy, iNewData);
    % Hide progress bar 
    bst_progress('stop');
end


%% ===== NEW GROUP ANALYSIS =====
function NewGroupAnalysis()
    % Create/get group analysis subject
    [sSubject, iSubject] = bst_get('NormalizedSubject');
    % Update tree
    panel_protocols('UpdateTree');
end


%% ===== PROJECT SOURCES: ALL SUBJECTS =====
function ProjectSourcesAll(ResultFiles)
    % Get all the subjects in the protocol
    sProtocolSubjects = bst_get('ProtocolSubjects');
    % Find subjects non using the default anatomy and with a valid default cortex
    iSubjects = [];
    for i = 1:length(sProtocolSubjects.Subject)
        if ~sProtocolSubjects.Subject(i).UseDefaultAnat && ~isempty(sProtocolSubjects.Subject(i).iCortex)
            iSubjects(end+1) = i;
        end
    end
    % Ask which subject to use
    SubjectName = java_dialog('combo', '<HTML>Select the destination subject:<BR><BR>', 'Project sources', [], {sProtocolSubjects.Subject(iSubjects).Name});
    if isempty(SubjectName)
        return
    end
    iSubject = find(strcmpi(SubjectName, {sProtocolSubjects.Subject.Name}));
    % Get all cortex surfaces
    sCortex = bst_get('SurfaceFileByType', iSubject, 'Cortex', 0);
    % If there is more than one cortex surface: ask which one to use
    if (length(sCortex) > 1)
        SurfaceComment = java_dialog('combo', '<HTML>Select the destination cortex surface:<BR><BR>', 'Project sources', [], {sCortex.Comment});
        if isempty(SurfaceComment)
            return
        end
        iCortex = find(strcmpi(SurfaceComment, {sCortex.Comment}));
        if (length(iCortex) > 1)
            error('Two surfaces have the same name: Rename one before projecting the sources.');
        end
    else
        iCortex = 1;
    end
    % Project sources to the selected subject/cortex surface
    bst_project_sources(ResultFiles, sCortex(iCortex).FileName);
end


%% ===== PROJECT GRID: ALL SUBJECTS =====
function ProjectGridAll(ResultFiles)
    % Get all the subjects in the protocol
    sProtocolSubjects = bst_get('ProtocolSubjects');
    % Use all the subjects except the group analysis one (already the source)
    iSubjects = find(~strcmpi({sProtocolSubjects.Subject.Name}, bst_get('NormalizedSubjectName')));
    % Ask which subject to use
    SubjectName = java_dialog('combo', '<HTML>Select the destination subject:<BR><BR>', 'Project sources', [], {sProtocolSubjects.Subject(iSubjects).Name});
    if isempty(SubjectName)
        return
    end
    iSubject = find(strcmpi(SubjectName, {sProtocolSubjects.Subject.Name}));
    % Project source grid
    bst_project_grid(ResultFiles, iSubject, 1);
end


%% ===== IMPORT CHANNEL WITH VERIFICATIONS =====
function ImportChannelCheck(iAllStudies)
    % Check only if importing a single file
    if (length(iAllStudies) == 1)
        % Get study folder
        sStudyChan = bst_get('Study', iAllStudies(1));
        sStudyData = bst_get('DataForStudy', iAllStudies(1));
        % If there is already a channel file defined
        if ~isempty(sStudyChan.Channel) && ~isempty(sStudyChan.Channel.FileName) && ~isempty(sStudyData)
            res = java_dialog('confirm', [...
                '<HTML><B>Warning</B>: There are existing channel files and data files in this folder.<BR>', ...
                'Importing a list of channels that does not match exactly the recordings<BR>' ...
                'may damage the database and make the data inacessible.<BR><BR>' ...
                'To add 3D positions for EEG electrodes in existing recordings,<BR>' ...
                'right-click on the channel file > <B>Add EEG positions > Import from file</B>.<BR><BR>' ...
                'Do you really want to overwrite the existing channel file?'], 'Import new channel file');
            if ~res
                return;
            end
        end
    end
    % Import channels
    import_channel(iAllStudies);
end


%% ===== MRI COREGISTER =====
function MriCoregister(MriFileSrc, MriFileRef, Method, isReslice)
    [MriFileReg, errMsg] = bst_call(@mri_coregister, MriFileSrc, MriFileRef, Method, isReslice);
    if isempty(MriFileReg) || ~isempty(errMsg)
        bst_error(['Could not coregister volume.', 10, 10, errMsg], 'MRI coregistration', 0);
    end
end

function MriReslice(MriFileSrc, MriFileRef, TransfSrc, TransfRef)
    [MriFileReg, errMsg] = bst_call(@mri_reslice, MriFileSrc, MriFileRef, TransfSrc, TransfRef);
    if isempty(MriFileReg) || ~isempty(errMsg)
        bst_error(['Could not reslice volume.', 10, 10, errMsg], 'MRI reslice', 0);
    end
end