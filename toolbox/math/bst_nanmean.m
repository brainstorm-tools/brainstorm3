function y = bst_nanmean(varargin)

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

% Try to use Matlab impementation
if exist('nanmean','file')
    y = nanmean(varargin{:});
% Otherwise, use the local implementation
else
    y = local_nanmean(varargin{:});
end
end


function y = local_nanmean(x, dim)
    if nargin<2
        N = sum(~isnan(x));
        y = local_nansum(x) ./ N;
    else
        N = sum(~isnan(x), dim);
        y = local_nansum(x, dim) ./ N;
    end
end


function y = local_nansum(x, dim)
    x(isnan(x)) = 0;
    if nargin==1
        y = sum(x);
    else
        y = sum(x,dim);
    end
end