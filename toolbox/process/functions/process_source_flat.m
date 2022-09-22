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
    OutputFiles = cell(1, numel(sInputs));
    % Get options
    switch(sProcess.options.method.Value)
        case {1, 'norm'}, Method = 'rms';  fileTag = 'norm';
        case {2, 'pca'},  Method = 'pca';  fileTag = 'pca';
        case 'pcaa',      Method = 'pcaa'; fileTag = 'pcaa';
    end
    % For PCA, we need to group input files by imaging kernel.
    % Extract kernel file names from result FileName string that have format: 'link|result.mat|data.mat' (is there a better way?)
    iLinkBars = strfind({sInputs.FileName}, '|');
    if any(cellfun(@isempty, iLinkBars))
        bst_report('Error', sProcess, sInputs, 'PCA flattening only available for imaging kernel files.');
        return;
    end
    ProcessedKernelFiles = {};
    PreviousKernelFile = '';
    PcaAcross = [];
    for iInput = 1:numel(sInputs)
        % ===== PROCESS INPUT =====
        if strncmpi(Method, 'pca', 3)
            KernelFile = sInputs(iInput).FileName((iLinkBars{iInput}(1)+1):(iLinkBars{iInput}(2)-1));
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
        % Load the source file
        ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
        % Error: Not an unconstrained model
        if (ResultsMat.nComponents == 1) || (ResultsMat.nComponents == 2)
            bst_report('Error', sProcess, sInputs(iInput), 'The input file is not an unconstrained source model.');
            return;
        end
        % Get study description
        sStudy = bst_get('Study', sInputs(iInput).iStudy);
        % Error: PCA requires kernel and data covariance
        if strncmpi(Method, 'pca', 3) 
            if numel(sStudy.NoiseCov) < 2
                bst_report('Error', sProcess, sInputs(iInput), 'PCA flattening requires data covariance matrix to be computed first.');
                return;
            end
            % Load kernel
            ResK = in_bst_results(sInputs(iInput).FileName, 0);
            ResultsMat.ImagingKernel = ResK.ImagingKernel;
        end
        if strcmpi(Method, 'pca')
            % For PCA per epoch, we use PCA across epochs for picking consistent sign for each epoch.
            % Only compute if different kernel than previous file.
            if ~strcmp(KernelFile, PreviousKernelFile)
                [unused, PcaAcross] = Compute(ResultsMat, 'pcaa', [], sStudy, []);
                PreviousKernelFile = KernelFile;
            end
        end

        % Compute flat map
        ResultsMat = Compute(ResultsMat, Method, [], sStudy, PcaAcross);

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
        if ~isempty(ResultsMat.ImagingKernel) 
            ResultsMat.ImageGridAmp = [];            
            % For PCA method, save a single shared kernel.
            if strcmpi(Method, 'pcaa')
                ResultsMat.DataFile = '';
                % db_add doesn't make it a shared kernel.
                %SharedFile = db_add(sInputs(iInput).iStudy, ResultsMat);
                SharedFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_KERNEL_' fileTag]);
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
function [ResultsMat, PcaOrient] = Compute(ResultsMat, Method, Field, sStudy, PcaOrient)
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
            [ResultsMat.(Field), ResultsMat.GridAtlas] = bst_source_orient([], ResultsMat.nComponents, ResultsMat.GridAtlas, ResultsMat.(Field), Method);        % Constrained source models
        case 1
            % The input file is not an unconstrained source model, nothing to do
        case 2
            error('Not supported.');
        % Unconstrained source models
        case 3
            % Apply source orientations
            OrientCov = [];
            Ker = [];
            if strcmpi(Method, 'pcaa') 
                if ~isfield(ResultsMat, 'ImagingKernel') || isempty(ResultsMat.ImagingKernel)
                    error('PCA flattening only available for imaging kernel files.');
                end
                Ker = reshape(ResultsMat.ImagingKernel, ResultsMat.nComponents, [], size(ResultsMat.ImagingKernel,2)); % (nComp, nSource, nChan)
                % Get data covariance matrix for provided data file.
                if numel(sStudy.NoiseCov) < 2
                    error('PCA flattening requires data covariance matrix to be computed first.');
                end
                DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName)); % size nChanAll
                % Keep 3x3 covariance per location: 3x3xnSource instead of (3*nSource)^2
                OrientCov = squeeze( sum(bsxfun(@times, sum(bsxfun(@times, permute(Ker, [3,4,1,2]), DataCov.NoiseCov(ResultsMat.GoodChannel, ResultsMat.GoodChannel)), 1), ... % (1, nChan, nComp, nSource)
                    permute(Ker, [1,3,4,2])), 2) ); % (nComp, nComp, nSource)
            elseif strcmpi(Method, 'pca')
                % Covariance computation is somewhat slow, avoid repeating for PCA per epoch, when using the same kernel.
                Ker = reshape(ResultsMat.ImagingKernel, ResultsMat.nComponents, [], size(ResultsMat.ImagingKernel,2)); % (nComp, nSource, nChan)
                OrientCov = PcaOrient;
            end
            [ResultsMat.(Field), GridAtlas, RowNames, PcaOrient] = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method, [], [], OrientCov);
            % Resulting kernel
            if ~isempty(PcaOrient) && ~isempty(Ker)
                ResultsMat.ImagingKernel = squeeze(sum(bsxfun(@times, Ker, PcaOrient), 1)); % nSource, nChan
            else
                ResultsMat.ImagingKernel = [];
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

