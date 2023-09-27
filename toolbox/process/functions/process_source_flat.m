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
%          Marc Lalancette, 2023

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
    sProcess.options.method.Controller.pca = 'pca';
    % Options: PCA
    sProcess.options.pcaedit.Comment = {'panel_pca', ' PCA options: '}; 
    sProcess.options.pcaedit.Type    = 'editpref';
    sProcess.options.pcaedit.Value   = bst_get('PcaOptions'); % function that returns defaults or saved preferences.
    sProcess.options.pcaedit.Class   = 'pca';
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
    end

    % ===== PCA 2023 =====
    if strcmpi(Method, 'pca') && isfield(sProcess.options, 'pcaedit') && isfield(sProcess.options.pcaedit, 'Value') && ...
            ~isempty(sProcess.options.pcaedit.Value) && ~strcmpi(sProcess.options.pcaedit.Value.Method, 'pca')
        PcaOptions = sProcess.options.pcaedit.Value;
        OutputFiles = bst_pca(sProcess, sInputs, PcaOptions); 

    % ===== Norm or legacy PCA =====
    else
        if strcmpi(Method, 'pca')
            disp('BST> Warning: Running deprecated legacy PCA.');
            bst_report('Warning', sProcess, sInputs, 'Running deprecated legacy PCA separately on each file/epoch, with arbitrary signs which can lead to averaging issues. See tutorial linked in PCA options panel.');
        end
        nFiles = numel(sInputs);
        bst_progress('start', 'Unconstrained to flat map', sprintf('Flattening %d files', nFiles), 0, 100);

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
            
            % Save file
            % File tag
            if ~isempty(strfind(sInputs(iInput).FileName, '_abs_zscore'))
                FileType = 'results_abs_zscore';
            elseif ~isempty(strfind(sInputs(iInput).FileName, '_zscore'))
                FileType = 'results_zscore';
            else
                FileType = 'results';
            end
            % Get study description
            sStudy = bst_get('Study', sInputs(iInput).iStudy);
            % Output filename
            OutputFiles{iInput} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_' fileTag]);
            % Save on disk
            bst_save(OutputFiles{iInput}, ResultsMat, 'v6');
            % Register in database
            db_add_data(sInputs(iInput).iStudy, OutputFiles{iInput}, ResultsMat);
            bst_progress('set', round(100*iInput/nFiles));
        end
    end
end


%% ===== COMPUTE =====
function [ResultsMat, PcaOrient] = Compute(ResultsMat, Method, Field)
    % TODO check: only linear Methods work for ImagingKernel. mean,sum,pca,max.
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
            ResultsMat.(Field) = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method);
            % Set the number of components
            ResultsMat.nComponents = 1;
    end
    % Save new file function; Disabled 2023-06: for result files, Function is the inverse method. This is saved elsewhere: tag and history.
    %     ResultsMat.Function = Method;

    % File tag
    switch(Method)
        case 'rms',  fileTag = 'norm';
        otherwise
            fileTag = Method;
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

