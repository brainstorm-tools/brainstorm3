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
                                       '<B>PCA</B>: First mode of svd(x,y,z)<BR>(requires pre-computed data covariance across epochs)'; ...
                                       'norm', 'pcag'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 1;
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
        case 'pcag',      Method = 'pcag'; fileTag = 'pcag';
    end
    for iInput = 1:numel(sInputs)
        % ===== PROCESS INPUT =====
        % Load the source file
        ResultsMat = in_bst_results(sInputs(iInput).FileName, 1);
        % Also get kernel if pca
        if strncmpi(Method, 'pca', 3)
            ResK = in_bst_results(sInputs(iInput).FileName, 0);
            if ~isempty(ResK.ImagingKernel)
                ResultsMat.ImagingKernel = ResK.ImagingKernel;
            end
        end
        % Error: Not an unconstrained model
        if (ResultsMat.nComponents == 1) || (ResultsMat.nComponents == 2)
            bst_report('Error', sProcess, sInputs(iInput), 'The input file is not an unconstrained source model.');
            return;
        end
        % Get study description
        sStudy = bst_get('Study', sInputs(iInput).iStudy);

        % Compute flat map
        ResultsMat = Compute(ResultsMat, Method, [], sStudy);

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
            % For global PCA method, save a single shared kernel.
            if strcmpi(Method, 'pcag')
                ResultsMat.DataFile = '';
                % db_add doesn't make it a shared kernel.
                %SharedFile = db_add(sInputs(iInput).iStudy, ResultsMat);
                SharedFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_KERNEL_' fileTag]);
                bst_save(SharedFile, ResultsMat, 'v6');
                db_add_data(sInputs(iInput).iStudy, SharedFile, ResultsMat);
                panel_protocols('UpdateNode', 'Study', sInputs(iInput).iStudy); 
                % Find links to the result kernel that was just created
                % This includes bad trials (same as process_inverse I think).
                OutputFiles = db_links('Study', sInputs(iInput).iStudy);
                OutputFiles(~contains(OutputFiles, file_short(SharedFile))) = [];
                return;
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
function ResultsMat = Compute(ResultsMat, Method, Field, sStudy)
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
            if strncmpi(Method, 'pca', 3) && isfield(ResultsMat, 'ImagingKernel') && ~isempty(ResultsMat.ImagingKernel)
                Ker = reshape(ResultsMat.ImagingKernel, ResultsMat.nComponents, [], size(ResultsMat.ImagingKernel,2)); % (nComp, nSource, nChan)
            else
                Ker = [];
            end
            if strncmpi(Method, 'pcag', 4)
                if ~isfield(ResultsMat, 'ImagingKernel') || isempty(ResultsMat.ImagingKernel)
                    error('PCA flattening only available for imaging kernel files.');
                end
                % Get data covariance matrix for provided data file.
                % Note that this process is called through bst_process for single
                % files (looped over elsewhere).  So we can't compute the global
                % covariance here.
                % NoiseCovFiles = bst_noisecov(iTargetStudies, iDataStudies, iDatas, Options, isDataCov)
                if numel(sStudy.NoiseCov) < 2
                    error('PCA flattening requires data covariance matrix to be computed first.');
                end
                DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName)); % size nChanAll
                if ResultsMat.nComponents > 1
                    % Maybe more efficient: save 3x3xnSource instead of (3*nSource)^2
                    SourceCov = squeeze( sum(bsxfun(@times, sum(bsxfun(@times, permute(Ker, [3,4,1,2]), DataCov.NoiseCov(ResultsMat.GoodChannel, ResultsMat.GoodChannel)), 1), ... % (1, nChan, nComp, nSource)
                        permute(Ker, [1,3,4,2])), 2) ); % (nComp, nComp, nSource)
                else
                    SourceCov = [];
                end
            else
                SourceCov = [];
            end
            [ResultsMat.(Field), GridAtlas, RowNames, PcaOrient] = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method, [], [], SourceCov);
            % Resulting kernel
            if ~isempty(PcaOrient) && ~isempty(Ker)
                ResultsMat.ImagingKernel = squeeze(sum(bsxfun(@times, Ker, PcaOrient), 1)); % nSource, nChan
            else
                ResultsMat.ImagingKernel = [];
            end
            % Set the number components
            ResultsMat.nComponents = 1;
    end
    % Save new file function
    ResultsMat.Function = Method;
    
    % File tag
    switch(Method)
        case 'rms',  fileTag = 'norm';
        case 'pca',  fileTag = 'pca';
        case 'pcag',  fileTag = 'pcag';
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

