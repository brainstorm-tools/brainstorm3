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
function sProcess = GetDescription() %#ok<DEFNU>
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
                                       '<B>PCA across epochs</B>: First mode of svd(x,y,z)<BR>Requires kernel linked source file(s) and pre-computed data covariance.<BR>Very fast: saves a flattened shared kernel.'; ...
                                       '<B>PCA per epoch</B>: First mode of svd(x,y,z), sign corrected with PCA across epochs<BR>Requires kernel linked source file(s) and pre-computed data covariance.<BR>Saves flattened individual files.'; ...
                                       'norm', 'pcaa', 'pca'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'norm';
    %sProcess.options.pcamode.Comment = {'once across epochs', 'separately for each epoch', 'PCA computation:'; ...
    %                                   'pcaa', 'pca', 'PCA computation:'};
    %sProcess.options.pcamode.Type    = 'radio_linelabel';
    %sProcess.options.pcamode.Value   = 'pcaa';

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    switch(sProcess.options.method.Value)
        case {1, 'norm'}, Method = 'rms';  fileTag = 'norm';
        case {2, 'pca'},  Method = 'pca';  fileTag = 'pca';
        case 'pcaa',      Method = 'pcaa'; fileTag = 'pcaa';
    end
    % Initialize variables for PCA
    ProcessedKernelFiles = {};
    PreviousKernelFile = '';
    DataCov = [];
    PcaAcross = [];
    for iInput = 1:numel(sInputs)
        % ===== PROCESS INPUT =====
        if strncmpi(Method, 'pca', 3)
            if strcmpi(file_gettype(InputFile), 'link')
                bst_report('Error', sProcess, sInputs, 'PCA flattening only available for imaging kernel files.');
                return;
            end
            KernelFile = file_resolve_link(sInputs(iInput).FileName);
            if strcmpi(Method, 'pcaa')
                % For PCA across epochs, we process and save a shared kernel, once for all data files linked to it.
                if ismember(KernelFile, ProcessedKernelFiles)
                    % Already saved a flattened version of this kernel.
                    % Find new link for this data file.
                    LinkFiles = db_links('Study', sInputs(iInput).iStudy);
                    iLink = ~cellfun(@isempty, strfind(LinkFiles, [file_short(SharedFile) '|' sInputs(iInput).DataFile]));
                    OutputFiles{iInput} = LinkFiles{iLink};
                    continue;
                else
                    % Add new kernel to the list and process it.
                    ProcessedKernelFiles{end+1} = KernelFile; %#ok<AGROW>
                end
            end
        end
        % Get study description
        sStudy = bst_get('Study', sInputs(iInput).iStudy);

        if strcmpi(Method, 'pcaa') || ...
                (strcmpi(Method, 'pca') && ~strcmp(KernelFile, PreviousKernelFile))
            % For PCA per epoch, we use PCA across epochs for picking consistent sign for each epoch.
            % Only compute if different kernel than previous file.

            % Error: PCA across epochs requires kernel and data covariance
            if numel(sStudy.NoiseCov) < 2
                bst_report('Error', sProcess, sInputs(iInput), 'PCA flattening requires data covariance matrix to be computed first.');
                return;
            end
            DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName)); 
            DataCov = DataCov.NoiseCov; % size nChanAll
            % Load kernel
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 0);

            if strcmpi(Method, 'pca')
                % Get PcaAcross 
                [unused, PcaAcross] = Compute(ResultsMat, 'pcaa', [], DataCov, []);
                PreviousKernelFile = KernelFile;
                % Keep kernel so we can save individual files as kernels too.
                Kernel = permute(reshape(ResultsMat.ImagingKernel, ResultsMat.nComponents, [], size(ResultsMat.ImagingKernel,2)), [2, 3, 1]); % (nSource, nChan, nComp)
                % Reload source file with full data.
                ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
            end
        else
            % Load the source file with full data.
            ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
            % Error: Not an unconstrained model
            if (ResultsMat.nComponents == 1) || (ResultsMat.nComponents == 2)
                bst_report('Error', sProcess, sInputs(iInput), 'The input file is not an unconstrained source model.');
                return;
            end
        end

        % Compute flat map
        [ResultsMat, PcaOrient] = Compute(ResultsMat, Method, [], DataCov, PcaAcross);

        % ===== SAVE FILE =====
        % Make comment unique
        ResultsMat.Comment = file_unique(ResultsMat.Comment, {sStudy.Result.Comment});
        % File tag
        if ~isempty(strfind(sInputs(iInput).FileName, '_abs_zscore'))
            FileType = 'results_abs_zscore';
        elseif ~isempty(strfind(sInputs(iInput).FileName, '_zscore'))
            FileType = 'results_zscore';
        else
            FileType = 'results';
        end
        % Save as kernel if possible.
        if ~isempty(PcaOrient)
            ResultsMat.ImageGridAmp = [];
            % For PCA per epoch, save a single-file kernel.
            if strcmpi(Method, 'pca')
                ResultsMat.ImagingKernel = sum(bsxfun(@times, Kernel, permute(PcaOrient, [2, 3, 1])), 3); % nSource, nChan
            % For PCA across epochs, save a shared kernel.
            elseif strcmpi(Method, 'pcaa')
                ResultsMat.DataFile = '';
                [KernelPath, KernelName] = bst_fileparts(KernelFile);
                SharedFile = fullfile(KernelPath, [KernelName '_' fileTag '.mat']);
                bst_save(SharedFile, ResultsMat, 'v6');
                db_add_data(sInputs(iInput).iStudy, SharedFile, ResultsMat);
                panel_protocols('UpdateNode', 'Study', sInputs(iInput).iStudy); 
                % Find link to the result kernel that was just created for this data file.
                LinkFiles = db_links('Study', sInputs(iInput).iStudy);
                iLink = ~cellfun(@isempty, strfind(LinkFiles, [file_short(SharedFile) '|' sInputs(iInput).DataFile]));
                OutputFiles{iInput} = LinkFiles{iLink};
                continue;
            end
        end
        % Output filename
        OutputFiles{iInput} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_' fileTag]);
        % Save on disk
        bst_save(OutputFiles{iInput}, ResultsMat, 'v6');
        % Register in database
        db_add_data(sInputs(iInput).iStudy, OutputFiles{iInput}, ResultsMat);
    end
