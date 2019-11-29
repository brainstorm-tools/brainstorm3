function surfaces = db_surface_sort( surfacesArray )
% DB_SURFACE_SORT: Sort surfaces in different categories.
% 
% USAGE:  surfaces = db_surface_sort( surfacesArray );
%
% INPUT:
%     - surfacesArray[] : Array of Surface structures
% OUTPUT:
%     - surfaces : structure with following fields
%          |- Scalp[]      : array of Surface
%          |- OuterSkull[] : array of Surface
%          |- InnerSkull[] : array of Surface
%          |- Cortex[]     : array of Surface
%          |- Other[]      : array of Surface
%          |- FEM[]        : array of Surface


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
% Authors: Francois Tadel, 2008-2010

templateSurface = db_template('Surface');
% Initialize output structure
surfaces = struct('Scalp',      repmat(templateSurface,0), ...
                  'OuterSkull', repmat(templateSurface,0), ...
                  'InnerSkull', repmat(templateSurface,0), ...
                  'Cortex',     repmat(templateSurface,0), ...
                  'Fibers',     repmat(templateSurface,0), ...
                  'FEM',        repmat(templateSurface,0), ...
                  'Other',      repmat(templateSurface,0), ...
                  'IndexScalp',      [], ...
                  'IndexOuterSkull', [], ...
                  'IndexInnerSkull', [], ...
                  'IndexCortex',     [], ...
                  'IndexFibers',     [], ...
                  'IndexFEM',        [], ...
                  'IndexOther',      []);

for iSurf = 1:length(surfacesArray)
    surfaces.(surfacesArray(iSurf).SurfaceType)(end + 1) = surfacesArray(iSurf);
    surfaces.(['Index' surfacesArray(iSurf).SurfaceType])(end + 1) = iSurf;
end



