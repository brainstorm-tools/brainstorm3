function varargout = process_source_flat( varargin )
% PROCESS_SOURCE_FLAT: Convert an unconstrained source file into a flat map.
%
% USAGE:  OutputFiles = process_source_flat('Run', sProcess, sInput)
%          ResultsMat = process_source_flat('Compute', ResultsMat, Method, Field)

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
% Authors: Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Unconstrained to flat map';
    sProcess.Category    = 'File';
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
                                       '<B>PCA</B>: First mode of svd(x,y,z)'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    switch(sProcess.options.method.Value)
        case 1, Method = 'rms';  fileTag = 'norm';
        case 2, Method = 'pca';  fileTag = 'pca';
    end

    % ===== PROCESS INPUT =====
    % Load the source file
    ResultsMat = in_bst_results(sInput.FileName, 1);
    % Error: Not an unconstrained model
    if (ResultsMat.nComponents == 1) || (ResultsMat.nComponents == 2)
        bst_report('Error', sProcess, sInput, 'The input file is not an unconstrained source model.');
        return;
    end
    % Compute flat map
    ResultsMat = Compute(ResultsMat, Method);

    % ===== SAVE FILE =====
    % File tag
    if ~isempty(strfind(sInput.FileName, '_abs_zscore'))
        FileType = 'results_abs_zscore';
    elseif ~isempty(strfind(sInput.FileName, '_zscore'))
        FileType = 'results_zscore';
    else
        FileType = 'results';
    end
    % Get study description
    sStudy = bst_get('Study', sInput.iStudy);
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_' fileTag]);
    % Save on disk
    bst_save(OutputFiles{1}, ResultsMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFiles{1}, ResultsMat);
end


%% ===== COMPUTE =====
function ResultsMat = Compute(ResultsMat, Method, Field)
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
            ResultsMat.(Field) = bst_source_orient([], ResultsMat.nComponents, [], ResultsMat.(Field), Method);
            % Set the number components
            ResultsMat.nComponents = 1;
    end
    % Save new file function
    ResultsMat.Function = Method;
    
    % File tag
    switch(Method)
        case 'rms',  fileTag = 'norm';
        case 'pca',  fileTag = 'pca';
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

