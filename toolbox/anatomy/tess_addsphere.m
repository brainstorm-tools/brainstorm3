function [TessMat, errMsg] = tess_addsphere(TessFile, SphereFile, FileFormat, isControlateral)
% TESS_ADD: Add a FreeSurfer registered sphere to an existing surface.
%
% USAGE:  TessMat = tess_addsphere(TessFile, SphereFile=select, FileFormat=select, isControlateral=0)

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
% Authors: Francois Tadel, 2013-2022

% Initialize returned variables
TessMat = [];
errMsg = [];

% No contralateral by default
if (nargin < 4) || isempty(isControlateral)
    isControlateral = 0;
end
% Ask for sphere file
if (nargin < 3) || isempty(SphereFile) || isempty(FileFormat)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get Surface files
    [SphereFile, FileFormat] = java_getfile( 'open', ...
       'Import surfaces...', ...      % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'single', 'files', ...         % Selection mode
       {{'.reg'}, 'Registered FreeSurfer sphere (*.reg)', 'FS'; ...
        {'.reg'}, 'Registered FreeSurfer controlateral sphere (*.reg)', 'FS-Controlateral' ; ...
        {'.gii'}, 'CAT12 registered spheres (*.gii)',     'GII-CAT'}, 'FS');

    if strcmp(FileFormat,'FS-Controlateral')
        isControlateral = 1;
        FileFormat      = 'FS';
    end

    % If no file was selected: exit
    if isempty(SphereFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(SphereFile);
    bst_set('LastUsedDirs', LastUsedDirs);
end

% Progress bar
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Load registration', 'Loading FreeSurfer sphere...');
end
  
% Load target surface file
TessMat = in_tess_bst(TessFile);

% Load the sphere surface
switch (FileFormat)
    case 'FS'
        % DO NOT CONVERT TO SCS!!!!
        % Load the surface, keep in the original coordinate system
        SphereVertices = mne_read_surface(SphereFile);
        
    case 'GII-CAT'
        SphereMat = in_tess_gii(SphereFile);
        % Get the subject MRI
        [sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
        if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
            errMsg = 'Subject does not have a registered MRI.';
            return;
        end
        % Load subject MRI
        sMri = bst_memory('LoadMri', iSubject);
        % Scale to have the same range as in the Brainstorm templates
        % => spm12/toolbox/cat12/template_surfaces/lh.sphere.freesurfer.gii => Radius = 0.1 (pas de changement)
        % => cat12_output/surf/lh.sphere.reg.0001GRE_25112014.gii => Radius = 0.001 (multiplication par 100)
        if (round(max(SphereMat.Vertices(:,1)) * 1000) < 10)
            SphereMat.Vertices = SphereMat.Vertices .* 100;
        end
        % Convert to the same space as the FreeSurfer spheres
        SphereVertices = bst_bsxfun(@rdivide, SphereMat.Vertices, sMri.Voxsize);
end

% Check that the number of vertices match
if (length(SphereVertices) ~= length(TessMat.Vertices))
    errMsg = sprintf('The number of vertices in the surface (%d) and the sphere (%d) do not match.', length(TessMat.Vertices), length(SphereVertices));
    TessMat = [];
    return;
end

if ~isControlateral
    % Add the sphere vertex information to the surface matrix
    TessMat.Reg.Sphere.Vertices = SphereVertices;
else
    % Add the contralateral sphere to the surface matrix (option "-contrasurfreg" from freesurfer recon-all)
    TessMat.Reg.SphereLR.Vertices = SphereVertices;
end

% Save modifications to input file
bst_save(file_fullpath(TessFile), TessMat, 'v7');

% Close progress bar
if isProgressBar
    bst_progress('stop');
end





