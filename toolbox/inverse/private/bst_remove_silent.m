function [Lnew,Q] = bst_remove_silent(L)
% bst_remove_silent: removes silent component of single sphere head model.
%
% USAGE:  [Lnew,Q]=bst_remove_silent(L)
%
% DESCRIPTION:
%     Removes silent component of single sphere head model.
%
% INPUTS:
%     - L : Forward field matrix for all the channels
%
% OUTPUTS:
%     - Lnew : New forward field matrix for all the channels containg 2/3
%     the number of dipole components. The radial dipole components have
%     been removed, and only the gain vectors produced by the two
%     tangential dipole components are included.
%     - Q: A matrix containg the orientations of the two tangential dipole
%     components per source point.

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
% Copyright (C) 2010 - Rey Rene Ramirez
% Authors:  Rey Rene Ramirez, Ph.D.   e-mail: rrramirez at mcw.edu

szL = size(L);
L = reshape(L,[szL(1) 3 szL(2)/3]);
Lnew = zeros(szL(1),szL(2)*(2/3));
sp = 0;
for spoint = 1:2:szL(2)*(2/3)
    sp = sp+1;
    [uL,sL,vL] = svd(L(:,:,sp),'econ');
    Lnew(:,spoint:spoint+1) = uL(:,1:2)*sL(1:2,1:2);
    Q(:,spoint:spoint+1) = vL(:,1:2);
end


