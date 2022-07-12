function varargout = process_threshold_percentile( varargin )
% PROCESS_THRESHOLD_PRECENTILE: Set all the values below the top n% to zero.

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
% Authors: Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Threshold by percentile';
    sProcess.FileTag     = 'abs';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 730;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity#Thresholding_of_connectivity_estimates';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = -1;
    % === OPTIONS
    sProcess.options.label.Comment = ['This process sorts all the values from the selected dimensions,<BR>' ...
                                      'keeps unchanged the top n% values, and sets to zero all the others.<BR><BR>' ...
                                      'This algorithm is repeated independently along the dimensions<BR>' ...
                                      'that are not selected. Example: if "frequency" is not selected,<BR>' ...
                                      'the top n% values are kept for each frequency bin.<BR><BR>'];
    sProcess.options.label.Type    = 'label';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === Percentile
    sProcess.options.percentile.Comment = 'Threshold percentile (n): ';
    sProcess.options.percentile.Type    = 'value';
    sProcess.options.percentile.Value   = {5,'%',0};
    % === Absolue values
    sProcess.options.abs.Comment = 'Sort the absolute values instead of the original';
    sProcess.options.abs.Type    = 'checkbox';
    sProcess.options.abs.Value   = 1;
    % === Dimensions 
    sProcess.options.label2.Comment = 'Dimensions to process together:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.dim1.Comment = '1: Signals or connectivity matrices';
    sProcess.options.dim1.Type    = 'checkbox';
    sProcess.options.dim1.Value   = 1;
    sProcess.options.dim2.Comment = '2: Time';
    sProcess.options.dim2.Type    = 'checkbox';
    sProcess.options.dim2.Value   = 1;
    sProcess.options.dim3.Comment = '3: Frequency';
    sProcess.options.dim3.Type    = 'checkbox';
    sProcess.options.dim3.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = [sProcess.Comment ' (top ' num2str(sProcess.options.percentile.Value{1}) '%)'];
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput)
    % Threshold percentile
    Threshold = sProcess.options.percentile.Value{1};
    if (Threshold <= 0) || (Threshold >= 100)
        bst_report('Error', sProcess, sInput, 'Threshold percentile value must be between 0 and 100.');
        sInput = [];
        return;
    end
    % Absolue values
    isAbsolute = sProcess.options.abs.Value;
    % Get dimensions
    Dimensions = [];
    if (sProcess.options.dim1.Value == 1)
        Dimensions(end+1) = 1;
    end
    if (sProcess.options.dim2.Value == 1)
        Dimensions(end+1) = 2;
    end
    if (sProcess.options.dim3.Value == 1)
        Dimensions(end+1) = 3;
    end
    if isempty(Dimensions)
        bst_report('Error', sProcess, sInput, 'At least one dimension must be selected.');
        sInput = [];
        return;
    end
    % Apply threshold
    sInput.A = Compute(sInput.A, Threshold, Dimensions, isAbsolute);
    % Comment tag
    sInput.CommentTag = ['top' num2str(Threshold)];
    if isAbsolute
        sInput.CommentTag = [sInput.CommentTag, 'abs'];
    end
    % Change data type
    if strcmpi(sInput.FileType, 'data')
        sInput.DataType = sInput.CommentTag;
    end
end


%% ===== APPLY THRESHOLD =====
function A = Compute(A, Threshold, Dimensions, isAbsolute)
    % Number of sorted values
    nValues = 1;
    sizeA = size(A);
    if (length(sizeA) < 3)
        sizeA(3) = 1;
    end
    if ismember(1, Dimensions)
        nValues = nValues * sizeA(1);
    end
    if ismember(2, Dimensions)
        nValues = nValues * sizeA(2);
    end
    if ismember(3, Dimensions)
        nValues = nValues * sizeA(3);
    end
    % Count number of values below the selected percentile
    nThresh = round(nValues * Threshold / 100);
    nThresh = max(nThresh, 2);
    nThresh = min(nThresh, nValues - 1);
    % Permute dimensions to have the controlled dimensions first
    dim = [Dimensions, setdiff([1 2 3], Dimensions)];
    A = permute(A, dim);
    % Reshape to the number of values to sort: [sorted dimensions x looped dimensions]
    origSize = size(A);
    A = reshape(A, nValues, []);
    % Absolue values
    if isAbsolute
        sortA = abs(A);
    else
        sortA = A;
    end
    % Sort values
    [sortA, I] = sort(sortA, 1);
    % Get indices of values below percentile threshold
    nReset = nValues - nThresh;
    iReset = I(1:nReset,:);
    jReset = repmat(1:size(A,2), nReset, 1);
    indReset = sub2ind(size(A), iReset(:), jReset(:));
    % Apply threshold
    A(indReset) = 0;
    % Reshape to original dimensions
    A = reshape(A, origSize);
    % Restore original dimensions
    invDim(dim) = 1:length(dim);
    A = permute(A, invDim);
end



