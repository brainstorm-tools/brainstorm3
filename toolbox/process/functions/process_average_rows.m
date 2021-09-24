function varargout = process_average_rows( varargin )
% PROCESS_AVERAGE_ROWS: For each file in input, compute the average of the different frequency bands.

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
% Authors: Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Average signals';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Average';
    sProcess.Index       = 305;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === AVERAGE TYPE
    sProcess.options.label1.Comment = '<U><B>Group signals</B></U>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.avgtype.Comment = {'Average all the signals together', 'Average the signals with identical name', 'Average by scout (if signal names include vertex index)'};
    sProcess.options.avgtype.Type    = 'radio';
    sProcess.options.avgtype.Value   = 1;
    % === FUNCTION
    sProcess.options.label2.Comment = '<BR><U><B>Function</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.avgfunc.Comment = {...
        'Arithmetic average: <FONT color="#777777">mean(x)</FONT>', ...
        'Average absolute values:  <FONT color="#777777">mean(abs(x))</FONT>', ...
        'Root mean square (RMS):  <FONT color="#777777">sqrt(sum(x.^2))</FONT>', ...
        'Standard deviation: <FONT color="#777777">std(x)</FONT>', ...
        'Standard error: <FONT color="#777777">std(x)/N</FONT>', ...
        'Maximum: <FONT color="#777777">sign(x) .* max(abs(x))</FONT>', ...
        'Temporal PCA: <FONT color="#777777">First mode of svd(x)</FONT>'};
    sProcess.options.avgfunc.Type    = 'radio';
    sProcess.options.avgfunc.Value   = 1;
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Function
    if isfield(sProcess.options, 'avgfunc')
        switch(sProcess.options.avgfunc.Value)
            case 1,  CommentFunc = 'Average: ';
            case 2,  CommentFunc = 'Average/abs: ';
            case 3,  CommentFunc = 'RMS: ';
            case 4,  CommentFunc = 'Standard deviation: ';
            case 5,  CommentFunc = 'Standard error: ';
            case 6,  CommentFunc = 'Maximum: ';
            case 7,  CommentFunc = 'PCA: ';
        end
    else
        CommentFunc = 'Average: ';
    end
    % Average type
    switch(sProcess.options.avgtype.Value)
        case 1,  CommentType = 'All signals';
        case 2,  CommentType = 'By name';
        case 3,  CommentType = 'By scout';
    end
    Comment = [CommentFunc, CommentType];
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = {};
    % Get options
    switch (sProcess.options.avgtype.Value)
        case 1,  AvgType = 'all';
        case 2,  AvgType = 'name';
        case 3,  AvgType = 'scout';
    end
    switch (sProcess.options.avgfunc.Value)
        case 1,  AvgFunc = 'mean';
        case 2,  AvgFunc = 'mean_norm';
        case 3,  AvgFunc = 'rms';
        case 4,  AvgFunc = 'std';
        case 5,  AvgFunc = 'stderr';
        case 6,  AvgFunc = 'max';
        case 7,  AvgFunc = 'pca';
    end
    isOverwrite = sProcess.options.overwrite.Value;
    
    % ===== CONNECT =====
    if strcmpi(sInput.FileType, 'timefreq') && ~isempty(strfind(bst_process('GetFileTag',sInput.FileName), 'connect'))
        % Check for measure
        if ~strcmpi(AvgType, 'scout')
            bst_report('Error', sProcess, sInput, 'Connectivity matrices can be processed by scouts only.');
            return;
        end
        % Load TF file
        FileMat = in_bst_timefreq(sInput.FileName, 0);
        % Get scouts to group
        if isfield(FileMat, 'Options') && isfield(FileMat.Options, 'sScoutsA') && isstruct(FileMat.Options.sScoutsA)
            sScoutsA = FileMat.Options.sScoutsA;
        else
            sScoutsA = [];
        end
        if isfield(FileMat, 'Options') && isfield(FileMat.Options, 'sScoutsB') && isstruct(FileMat.Options.sScoutsB)
            sScoutsB = FileMat.Options.sScoutsB;
        else
            sScoutsB = [];
        end
        % Trying to rebuild scouts from row names (for connectivity matrices coming from extracted time series)
        if isempty(sScoutsB) && isempty(sScoutsA)
            % Get scouts names (removes the "@" and ".")
            if iscell(FileMat.RefRowNames)
                scoutNamesA = cellfun(@GetScoutName, FileMat.RefRowNames, 'UniformOutput', 0);
            else
                scoutNamesA = [];
            end
            if iscell(FileMat.RowNames)
                scoutNamesB = cellfun(@GetScoutName, FileMat.RowNames, 'UniformOutput', 0);
            else
                scoutNamesB = [];
            end
            [uniqueNamesA, iA] = unique(scoutNamesA);
            [uniqueNamesB, iB] = unique(scoutNamesB);
            uniqueNamesA = scoutNamesA(sort(iA));
            uniqueNamesB = scoutNamesA(sort(iB));
            % Rebuild scouts A
            if (length(uniqueNamesA) >= 1) && (length(uniqueNamesA) < length(scoutNamesA))
                sScoutsA = repmat(db_template('scout'), 1, length(uniqueNamesA));
                for iScout = 1:length(uniqueNamesA)
                    sScoutsA(iScout).Label = uniqueNamesA{iScout};
                    sScoutsA(iScout).Vertices = find(strcmpi(uniqueNamesA{iScout}, scoutNamesA));
                end
            end
            % Rebuild scouts B
            if (length(uniqueNamesB) >= 1) && (length(uniqueNamesB) < length(scoutNamesB))
                sScoutsB = repmat(db_template('scout'), 1, length(uniqueNamesB));
                for iScout = 1:length(uniqueNamesB)
                    sScoutsB(iScout).Label = uniqueNamesB{iScout};
                    sScoutsB(iScout).Vertices = find(strcmpi(uniqueNamesB{iScout}, scoutNamesB));
                end
            end
        end
        % Checking for errors in the inputs
        if isempty(sScoutsB) && isempty(sScoutsA)
            bst_report('Error', sProcess, sInput, 'No scouts are defined for this connectivity matrix.');
            return;
        end
        if (~isempty(sScoutsA) && (sum(cellfun(@length, {sScoutsA.Vertices})) ~= length(FileMat.RefRowNames))) || ...
           (~isempty(sScoutsB) && (sum(cellfun(@length, {sScoutsB.Vertices})) ~= length(FileMat.RowNames)))
            bst_report('Error', sProcess, sInput, 'Number of elements in connectivity matrix do not match the number of vertices in the scouts.');
            return;
        end
        % Call aggregate function
        FileMat = ProcessConnectScouts(FileMat, AvgFunc, sScoutsA, sScoutsB);

    % ===== TIMEFREQ =====
    elseif strcmpi(sInput.FileType, 'timefreq')
        % Load TF file
        FileMat = in_bst_timefreq(sInput.FileName, 0);
        % Check for measure
        if strcmpi(FileMat.Measure, 'none')
            bst_report('Error', sProcess, sInput, 'Cannot average complex values. Please apply a measure to the values before calling this function.');
            return;
        end
        % Check row number
        if (size(FileMat.TF, 1) == 1)
            bst_report('Error', sProcess, sInput, 'Only one row available, nothing to process.');
            return;
        end
        % Remove the signals information if averaging the signals together
        if strcmpi(AvgType, 'all')
            FileMat.RowNames = repmat({'AVG'}, size(FileMat.RowNames));
        elseif strcmpi(AvgType, 'scout') && iscell(FileMat.RowNames)
            FileMat.RowNames = cellfun(@GetScoutName, FileMat.RowNames, 'UniformOutput', 0);
        end
        % Unique row names
        uniqueRowNames = unique(FileMat.RowNames);
        newTF = zeros(length(uniqueRowNames), size(FileMat.TF,2), size(FileMat.TF,3));
        % Check for things to process
        if (length(uniqueRowNames) == length(FileMat.RowNames))
            bst_report('Error', sProcess, sInput, 'All row names are different, nothing to process.');
            return;
        end
        % Loop on the row names
        for iUnique = 1:length(uniqueRowNames)
            iRows = find(strcmp(FileMat.RowNames, uniqueRowNames{iUnique}));
            newTF(iUnique,:,:) = bst_scout_value(FileMat.TF(iRows,:,:), AvgFunc);
        end
        % Save changes
        FileMat.TF = newTF;
        FileMat.RowNames = uniqueRowNames;
        
    % ===== MATRIX =====
    elseif strcmpi(sInput.FileType, 'matrix')
        % Load TF file
        FileMat = in_bst_matrix(sInput.FileName);
        % Check row number
        if (size(FileMat.Value, 1) == 1)
            bst_report('Error', sProcess, sInput, 'Only one row available, nothing to process.');
            return;
        end
        % Remove the signals information if averaging the signals together
        if strcmpi(AvgType, 'all')
            FileMat.Description = repmat({'AVG'}, size(FileMat.Description));
        elseif strcmpi(AvgType, 'scout')
            FileMat.Description = cellfun(@GetScoutName, FileMat.Description, 'UniformOutput', 0);
        end
        % Unique row names
        uniqueRowNames = unique(FileMat.Description);
        newValue = zeros(length(uniqueRowNames), size(FileMat.Value,2), size(FileMat.Value,3));
        % Check for things to process
        if (length(uniqueRowNames) == length(FileMat.Description))
            bst_report('Error', sProcess, sInput, 'All row names are different, nothing to process.');
            return;
        end
        % Loop on the row names
        for iUnique = 1:length(uniqueRowNames)
            iRows = find(strcmp(FileMat.Description, uniqueRowNames{iUnique}));
            newValue(iUnique,:,:) = bst_scout_value(FileMat.Value(iRows,:,:), AvgFunc);
        end
        % Save changes
        FileMat.Value = newValue;
        FileMat.Description = uniqueRowNames;
    end
    % Add history entry
    switch (AvgType)
        case 'all',   FileMat = bst_history('add', FileMat, 'avgfreq', 'Average all the signals.');
        case 'name',  FileMat = bst_history('add', FileMat, 'avgfreq', 'Average signals by name.');
        case 'scout', FileMat = bst_history('add', FileMat, 'avgfreq', 'Average scouts.');
    end
    % Add file tag
    FileMat.Comment = [FileMat.Comment, ' | row_', AvgFunc];
    % Overwrite the input file
    if isOverwrite
        OutputFile = file_fullpath(sInput.FileName);
        bst_save(OutputFile, FileMat, 'v6');
    % Create a new file
    else
        % Output filename: add file tag
        OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', '_avgrows.mat');
        % If file was modified from a connect NxN to a connect 1xN file
        if ~isempty(strfind(OutputFile, '_connectn_')) && (length(FileMat.RefRowNames) == 1)
            OutputFile = strrep(OutputFile, '_connectn_', '_connect1_');
        end
        % Make file unique
        OutputFile = file_unique(OutputFile);
        % Save file
        bst_save(OutputFile, FileMat, 'v6');
        % Add file to database structure
        db_add_data(sInput.iStudy, OutputFile, FileMat);
    end
