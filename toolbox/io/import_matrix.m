function OutputFile = import_matrix(iStudy, Value, sfreq)
% IMPORT_MATRIX: Imports a 2D matrix as a "matrix" file.
% 
% USAGE:  OutputFile = import_matrix(iStudy, Value=[ask], sfreq=[ask])
%
% INPUT:
%    - iStudy  : Index of the study where to import the SourceFiles
%    - Value   : 2D matrix to import as a "matrix" object in the database
%                If not specified: ask for selecting a variable in the workspace
%    - sfreq   : Sampling frequency of the signals (Hertz)

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
% Authors: Francois Tadel, 2015

% Parse inputs
if (nargin < 3) || isempty(sfreq)
    sfreq = [];
end
if (nargin < 2) || isempty(Value)
    Value = [];
end
OutputFile = [];

% Ask for a variable in the workspace
if isempty(Value)
    Value = in_matlab_var([], 'numeric');
    if isempty(Value)
        OutputFile = [];
        return
    end
end
% Build time vector
if (size(Value,2) == 1)
    Time = 0;
elseif (size(Value,2) == 2)
    Time = [0 1];
else
    % Ask for the sampling frequency
    if isempty(sfreq)
        res = java_dialog('input', sprintf('Matrix size: [%d signals x %d samples].\nEnter the sampling frequency of the signal:\n\n', size(Value,1), size(Value,2)), 'Import data matrix', [], '1000');
        if isempty(res) || isempty(str2num(res)) || (str2num(res) < 0)
            return;
        end
        sfreq = str2num(res);
    end
    % Create time vector
    Time = (0:(size(Value,2)-1)) ./ sfreq;
end

% Create a "matrix" structure
sMat = db_template('matrixmat');
sMat.Value       = Value;
sMat.Time        = Time;
sMat.Comment     = sprintf('Imported matrix [%dx%d]', size(Value,1), size(Value,2));
sMat.Description = cell(size(Value,1),1);
for i = 1:size(Value,1)
    sMat.Description{i} = ['s', num2str(i)];
end
% Add history entry
sMat = bst_history('add', sMat, 'process', 'Imported matrix');

% Add structure to database
OutputFile = db_add(iStudy, sMat);

