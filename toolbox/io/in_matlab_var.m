function [value, varname] = in_matlab_var(varname, vartype)
% IN_MATLAB_VAR: Reads the contents of a Matlab variable in base workspace
% 
% USAGE:  value = in_matlab_var(varname, vartype)
%         value = in_matlab_var(varname, 'numeric')
%         value = in_matlab_var(varname)
%         value = in_matlab_var()        : Ask the variable name to the user

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
% Authors: Francois Tadel, 2009-2015

value = [];
% Variable type not specified
if (nargin < 2) || isempty(vartype)
    vartype = [];
end
% Ask user the name of the destination variable
if (nargin < 1) || isempty(varname)
    % Get the list of all the base workspace variables (structures only)
    allVars = evalin('base', 'whos');
    if isempty(allVars)
        bst_error('No variables in the base workspace.', 'Import from Matlab', 0);
        return;
    end
    % If variable type not specified, show all variables
    if isempty(vartype)
        listVar = {allVars.name};
    elseif isequal(vartype, 'numeric')
        iVar = find(ismember({allVars.class}, {'uint8','int8','uint16','int16','uint32','int32','uint64','int64','single','double'}));
        listVar = {allVars(iVar).name};
    else
        iVar = find(strcmpi({allVars.class}, vartype));
        listVar = {allVars(iVar).name};
    end
    % Check again that there are variables availables
    if isempty(listVar)
        bst_error('No valid variables in the base workspace.', 'Import from Matlab', 0);
        return;
    end
    % Show question
    varname = java_dialog('combo', '<HTML>Select a workspace variable:<BR><BR>', 'Import from Matlab', [], listVar);
    if isempty(varname)
        return
    end
end
% Get variable value
try 
    value = evalin('base', varname);
catch 
    bst_error(['Variable "' varname '" does not exist in Matlab workspace.'], 'Import from workspace', 0);
    value = [];
end



