function node_set_type(bstNode, targetType)
% NODE_SET_TYPE: Set surface type for a Surface tree node (cortex, scalp, innerskull, outerskull, or other)

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
% Authors: Francois Tadel, 2008-2010

% ===== GET NODE INFO =====
nodeType = char(bstNode.getType());
SurfaceFile = char(bstNode.getFileName());
% If surface type did not change : nothing to do
if strcmpi(nodeType, targetType)
    return
end

% ===== SET SURFACE TYPE =====
newFileName = db_surface_type(SurfaceFile, targetType);
if isempty(newFileName)
    return
end

% ===== UPDATE TREE =====
% Repain subject node
panel_protocols('UpdateNode', 'Subject', bstNode.getStudyIndex());
% Select new surface file
panel_protocols('SelectNode', [], newFileName);






