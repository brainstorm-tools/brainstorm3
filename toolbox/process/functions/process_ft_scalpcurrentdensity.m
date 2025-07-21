function varargout = process_ft_scalpcurrentdensity( varargin )
% PROCESS_FT_SCALPCURRENTDENSITY: Call FieldTrip function ft_scalpcurrentdensity.
%
% DESCRIPTION: 
%    Computes an estimate of the SCD using the second-order derivative (the surface Laplacian)
%    of the EEG potential distribution.
%    Reference documentation: http://www.fieldtriptoolbox.org/reference/ft_scalpcurrentdensity
%
%    Output units are arbitrary: 
%    https://github.com/fieldtrip/fieldtrip/issues/1043

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
% Authors: Svetlana Pinet, 2015
%          Francois Tadel, 2015-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FieldTrip: ft_scalpcurrentdensity';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 310;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % Definition of the options
    % === INTEPROLATION METHOD
    % Method
    sProcess.options.method_label.Comment = '<B>Interpolation method</B>';
    sProcess.options.method_label.Type    = 'label';
    sProcess.options.method.Comment = {'Finite-difference', 'Spherical spline', 'Hjorth approximation'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 2;
    % === SENSOR TYPES
    sProcess.options.sensortypes.Comment = 'Sensor types (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    
    % Param title
    sProcess.options.param_label1.Comment = '<BR><BR><B>Options: Hjorth approximation</B>';
    sProcess.options.param_label1.Type    = 'label';
    % Max distance between neighbors
    sProcess.options.maxdist.Comment = 'Maximal distance between neighbours: ';
    sProcess.options.maxdist.Type    = 'value';
    sProcess.options.maxdist.Value   = {5, 'cm', 1};
    
    % Param title
    sProcess.options.param_label2.Comment = '<BR><B>Options: Finite-difference / Spherical spline</B>';
    sProcess.options.param_label2.Type    = 'label';
    % Lambda
    sProcess.options.lambda.Comment = 'Regularization parameter (lambda): ';
    sProcess.options.lambda.Type    = 'value';
    sProcess.options.lambda.Value   = {1e-5, '', 6};
    % Order of splines
    sProcess.options.order.Comment = 'Order of the splines';
    sProcess.options.order.Type    = 'value';
    sProcess.options.order.Value   = {4, '', 0};    
    % Degree of Legendre polynomials
    sProcess.options.degree.Comment = 'Degree of Legendre polynomials';
    sProcess.options.degree.Type    = 'value';
    sProcess.options.degree.Value   = {20, '', 0};
    sProcess.options.label.Comment = '<FONT color="#777777">9 for less than 32 channels, 14 for less than 64 channels<BR>20 for less than 128 channels, 32 for more than 128 channels</I><BR><BR>';
    sProcess.options.label.Type    = 'label';

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
    
    % ===== GET OPTIONS =====
    Conductivity = 0.33; % Default value
    Lambda       = sProcess.options.lambda.Value{1};
    Order        = sProcess.options.order.Value{1};
    Degree       = sProcess.options.degree.Value{1};
    MaxDist      = sProcess.options.maxdist.Value{1} / 100;   % Convert from centimeters to meters
    SensorTypes  = sProcess.options.sensortypes.Value;
    switch (sProcess.options.method.Value)
        case 1,    Method  = 'finite';   
        case 2,    Method  = 'spline';
        case 3,    Method  = 'hjorth';
        otherwise, error('Invalid method');
    end

    % ===== CALL FIELDTRIP FUNCTION =====
    % Convert 'raw' input to FieldTrip 'ft_datatype_raw' structure. Only for given SensorTypes
    [ftData, DataMat, ChannelMat, iChannels] = out_fieldtrip_data(sInput.FileName, sInput.ChannelFile, SensorTypes, 0);
    sFileIn = DataMat.F;
    % Stop if there are projectors that have not being applied
    if isfield(ChannelMat, 'Projector') && numel(ChannelMat.Projector)
        pendingProjectors = any([ChannelMat.Projector.Status] ~= 2);
        if pendingProjectors > 0
            errMsg = sprintf(['Data file has %d SSP/ICA projectors that have been computed but not yet applied.\n' ...
                              'If they exist, projectors must be applied before using this method.'], pendingProjectors);
            bst_report('Error', sProcess, sInput, errMsg);
            return
        end
    end

    % Load entire 'raw' file
    [sMat, matName] = in_bst(sInput.FileName, [], 1, 1, 'no', 0);
    F = sMat.(matName);

    % Prepare options according to method chosen
    scdcfg.method = Method;
    switch Method
        case {'finite','spline'}
            scdcfg.conductivity = Conductivity;
            scdcfg.lambda       = Lambda;
            scdcfg.order        = Order;
            scdcfg.degree       = Degree;
        case 'hjorth'
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
            scdcfg.neighbours = ft_prepare_neighbours(neicfg);
    end
    
    % Call FieldTrip function
    scdData = ft_scalpcurrentdensity(scdcfg, ftData);
    F(iChannels, :) = scdData.trial{1};
    
    % ===== SAVE RESULTS =====
    % New folder name
    newCondition = [sInput.Condition, '_scd'];
    % Get new condition name
    ProtocolInfo = bst_get('ProtocolInfo');
    newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
    % Output file name derives from the condition name
    [~, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
    rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
    % Full output filename
    RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);
    % Get input study (to copy the creation date)
    sInputStudy = bst_get('AnyFile', sInput.FileName);
    % Get new condition name
    [~, ConditionName] = bst_fileparts(newStudyPath, 1);
    % Create output condition
    iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);
    % Get output study
    sOutputStudy = bst_get('Study', iOutputStudy);
    % Full file name
    MatFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), ['data_0raw_' rawBaseOut '.mat']);
    % Create an empty Brainstorm-binary file
    sFileOut = out_fopen(RawFileOut, 'BST-BIN', sFileIn, ChannelMat);

    % Add history comment
    switch Method
        case {'finite', 'spline'}
            DataMat = bst_history('add', DataMat, 'scd', ['Computed Scalp Current Density with "' Method '" method (Lambda' num2str(Lambda) ', Order ' num2str(Order) ', Degree ' num2str(Degree) ')']);
        case 'hjorth'
            DataMat = bst_history('add', DataMat, 'scd', ['Computed Scalp Current Density with "' Method '" method']);
    end
    % Add comment tag
    DataMat.Comment = [DataMat.Comment ' | scd'];

    % ===== SAVE THE RESULTS =====
    % Set Output sFile structure
    DataMat.F = sFileOut;
    % Save new link to raw .mat file
    bst_save(MatFile, DataMat, 'v6');
    % Create new channel file
    db_set_channel(iOutputStudy, ChannelMat, 2, 0);
    % Write block
    out_fwrite(sFileOut, ChannelMat, 1, [], [], F);
    % Register in BST database
    db_add_data(iOutputStudy, MatFile, DataMat);
    OutputFiles{1} = MatFile;
    % Remove logo
    bst_plugin('SetProgressLogo', []);
end




