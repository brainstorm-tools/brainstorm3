function varargout = process_pls2( varargin )
% PROCESS_PLS: Partial Least Squares.
% 
% USAGE:  OutputFiles = process_pls('Run', sProcess, sInputsA, sInputsB)

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
% Authors: Golia Shafiei, 2016-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Partial Least Squares (PLS)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 133;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/PLS';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    
    % === Name of Conditions
    sProcess.options.label1.Comment = 'Condition 1: ';
    sProcess.options.label1.Type    = 'text';
    sProcess.options.label1.Value   = '';
    sProcess.options.label2.Comment = 'Condition 2: ';
    sProcess.options.label2.Type    = 'text';
    sProcess.options.label2.Value   = '';
    % === statistics
    sProcess.options.label3.Comment = 'Number of permutations:';
    sProcess.options.label3.Type    = 'value';
    sProcess.options.label3.Value   = {500,'',0};
    sProcess.options.label4.Comment = 'Number of bootstraps:';
    sProcess.options.label4.Type    = 'value';
    sProcess.options.label4.Value   = {500,'',0};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names: ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function  OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    num_subj_lst    = length(sInputsA);
    option.num_perm = sProcess.options.label3.Value{1};
    option.num_boot = sProcess.options.label4.Value{1};
    option.method   = 1; 
    num_cond        = 2;
    
    % Make sure that sensor type field is identified by user
    if isempty(sProcess.options.sensortypes.Value)
        bst_report('Error', sProcess, sInputsA, 'Sensor type must be identified.');
        return;
    end
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        return;
    end
    % Check the number of files in input
    if (length(sInputsA) < 2) || (length(sInputsB) < 2)
        bst_report('Error', sProcess, sInputsA, 'Not enough files in input.');
        return;
    end
    % Force the same number of trials in both conditions
    if (length(sInputsA) ~= length(sInputsB))
        bst_report('Error', sProcess, sInputsA, 'The number of trials must be the same in the two sets of files.');
        return;
    end
    
    % Process separately the two types of files
    switch (sInputsA(1).FileType)
        case 'data'
            X = cell(1, length(sInputsA));
            for iInput = 1:length(sInputsA)
                   DataMat = in_bst(sInputsA(iInput).FileName, []);
                   ChannelMat= in_bst_channel(sInputsA(iInput).ChannelFile);
                   iChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, {sProcess.options.sensortypes.Value});
                   % Make sure that the entered channel type is valid
                   if isempty(iChannels)
                        bst_report('Error', sProcess, sInputsA, 'Channel type was not found.');
                        return;
                   end
                   X{1, iInput} = DataMat.F(iChannels,:);
            end
            
            X2 = cell(1, length(sInputsB));
            for iInput = 1:length(sInputsB)
                   DataMat2 = in_bst(sInputsB(iInput).FileName, []);
                   ChannelMat2 = in_bst_channel(sInputsB(iInput).ChannelFile);
                   iChannels2 = good_channel(ChannelMat2.Channel, DataMat2.ChannelFlag, {sProcess.options.sensortypes.Value});
                   % Make sure that the entered channel type is valid
                   if isempty(iChannels2)
                        bst_report('Error', sProcess, sInputsA, 'Channel type was not found.');
                        return;
                   end
                   X2{1, iInput} = DataMat2.F(iChannels2,:);
            end
            
            % Make sure that the number of channels are equal for all inputs
            for i = 1:length(sInputsA) 
                for j = 1:length(sInputsA) 
                      if (size(X{1,i}, 1) ~= size(X{1,j}, 1))
                          bst_report('Error', sProcess, sInputsA, ['The number of ', sProcess.options.sensortypes.Value, ' channels must be the same in the input files.']);
                          return;
                      end
                end
            end
            
            for i = 1:length(sInputsB) 
                for j = 1:length(sInputsB) 
                      if (size(X2{1,i}, 1) ~= size(X2{1,j}, 1))
                          bst_report('Error', sProcess, sInputsB, ['The number of ', sProcess.options.sensortypes.Value, ' channels must be the same in the input files.']);
                          return;
                      end
                end
            end
            
            new_X = X;
            for i = 1:length(sInputsA)
                    new_X{1,i} = reshape((X{1,i})', 1, []);
            end

            data_X = cell2mat(new_X);
            data_X = reshape((data_X), [] , length(sInputsA))';

            new_X2 = X2;
            for j = 1:length(sInputsB)
                    new_X2{1,j} = reshape((X2{1,j})', 1, []);
            end

            data_X2 = cell2mat(new_X2);
            data_X2 = reshape((data_X2), [] , length(sInputsB))';

            datamat_lst = cell(1);
            datamat_lst{1,1} = vertcat(data_X , data_X2);
            
            % Check for PLS toolbox 
            if ~exist('plscmd')
                 bst_report('Error', sProcess, sInputsA, 'This process requires the PLS Toolbox.');
                 return;
            end
            
            % Run PLS
            result = pls_analysis(datamat_lst, num_subj_lst, num_cond, option);
            bootstrap_ratio = result.boot_result.compare_u;
            boot_ratio_lv1 = bootstrap_ratio(:,1);
            boot_ratio_lv1 = boot_ratio_lv1';
            boot_ratio_lv1 = reshape((boot_ratio_lv1), [], size(iChannels, 2))';
            
            p_valus = zeros(1,1);
            p_valus(1,1) = result.perm_result.sprob(1,1);
            
            Contrast = zeros((num_cond), ((num_cond)-1));
            for i = 1:((num_cond)-1)
                Contrast(:,i) = result.v(:,i);
            end
            
        case 'results'
            X = cell(1, length(sInputsA));
            for iInput = 1:length(sInputsA)
                  DataMat = in_bst(sInputsA(iInput).FileName, []);
                  % Make sure that the full time series are available
                  if isempty(DataMat.ImageGridAmp)
                      bst_report('Error', sProcess, sInputsA, 'Full source time series are required for the source level PLS analysis.');
                      return;
                  end
                  iTime = DataMat.Time;
                  X{1, iInput} = DataMat.ImageGridAmp;
            end
            
            X2 = cell(1, length(sInputsB));
            for iInput = 1:length(sInputsB)
                  DataMat2 = in_bst(sInputsB(iInput).FileName, []);
                  % Make sure that the full time series are available
                  if isempty(DataMat2.ImageGridAmp)
                      bst_report('Error', sProcess, sInputsA, 'Full source time series are required for the source level PLS analysis.');
                      return;
                  end
                  iTime = DataMat2.Time;
                  X2{1, iInput} = DataMat2.ImageGridAmp;
            end
            
            new_X = X;
            for i = 1:length(sInputsA)
                    new_X{1,i} = reshape((X{1,i})', 1, []);
            end

            data_X = cell2mat(new_X);
            data_X = reshape((data_X), [] , length(sInputsA))';

            new_X2 = X2;
            for j = 1:length(sInputsB)
                    new_X2{1,j} = reshape((X2{1,j})', 1, []);
            end

            data_X2 = cell2mat(new_X2);
            data_X2 = reshape((data_X2), [] , length(sInputsB))';

            datamat_lst = cell(1);
            datamat_lst{1,1} = vertcat(data_X , data_X2);
                     
            % Check for PLS toolbox 
            if ~exist('plscmd')
                 bst_report('Error', sProcess, sInputsA, 'This process requires the PLS Toolbox.');
                 return;
            end
            
            % Run PLS
            result = pls_analysis(datamat_lst, num_subj_lst, num_cond, option);
            bootstrap_ratio = result.boot_result.compare_u;
            boot_ratio_lv1 = bootstrap_ratio(:,1);
            boot_ratio_lv1 = boot_ratio_lv1';
            boot_ratio_lv1 = reshape((boot_ratio_lv1), size(iTime,2), [])';
            
            p_valus = zeros(1,1);
            p_valus(1,1) = result.perm_result.sprob(1,1);
            
            Contrast = zeros((num_cond), ((num_cond)-1));
            for i = 1:((num_cond)-1)
                Contrast(:,i) = result.v(:,i);
            end
    end
    
    % ===== SAVE TO DATABASE =====
    % Get output study
    [tmp, iSubject] = bst_get('Subject', sInputsA(1).SubjectName);
    [sStudyIntra, iStudyIntra] = bst_get('AnalysisIntraStudy', iSubject);
    switch (sInputsA(1).FileType)
        case 'data'
            iStudy = iStudyIntra;
            DataMat.F(iChannels,:) = boot_ratio_lv1;
            DataMat.Comment = ['PLS: Bootstrap Ratio: ', sProcess.options.label1.Value, ' vs ', sProcess.options.label2.Value,  ' | ' , sProcess.options.sensortypes.Value];
            DataMat.nAvg = [];
            DataMat.DisplayUnits = 'Bootstrap Ratio';
            OutputFiles{1} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'data');
            % Save file
            bst_save(OutputFiles{1}, DataMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{1}, DataMat);
            
            % to save p-values and contrast
            PMatrix = db_template('matrixmat');
            PMatrix.Value = p_valus;
            PMatrix.Comment = ['PLS: p-value for latent variable ', ' | ' , sProcess.options.sensortypes.Value];
            OutputFiles{2} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{2}, PMatrix, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{2}, PMatrix);
            
            ContrastMat = db_template('matrixmat');
            ContrastMat.Value = Contrast';
            ContrastMat.Comment = ['PLS: Contrast ', ' | ' , sProcess.options.sensortypes.Value];
            ContrastMat.DisplayUnits = 'Design Salience';
            ContrastMat.Time = [1,2];
            ContrastMat.Description = {'LV1'};
            OutputFiles{3} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{3}, ContrastMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{3}, ContrastMat);
            
        case'results'
            iStudy = iStudyIntra;
            DataMat.ImageGridAmp = boot_ratio_lv1;
            DataMat.Comment = ['PLS: Bootstrap Ratio: ', sProcess.options.label1.Value, ' vs ', sProcess.options.label2.Value,  ' | ' , sProcess.options.sensortypes.Value];
            DataMat.nAvg = [];
            DataMat.DisplayUnits = 'Bootstrap Ratio';
            % Output filename
            OutputFiles{1} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'results');
            % Save file
            bst_save(OutputFiles{1}, DataMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{1}, DataMat);
            
            % to save p-values and contrast
            PMatrix = db_template('matrixmat');
            PMatrix.Value = p_valus;
            PMatrix.Comment = ['PLS: p-value for latent variable ', ' | ' , sProcess.options.sensortypes.Value];
            OutputFiles{2} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{2}, PMatrix, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{2}, PMatrix);
            
            ContrastMat = db_template('matrixmat');
            ContrastMat.Value = Contrast';
            ContrastMat.Comment = ['PLS: Contrast ', ' | ' , sProcess.options.sensortypes.Value];
            ContrastMat.DisplayUnits = 'Design Salience';
            ContrastMat.Time = [1,2];
            ContrastMat.Description = {'LV1'};
            OutputFiles{3} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{3}, ContrastMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{3}, ContrastMat);
    end
end
