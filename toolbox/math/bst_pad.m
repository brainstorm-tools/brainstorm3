function Apad = bst_pad(A, p, method)
% BST_PAD: Pad a 2D array with circular/mirrored values, or zeros
%
% USAGE:  Apad = bst_pad(A, p, method)
%
% INPUT:
%    - A      : Array to pad
%    - p      : Number of values to add before and after, in each direction
%               If one value: use the same for dimensions 1 and 2
%               If two values: pad dimensions 1 and 2 with a different amount of values
%    - method : {'zeros', 'mirror', 'circular'}

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
% Authors: Francois Tadel, 2010-2011

% Parse inputs
if (length(p) == 1)
    px = p;
    py = p;
elseif (length(p) == 2)
    px = p(1);
    py = p(2);
else
    error('Invalid call');
end

% Initialize returned array
Apad = zeros(size(A) + 2*[px py]);
Apad(px+1:end-px, py+1:end-py) = A;
% Padding method
switch lower(method)
    case 'zeros'
        % Nothing to do...
    case 'circular'
        if (px > size(A,1)) || (py > size(A,2))
            error('Paddind size exceeds limit for "circular" method.');
        end
        % Padding x
        Apad(1:px, py+1:end-py) = A(end-px+1:end, :);
        Apad(end-px+1:end, py+1:end-py) = A(1:px,:);
        % Padding y
        Apad(:, 1:py) = Apad(:, end-2*py+1:end-py);
        Apad(:, end-py+1:end) = Apad(:,py+1:2*py);
    case 'mirror'
        if (px > size(A,1)-1) || (py > size(A,2)-1)
            error('Paddind size exceeds limit for "mirror" method.');
        end
        % Padding x
        Apad(1:px, py+1:end-py) = A(px+1:-1:2, :);
        Apad(end-px+1:end, py+1:end-py) = A(end-1:-1:end-px,:);
        % Padding y
        Apad(:, 1:py) = Apad(:, 2*py+1:-1:py+2);
        Apad(:, end-py+1:end) = Apad(:, end-py-1:-1:end-2*py);
    otherwise
        error('Unknown method');
end