end


%% =================================================================================================
%  ====== HELPER FIGURES ===========================================================================
%  =================================================================================================

%% ====== EXTRACT SCOUT NAME ======
function RowName = GetScoutName(RowName)
    % Format: "scoutname @ filename" (extracting the same scout from multiple files)
    iAt = find(RowName == '@', 1);
    if ~isempty(iAt) && (iAt > 1)
        RowName = strtrim(RowName(1:iAt-1));
    end
    % Get the separations scoutname/vertex/component
    iDot = find(RowName == '.');
    % Format: "scoutname.ivertex" (extracting the same scout from multiple files)
    if (length(iDot) == 1) && (iDot > 1) && (iDot < length(RowName)) && ~isnan(str2double(RowName(iDot+1:end)))
        RowName = strtrim(RowName(1:iDot-1));
    % Format: "scoutname.ivertex.component" (unconstrained sources)
    elseif (length(iDot) == 2) && all(iDot > 1) && all(iDot < length(RowName)) && ~isnan(str2double(RowName(iDot(1)+1:iDot(2)-1))) && ~isnan(str2double(RowName(iDot(2)+1:end)))
        RowName = [strtrim(RowName(1:iDot(1)-1)) '.' strtrim(RowName(iDot(2)+1:end))];
    end
end


