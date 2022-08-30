function import_anatomy(iSubject, isAuto)
% IMPORT_ANATOMY: Import a full anatomy folder in interactive mode (BrainVISA, BrainSuite, FreeSurfer, CIVET, SimNIBS)
%
% USAGE:  import_anatomy(iSubject, isAuto=0)

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
% Authors: Francois Tadel, 2013-2020

% Parse inputs
if (nargin < 2) || isempty(isAuto)
    isAuto = 0;
end

% Get default import directory and formats
LastUsedDirs = bst_get('LastUsedDirs');
DefaultFormats = bst_get('DefaultFormats');
% Open file selection dialog
[AnatDir, FileFormat] = java_getfile( 'open', ...
    'Import anatomy folder...', ...
    bst_fileparts(LastUsedDirs.ImportAnat, 1), ...
    'single', 'dirs', ...
    bst_get('FileFilters', 'AnatIn'), DefaultFormats.AnatIn);
% If no folder was selected: exit
if isempty(AnatDir)
    return
end
% Save default import directory
LastUsedDirs.ImportAnat = AnatDir;
bst_set('LastUsedDirs', LastUsedDirs);
% Save default import format
DefaultFormats.AnatIn = FileFormat;
bst_set('DefaultFormats',  DefaultFormats);

% Auto-import: 15000 vertices, MNI registration
if isAuto
    isInteractive = 0;
    nVertices = 15000;
else
    isInteractive = 1;
    nVertices = [];
end
sFid = [];

% Import folder
switch (FileFormat)
    case 'FreeSurfer-fast'
        errorMsg = import_anatomy_fs(iSubject, AnatDir, nVertices, isInteractive, sFid, 0, 0);
    case 'FreeSurfer'
        errorMsg = import_anatomy_fs(iSubject, AnatDir, nVertices, isInteractive, sFid, 0, 1);
    case 'FreeSurfer+Thick'
        errorMsg = import_anatomy_fs(iSubject, AnatDir, nVertices, isInteractive, sFid, 1, 1);
    case 'BrainSuite-fast'
        errorMsg = import_anatomy_bs(iSubject, AnatDir, nVertices, isInteractive, sFid, 0);
    case 'BrainSuite'
        errorMsg = import_anatomy_bs(iSubject, AnatDir, nVertices, isInteractive, sFid, 1);
    case 'BrainVISA'
        errorMsg = import_anatomy_bv(iSubject, AnatDir, nVertices, isInteractive);
    case 'CAT12'
        errorMsg = import_anatomy_cat(iSubject, AnatDir, nVertices, isInteractive, sFid, 0);
    case 'CAT12+Thick'
        errorMsg = import_anatomy_cat(iSubject, AnatDir, nVertices, isInteractive, sFid, 1);
    case 'CIVET'
        errorMsg = import_anatomy_civet(iSubject, AnatDir, nVertices, isInteractive, sFid, 0);
    case 'CIVET+Thick'
        errorMsg = import_anatomy_civet(iSubject, AnatDir, nVertices, isInteractive, sFid, 1);
    case 'HCPv3'
        errorMsg = import_anatomy_hcp_v3(iSubject, AnatDir, isInteractive);
    case 'SimNIBS'
        errorMsg = import_anatomy_simnibs(iSubject, AnatDir, nVertices, isInteractive, sFid, 0);
end
% Handling errors in automatic mode
if isAuto && ~isempty(errorMsg)
    bst_error(['Could not import anatomy folder (' FileFormat '): ' 10 10 errorMsg], 'Import anatomy folder', 0);   
end


                    