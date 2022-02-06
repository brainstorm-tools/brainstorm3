function [TessMat, errMsg] = tess_addsquare(TessFile, SquareFile, AtlasSquareFile)
% TESS_ADD: Add a BrainSuite registered square to an existing surface.
%
% USAGE:  TessMat = tess_addsquare(TessFile, SquareFile=select)
%         TessMat = tess_addsquare(TessMat,  SquareFile=select)

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
% Authors: Anand Joshi, 2015

% Initialize returned variables
TessMat = [];
errMsg = [];

% Ask for Square file
if (nargin < 3) || isempty(SquareFile) || isempty(AtlasSquareFile)
    % Get last used directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get Surface files
    SquareFile = java_getfile( 'open', ...
       'Import registered surfaces...', ...      % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'single', 'files', ...         % Selection mode
       {{'.dfs'}, 'Registered SVReg surface (*.dfs)', 'BrainSuite'}, 'BrainSuite');
    % If no file was selected: exit
    if isempty(SquareFile)
        return
    end
    % Check corresponding atlas
    [fPath, fBase, fExt] = bst_fileparts(SquareFile);
    if ~isempty(strfind(fBase, 'right'))
        AtlasSquareFile = bst_fullfile(fPath, 'atlas.right.mid.cortex.svreg.dfs');
    else
        AtlasSquareFile = bst_fullfile(fPath, 'atlas.left.mid.cortex.svreg.dfs');
    end
    if ~file_exist(AtlasSquareFile)
        error(['Could not find corresponding atlas file: ', 10, fBase, fExt]);
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(SquareFile);
    bst_set('LastUsedDirs', LastUsedDirs);
end

% Progress bar
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Load registration', 'Loading BrainSuite registered square...');
end

% If destination surface is already loaded
if isstruct(TessFile)
    TessMat = TessFile;
    TessFile = [];
% Else: load target surface file
else
    TessMat = in_tess_bst(TessFile);
end

% Load the surface, keep in the original coordinate system
[tmp, surfSqr]  = in_tess_dfs(SquareFile);
[tmp, atlasSqr] = in_tess_dfs(AtlasSquareFile);
if strfind(AtlasSquareFile,'atlas.left.mid.cortex.svreg.dfs');
    % Left Hemisphere is being loaded Multiply the U coordinates by -1 for
    % easy computation to distinguish between left and right hemispheres
    surfSqr.u  = -1 * surfSqr.u;
    atlasSqr.u = -1 * atlasSqr.u;
end
SquareVertices = [surfSqr.u', surfSqr.v'];
AtlasSquareVertices = [atlasSqr.u', atlasSqr.v'];
% Check that the number of vertices match
if (length(SquareVertices) ~= length(TessMat.Vertices))
    errMsg = sprintf('The number of vertices in the surface (%d) and the Square (%d) do not match.', length(TessMat.Vertices), length(SquareVertices));
    TessMat = [];
    return;
end
% Add the Square vertex information to the surface matrix
TessMat.Reg.Square.Vertices = SquareVertices;
TessMat.Reg.AtlasSquare.Vertices = AtlasSquareVertices;
% Save modifications to input file
bst_save(file_fullpath(TessFile), TessMat, 'v7');

% Close progress bar
if isProgressBar
    bst_progress('stop');
end





