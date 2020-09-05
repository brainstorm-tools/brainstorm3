function mat = bst_py2mat(npObj)
% BST_PY2MAT: Converts Python arrays to Matlab matrices
%
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
% Authors: Francois Tadel, 2019


switch class(npObj)
    % NumPy array
    case 'py.numpy.ndarray'
        % Solution #1
        sz = int32(py.array.array('i', npObj.shape));
        mat = double(py.array.array('d', npObj.flatten('F')));
        if (length(sz) > 1)
            mat = reshape(mat, sz);
        end

        % Solution #2
        % mat = double(py.array.array('d', py.numpy.nditer(npObj)));

        % Multidimensional: 
        % sh = double(py.array.array('d',npary.shape));
        % npary2 = double(py.array.array('d',py.numpy.nditer(npary)));
        % mat = reshape(npary2,fliplr(sh))';  % matlab 2d array 

        % Solution #3
        % Save as .mat from Python and load as .mat from Matlab
        % https://stackoverflow.com/a/45284125/2524427
        
    case 'py.int'
        mat = double(npObj);
    case 'py.str'
        mat = char(npObj);
    case 'py.numpy.int32'
        mat = double(npObj);
       
    % MNE-Python specific
    case 'py.mne.utils._bunch.NamedInt'
        mat = double(npObj.real);
        
    % Already converted to Matlab types
    case 'logical'
        mat = double(npObj);
    case 'double'
        mat = npObj;
        
    otherwise
        error(['Unsupported class: ' class(npObj)]);
end
