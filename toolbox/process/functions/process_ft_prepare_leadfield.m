function varargout = process_ft_prepare_leadfield( varargin )
% PROCESS_FT_PREPARE_LEADFIELD: Call FieldTrip functions ft_prepare_headmodel and ft_prepare_leadfield.

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
% Authors: Francois Tadel, 2016-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_prepare_leadfield';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 355;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/tutorial/headmodel_meg';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Source space
    sProcess.options.label1.Comment = '<B>Source space</B>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.sourcespace.Comment = {'Cortex surface', 'MRI volume'; 'surface', 'volume'};
    sProcess.options.sourcespace.Type    = 'radio_label';
    sProcess.options.sourcespace.Value   = 'surface';
    % Options: Volume source model Options
    sProcess.options.volumegrid.Comment = {'panel_sourcegrid', 'MRI volume grid: '};
    sProcess.options.volumegrid.Type    = 'editpref';
    sProcess.options.volumegrid.Value   = [];
    % Option: Surfaces selection
    sProcess.options.label2.Comment = '<BR><B>Surfaces used for the head model</B>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.surfaces.Comment = {'Brainstorm: Surfaces from the database (BEM or Single shell)', 'FieldTrip: ft_volumesegment + ft_prepare_headmodel'; 'brainstorm', 'fieldtrip'};
    sProcess.options.surfaces.Type    = 'radio_label';
    sProcess.options.surfaces.Value   = 'fieldtrip';
    % Option: MEG headmodel
    sProcess.options.label3.Comment = '<BR><B>Forward modeling methods</B>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.meg.Comment = 'MEG method:';
    sProcess.options.meg.Type    = 'combobox_label';
    sProcess.options.meg.Value   = {'singleshell', {'<none>', 'Single sphere', 'Local spheres', 'Single shell', 'BEM OpenMEEG'; ...
                                                    '',       'singlesphere',  'localspheres',  'singleshell',  'openmeeg'}};
    % Option: EEG headmodel
    sProcess.options.eeg.Comment = 'EEG method:';
    sProcess.options.eeg.Type    = 'combobox_label';
    sProcess.options.eeg.Value   = {'concentricspheres', {'<none>', 'Single sphere', 'Concentric spheres', 'BEM OpenMEEG', 'BEM Christophe Phillips', 'BEM Thom Oostendorp'; ...
                                                          '',       'singlesphere',  'concentricspheres',  'openmeeg',     'bemcp',                   'dipoli'}};
    % Show options
    sProcess.options.verbose.Comment = 'Display sensor/MRI registration &nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777"><I>(may crash)</I>';
    sProcess.options.verbose.Type    = 'checkbox';
    sProcess.options.verbose.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Initialize FieldTrip
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    bst_plugin('SetProgressLogo', 'fieldtrip');
    
    % ===== GET OPTIONS =====
    % MEG headmodel
    if isfield(sProcess.options, 'meg') && isfield(sProcess.options.meg, 'Value') && iscell(sProcess.options.meg.Value) && ~isempty(sProcess.options.meg.Value{1})
        MEGMethod = sProcess.options.meg.Value{1};
    else
        MEGMethod = '';
    end
    % EEG headmodel
    if isfield(sProcess.options, 'eeg') && isfield(sProcess.options.eeg, 'Value') && iscell(sProcess.options.eeg.Value) && ~isempty(sProcess.options.eeg.Value{1})
        EEGMethod = sProcess.options.eeg.Value{1};
    else
        EEGMethod = '';
    end
    % Get all methods
    allMethods = unique({MEGMethod, EEGMethod});
    allMethods(cellfun(@isempty, allMethods)) = [];
    isBEM = any(ismember({'openmeeg', 'bemcp', 'dipoli'}, allMethods));
    % Something must be selected
    if isempty(allMethods)
        bst_report('Error', sProcess, sInputs, 'Nothing to compute.');
        return;
    end
    % Warnings
    if isequal(MEGMethod, 'localspheres')
        bst_report('Warning', sProcess, sInputs, 'The method "localspheres" might not be working in FieldTrip. Consider using "singleshell" instead.');
    end
    % Source space options
    HeadModelType = sProcess.options.sourcespace.Value;
    if strcmpi(HeadModelType, 'volume')
        if isfield(sProcess.options, 'volumegrid') && isfield(sProcess.options.volumegrid, 'Value') && ~isempty(sProcess.options.volumegrid.Value)
            GridOptions = sProcess.options.volumegrid.Value;
        else
            GridOptions = bst_get('GridOptions_headmodel');
        end
        % Group option not available
        if strcmpi(GridOptions.Method, 'group')
            bst_report('Error', sProcess, sInputs, 'Using template source grid for this process is not possible yet with this process, select another option. Post a message on the forum if you need this option implemented.');
            return;
        end
    else
        GridOptions = [];
    end
    % Type of headmodel
    SurfaceMethod = sProcess.options.surfaces.Value;
    % Display intermediate results
    isVerbose = sProcess.options.verbose.Value;

    % ===== INSTALL OPENMEEG =====
    if ismember('openmeeg', allMethods) && (system('om_assemble') ~= 0)
        % Install/load OpenMEEG
        [isOk, errMsg, PlugDesc] = bst_plugin('Install', 'openmeeg');
        if ~isOk
            bst_report('Error', sProcess, sInputs, ['Error installing OpenMEEG: ' 10 errMsg]);
            return;
        end
        % Add the OpenMEEG bin folder to the system path
        binDir = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'bin');
        setenv('path', [getenv('path'), pathsep, binDir, pathsep]);
    end

    % ===== GET STUDIES =====
    % Get channel studies
    [sChannels, iChanStudies] = bst_get('ChannelForStudy', unique([sInputs.iStudy]));
    % Check if there are channel files everywhere
    if (length(sChannels) ~= length(iChanStudies))
        bst_report('Error', sProcess, sInputs, ['Some of the input files are not associated with a channel file.' 10 'Please import the channel files first.']);
        return;
    end
    % Keep only once each channel file
    iChanStudies = unique(iChanStudies);
    
    
    % ===== LOOP ON FOLDERS =====
    for istd = 1:length(iChanStudies)

        % ===== GET SUBJECT =====
        % Get study
        [sStudy, iStudy] = bst_get('Study', iChanStudies(istd));
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
        % Check if a MRI is available for the subject
        if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
            bst_report('Error', sProcess, [], ['No MRI available for subject "' sSubject.Name '".']);
            return
        end
        % Get default cortex surface
        CortexFile = sSubject.Surface(sSubject.iCortex).FileName;

        % ===== PREPARE HEAD MODEL =====
        switch (SurfaceMethod)
            % FieldTrip: Compute surfaces using ft_volumesegment and ft_prepare_headmodel
            case 'fieldtrip'
                % Get previously computed mri mask from the database
                iTissue = find(strcmpi({sSubject.Anatomy.Comment}, 'tissues'), 1);
                if isempty(iTissue)
                    iTissue = find(~cellfun(@(c)isempty(strfind(lower(c), 'tissue')), {sSubject.Anatomy.Comment}), 1);
                end
                % If tissue mask doesn't exist yet: compute it
                if isempty(iTissue)
                    % Segmentation process
                    OPTIONS.layers     = {'brain', 'skull', 'scalp'};
                    OPTIONS.isSaveTess = 0;
                    [isOk, errMsg, TissueFile] = process_ft_volumesegment('Compute', iSubject, [], OPTIONS);
                    if ~isOk
                        bst_report('Error', sProcess, sInputs, errMsg);
                        return;
                    end
                    % Get index of tissue file
                    [sSubject, iSubject, iTissue] = bst_get('MriFile', TissueFile);
                end
                % Load saved brain mask
                bst_progress('text', 'Loading tissue mask...');
                sMriTissues = in_mri_bst(sSubject.Anatomy(iTissue).FileName);
                % Convert to FieldTrip structure
                ftGeometry = out_fieldtrip_mri(sMriTissues, 'tissues');
                % Brain mask
                ftGeometry.brain = (ftGeometry.tissues >= 1) & (ftGeometry.tissues <= 3);
                % For BEM models: skull and scalp masks
                if isBEM
                    % Skull mask
                    ftGeometry.skull = (ftGeometry.tissues == 4);
                    % Scalp
                    ftGeometry.scalp = (ftGeometry.tissues == 5);
                end
                ftGeometry = rmfield(ftGeometry, 'tissues');
                
            % Brainstorm: Use the surfaces available in the database
            case 'brainstorm'
                % Check what is needed for the various models
                if isempty(sSubject.iInnerSkull)
                    bst_report('Error', sProcess, sInputs, 'No inner skull surface in the database. Use the menu "Generate BEM surfaces" or the process "ft_volumesegment" first.');
                    return;
                elseif isBEM && (isempty(sSubject.iOuterSkull) || isempty(sSubject.iScalp))
                    bst_report('Error', sProcess, sInputs, 'No scalp or outer skull surface in the database. Use the menu "Generate BEM surfaces" or the process "ft_volumesegment" first.');
                    return;
                end
                % Get needed surfaces
                if isBEM
                    SurfaceFiles = {sSubject.Surface(sSubject.iScalp).FileName, ...
                                    sSubject.Surface(sSubject.iOuterSkull).FileName, ...
                                    sSubject.Surface(sSubject.iInnerSkull).FileName};
                else
                    SurfaceFiles = {sSubject.Surface(sSubject.iInnerSkull).FileName};
                end
                % Convert layers to FieldTrip structures
                ftGeometry = out_fieldtrip_tess(SurfaceFiles);
        end
        % ===== GET SOURCE SPACE =====
        switch (HeadModelType)
            case 'surface'
                % Load cortex surface
                SurfaceMat = in_tess_bst(CortexFile);
                GridLoc    = SurfaceMat.Vertices;
                Faces      = SurfaceMat.Faces;
                GridOrient = SurfaceMat.VertNormals;
                fileTag    = 'surf';
            case 'volume'
                % Generate volume grid
                GridLoc    = bst_sourcegrid(GridOptions, CortexFile);
                GridOrient = [];
                Faces      = [];
                fileTag    = 'vol';
        end
        % Convert to a FieldTrip grid structure
        ftGrid.pos    = GridLoc;            % source points
        ftGrid.inside = 1:size(GridLoc,1);  % all source points are inside of the brain
        ftGrid.unit   = 'm';
                
        % ===== GET CHANNEL FILE =====
        % Check if a MRI is available for the subject
        if isempty(sStudy.Channel) || isempty(sStudy.Channel.FileName)
            bst_report('Error', sProcess, [], ['No channel file available for folder "' bst_fileparts(sStudy.FileName) '".']);
            return
        end
        % Load channel file
        ChannelMat = in_bst_channel(sStudy.Channel.FileName);
        % Convert to FieldTrip structure
        [ftElec, ftGrad] = out_fieldtrip_channel(ChannelMat);
        % Cancel computation if there are not sensors
        if isempty(ftElec)
            EEGMethod = '';
        end
        if isempty(ftGrad)
            MEGMethod = '';
        end
        
        % ===== COMPUTE HEAD MODEL =====
        % Initialize saved values
        Gain = nan(length(ChannelMat.Channel), 3*length(ftGrid.pos));
        % === MEG ===
        if ~isempty(MEGMethod)
            % === MEG: FT_PREPARE_HEADMODEL ===
            bst_progress('text', 'Calling FieldTrip function: ft_prepare_headmodel... (MEG)');
            % Prepare FieldTrip cfg structure
            cfg = [];
            cfg.method = MEGMethod; 
            cfg.grad   = ftGrad;    % Sensor positions
            % Call FieldTrip function: ft_prepare_headmodel
            ftHeadmodelMeg = ft_prepare_headmodel(cfg, ftGeometry);
