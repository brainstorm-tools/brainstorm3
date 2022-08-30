function mat = bst_py2mat(pyObj, isDouble)
% BST_PY2MAT: Converts Python objects into Matlab objects
%
% USAGE:  mat = bst_py2mat(pyObj, isDouble=1)
%
% INPUTS:
%    - pyObj    : Python object convertible to a numeric array or a string
%    - isDouble : If 1, always convert numeric outputs to Matlab's double

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
% Authors: Francois Tadel, 2019-2020

% Parse inputs
if (nargin < 2) || isempty(isDouble)
    isDouble = 1;
end

% List of input types
switch class(pyObj)
    % Empty matrix
    case 'py.NoneType'
        mat = [];
        
    % Basic Python types
    case 'py.str'
        mat = char(pyObj);
    case 'py.datetime.datetime'
        mat = char(pyObj.strftime('%d-%b-%Y %H:%M:%S'));
    case 'py.int'
        mat = int64(pyObj);
        if isDouble
            mat = double(mat);
        end

    % NumPy array
    case 'py.numpy.ndarray'
        % Solution #1
        sz = int32(py.array.array('i', pyObj.shape));
        mat = double(py.array.array('d', pyObj.flatten('F')));
        if (length(sz) > 1)
            mat = reshape(mat, sz);
        end

        % Solution #2
        % mat = double(py.array.array('d', py.numpy.nditer(pyObj)));

        % Multidimensional: 
        % sh = double(py.array.array('d',npary.shape));
        % npary2 = double(py.array.array('d',py.numpy.nditer(npary)));
        % mat = reshape(npary2,fliplr(sh))';  % matlab 2d array 

        % Solution #3
        % Save as .mat from Python and load as .mat from Matlab
        % https://stackoverflow.com/a/45284125/2524427
       
    % NumPy scalars
    case {'py.numpy.int8', 'py.numpy.int16', 'py.numpy.int32', 'py.numpy.int64'}
        mat = int64(pyObj.item());
        if isDouble
            mat = double(mat);
        end
    case {'py.numpy.uint8', 'py.numpy.uint16', 'py.numpy.uint32', 'py.numpy.uint64'}
        mat = uint64(pyObj.item());
        if isDouble
            mat = double(mat);
        end
        
    % MNE-Python specific
    case 'py.mne.utils._bunch.NamedInt'
        mat = int64(pyObj.real);
        if isDouble
            mat = double(mat);
        end
        
    % Already converted to Matlab types
    case 'logical'
        mat = logical(pyObj);
    case 'double'
        mat = pyObj;
        
    otherwise
        error(['Unsupported class: ' class(pyObj)]);
end



