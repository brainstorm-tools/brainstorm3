function TessMat = in_tess_nwb(TessFile)
% IN_TESS_NWB: Import a surface from an .nwb file

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
% Authors: Konstantinos Nasiotis, 2019



try
    nwb2 = nwbRead(TessFile);
    
    if isempty(nwb2.general_subject.cortical_surfaces.surface)
        error('There doesnt appear to be a surface present in this .nwb file')
    else
        % Get all surfaces
        all_surface_keys = keys(nwb2.general_subject.cortical_surfaces.surface)';
    end
    
catch
    error('Loading the .nwb file failed. Have you already installed the NWB SDK? If not, try loading a dataset before importing the anatomy')
end



TessMat.Comment = 'NWB SURFACES'; % aseg atlas
TessMat.iAtlas = length(all_surface_keys);


accumulated_index   = 0;
cummulativeVertices = [];
cummulativeFaces    = [];





selectedSurfaces = [7 9];
TessMat.iAtlas = length(selectedSurfaces);







for iSurface = selectedSurfaces % 1:length(all_surface_keys)
    nVerticesSurface = nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{iSurface}).vertices.dims(1);
    Scouts(iSurface).Vertices  = accumulated_index + [1:nVerticesSurface];
    Scouts(iSurface).Seed      = Scouts(iSurface).Vertices(1);
    Scouts(iSurface).Color     = rand(1,3);
    Scouts(iSurface).Label     = all_surface_keys{iSurface};
    Scouts(iSurface).Function  = 'Mean';
    Scouts(iSurface).Region    = 'DEEP';%all_surface_keys{iSurface};
    Scouts(iSurface).Handles   = [];
    
    
    cummulativeVertices = [cummulativeVertices; nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{iSurface}).vertices.load' + 1]; % NWB vertices start from 0 ????? THIS IS NOT CONFIRMED YET, but it's probably true]
    cummulativeFaces    = [cummulativeFaces   ; nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{iSurface}).faces.load'    + 1 + accumulated_index];    % NWB faces start from 0 ????? THIS IS NOT CONFIRMED YET, but it's probably true

    accumulated_index = accumulated_index + nVerticesSurface;

end

TessMat.Atlas.Name   = 'Structures';
TessMat.Atlas.Scouts = Scouts;

TessMat.Vertices = cummulativeVertices;
TessMat.Faces    = cummulativeFaces;

end