%             % Convert to meters (same units as the sensors)
%             ftHeadmodelMeg = ft_convert_units(ftHeadmodelMeg, 'm');
            % Display sensors/headmodel alignment
            if isVerbose
                figure; hold on;
                ft_plot_sens(ftGrad, 'style', '*b');
                ft_plot_vol(ftHeadmodelMeg, 'facecolor', 'none'); alpha 0.5;
                if ~isempty(Faces)
                    ft_plot_mesh(struct('pos',GridLoc,'tri',Faces), 'edgecolor', 'none'); camlight;
                end
            end
                    
            % === MEG: FT_PREPARE_LEADFIELD ===
            bst_progress('text', 'Calling FieldTrip function: ft_prepare_leadfield... (MEG)');
            % Prepare FieldTrip cfg structure
            cfg = [];
            cfg.grad      = ftGrad;    % Sensor positions
            cfg.grid      = ftGrid;    % Source grid
            cfg.headmodel = ftHeadmodelMeg;  % Volume conduction model
            % Call FieldTrip function: ft_prepare_leadfield
            ftLeadfieldMeg = ft_prepare_leadfield(cfg);
            
            % === MEG: GET RESULTS ===
            % Get list of output sensor indices
            iChannelsMeg = zeros(1,length(ftLeadfieldMeg.label));
            for i = 1:length(ftLeadfieldMeg.label)
                iChannelsMeg(i) = find(strcmpi(ftLeadfieldMeg.label{i}, {ChannelMat.Channel.Name}));
            end
            % Convert leadfield values in Brainstorm format
            Gain(iChannelsMeg,:) = [ftLeadfieldMeg.leadfield{:}];
        else
            ftHeadmodelMeg = [];
            iChannelsMeg = [];
        end

        % === EEG ===
        if ~isempty(EEGMethod)
            % === EEG: FT_PREPARE_HEADMODEL ===
            bst_progress('text', 'Calling FieldTrip function: ft_prepare_headmodel... (EEG)');
            % Prepare FieldTrip cfg structure
            cfg = [];
            cfg.method = EEGMethod; 
            cfg.elec   = ftElec;    % Sensor positions
            % Call FieldTrip function: ft_prepare_headmodel
            ftHeadmodelEeg = ft_prepare_headmodel(cfg, ftGeometry);
