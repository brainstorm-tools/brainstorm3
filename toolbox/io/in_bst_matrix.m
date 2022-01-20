function sMat = in_bst_matrix(MatFile, varargin)
% IN_BST_MATRIX: Read a "matrix" file in Brainstorm format.
% 
% USAGE:  sMat = in_bst_matrix(MatFile, FieldsList) : Read the specified fields        
%         sMat = in_bst_matrix(MatFile)             : Read all the fields
% 
% INPUT:
%    - MatFile    : Absolute or relative path to the file to read
%    - FieldsList : List of fields to read from the file
% OUTPUT:
%    - sMat : Brainstorm matrix file structure

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
% Authors: Francois Tadel, 2010-2019

%% ===== PARSE INPUTS =====
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Filename: Relative / absolute
if ~file_exist(MatFile)
    MatFile = bst_fullfile(ProtocolInfo.STUDIES, MatFile);
    if ~file_exist(MatFile)
        error('File not found.');
    end
end

% Specific fields
if (nargin < 2)
    % Read all fields
    sMat = load(MatFile);
    % Get all the fields
    FieldsToRead = fieldnames(sMat);
    FieldsToRead{end+1} = 'ZScore';
else
    % Get fields to read
    FieldsToRead = varargin;
    % Add other necessary fields
    if ismember('Value', FieldsToRead)
        FieldsToRead{end+1} = 'ZScore';
    end
    % When reading Leff, make sure nAvg is read as well
    if ismember('Leff', FieldsToRead) && ~ismember('nAvg', FieldsToRead)
        FieldsToRead{end+1} = 'nAvg';
    end
    % Read each field only once
    FieldsToRead = unique(FieldsToRead);
    % Read specified files only
    warning off MATLAB:load:variableNotFound
    sMat = load(MatFile, FieldsToRead{:});
    warning on MATLAB:load:variableNotFound
end


%% ===== FILL OTHER MISSING FIELDS =====
for i = 1:length(FieldsToRead)
    if ~isfield(sMat, FieldsToRead{i}) || isempty(sMat.(FieldsToRead{i}))
        switch(FieldsToRead{i}) 
            case 'nAvg'
                sMat.(FieldsToRead{i}) = 1;
            case 'Leff'
                if isfield(sMat, 'nAvg') && ~isempty(sMat.nAvg)
                    sMat.Leff = sMat.nAvg;
                else
                    sMat.Leff = 1;
                end
            otherwise
                sMat.(FieldsToRead{i}) = [];
        end
    end
end

%% ===== APPLY DYNAMIC ZSCORE =====
% DEPRECATED
% Check for structure integrity
if ismember('ZScore', FieldsToRead) && ~isempty(sMat.ZScore) && (~isfield(sMat.ZScore, 'mean') || ~isfield(sMat.ZScore, 'std') || ~isfield(sMat.ZScore, 'abs') || ~isfield(sMat.ZScore, 'baseline') || isempty(sMat.ZScore.abs))
    sMat.ZScore = [];
end
% Apply to file values
if ismember('ZScore', FieldsToRead) && ismember('Value', FieldsToRead) && ~isempty(sMat.ZScore) && ~isempty(sMat.Value)
    sMat.Value = process_zscore_dynamic('Compute', sMat.Value, sMat.ZScore);
    sMat = rmfield(sMat, 'ZScore');
end

% ===== FIX TRANSPOSED TIME VECTOR =====
if isfield(sMat, 'Time') && (size(sMat.Time,1) > 1)
    sMat.Time = sMat.Time';
end






