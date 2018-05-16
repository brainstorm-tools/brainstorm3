function varargout = process_pls( varargin )
% PROCESS_PLS: Partial Least Squares.
% 
% USAGE:  OutputFiles = process_pls('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
    sProcess.Index       = 703;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/PLS#More_than_two_conditions';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',  'results', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;

    % === Name of Conditions
    sProcess.options.label1.Comment = 'Number of conditions: ';
    sProcess.options.label1.Type    = 'value';
    sProcess.options.label1.Value   = {3,'',0};
    % === Number of Subjects/Trials
    sProcess.options.label2.Comment = 'Number of subjects/Trials per condition: ';
    sProcess.options.label2.Type    = 'value';
    sProcess.options.label2.Value   = {3,'',0};
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
function  OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    num_cond        = sProcess.options.label1.Value{1};
    num_subj_lst    = sProcess.options.label2.Value{1};
    option.num_perm = sProcess.options.label3.Value{1};
    option.num_boot = sProcess.options.label4.Value{1};
    option.method   = 1;
    
    % Make sure that sensor type field is identified by user
    if isempty(sProcess.options.sensortypes.Value)
        bst_report('Error', sProcess, sInputs, 'Sensor type must be identified.');
        return;
    end
    
    % Check the number of files in input
    if (length(sInputs) < 2)
        bst_report('Error', sProcess, sInputs, 'Not enough files in input.');
        return;
    end
    
    % Process separately the two types of files
    switch (sInputs(1).FileType)
        case 'data'
            X = cell((num_cond), 1);
            for j = 1:num_cond
                 X{j,1} = cell(1, (num_subj_lst));
                 n = j * (num_subj_lst);
                 if j == 1
                     for iInput = 1:(num_subj_lst)
                           DataMat = in_bst(sInputs(iInput).FileName, []);
                           ChannelMat= in_bst_channel(sInputs(iInput).ChannelFile);
                           iChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, {sProcess.options.sensortypes.Value});
                           % Make sure that the entered channel type is valid
                           if isempty(iChannels)
                                bst_report('Error', sProcess, sInputs, 'Channel type was not found.');
                                return;
                           end
                           X{j,1}{1, iInput} = DataMat.F(iChannels,:);
                     end                 
                 elseif j>1
                     for iInput = ((n-(num_subj_lst))+1) : n
                           DataMat = in_bst(sInputs(iInput).FileName, []);
                           ChannelMat= in_bst_channel(sInputs(iInput).ChannelFile);
                           iChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, {sProcess.options.sensortypes.Value});
                           % Make sure that the entered channel type is valid
                           if isempty(iChannels)
                                bst_report('Error', sProcess, sInputs, 'Channel type was not found.');
                                return;
                           end
                           X{j,1}{1, (iInput-(n-(num_subj_lst)))} = DataMat.F(iChannels,:);
                     end
                 end
            end
            

            
            % Make sure that the number of channels are equal for all inputs
            for k = 1:(num_cond)
                for i = 1:(num_subj_lst) 
                    for j = 1:(num_subj_lst) 
                          if (size(X{k,1}{1,i}, 1) ~= size(X{k,1}{1,j}, 1))
                              bst_report('Error', sProcess, sInputs, ['The number of ', sProcess.options.sensortypes.Value, ' channels must be the same in the input files.']);
                              return;
                          end
                    end
                end
            end

            new_X = X;
            for k = 1:(num_cond)
                for i = 1:(num_subj_lst)
                        new_X{k,1}{1,i} = reshape((X{k,1}{1,i})', 1, []);
                end
            end
            
            data_X = new_X;
            for k = 1:(num_cond)
                data_X{k,1} = cell2mat(new_X{k,1});
                data_X{k,1} = reshape((data_X{k,1}), [] , (num_subj_lst))';
            end

            datamat_lst = cell(1);
            datamat_lst{1,1} = vertcat(data_X{:});
          
            
            % Check for PLS toolbox 
            if ~exist('plscmd')
                 bst_report('Error', sProcess, sInputs, 'This process requires the PLS Toolbox.');
                 return;
            end
            
            % Run PLS
            result = pls_analysis(datamat_lst, num_subj_lst, num_cond, option);
            bootstrap_ratio = result.boot_result.compare_u;
            boot_ratio_lv = cell(1, ((num_cond)-1));
            for i = 1:((num_cond)-1)
                boot_ratio_lv{1,i} = bootstrap_ratio(:,i);
                boot_ratio_lv{1,i} = (boot_ratio_lv{1,i})';
                boot_ratio_lv{1,i} = reshape((boot_ratio_lv{1,i}), [], size(iChannels, 2))';
            end
            
            p_values = zeros(1,((num_cond)-1));
            for i = 1:((num_cond)-1)
               p_values(1,i) = result.perm_result.sprob(i,1);
            end
            
            Contrast = zeros((num_cond), ((num_cond)-1));
            for i = 1:((num_cond)-1)
              Contrast(:,i) = result.v(:,i);
            end
            
        case 'results'
            X = cell((num_cond), 1);
            for j = 1:num_cond
                 X{j,1} = cell(1, (num_subj_lst));
                 n = j * (num_subj_lst);
                 if j == 1
                     for iInput = 1:(num_subj_lst)
                           DataMat = in_bst(sInputs(iInput).FileName, []);
                           if isempty(DataMat.ImageGridAmp)
                              bst_report('Error', sProcess, sInputs, 'Full source time series are required for the source level PLS analysis.');
                              return;
                           end
                           iTime = DataMat.Time;
                           X{j,1}{1, iInput} = DataMat.ImageGridAmp;
                     end                 
                 elseif j>1
                     for iInput = ((n-(num_subj_lst))+1) : n
                           DataMat = in_bst(sInputs(iInput).FileName, []);
                           if isempty(DataMat.ImageGridAmp)
                              bst_report('Error', sProcess, sInputs, 'Full source time series are required for the source level PLS analysis.');
                              return;
                           end
                           iTime = DataMat.Time;
                           X{j,1}{1, (iInput-(n-(num_subj_lst)))} = DataMat.ImageGridAmp;
                     end
                 end
            end
          
            new_X = X;
            for k = 1:(num_cond)
                for i = 1:(num_subj_lst)
                        new_X{k,1}{1,i} = reshape((X{k,1}{1,i})', 1, []);
                end
            end
            
            data_X = new_X;
            for k = 1:(num_cond)
                data_X{k,1} = cell2mat(new_X{k,1});
                data_X{k,1} = reshape((data_X{k,1}), [] , (num_subj_lst))';
            end

            datamat_lst = cell(1);
            datamat_lst{1,1} = vertcat(data_X{:});
                     
            % Check for PLS toolbox 
            if ~exist('plscmd')
                 bst_report('Error', sProcess, sInputs, 'This process requires the PLS Toolbox.');
                 return;
            end
            
            % Run PLS
            result = pls_analysis(datamat_lst, num_subj_lst, num_cond, option);
            bootstrap_ratio = result.boot_result.compare_u;
            boot_ratio_lv = cell(1, ((num_cond)-1));
            for i = 1:((num_cond)-1)
                boot_ratio_lv{1,i} = bootstrap_ratio(:,i);
                boot_ratio_lv{1,i} = (boot_ratio_lv{1,i})';
                boot_ratio_lv{1,i} = reshape((boot_ratio_lv{1,i}), size(iTime,2), [])';
            end
            
            p_values = zeros(1,((num_cond)-1));
            for i = 1:((num_cond)-1)
               p_values(1,i) = result.perm_result.sprob(i,1);
            end
            
            Contrast = zeros((num_cond), ((num_cond)-1));
            for i = 1:((num_cond)-1)
              Contrast(:,i) = result.v(:,i);
            end
    end
    
    % ===== SAVE TO DATABASE =====
    % Get output study
    [tmp, iSubject] = bst_get('Subject', sInputs(1).SubjectName);
    [sStudyIntra, iStudyIntra] = bst_get('AnalysisIntraStudy', iSubject);
    switch (sInputs(1).FileType)
        case 'data'
            iStudy = iStudyIntra;
            DataMat.nAvg = [];
            DataMat.DisplayUnits = 'Bootstrap Ratio';
            for m= 1:((num_cond)-1)
                DataMat.F(iChannels,:) = boot_ratio_lv{1,m};
                DataMat.Comment = ['PLS: Bootstrap Ratio: LV', num2str(m), ' | ' , sProcess.options.sensortypes.Value];
                OutputFiles{m} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'data');
                % Save file
                bst_save(OutputFiles{m}, DataMat, 'v6');
                % Add file to database structure
                db_add_data(iStudy, OutputFiles{m}, DataMat);
            end
            
            % Save p-values
            PMatrix = db_template('matrixmat');
            PMatrix.Value = p_values;
            PMatrix.Comment = ['PLS: p-values for latent variables ', ' | ' , sProcess.options.sensortypes.Value];
            OutputFiles{num_cond} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{num_cond}, PMatrix, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{num_cond}, PMatrix);
            
            % Save contrast
            ContrastMat = db_template('matrixmat');
            ContrastMat.Value = Contrast';
            ContrastMat.Comment = ['PLS: Contrast ', ' | ' , sProcess.options.sensortypes.Value];
            ContrastMat.DisplayUnits = 'Design Salience';
            ContrastMat.Time = [1:(num_cond)];
            ContrastMat.Description = cell(1, (num_cond)-1);
            for m = 1:((num_cond)-1)
                ContrastMat.Description{1,m} = ['LV', num2str(m)];
            end
            OutputFiles{(num_cond)+1} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{(num_cond)+1}, ContrastMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{(num_cond)+1}, ContrastMat);
            
        case'results'
            iStudy = iStudyIntra;
            DataMat.nAvg = [];
            DataMat.DisplayUnits = 'Bootstrap Ratio';
            for m = 1:((num_cond)-1)
                DataMat.ImageGridAmp = boot_ratio_lv{1,m};
                DataMat.Comment = ['PLS: Bootstrap Ratio: LV', num2str(m), ' | ' , sProcess.options.sensortypes.Value];
                % Output filename
                OutputFiles{m} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'results');
                % Save file
                bst_save(OutputFiles{m}, DataMat, 'v6');
                % Add file to database structure
                db_add_data(iStudy, OutputFiles{m}, DataMat);
            end
            
            % Save p-values
            PMatrix = db_template('matrixmat');
            PMatrix.Value = p_values;
            PMatrix.Comment = ['PLS: p-values for latent variables ', ' | ' , sProcess.options.sensortypes.Value];
            OutputFiles{num_cond} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{num_cond}, PMatrix, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{num_cond}, PMatrix);
            
            % Save contrast
            ContrastMat = db_template('matrixmat');
            ContrastMat.Value = Contrast';
            ContrastMat.Comment = ['PLS: Contrast ', ' | ' , sProcess.options.sensortypes.Value];
            ContrastMat.DisplayUnits = 'Design Salience';
            ContrastMat.Time = [1:(num_cond)];
            for m = 1:((num_cond)-1)
                ContrastMat.Description{1,m} = ['LV', num2str(m)];
            end
            OutputFiles{(num_cond)+1} = bst_process('GetNewFilename', fileparts(sStudyIntra.FileName), 'matrix');
            % Save file
            bst_save(OutputFiles{(num_cond)+1}, ContrastMat, 'v6');
            % Add file to database structure
            db_add_data(iStudy, OutputFiles{(num_cond)+1}, ContrastMat);
    end
end
