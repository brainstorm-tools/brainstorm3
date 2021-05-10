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
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
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
    % Convert input to FieldTrip structure
    [ftData, DataMat, ChannelMat, iChannels] = out_fieldtrip_data(sInput.FileName, sInput.ChannelFile, SensorTypes, 0);

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

    
    % ===== GET RESULTS =====
    % Replace channels
    DataMat.F(iChannels,:) = scdData.trial{1}; 
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
    % Create output filename
    [fPath, fBase, fExt] = bst_fileparts(file_fullpath(sInput.FileName));
    OutputFiles{1} = file_unique(bst_fullfile(fPath, [fBase '_scd', fExt]));
    % Save on disk
    bst_save(OutputFiles{1}, DataMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFiles{1}, DataMat);
    % Remove logo
    bst_plugin('SetProgressLogo', []);
end




