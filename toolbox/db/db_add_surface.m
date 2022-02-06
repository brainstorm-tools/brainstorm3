function [ iSurface ] = db_add_surface( iSubject, FileName, Comment, SurfaceType )
% DB_ADD_SURFACE: Add a surface in database and refresh tree.
%
% USAGE:  [iSurface] = db_add_surface( iSubject, FileName, Comment, SurfaceType )
%
% INPUT:
%    - iSubject    : Indice of the subject where to add the surface
%    - FileName    : Relative path to the file in which the tesselation is defined
%    - Comment     : Surface description
%    - SurfaceType : String {'Cortex', 'Scalp', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM', 'Other'}
% OUTPUT:
%    - iSurface : indice of the surface that was created in the sSubject structure

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
% Authors: Francois Tadel, 2008-2019

% If surface type is not defined : detect it
if (nargin < 4)
    % Get surface type 
    fileType = file_gettype(FileName);
    switch (fileType)
        case 'cortex',      SurfaceType = 'Cortex';
        case 'scalp',       SurfaceType = 'Scalp';
        case 'outerskull',  SurfaceType = 'OuterSkull';
        case 'innerskull',  SurfaceType = 'InnerSkull';  
        case 'fibers',      SurfaceType = 'Fibers';
        case 'fem',         SurfaceType = 'FEM';
        otherwise,          SurfaceType = 'Other';  
    end
end
% Get protocol's subjects database
ProtocolSubjects = bst_get('ProtocolSubjects');

% Fill Surface structure
newSurface = db_template('Surface');
newSurface.FileName    = file_short(FileName);
newSurface.Comment     = Comment;
newSurface.SurfaceType = SurfaceType;

% Add Surface structure to database
if (iSubject == 0) % Default subject
    iSurface = length(ProtocolSubjects.DefaultSubject.Surface) + 1;
	ProtocolSubjects.DefaultSubject.Surface(iSurface) = newSurface;
else % Normal subject
    iSurface = length(ProtocolSubjects.Subject(iSubject).Surface) + 1;
	ProtocolSubjects.Subject(iSubject).Surface(iSurface) = newSurface;
end
% Update database
bst_set('ProtocolSubjects', ProtocolSubjects);
% Make surface as default (if not 'Other')
if ~strcmpi(SurfaceType, 'Other')
    db_surface_default(iSubject, SurfaceType, iSurface);
end

% ===== UPDATE TREE =====
panel_protocols('UpdateNode', 'Subject', iSubject);
%panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
panel_protocols('SelectNode', [], newSurface.FileName);
% Save database
db_save();



