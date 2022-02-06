function tess_transform( SurfaceFiles, transf )
% TESS_TRANSFORM: Apply a transformation (rotation + translation) to a set of surfaces.
%
% USAGE:  tess_transform( SurfaceFiles, transf )
%    
% DESCRIPTION:
%     The transformation structure should contain at least 2 fields: transf.R and transf.T
%     They are the rotation and the translation that will be applied to the coordinates
%     of the vertices of each of the surfaces listed in SurfaceFiles.
% 
% INPUT:
%     - SurfaceFiles   : cell array of strings, full path to all the surfaces files to process
%     - Transformation : structure, rotation (.R) + translation (.T) to apply

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
% Authors: Francois Tadel, 2009

% Parse inputs
if ischar(SurfaceFiles)
    SurfaceFiles = {SurfaceFiles};
end
% Process all the files
for iFile = 1:length(SurfaceFiles)
    % If relative path name, add the protocol path
    if ~file_exist(SurfaceFiles{iFile})
        SurfaceFiles{iFile} = file_fullpath(SurfaceFiles{iFile});
    end
    % Load vertices
    SurfaceMat = in_tess_bst(SurfaceFiles{iFile});
    % Apply transform
    SurfaceMat.Vertices = ([transf.R, transf.T] * [SurfaceMat.Vertices'; ones(1,size(SurfaceMat.Vertices,1))])';
    % Update comment
    SurfaceMat.Comment = [SurfaceMat.Comment, '_SCS'];
    % History: Apply rotation + translation
    SurfaceMat = bst_history('add', SurfaceMat, 'transform', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', transf.R'));
    SurfaceMat = bst_history('add', SurfaceMat, 'transform', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', transf.T));
    % Save new vertices positions
    bst_save(SurfaceFiles{iFile}, SurfaceMat, 'v7');
    % Unload surface file
    bst_memory('UnloadSurface', SurfaceFiles{iFile});
end

        
        
        
        
