function pyObj = bst_mat2py(matArray)
% BST_MAT2PY: Converts Matlab matrices to Python arrays
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2019


switch class(matArray)
    case {'double', 'single', 'logical'}
        % Convert numerical matrices to Numpy arrays
        shape = int64(size(matArray));
        pyObj = py.numpy.array(matArray(:)');
        pyObj = pyObj.reshape(shape);
        
    case 'cell'
        % Convert cell arrays to Python lists (which support mixed types)
        pyObj = py.list(matArray(:)');
        
    otherwise
        error(['Unsupported class: ' class(matArray)]);
end

