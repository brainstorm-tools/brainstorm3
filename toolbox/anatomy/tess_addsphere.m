function [TessMat, errMsg] = tess_addsphere(TessFile, SphereFile)
% TESS_ADD: Add a FreeSurfer registered sphere to an existing surface.
%
% USAGE:  TessMat = tess_addsphere(TessFile, SphereFile=select)
%         TessMat = tess_addsphere(TessMat,  SphereFile=select)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

% Initialize returned variables
TessMat = [];
errMsg = [];

% Ask for sphere file
if (nargin < 2) || isempty(SphereFile)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get Surface files
    SphereFile = java_getfile( 'open', ...
       'Import surfaces...', ...      % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'single', 'files', ...         % Selection mode
       {{'.reg'}, 'Registered FreeSurfer sphere (*.reg)', 'FS'}, 'FS');
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

% Get the subject MRI
[sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
    errMsg = 'Subject does not have a registered MRI.';
    return;
end
sMri = bst_memory('LoadMri', iSubject);
    
% If destination surface is already loaded
if isstruct(TessFile)
    TessMat = TessFile;
    TessFile = [];
% Else: load target surface file
else
    TessMat = in_tess_bst(TessFile);
end

% Load the sphere surface: DO NOT CONVERT TO SCS!!!!
%SphereMat = in_tess(SphereFile, 'FS', sMri);
% Load the surface, keep in the original coordinate system
SphereVertices = mne_read_surface(SphereFile);

% Check that the number of vertices match
if (length(SphereVertices) ~= length(TessMat.Vertices))
    errMsg = sprintf('The number of vertices in the surface (%d) and the sphere (%d) do not match.', length(TessMat.Vertices), length(SphereMat.Vertices));
    TessMat = [];
    return;
end
% Add the sphere vertex information to the surface matrix
TessMat.Reg.Sphere.Vertices = SphereVertices;
% Save modifications to input file
bst_save(file_fullpath(TessFile), TessMat, 'v7');

% Close progress bar
if isProgressBar
    bst_progress('stop');
end





