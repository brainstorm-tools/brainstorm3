function import_anatomy(iSubject)
% IMPORT_ANATOMY: Import a full anatomy folder in interactive mode (BrainVISA, BrainSuite, FreeSurfer, CIVET, SimNIBS)
%
% USAGE:  import_anatomy(iSubject)

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
% Authors: Francois Tadel, 2013-2020

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


% Import folder
switch (FileFormat)
    case 'FreeSurfer'
        import_anatomy_fs(iSubject, AnatDir, [], 1, [], 0);
    case 'FreeSurfer+Thick'
        import_anatomy_fs(iSubject, AnatDir, [], 1, [], 1);
    case 'BrainSuite'
        import_anatomy_bs(iSubject, AnatDir, [], 1, [], 0);
    case 'BrainVISA'
        import_anatomy_bv(iSubject, AnatDir, [], 1);
    case 'CAT12'
        import_anatomy_cat(iSubject, AnatDir, [], 1, [], 0);
    case 'CAT12+Thick'
        import_anatomy_cat(iSubject, AnatDir, [], 1, [], 1);
    case 'CIVET'
        import_anatomy_civet(iSubject, AnatDir, [], 1, [], 0);
    case 'CIVET+Thick'
        import_anatomy_civet(iSubject, AnatDir, [], 1, [], 1);
    case 'HCPv3'
        import_anatomy_hcp_v3(iSubject, AnatDir, 1);
    case 'SimNIBS'
        import_anatomy_simnibs(iSubject, AnatDir, [], 1, [], 0);
end


                    