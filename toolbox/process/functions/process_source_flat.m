function varargout = process_source_flat( varargin )
% PROCESS_SOURCE_FLAT: Convert an unconstrained source file into a flat map.
%
% USAGE:  OutputFiles = process_source_flat('Run', sProcess, sInput)
%          ResultsMat = process_source_flat('Compute', ResultsMat, Method, Field)

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
% Authors: Francois Tadel, 2013-2015
%          Marc Lalancette, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Unconstrained to flat map';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 337;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation?highlight=(Unconstrained+to+flat+map)#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results'};
    sProcess.OutputTypes = {'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === SELECT METHOD
    sProcess.options.label1.Comment = ['Converts unconstrained source files (3 values per vertex: x,y,z)<BR>' 10 ...
        'to simpler files with only one value per vertex.<BR><BR>' 10 ...
        'Method used to perform this conversion:'];
    sProcess.options.label1.Type    = 'label';
    sProcess.options.method.Comment = {'<B>Norm</B>: sqrt(x^2+y^2+z^2)', ...
        '<B>PCA</B>: First mode of svd(x,y,z), maximizes retained power'; ...
        'norm', 'pca'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'norm';
    % Options: PCA
    sProcess.options.edit.Comment = {'panel_pca', ' PCA options: '}; 
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = bst_get('PcaOptions'); % empty or function that returns defaults.
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};
    % Get options
    switch(sProcess.options.method.Value)
        case {1, 'norm'}, Method = 'rms';  fileTag = 'norm';
        case {2, 'pca'},  Method = 'pca';  fileTag = 'pca';
        %case 'pcaa',      Method = 'pcaa'; fileTag = 'pcaa';
    end

    nFiles = numel(sInputs);
    bst_progress('start', 'Unconstrained to flat map', sprintf('Flattening %d files', nFiles), 0, nFiles);

    % ===== PCA =====
    % Sort and group files, then run by group
    if strncmpi(Method, 'pca', 3)
        PcaOptions = sProcess.options.edit.Value;
        % Sort to be able to efficiently re-use reference components.
        [~, iSorted] = sort({sInputs.FileName});
        sInputs = sInputs(iSorted);
        iGroups = process_average('SortFiles', sInputs, PcaOptions.AvgType);
        % Run separately for each group.
        for iG = 1:numel(iGroups)
            [GroupOutputFiles, Message] = RunPcaGroup(sInputs(iGroups{iG}), PcaOptions);
            if isempty(GroupOutputFiles) && ~isempty(Message)
                bst_report('Error', sProcess, sInputs(iGroups{iG}), Message);
                OutputFiles = {};
                return;
            end
            OutputFiles = [OutputFiles, GroupOutputFiles];
        end

    % ===== Norm =====
    else
        for iInput = 1:nFiles
            % Load the source file with full data.
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
            % Error: Not an unconstrained model
            if (ResultsMat.nComponents == 1) || (ResultsMat.nComponents == 2)
                bst_report('Error', sProcess, sInputs(iInput), 'The input file is not an unconstrained source model.');
                OutputFiles = {};
                return;
            end
            % Compute flat map
            ResultsMat = Compute(ResultsMat, Method);
            bst_progress('inc', 1);
            % Save file
            OutputFiles{iInput} = SaveResultFile(sInputs(iInput), ResultsMat, fileTag);
        end
    end
end


%% ===== RUN on PCA FILE GROUP =====
function [OutputFiles, Message] = RunPcaGroup(sInputs, PcaOptions)
    % Prepare group of result files for PCA (compute reference component across all
    % files for sign consistency), then run on individual files if needed.
    OutputFiles = {};
    Message = '';
    PrevCond = '';
    isAllLink = false;
    nInputs = numel(sInputs);

    if strcmpi(PcaOptions.Method, 'pca')
        PcaRefOrient = [];
    else
    %________________________________________________________
    % Compute reference component for this group of files.
    for iInput = 1:nInputs
        % Process by condition (already sorted)
        if ~strcmp(sInputs(iInput).Condition, PrevCond)
            PrevCond = sInputs(iInput).Condition;
            DataCov = [];
            if PcaOptions.UseDataCov
                % Use pre-computed data covariance if all files from this condition are kernel links.
                isAllLink = true;
                nF = 0;
                for iF = 0:(nInputs - iInput)
                    if ~strcmp(sInputs(iInput).Condition, PrevCond)
                        % Reached end of this condition.
                        break;
                    end
                    nF = nF + 1;
                    if ~strcmpi(file_gettype(sInputs(iInput).FileName), 'link')
                        isAllLink = false;
                        break;
                    end
                end
                if isAllLink
                    sStudy = bst_get('Study', sInputs(iInput).iStudy);
                    if numel(sStudy.NoiseCov) < 2
                        Message = 'Data covariance not found for PCA flattening with pre-computed data covariance.';
                        return;
                    end
                    DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName));
                    DataCov = DataCov.NoiseCov; % size nChanAll
                end
            end
        elseif isAllLink
            % This condition was fully taken into account with a data covariance matrix, nothing to do.
            continue;
        end

        % Sum covariance
        % Load file
        isLink = strcmpi(file_gettype(sInputs(iInput).FileName), 'link');
        if isLink
            % Load kernel
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 0);
            Field = 'ImagingKernel';
        else
            % Load the source file with full data.
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
            Field = 'ImageGridAmp';
        end
        if iInput == 1
            % Initialize covariance
            nComp = ResultsMat.nComponents;
            nVert = size(ResultsMat.(Field), 1) / nComp;
            OrientCov = zeros(nComp, nComp, nVert);
        elseif nComp ~= ResultsMat.nComponents || nVert ~= (size(ResultsMat.(Field), 1) / nComp)
            Message = 'Incompatible result dimensions (number of sources or orientations).';
        end
        if isLink
            if ~isAllLink
                % Get data covariance for this file only.
                DataCov = GetCovariance(ResultsMat.DataFile, PcaOptions, sInputs(iInput));
                nF = 1;
                %else
                % If using a pre-computed data covariance, we only get here for the first
                % file corresponding to this condition, other files are skipped above.
            end
            Kernel = permute(reshape(ResultsMat.(Field), nComp, nVert, []), [2, 3, 1]); % (nVert, nChan, nComp)
            % For each source (each [3 x nChan] page of Kernel), get K * Cov * K' -> [3 x 3]
            % For efficiency, loop on components instead of sources.
            FileOrientCov = zeros([1, nComp, size(Kernel,1), size(Kernel,2)]);
            for i = 1:ResultsMat.nComponents
                FileOrientCov(1,i,:,:) = Kernel(:,:,i) * DataCov(ResultsMat.GoodChannel, ResultsMat.GoodChannel);
            end
            % Add to sum weigthed by number of files in this condition.
            % nF is how many files from this condition that were passed to the process,
            % not necessarily those used to compute the data covariance.
            OrientCov = OrientCov + nF * sum(bsxfun(@times, permute(Kernel, [3,4,1,2]), FileOrientCov), 4); % (nComp, nComp, nVert)
        else % no kernel
            % Loop over component pairs to get covariance
            SourceData = permute(reshape(ResultsMat.(Field), nComp, nVert, []), [2, 3, 1]); % (nVert, nTime, nComp)
            FileOrientCov = zeros(size(OrientCov));
            for iC1 = 1:nComp
                for iC2 = iC1:nComp
                    FileOrientCov(iC1,iC2,:) = sum(SourceData(:, :, iC1) .* SourceData(:, :, iC2), 2);
                    if iC2 ~= iC1
                        % Fill symmetric matrix entries.
                        FileOrientCov(iC2,iC1,:) = FileOrientCov(iC1,iC2,:);
                    end
                end
            end
            OrientCov = OrientCov + FileOrientCov;
        end

        bst_progress('inc', 0.5);
    end % first file loop
    % Normalize by number of files summed.
    OrientCov = OrientCov / nInputs;

    % Compute reference component. Empty data for speed.
    ResultsMat.ImageGridAmp = [];
    [~, PcaRefOrient] = Compute(ResultsMat, 'pcaa', '', OrientCov);
    if strcmpi(PcaOptions.Method, 'pcaa')
        PcaOrient = permute(PcaRefOrient, [2, 3, 1]);
    end
    end

    %________________________________________________________
    % Compute and save PCA for individual files
    PrevCond = '';
    for iInput = 1:nInputs
        % Process by condition (already sorted)
        if ~strcmp(sInputs(iInput).Condition, PrevCond) %&& ~strcmp(sInputs(iInput).SubjectName, PrevSub)
            PrevCond = sInputs(iInput).Condition;
            if strcmpi(PcaOptions.Method, 'pcaa')
                % Check if all files from this condition are kernel links.
                isAllLink = true;
                for iF = 0:(nInputs - iInput)
                    if ~strcmp(sInputs(iInput).Condition, PrevCond)
                        % Reached end of this condition.
                        break;
                    end
                    if ~strcmpi(file_gettype(sInputs(iInput).FileName), 'link')
                        isAllLink = false;
                        break;
                    end
                end
            else
                isAllLink = false;
            end
        elseif isAllLink
            % Already saved a flattened version of this kernel.
            % Find new link for this data file.
            LinkFiles = db_links('Study', sInputs(iInput).iStudy);
            iLink = ~cellfun(@isempty, strfind(LinkFiles, [file_short(SharedFile) '|' sInputs(iInput).DataFile]));
            if sum(iLink) ~= 1
                Message = 'Problem finding the correct linked file.';
                OutputFiles = {};
                return;
            end
            OutputFiles{iInput} = LinkFiles{iLink}; %#ok<*AGROW>
            continue;
        end

        % Load file
        isLink = strcmpi(file_gettype(sInputs(iInput).FileName), 'link');
        if isLink
            % Load kernel
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 0);
            Field = 'ImagingKernel';
        else
            % Load the source file with full data.
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
            Field = 'ImageGridAmp';
        end
        % Compute
        switch PcaOptions.Method
            case 'pcaa'
                % Apply reference components directly.
                if isAllLink
                    % Save shared kernel and find link.
                    ResultsMat.DataFile = '';
                    % Keep original kernel file name, but ensure unique.
                    [KernelPath, KernelName] = bst_fileparts(file_resolve_link(sInputs(iInput).FileName));
                    iK = strfind(KernelName, '_KERNEL_');
                    SharedFile = bst_process('GetNewFilename', KernelPath, [KernelName(1:iK) 'KERNEL_' PcaOptions.Method]);
                    bst_save(SharedFile, ResultsMat, 'v6');
                    db_add_data(sInputs(iInput).iStudy, SharedFile, ResultsMat);
                    panel_protocols('UpdateNode', 'Study', sInputs(iInput).iStudy);
                    % Find link to the result kernel that was just created for this data file.
                    LinkFiles = db_links('Study', sInputs(iInput).iStudy);
                    iLink = ~cellfun(@isempty, strfind(LinkFiles, [file_short(SharedFile) '|' sInputs(iInput).DataFile]));
                    if sum(iLink) ~= 1
                        bst_report('Error', sProcess, sInputs(iInput), 'Problem finding the correct linked file.');
                        OutputFiles = {};
                        return;
                    end
                    OutputFiles{iInput} = LinkFiles{iLink};
                    continue;
                else
                    % Data was not passed when computing reference component above, so still need to project. This works for kernel or timeseries.
                    SourceData = permute(reshape(ResultsMat.(Field), nComp, nVert, []), [2, 3, 1]); % [nVert, (nTime or nChan), nComp]
                    ResultsMat.(Field) = sum(bsxfun(@times, SourceData, PcaOrient), 3); % [nSource, (nTime or nChan)]
                end
            otherwise
                % Get PCA for this file, with sign matched to reference.
                if isLink
                    % If we passed Field='ImagingKernel' without a covariance, it would do PCA on
                    % the inverse model instead of the timeseries (valid but not what we want here).
                    % Instead, pre-compute the covariance from this file only (like we did above).
                    % (We could also instead load full data, compute, and apply the returned component to the kernel.)
                    PcaOptions.ChannelTypes = ResultsMat.Options.DataTypes;
                    DataCov = GetCovariance(ResultsMat.DataFile, PcaOptions, sInputs(iInput));
                    Kernel = permute(reshape(ResultsMat.(Field), nComp, nVert, []), [2, 3, 1]); % (nVert, nChan, nComp)
                    % For each source (each [3 x nChan] page of Kernel), get K * Cov * K' -> [3 x 3]
                    % For efficiency, loop on components instead of sources.
                    FileOrientCov = zeros([1, nComp, size(Kernel,1), size(Kernel,2)]);
                    for i = 1:ResultsMat.nComponents
                        FileOrientCov(1,i,:,:) = Kernel(:,:,i) * DataCov(ResultsMat.GoodChannel, ResultsMat.GoodChannel);
                    end
                    FileOrientCov = sum(bsxfun(@times, permute(Kernel, [3,4,1,2]), FileOrientCov), 4); % (nComp, nComp, nVert)
                else
                    FileOrientCov = [];
                end
                [ResultsMat, PcaOrient] = Compute(ResultsMat, PcaOptions.Method, Field, FileOrientCov, PcaRefOrient);
        end
        % Save individual files as single-file kernel or data result.
        OutputFiles{iInput} = SaveResultFile(sInputs(iInput), ResultsMat, fileTag);
        bst_progress('inc', 0.5);
    end % second file loop
