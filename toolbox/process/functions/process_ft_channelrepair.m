function varargout = process_ft_channelrepair( varargin )
% PROCESS_FT_CHANNELREPAIR: Call FieldTrip function ft_channelrepair.
% Replace bad channels with interpolations of neighboring values.

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
% Authors: Roey Schurr, Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_channelrepair';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 309;
    sProcess.Description = 'http://www.fieldtriptoolbox.org/reference/ft_channelrepair';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Definition of the options
    % === INTEPROLATION METHOD
    sProcess.options.warning.Comment = ['Note that you cannot indicate the bad channels here, <BR>' ...
                                        'you need to mark them from the interface before.<BR><BR>' ...
                                        'Interpolation method:'];
    sProcess.options.warning.Type    = 'label';
    sProcess.options.method.Comment = {'Nearest: Neighbours weighted by distance', 'Average: Mean of all neighbours', 'Spline: Spherical spline', 'Slap: Surface Laplacian'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % === MAXIMAL DISTANCE BETWEEN NEIGHBOURS
    sProcess.options.maxdist.Comment = 'Maximal distance between neighbours: ';
    sProcess.options.maxdist.Type    = 'value';
    sProcess.options.maxdist.Value   = {4, 'cm', 1};
    % === SENSOR TYPES
    sProcess.options.sensortypes.Comment = 'Sensor types (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
     Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Initialize returned list of files
    OutputFiles = {};
    % Initialize FieldTrip
    [isInstalled, errMsg] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        bst_report('Error', sProcess, [], errMsg);
        return;
    end
    bst_plugin('SetProgressLogo', 'fieldtrip');
    % Get option values
    MaxDist = sProcess.options.maxdist.Value{1} / 100;   % Convert from centimeters to meters
    SensorTypes = sProcess.options.sensortypes.Value;
    switch (sProcess.options.method.Value)
        case 1,    Method  = 'nearest';   % replacs the electrode with the average of its neighbours weighted by distance
        case 2,    Method  = 'average';
        case 3,    Method  = 'spline';
        case 4,    Method  = 'slap';
        otherwise, error('Invalid method');
    end

    % ===== LOAD DATA =====
    % Convert to FieldTrip structures
    [ftData, DataMat, ChannelMat] = out_fieldtrip_data(sInput.FileName, sInput.ChannelFile, SensorTypes, 0);

    % ===== FIND NEIGHBORS =====
    % Prepare structure of neighbouring electrodes
    neicfg = struct();
    neicfg.method        = 'distance';
    neicfg.neighbourdist = MaxDist;
    if isfield(ftData, 'elec')
        neicfg.elec = ftData.elec;
    end
    if isfield(ftData, 'grad')
        neicfg.grad = ftData.grad;
    end
    neighbours = ft_prepare_neighbours(neicfg);
    
    % ===== INTERPOLATE CHANNELS =====
    % Find bad channels
    iBadChan = find(DataMat.ChannelFlag == -1);
    badchannel = {ChannelMat.Channel(iBadChan).Name};
    % Preprare structure
    intcfg = struct();
    intcfg.neighbours = neighbours;
    intcfg.method     = Method;   
    intcfg.badchannel = badchannel';
    intcfg.trials     = 1;
    interpolatedData = ft_channelrepair(intcfg, ftData);
    
    % ===== GET RESULTS =====
    % Get indices of the channels that were updated
    [tmp,I,J] = intersect({ChannelMat.Channel(iBadChan).Name}, ftData.label);
    % Replace interpolated channels
    DataMat.F(iBadChan(I),:) = interpolatedData.trial{1}(J,:);
    % Set those channels as good
    DataMat.ChannelFlag(iBadChan(I),:) = 1;
    % Add history comment
    DataMat = bst_history('add', DataMat, 'interpbad', ['Replaced bad channels with method "' Method '" (' num2str(MaxDist*100) 'cm): ' sprintf('%s ', intcfg.badchannel{:})]);
    if isfield(interpolatedData, 'cfg') && isfield(interpolatedData.cfg, 'version')
        DataMat = bst_history('add', DataMat, 'fieldtrip', interpolatedData.cfg.version.name);
        DataMat = bst_history('add', DataMat, 'fieldtrip', interpolatedData.cfg.version.id);
    end
    % Add comment tag
    DataMat.Comment = [DataMat.Comment ' | interpbad'];
    
    % ===== SAVE THE RESULTS =====
    % Create output filename
    [fPath, fBase, fExt] = bst_fileparts(file_fullpath(sInput.FileName));
    OutputFiles{1} = file_unique(bst_fullfile(fPath, [fBase '_interpbad', fExt]));
    % Save on disk
    bst_save(OutputFiles{1}, DataMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFiles{1}, DataMat);
    % Remove logo
    bst_plugin('SetProgressLogo', []);
end