end


%% ===== COMPUTE =====
function [ResultsMat, PcaOrient] = Compute(ResultsMat, Method, Field, DataCov, PcaOrient)
    % Field to process
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
            OrientCov = [];
            Kernel = [];
            if strcmpi(Method, 'pcaa') 
                Kernel = permute(reshape(ResultsMat.ImagingKernel, ResultsMat.nComponents, [], size(ResultsMat.ImagingKernel,2)), [2, 3, 1]); % (nSource, nChan, nComp)
                % Keep 3x3 covariance per location: 3x3xnSource instead of (3*nSource)^2
                % For each source (each [3 x nChan] page of Kernel), get K * Cov * K' -> [3 x 3]
                % For efficiency, loop on components instead of sources.
                OrientCov = zeros([1, ResultsMat.nComponents, size(Kernel,1), size(Kernel,2)]);
                for i = 1:ResultsMat.nComponents
                    OrientCov(1,i,:,:) = Kernel(:,:,i) * DataCov(ResultsMat.GoodChannel, ResultsMat.GoodChannel);
                end
                OrientCov = sum(bsxfun(@times, permute(Kernel, [3,4,1,2]), OrientCov), 4); % (nComp, nComp, nSource)
            elseif strcmpi(Method, 'pca')
                % Reuse pcaa component (in PcaOrient) when using the same kernel.
                OrientCov = PcaOrient;
            end
            [ResultsMat.(Field), GridAtlas, RowNames, PcaOrient] = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method, [], [], OrientCov);
            % Resulting kernel
            if ~isempty(PcaOrient) && ~isempty(Kernel)
                ResultsMat.ImagingKernel = sum(bsxfun(@times, Kernel, permute(PcaOrient, [2, 3, 1])), 3); % nSource, nChan
            end
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