%             % Convert to meters (same units as the sensors)
%             ftHeadmodelEeg = ft_convert_units(ftHeadmodelEeg, 'm');
            % Display sensors/headmodel alignment
            if isVerbose
                figure; hold on;
                ft_plot_sens(ftElec, 'style', '*b');
                ft_plot_vol(ftHeadmodelEeg, 'facecolor', 'none'); alpha 0.5;
                if ~isempty(Faces)
                    ft_plot_mesh(struct('pos',GridLoc,'tri',Faces), 'edgecolor', 'none'); camlight;
                end
            end
            
            % === EEG: FT_PREPARE_LEADFIELD ===
            bst_progress('text', 'Calling FieldTrip function: ft_prepare_leadfield... (EEG)');
            % Prepare FieldTrip cfg structure
            cfg = [];
            cfg.elec      = ftElec;    % Sensor positions
            cfg.grid      = ftGrid;    % Source grid
            cfg.headmodel = ftHeadmodelEeg;  % Volume conduction model
            % Call FieldTrip function: ft_prepare_leadfield
            ftLeadfieldEeg = ft_prepare_leadfield(cfg);
            
            % === EEG: GET RESULTS ===
            % Get list of output sensor indices
            iChannelsEeg = zeros(1,length(ftLeadfieldEeg.label));
            for i = 1:length(ftLeadfieldEeg.label)
                iChannelsEeg(i) = find(strcmpi(ftLeadfieldEeg.label{i}, {ChannelMat.Channel.Name}));
            end
            % Convert leadfield values in Brainstorm format
            Gain(iChannelsEeg,:) = [ftLeadfieldEeg.leadfield{:}];
        else
            ftHeadmodelEeg = [];
            iChannelsEeg = [];
        end
        
        % ===== COPY PARAMETERS OF SPHERICAL MODELS =====
        % Copy parameters for spherical head models
        if ismember(MEGMethod, {'singlesphere', 'localspheres'}) || ismember(EEGMethod, {'singlesphere', 'concentricspheres'})
            Param = repmat(struct('Center', [], 'Radii',  []), 1, length(ChannelMat.Channel));
            if isequal(MEGMethod, 'singlesphere')
                [Param(iChannelsMeg).Radii]  = deal(ftHeadmodelMeg.r);
                [Param(iChannelsMeg).Center] = deal(ftHeadmodelMeg.o(:));
            end
            if isequal(MEGMethod, 'localspheres')
                for i = 1:length(iChannelsMeg)
                    Param(iChannelsMeg(i)).Radii  = ftHeadmodelMeg.r(i);
                    Param(iChannelsMeg(i)).Center = ftHeadmodelMeg.o(i,:);
                end
            end
            if isequal(EEGMethod, 'singlesphere') || isequal(EEGMethod, 'concentricspheres')
                [Param(iChannelsEeg).Radii]  = deal(ftHeadmodelEeg.r);
                [Param(iChannelsEeg).Center] = deal(ftHeadmodelEeg.o(:));
            end
        else
            Param = [];
        end
        
        % ===== SAVE OUTPUT =====
        bst_progress('text', 'Saving head model...');
        % Create structure
        HeadModelMat = db_template('headmodelmat');
        HeadModelMat.MEGMethod      = MEGMethod;
        HeadModelMat.EEGMethod      = EEGMethod;
        HeadModelMat.Gain           = Gain;
        HeadModelMat.HeadModelType  = HeadModelType;
        HeadModelMat.GridLoc        = GridLoc;
        HeadModelMat.GridOrient     = GridOrient;
        HeadModelMat.GridOptions    = GridOptions;
        HeadModelMat.SurfaceFile    = CortexFile;
        HeadModelMat.ftHeadmodelMeg = ftHeadmodelMeg;
        HeadModelMat.ftHeadmodelEeg = ftHeadmodelEeg;
        HeadModelMat.Param          = Param;
        % Build default comment
        methodComment = '';
        if ~isempty(MEGMethod)
            methodComment = [methodComment, ' ft_', MEGMethod];
        end
        if ~isempty(EEGMethod)
            methodComment = [methodComment, ' ft_', EEGMethod];
        end
        HeadModelMat.Comment = [methodComment(2:end), ' (', HeadModelType, ')'];
        % History: compute head model
        HeadModelMat = bst_history('add', HeadModelMat, 'compute', ['Compute head model: ft_prepare_leadfield, ' HeadModelMat.Comment]);
        
        % Output file name
        HeadModelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['headmodel_', fileTag, strrep(methodComment, ' ', '_'), '.mat']);
        HeadModelFile = file_unique(HeadModelFile);
        % Save file
        bst_save(HeadModelFile, HeadModelMat, 'v7');
        
        % ===== REGISTER NEW FILE =====
        % New database entry
        newHeadModel = db_template('HeadModel');
        newHeadModel.FileName      = file_win2unix(file_short(HeadModelFile));
        newHeadModel.Comment       = HeadModelMat.Comment;
        newHeadModel.HeadModelType = HeadModelMat.HeadModelType;
        newHeadModel.MEGMethod     = HeadModelMat.MEGMethod;
        newHeadModel.EEGMethod     = HeadModelMat.EEGMethod;
        % Update Study structure
        iHeadModel = length(sStudy.HeadModel) + 1;
        sStudy.HeadModel(iHeadModel) = newHeadModel;
        sStudy.iHeadModel = iHeadModel;
        % Update DataBase
        bst_set('Study', iStudy, sStudy);
        panel_protocols('UpdateNode', 'Study', iStudy);
    end
    % Save database
    db_save();
    % Remove logo
    bst_plugin('SetProgressLogo', []);
    % Return the data files in input
    OutputFiles = {sInputs.FileName};
end



