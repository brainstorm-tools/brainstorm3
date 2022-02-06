function export_matlab( values, varname )
% EXPORT_MATLAB: Export a variable to Matlab base workspace.
%
% USAGE:  export_matlab( values )       : Export value to Matlab base workspace
%         export_matlab( bstNode )      : Export node to Matlab base workspace
%         export_matlab( filename )     : Export the contents of a file to Matlab base workspace
%         export_matlab( ..., varname ) : Specify the name of the target variable name

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
% Authors: Francois Tadel, 2008-2015

% Get data source
if ischar(values)
    filenames = {values};
    nExport = 1;
elseif iscell(values)
    filenames = values;
    nExport = length(filenames);
elseif isstruct(values)
    filenames = {};
    %nExport = length(values);
    nExport = 1;
elseif isjava(values)
    nExport = length(values);
    for i = 1:nExport
        filenames{i} = char(values(i).getFileName());
    end
else
    error(['Unsupported input type: "' class(values) '"']);
end
% Ask user the name of the destination variable
if (nargin < 2) || isempty(varname)
    varname = java_dialog('input', ['  Please enter a name for destination workspace variable : ' 10 10], ...
                                   'Export to Matlab workspace');
    if isempty(varname)
       return
    end
    drawnow;
end

% Loop on each file
for i = 1:nExport
    % Load brainstorm file
    if ~isempty(filenames)
        bst_progress('start', 'Export to workspace variable', 'Loading file...');
        val = load(file_fullpath(filenames{i}));
        bst_progress('stop');
    elseif (nExport == 1)
        val = values;
    elseif iscell(values)
        val = values{i};
    else
        val = values(i);
    end

    % Local variable name
    if (nExport == 1)
        vname = varname;
    elseif (length(values) < 10)
        vname = sprintf('%s%d', varname, i);
    elseif (length(values) < 100)
        vname = sprintf('%s%02d', varname, i);
    else
        vname = sprintf('%s%03d', varname, i);
    end
    % Export value to base workspace
    try
        assignin('base', vname, val);
        if (i == 1)
            disp(' ');
        end
        disp(['Data exported as "' vname '"']);
    catch
        bst_error(['Invalid variable name ''' vname ''''], 'Export to Matlab workspace');
    end
end






