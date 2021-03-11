function TessMat = in_tess_nwb(TessFile)
% IN_TESS_NWB: Import a surface from an .nwb file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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

error('This code is outdated, see: https://neuroimage.usc.edu/forums/t/error-opening-nwb-files/21025');

% If ever restored, it should be edited to use the new plugin framework.
% Archive:   url = 'https://github.com/mpompolas/ECoG-Yaml/archive/master.zip';
% Configure for nwb-ecog should call:  generateCore(bst_fullfile('ecog.namespace.yaml'))


%%  INITIALIALIZE NWB SDK AND ECOG LIBRARY (FOR NOW THESE ARE SEPARATE)


%% ===== INSTALL NWB LIBRARY =====
% Check if the NWB builder has already been downloaded
NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
% Install toolbox
if exist(bst_fullfile(NWBDir, 'generateCore.m'),'file') ~= 2
    isOk = java_dialog('confirm', ...
        ['The NWB SDK is not installed on your computer.' 10 10 ...
             'Download and install the latest version?'], 'Neurodata Without Borders');
    if ~isOk
        bst_report('Error', sProcess, sInputs, 'This process requires the Neurodata Without Borders SDK.');
        return;
    end
    downloadNWB();
% If installed: add folder to path
elseif isempty(strfind(NWBDir, path))
    addpath(genpath(NWBDir));
end


%% ===== INSTALL NWB - ECoG LIBRARY =====
% Check if the NWB ECoG builder has already been downloaded
NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
% Install toolbox
if exist(bst_fullfile(NWBDir, 'ECoG', 'ecog.extensions.yaml'),'file') ~= 2
    isOk = java_dialog('confirm', ...
        ['The ECoG library is not installed on your computer.' 10 10 ...
             'Download and install the latest version?'], 'Neurodata Without Borders - ECoG');
    if ~isOk
        bst_report('Error', sProcess, sInputs, 'This process requires the Neurodata Without Borders ECoG YAML files.');
        return;
    end
    downloadNWB_ECOG();
% If installed: add folder to path
elseif isempty(strfind(NWBDir, path))
    addpath(genpath(NWBDir));
end




%% CHECK IF SURFACES ARE PRESENT
try
    nwb2 = nwbRead(TessFile);
    
    if isempty(nwb2.general_subject.cortical_surfaces.surface)
        error('There doesnt appear to be a surface present in this .nwb file')
    else
        % Get all surfaces
        all_surface_keys = keys(nwb2.general_subject.cortical_surfaces.surface)';
    end
    
catch
    error('Loading the .nwb file failed. Have you already installed the NWB SDK? Try loading a dataset before importing the anatomy')
end



%% I create the cortex surface based on the lh_pial and the rh_pial
iCortexSurfaces = [];
iOtherSurfaces  = [];
for iSurface = 1:length(all_surface_keys)
    if ~isempty(strfind(all_surface_keys{iSurface},'lh_pial'))
        iCortexSurfaces = [iCortexSurfaces iSurface];
    elseif ~isempty(strfind(all_surface_keys{iSurface},'rh_pial'))
        iCortexSurfaces = [iCortexSurfaces iSurface];
    else
        iOtherSurfaces = [iOtherSurfaces iSurface];
    end
end

%% Create separately in the struct 
separated_surfaces = {iCortexSurfaces ; iOtherSurfaces};

currentStructure = 0;
for iStructure = 1 % Just do the cortex surface          1:2
    
    if ~isempty(separated_surfaces{iStructure})
        currentStructure = currentStructure+1;

        TessMat(currentStructure).iAtlas = length(iCortexSurfaces);

        accumulated_index   = 0;
        cummulativeVertices = [];
        cummulativeFaces    = [];

        for iSurface = 1:length(separated_surfaces{iStructure})
            nVerticesSurface = nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{separated_surfaces{iStructure}(iSurface)}).vertices.dims(1);
            Scouts(iSurface).Vertices  = accumulated_index + [1:nVerticesSurface];
            Scouts(iSurface).Seed      = Scouts(iSurface).Vertices(1);
            Scouts(iSurface).Color     = rand(1,3);
            Scouts(iSurface).Label     = all_surface_keys{separated_surfaces{iStructure}(iSurface)};
            Scouts(iSurface).Function  = 'Mean';
            Scouts(iSurface).Region    = 'DEEP';%all_surface_keys{iSurface};
            Scouts(iSurface).Handles   = [];

            cummulativeVertices = [cummulativeVertices; nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{separated_surfaces{iStructure}(iSurface)}).vertices.load' + 1]; % NWB vertices start from 0 ????? THIS IS NOT CONFIRMED YET, but it's probably true]
            cummulativeFaces    = [cummulativeFaces   ; nwb2.general_subject.cortical_surfaces.surface.get(all_surface_keys{separated_surfaces{iStructure}(iSurface)}).faces.load'    + 1 + accumulated_index];    % NWB faces start from 0 ????? THIS IS NOT CONFIRMED YET, but it's probably true

            accumulated_index = accumulated_index + nVerticesSurface;
        end

        %% Invert the Face that the nwb files are saved in
        % Brainstorm uses the opposite side
        cummulativeFaces = cummulativeFaces(:,[3,2,1]);

        TessMat(currentStructure).Atlas(1).Name   = 'User scouts';
        TessMat(currentStructure).Atlas(1).Scouts = [];
        TessMat(currentStructure).Atlas(2).Name   = 'Structures';
        TessMat(currentStructure).Atlas(2).Scouts = Scouts;

        TessMat(currentStructure).Vertices = cummulativeVertices./1000; % Vertices in NWB are saved in meters, Brainstorm uses mm
        TessMat(currentStructure).Faces    = cummulativeFaces;

         if iStructure == 1
            TessMat(currentStructure).Comment = ['cortex_' num2str(size(TessMat(currentStructure).Vertices,1)) 'V']; % cortex surface
        else
            TessMat(currentStructure).Comment = 'subcortical';
        end

        %% Fill the rest of the fields
        % ===== VERTEX CONNECTIVITY =====
        % If vertex connectivity field is not available for this surface: Compute it
        TessMat(currentStructure).VertConn = tess_vertconn(TessMat(currentStructure).Vertices, TessMat(currentStructure).Faces);


        % ===== VERTEX NORMALS =====
        % If VertexNormal field is not available for this surface: Compute it
        TessMat(currentStructure).VertNormals = tess_normals(TessMat(currentStructure).Vertices, TessMat(currentStructure).Faces, TessMat(currentStructure).VertConn);

        % ===== CURVATURE =====
        % If Curvature field is not available for this surface: Compute it
        TessMat(currentStructure).Curvature = single(tess_curvature(TessMat(currentStructure).Vertices, TessMat(currentStructure).VertConn, TessMat(currentStructure).VertNormals, .1));

        % ===== SULCI MAP =====
        % If Curvature field is not available for this surface: Compute it
        TessMat(currentStructure).SulciMap = tess_sulcimap(TessMat(currentStructure));
    end

end