end


%% ===== COMPUTE =====
function [ResultsMat, PcaOrient] = Compute(ResultsMat, Method, Field, OrientCov, PcaOrient)
    % Field to process
    % TODO check: only linear Methods work for ImagingKernel. mean,sum,pca.
    if (nargin < 5) || isempty(PcaOrient)
        PcaOrient = [];
    end
    if (nargin < 4) || isempty(OrientCov)
        OrientCov = [];
    end
    if (nargin < 3) || isempty(Field)
        Field = 'ImageGridAmp';
    end
    if (nargin < 2) || isempty(Method)
        Method = 'rms';
    end
    % Process differently the different types of source spaces
    switch (ResultsMat.nComponents)
        % Mixed source models
        case 0
            % Apply orientations for each region independently
            [ResultsMat.(Field), ResultsMat.GridAtlas] = bst_source_orient([], ResultsMat.nComponents, ResultsMat.GridAtlas, ResultsMat.(Field), Method);
            % Constrained source models
        case 1
            % The input file is not an unconstrained source model, nothing to do
        case 2
            error('Not supported.');
            % Unconstrained source models
        case 3
            % Apply source orientations
            [ResultsMat.(Field), GridAtlas, RowNames, PcaOrient] = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method, [], [], OrientCov, PcaOrient);
            % Set the number of components
            ResultsMat.nComponents = 1;
    end
    % Save new file function
    ResultsMat.Function = Method;

    % File tag
    switch(Method)
        case 'rms',  fileTag = 'norm';
        case 'pca',  fileTag = 'pca';
        case 'pcaa',  fileTag = 'pcaa';
    end
    % Reset the data file initial path
    if ~isempty(ResultsMat.DataFile)
        ResultsMat.DataFile = file_win2unix(file_short(ResultsMat.DataFile));
    end
    % Add comment
    ResultsMat.Comment = [ResultsMat.Comment ' | ' fileTag];
    % Add history entry
    ResultsMat = bst_history('add', ResultsMat, 'flat', ['Convert unconstrained sources to a flat map with option: ' fileTag]);
end


%% ===== Get data covariance from one file =====
function DataCov = GetCovariance(DataFile, Options, sInput)
    CovMat = bst_noisecov(sInput.iStudy, sInput.iStudy, sInput.iItem, Options, true, false); % isDataCov=true, isSave=false
    DataCov = CovMat.NoiseCov;
end


% ===== SAVE FILE =====
function OutputFile = SaveResultFile(sInput, ResultsMat, Method)
    % Get study description
    sStudy = bst_get('Study', sInput.iStudy);
    % Make comment unique (for this data file)
    iResults = ~cellfun(@isempty, strfind({sStudy.Result.FileName}, sInput.DataFile));
    ResultsMat.Comment = file_unique(ResultsMat.Comment, {sStudy.Result(iResults).Comment});
    % File tag
    if ~isempty(strfind(sInput.FileName, '_abs_zscore'))
        FileType = 'results_abs_zscore';
    elseif ~isempty(strfind(sInput.FileName, '_zscore'))
        FileType = 'results_zscore';
    else
        FileType = 'results';
    end
    % Output filename
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_' Method]);
    % Save on disk
    bst_save(OutputFile, ResultsMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFile, ResultsMat);
end
