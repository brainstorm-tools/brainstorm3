function varargout = process_ft_dipolefitting( varargin )
% PROCESS_FT_DIPOLEFITTING: Call FieldTrip function ft_dipolefitting.
%
% REFERENCES: 
%     - http://www.fieldtriptoolbox.org/reference/ft_dipolefitting
%     - http://www.fieldtriptoolbox.org/tutorial/natmeg/dipolefitting

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
% Authors: Jeremy T. Moreau, Elizabeth Bock, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_dipolefitting';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 350;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/DipoleFitting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'dipoles'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Time window
    sProcess.options.label1.Comment = '<B>Input options</B>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Options: Sensor type
    sProcess.options.sensortypes.Comment = 'Sensor type or names: ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    
    % Options: Dipole model
    sProcess.options.label2.Comment = '<BR><B>Dipole fitting options</B>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.dipolemodel.Comment = {'Moving dipole', 'Regional dipole', 'Dipole type: '};
    sProcess.options.dipolemodel.Type    = 'radio_line';
    sProcess.options.dipolemodel.Value   = 1;
    % Options: Number of dipoles
    sProcess.options.numdipoles.Comment = 'Number of dipoles to fit: ';
    sProcess.options.numdipoles.Type    = 'value';
    sProcess.options.numdipoles.Value   = {1, 'dipoles', 0};
    % Options: Initial grid
    sProcess.options.volumegrid.Comment = {'panel_sourcegrid', 'Initial dipole grid: '};
    sProcess.options.volumegrid.Type    = 'editpref';
    sProcess.options.volumegrid.Value   = [];
    % Options: Symmetry constraint
    sProcess.options.symmetry.Comment = 'Left-right symmetry constraint (for two dipoles only)';
    sProcess.options.symmetry.Type    = 'checkbox';
    sProcess.options.symmetry.Value   = 0;
    
    % Options: Comment
    sProcess.options.label3.Comment = '<BR><B>Output options</B>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.filetag.Comment = 'Output file tag: ';
    sProcess.options.filetag.Type    = 'text';
    sProcess.options.filetag.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    % Initialize FieldTrip
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    bst_plugin('SetProgressLogo', 'fieldtrip');
    
    % ===== GET OPTIONS =====
    SensorTypes = sProcess.options.sensortypes.Value;
    TimeWindow  = sProcess.options.timewindow.Value{1};
    NumDipoles  = sProcess.options.numdipoles.Value{1};
    % Dipole model
    switch (sProcess.options.dipolemodel.Value)
        case 1,  DipoleModel = 'moving';
        case 2,  DipoleModel = 'regional';
    end
    % Symmetry constraints
    if (sProcess.options.symmetry.Value) && (NumDipoles == 2)
        SymmetryConstraint = 'y';
    else
        SymmetryConstraint = [];
    end
    % Initial grid
    if isfield(sProcess.options, 'volumegrid') && isfield(sProcess.options.volumegrid, 'Value') && ~isempty(sProcess.options.volumegrid.Value)
        GridOptions = sProcess.options.volumegrid.Value;
    else
        GridOptions = bst_get('GridOptions_dipfit');
    end
    % File tag
    fileTag = sProcess.options.filetag.Value;
    if isempty(fileTag)
        c = clock();
        fileTag = sprintf('%02.0f%02.0f%02.0f_%02.0f%02.0f', c(1)-2000, c(2:5));
    end

    % ===== LOAD INPUTS =====
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Get selected sensors
    iChannels = channel_find(ChannelMat.Channel, SensorTypes);
    if isempty(iChannels)
        bst_report('Error', sProcess, sInput, ['Channels "' SensorTypes '" not found in channel file.']);
        return;
    end
    % Check the sensor types (only one type allowed)
    AllTypes = unique({ChannelMat.Channel(iChannels).Type});
    if (length(AllTypes) > 1) && all(ismember(AllTypes, {'MEG MAG', 'MEG GRAD'}))
        AllTypes = setdiff(AllTypes, {'MEG MAG', 'MEG GRAD'});
        AllTypes = union(AllTypes, 'MEG');
    end
    if (length(AllTypes) ~= 1)
        bst_report('Error', sProcess, sInput, 'FieldTrip dipole fitting works only on one sensor type at a time.');
        return;
    elseif ~ismember(AllTypes{1}, {'MEG','EEG','MEG MAG','MEG GRAD', 'MEG GRAD2', 'MEG GRAD3'})
        bst_report('Error', sProcess, sInput, 'Only MEG and EEG sensor types are supported at this moment.');
        return;
    end

    % Get head model
    sHeadModel = bst_get('HeadModelForStudy', sInput.iStudy);
    % Error: No head model
    if isempty(sHeadModel)
        bst_report('Error', sProcess, sInput, 'No head model available for this data file.');
        return;
    end
    
    % Load data
    DataFile = sInput.FileName;
    DataMat = in_bst_data(DataFile);
    % Remove bad channels
    iBadChan = find(DataMat.ChannelFlag == -1);
    iChannels = setdiff(iChannels, iBadChan);
    % Error: All channels tagged as bad
    if isempty(iChannels)
        bst_report('Error', sProcess, sInput, 'All the selected channels are tagged as bad.');
        return;
    end
    

    % ===== CALL FIELDTRIP =====
    % Load head model
    HeadModelMat = in_bst_headmodel(sHeadModel.FileName);
    % Convert head model
    ftHeadmodel = out_fieldtrip_headmodel(HeadModelMat, ChannelMat, iChannels);
    if strcmpi(ftHeadmodel.type, 'openmeeg')
        bst_report('Error', sProcess, sInput, 'OpenMEEG headmodel not supported for dipole fitting: Compute another head model first.');
        return;
    end
    % Convert data file
    ftData = out_fieldtrip_data(DataMat, ChannelMat, iChannels, 1);
    % Generate rough grid for first estimation
    GridLoc = bst_sourcegrid(GridOptions, HeadModelMat.SurfaceFile);
    
    % Initialise unlimited progress bar
    bst_progress('text', 'Calling FieldTrip function: ft_dipolefitting...');
    % Prepare FieldTrip cfg structure
    cfg = [];
    cfg.channel     = {ChannelMat.Channel(iChannels).Name};
    cfg.headmodel   = ftHeadmodel;
    cfg.latency     = TimeWindow;
    cfg.numdipoles  = NumDipoles;
    cfg.model       = DipoleModel;
    cfg.nonlinear   = 'yes';
    cfg.grid.pos    = GridLoc;
    cfg.grid.inside = ones(size(GridLoc,1),1);
    cfg.grid.unit   = 'm';
    cfg.symmetry    = SymmetryConstraint;
    cfg.feedback    = 'textbar';
    % Grid search: Only if there is one dipole (not supported by ft_dipolefitting otherwise)
    if (NumDipoles == 1) || ((NumDipoles == 2) && ~isempty(SymmetryConstraint))
        cfg.gridsearch = 'yes';
    else
        cfg.gridsearch = 'no';
        bst_report('Warning', sProcess, sInput, 'When fitting multiple dipoles, the initial grid search is disabled because it is not supported by ft_dipolefitting.');
    end
    % Sensor type
    if ismember(AllTypes{1}, {'MEG', 'MEG MAG', 'MEG GRAD', 'MEG GRAD2', 'MEG GRAD3'})
        cfg.senstype = 'MEG';
    else
        cfg.senstype = 'EEG';
    end
    % Optimization function
    if exist('fminunc', 'file')
        cfg.dipfit.optimfun = 'fminunc';
    else 
        cfg.dipfit.optimfun = 'fminsearch';
    end
    % Run ft_dipolefitting
    ftDipole = ft_dipolefitting(cfg, ftData);
    % Check if something was returned
    if isempty(ftDipole) || isempty(ftDipole.dip) || all(ftDipole.dip(1).pos(:) == 0) || all(ftDipole.dip(1).mom(:) == 0)
        bst_report('Error', sProcess, sInput, 'Something went wrong during the execution of the FieldTrip function. Check the command window...');
        return;
    end
    % Get output dipoles
    nTime = length(ftDipole.time);
    dipTime = ftDipole.time;
    switch (DipoleModel)
        case 'moving'
            dipPos = cat(1, ftDipole.dip.pos)';
            dipMom = reshape(cat(2, ftDipole.dip.mom), 3, []);
            dipRv  = cat(2, ftDipole.dip.rv);
        case 'regional'
            dipPos = repmat(ftDipole.dip.pos, nTime, 1)';
            dipMom = reshape(ftDipole.dip.mom, 3, []);
            dipRv  = ftDipole.dip.rv;
    end
    % Replace single values for multiple dipoles
    if (NumDipoles > 1)
        dipRv = reshape(repmat(dipRv, NumDipoles, 1), 1, []);
        dipTime = reshape(repmat(dipTime, NumDipoles, 1), 1, []);        
    end
    
    % ===== OUTPUT STRUCTURE =====
    % Intialize dipole structure
    DipolesMat = db_template('dipolemat');
    DipolesMat.Time        = ftDipole.time;
    DipolesMat.DataFile    = sInput.FileName;
    DipolesMat.DipoleNames = {'ft_dipolefitting'};
    DipolesMat.Subset      = 1;
    if (NumDipoles > 1)
        strDip = [num2str(NumDipoles), '|'];
    else
        strDip = '';
    end
    DipolesMat.Comment = ['ft_dipolefitting [', strDip, process_extract_time('GetTimeString', sProcess) ']: ', fileTag];
    % Estimated dipoles
    for iDip = 1:length(dipTime)
        DipolesMat.Dipole(iDip).Index     = 1;
        DipolesMat.Dipole(iDip).Time      = dipTime(iDip);
        DipolesMat.Dipole(iDip).Origin    = [0, 0, 0];
        DipolesMat.Dipole(iDip).Loc       = dipPos(:,iDip);
        DipolesMat.Dipole(iDip).Amplitude = dipMom(:,iDip);
        DipolesMat.Dipole(iDip).Errors    = 0;
        DipolesMat.Dipole(iDip).Goodness  = 1 - dipRv(iDip);    % RV = RESIDUAL VARIANCE
    end
    % Save FieldTrip configuration structure
    DipolesMat.cfg = cfg;
    if isfield(DipolesMat.cfg, 'headmodel')
        DipolesMat.cfg = rmfield(DipolesMat.cfg, 'headmodel');
    end
    if isfield(ftDipole, 'cfg') && isfield(ftDipole.cfg, 'version')
        DipolesMat.cfg.version = ftDipole.cfg.version;
    end
       
    
    % ===== SAVE FILE =====
    % Create a file with the same name as the input data file
    [fPath, fBase, fExt] = bst_fileparts(file_fullpath(sInput.FileName));
    DipoleFile = file_unique(bst_fullfile(fPath, [strrep(fBase, 'data_', 'dipoles_'), '.mat']));
    % Save new file in Brainstorm format
    bst_save(DipoleFile, DipolesMat);
    
    % ===== UPDATE DATABASE =====
    % Create structure
    BstDipolesMat = db_template('Dipoles');
    BstDipolesMat.FileName = file_short(DipoleFile);
    BstDipolesMat.Comment  = DipolesMat.Comment;
    BstDipolesMat.DataFile = DipolesMat.DataFile;
    % Add to study
    sStudy = bst_get('Study', sInput.iStudy);
    iDipole = length(sStudy.Dipoles) + 1;
    sStudy.Dipoles(iDipole) = BstDipolesMat;
    % Save study
    bst_set('Study', sInput.iStudy, sStudy);
    % Update tree
    panel_protocols('UpdateNode', 'Study', sInput.iStudy);
    % Save database
    db_save();
    % Remove logo
    bst_plugin('SetProgressLogo', []);
    
    % Return the input file (as we cannot handle the dipole files in the pipeline editor)
    OutputFile = DipoleFile;
end



