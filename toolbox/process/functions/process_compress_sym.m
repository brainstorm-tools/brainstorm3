function varargout = process_compress_sym( varargin )
% PROCESS_COMPRESS_SYM: Compress/expand symetric matrices.
%
% USAGE:  
%         TF = process_compress_sym('Expand', TF, nRows)
%         TF = process_compress_sym('Compress', TF)

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
    sProcess.Comment     = 'Symmetric matrix: compress/expand';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1030;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === COMPRESS/EXPAND
    sProcess.options.method.Comment = {'Expand', 'Compress'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    switch(sProcess.options.method.Value)
        case 1,  Comment = 'Expand symmetric matrix';
        case 2,  Comment = 'Compress symmetric matrix';
    end
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = sInput.FileName;
    % Load TF file
    TimefreqMat = in_bst_timefreq(sInput.FileName, 0);
    % Get options
    switch(sProcess.options.method.Value)
        % EXPAND
        case 1
            % Check file status
            if ~TimefreqMat.Options.isSymmetric
                bst_report('Warning', sProcess, sInput, 'File is already expanded.');
                return;
            end
            % Process
            TimefreqMat.TF = Expand(TimefreqMat.TF, length(TimefreqMat.RowNames));
            TimefreqMat.Options.isSymmetric = 0;
            fileTag = 'expand';
        % COMPRESS
        case 2
            % Check file status
            if TimefreqMat.Options.isSymmetric
                bst_report('Warning', sProcess, sInput, 'File is already compressed.');
                return;
            end
            % Process
            TimefreqMat.TF = Compress(TimefreqMat.TF);
            TimefreqMat.Options.isSymmetric = 1;
            fileTag = 'compress';
    end
    % Comment
    TimefreqMat.Comment = [TimefreqMat.Comment ' | ' fileTag];
    % Overwrite input
    if sProcess.options.overwrite.Value
        % Save file
        bst_save(file_fullpath(sInput.FileName), TimefreqMat, v6);
        % Reload study
        db_reload_studies(sInput.iStudy);
    % Save new file
    else
        % Output filename: add file tag
        OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', ['_' fileTag '.mat']);
        OutputFile = file_unique(OutputFile);
        % Save file
        bst_save(OutputFile, TimefreqMat, 'v6');
        % Add file to database structure
        db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
    end
end


%% ===== EXPAND SYMMETRIC MATRIX =====
function fullTF = Expand(TF, N, isConjugate)
    if (nargin < 3) || isempty(isConjugate)
        isConjugate = 0;
    end
    % Check if matrix is already compressed
    if (size(TF,1) == N^2)
        fullTF = TF;
        return;
    end
    % Generate all the indices
    [iAall,iBall] = meshgrid(1:N,1:N);
    % Find the values below/above the diagonal
    [iA,iB] = find(iBall <= iAall);
    % Build two sets of indices
    indAll1 = sub2ind([N,N], iA(:), iB(:));
    indAll2 = sub2ind([N,N], iB(:), iA(:));
    % Rebuild full matrix
    fullTF = zeros(N*N, size(TF,2), size(TF,3), size(TF,4));
    fullTF(indAll1,:,:,:) = TF;
    if isConjugate
        fullTF(indAll2,:,:,:) = conj(TF);
    else
        fullTF(indAll2,:,:,:) = TF;
    end
end


%% ===== COMPRESS SYMMETRIC MATRIX =====
function TF = Compress(TF)
    % Get number of elements
    N = sqrt(size(TF,1));
    % Check if matrix is already compressed
    if (N ~= round(N))
        return;
    end
    % Generate all the indices
    [iA,iB] = meshgrid(1:N,1:N);
    % Find the values below the diagonal
    indAll = find(iB <= iA);
    % Keep only those values
    TF = TF(indAll,:,:,:);
end


%% ===== REMOVE DIAGONAL =====
function TF = RemoveDiagonal(TF, N) %#ok<DEFNU>
    % If matrix is expanded
    if (size(TF,1) == N^2)
        iDel = (1:N) + (0:N-1)*N;
    % If matrix is compressed
    elseif (size(TF,1) == sum(1:N))
        iDel = cumsum(1:N);
    else
        disp('Warning: Invalid matrix size, cannot remove diagonal.');
        return;
    end
    % Remove diagonal
    TF(iDel,:,:,:) = [];
end


%% ===== ADD DIAGONAL =====
function TFedit = AddDiagonal(TF, N) %#ok<DEFNU>
    TFedit = zeros(size(TF,1) + N, size(TF,2), size(TF,3), size(TF,4));
    % If matrix is expanded
    if (size(TFedit,1) == N^2)
        iDel = (1:N) + (0:N-1)*N;
    % If matrix is compressed
    elseif (size(TFedit,1) == sum(1:N))
        iDel = cumsum(1:N);
    else
        disp('Warning: Invalid matrix size, cannot add diagonal.');
        return;
    end
    % Copy values
    TFedit(setdiff(1:size(TFedit,1), iDel),:,:,:) = TF;
end