%% ===== PROCESS CONNECTIVITY MATRICES: SCOUTS ======
function FileMat = ProcessConnectScouts(FileMat, ScoutFunc, sScoutsA, sScoutsB)
    % Unpack connectivity matrix
    %if isfield(FileMat, 'Options') && isfield(FileMat.Options, 'isSymmetric') && FileMat.Options.isSymmetric && (size(FileMat.TF,1) ~= length(FileMat.RowNames)^2)
    if (length(FileMat.RowNames) == length(FileMat.RefRowNames)) && (size(FileMat.TF,1) < length(FileMat.RowNames)^2)
        FileMat.TF = process_compress_sym('Expand', FileMat.TF, length(FileMat.RowNames));
        isSymmetric = 1;
    else
        isSymmetric = 0;
    end
    % Reshape connectivity matrix to a square form
    Ntime = size(FileMat.TF,2);
    Nfreq = size(FileMat.TF,3);
    FileMat.TF = reshape(FileMat.TF, length(FileMat.RefRowNames), length(FileMat.RowNames), Ntime * Nfreq);
    % Get the scouts indices in the connectivity matrix
    if ~isempty(sScoutsA)
        indScoutsA = [1, cumsum(cellfun(@length, {sScoutsA.Vertices})) + 1];
        nScoutsA = length(sScoutsA);
    else
        nScoutsA = length(FileMat.RefRowNames); 
    end
    if ~isempty(sScoutsB)
        indScoutsB = [1, cumsum(cellfun(@length, {sScoutsB.Vertices})) + 1];
        nScoutsB = length(sScoutsB);
    else
        nScoutsB = length(FileMat.RowNames); 
    end
    % Initialize final aggregated connectivity matrix
    Rscout = zeros(nScoutsA, nScoutsB, Ntime * Nfreq);
    % ScoutsA and ScoutsB: Collapse in both dimensions
    if ~isempty(sScoutsA) && ~isempty(sScoutsB)
        % For each pair of scout: aggregate the values in dimensions 1 and 2
        for iScoutA = 1:nScoutsA
            for iScoutB = 1:nScoutsB
                % Get scout vertex indices in the connect matrix
                indA = indScoutsA(iScoutA):indScoutsA(iScoutA+1)-1;
                indB = indScoutsB(iScoutB):indScoutsB(iScoutB+1)-1;
                % Loop on the frequencies
                for i = 1:size(FileMat.TF,3)
                    switch (ScoutFunc)
                        case 'mean'
                            Rscout(iScoutA,iScoutB,i) = mean(reshape(FileMat.TF(indA,indB,i),[],1));
                        case 'max'
                            Rscout(iScoutA,iScoutB,i) = bst_max(FileMat.TF(indA,indB,i), []);
                        case 'std'
                            Rscout(iScoutA,iScoutB,i) = std(reshape(FileMat.TF(indA,indB,i),[],1));
                    end
                end
            end
        end
        % Use the scout names as the row names
        FileMat.RefRowNames = {sScoutsA.Label};
        FileMat.RowNames    = {sScoutsB.Label};
    % ScoutsA: Collapse in one dimension
    elseif ~isempty(sScoutsA)
        for iScoutA = 1:nScoutsA
            % Get scout vertex indices in the connectivity matrix
            indA = indScoutsA(iScoutA):indScoutsA(iScoutA+1)-1;
            % Loop on the frequencies
            for i = 1:size(FileMat.TF,3)
                Rscout(iScoutA,:,i) = bst_scout_value(FileMat.TF(indA,:,i), ScoutFunc);
            end
        end
        % Use the scout names as the row names
        FileMat.RefRowNames = {sScoutsA.Label};
    % ScoutsB: Collapse in one dimension
    elseif ~isempty(sScoutsB)
        for iScoutB = 1:nScoutsB
            % Get scout vertex indices in the connectivity matrix
            indB = indScoutsB(iScoutB):indScoutsB(iScoutB+1)-1;
            % Loop on the frequencies
            for i = 1:size(FileMat.TF,3)
                Rscout(:,iScoutB,i) = bst_scout_value(FileMat.TF(:,indB,i)', ScoutFunc)';
            end
        end
        % Use the scout names as the row names
        FileMat.RowNames = {sScoutsB.Label};
    end
    % Replace full connectivity matrix with aggregated one
    FileMat.TF = Rscout;
    % Reshape connectivity matrix to a linear form
    FileMat.TF = reshape(FileMat.TF, length(FileMat.RefRowNames) * length(FileMat.RowNames), Ntime, Nfreq);
    % Repack connectivity matrix
    %if isfield(FileMat, 'Options') && isfield(FileMat.Options, 'isSymmetric') && FileMat.Options.isSymmetric
    if isSymmetric
        FileMat.TF = process_compress_sym('Compress', FileMat.TF);
    end
end


