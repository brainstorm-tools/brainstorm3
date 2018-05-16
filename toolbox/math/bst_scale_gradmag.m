function F = bst_scale_gradmag( F, Channel, varargin )
% BST_SCALE_GRADMAG: Apply an "axial factor" to uniformize the magnetometers and gradiometers values.
%                    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert from fT/m to fT
%                    - CTF: Apply factor to MEG REF gradiometers
%
% USAGE:  F = bst_scale_gradmag( F, Channel )
%         F = bst_scale_gradmag( F, Channel, 'reverse' ) : Convert back to the original values

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: François Tadel, 2009-2011

% === PARSE INPUTS ===
if (nargin >= 3) && any(strcmpi(varargin, 'reverse'))
    isReverse = 1;
else
    isReverse = 0;
end

% === NEUROMAG: SCALE MEG GRAD ===
% Axial multiplier: 4cm
AxialFactor = 0.04;
% Apply axial factor to the gradiometers
iGrad = good_channel(Channel, [], 'MEG GRAD');
if ~isempty(iGrad)
    %disp(sprintf('BST> WARNING: MEG Gradiometers values are multiplied by: %1.3f (axial factor)', AxialFactor));
    if isReverse
        F(iGrad,:) = F(iGrad,:) ./ AxialFactor;
    else
        F(iGrad,:) = F(iGrad,:) .* AxialFactor;
    end
end

% % === CTF: SCALE MEG REF GRADIOMETERS ===
% % Factor: ???? Empirical value... Doesn't matter, the goal is just to view the shape of the traces
% AxialFactor = 35;
% % Get MEG REF channels
% iRef = good_channel(Channel, [], 'MEG REF');
% if ~isempty(iRef)
%     % Get only the MEG REF sensors that have two coils (=> REF Gradiometers)
%     iRefGrad = iRef(cellfun(@(c)isequal(size(c,2), 2), {Channel(iRef).Loc}));
%     % Apply factor
%     %disp(sprintf('BST> WARNING: MEG REF gradiometers values are multiplied by: %1.3f (axial factor)', AxialFactor));
%     if isReverse
%         F(iRefGrad,:) = F(iRefGrad,:) ./ AxialFactor;
%     else
%         F(iRefGrad,:) = F(iRefGrad,:) .* AxialFactor;
%     end
% end


