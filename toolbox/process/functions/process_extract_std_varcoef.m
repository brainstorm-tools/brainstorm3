function varargout = process_extract_std_varcoef( varargin )
    % EXTRACT_STD_VARCOEF: Extract std and coefficient of variation from file 
    % with mean in TF and std in Std field.
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
    % Authors: Pauline Amrouche, 2024
    %                
    %
    eval(macro_method);
    end
    
    
    %% ===== GET DESCRIPTION =====
    function sProcess = GetDescription() %#ok<DEFNU>
        % Description the process
        sProcess.Comment     = 'Extract std and varcoef';
        sProcess.Category    = 'File';
        sProcess.SubGroup    = 'Extract';
        sProcess.Index       = 400;
        % Definition of the input accepted by this process
        sProcess.InputTypes  = {'timefreq'};
        sProcess.OutputTypes = {'timefreq'};
        sProcess.nInputs     = 1;
        sProcess.nMinFiles   = 1;
    
        % Option: Overwrite input file with mean only
        sProcess.options.overwrite.Comment = 'Overwrite input file with mean only';
        sProcess.options.overwrite.Type    = 'checkbox';
        sProcess.options.overwrite.Value   = 1;
        % Option: Extract std
        sProcess.options.std.Comment = 'Extract std';
        sProcess.options.std.Type    = 'checkbox';
        sProcess.options.std.Value   = 1;
        % Option: Extract varcoef
        sProcess.options.varcoef.Comment = 'Extract varcoef';
        sProcess.options.varcoef.Type    = 'checkbox';
        sProcess.options.varcoef.Value   = 0;
    end
    
    %% ===== FORMAT COMMENT =====
    function Comment = FormatComment(sProcess) %#ok<DEFNU>
        Comment = sProcess.Comment;
    end
    
    %% ===== RUN =====
    function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
        % Initialize returned files
        OutputFiles = {};
    
        % Get options
        overwrite      = sProcess.options.overwrite.Value;
        extractStd     = sProcess.options.std.Value;
        extractVarcoef = sProcess.options.varcoef.Value;
    
        % Check that at least one feature is selected for extraction
        if ~(overwrite || extractStd || extractVarcoef)
            bst_report('Error', sProcess, [], 'Must select at least one feature to extract');  
            return;
        end
    
        % Get Output Study
        [sStudy, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sInputs);
    
        inputFile = sInputs(1);
        inputMat = in_bst_timefreq(inputFile.FileName);
    
        if isempty(inputMat.Std)
            bst_report('Error', sProcess, [], 'Input file must contain Std matrix.');  
            return;
        end
    
        if extractStd
            % Copy Std matrix of input file into TF field of stdFile
            newTF = inputMat.Std;
            saveMat(inputMat, inputFile, newTF, 'std', sStudy, iStudy);
        end
    
        if extractVarcoef
            % Varcoef = std ./ mean
            newTF = inputMat.Std ./ inputMat.TF;
            saveMat(inputMat, inputFile, newTF, 'varcoef', sStudy, iStudy);
        end
    
        if overwrite
            % Do not change TF
            newMat.Std = [];
            % Update the function name
            newMat.Options = inputMat.Options;
            newMat.Options.WindowFunction = 'mean';
            % Update Comment
            newMat.Comment = replace(inputMat.Comment, 'mean+std', 'mean');
            % Add extraction in history
            newMat.History = inputMat.History;
            newMat = bst_history('add', newMat, 'extract_std_varcoef', sprintf('mean matrix extracted from %s', inputFile.FileName));
            fileName = file_fullpath(inputFile.FileName);
            bst_save(fileName, newMat, [], 1);
        end
        db_reload_studies(iStudy);
    end
    
    function newMat = saveMat(inputMat, inputFile, newTF, function_name, sStudy, iStudy)
        newMat = inputMat;
        newMat.TF = newTF;
        newMat.Std = [];
        % Update the function name
        newMat.Options.WindowFunction = function_name;
        % Update Comment, replace mean+std with function name
        newMat.Comment = replace(inputMat.Comment, 'mean+std', function_name);
        % Add extraction in history
        newMat = bst_history('add', newMat, 'extract_std_varcoef', sprintf('%s matrix extracted from %s', function_name, inputFile.FileName));
        [~, inputFilename] = bst_fileparts(inputFile.FileName);
        output = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [inputFilename, function_name]);
        % Save the file
        bst_save(output, newMat, 'v6');
        db_add_data(iStudy, output, newMat);
    end
    