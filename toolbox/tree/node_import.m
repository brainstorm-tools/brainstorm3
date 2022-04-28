function node_import( bstnode )
% NODE_IMPORT: Update a brainstorm file with a variable coming from the Matlab base workspace.

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
% Authors: Francois Tadel, 2008-2013

% Get node information
FileName = char(bstnode.getFileName());
iItem    = bstnode.getStudyIndex();
% Get full filename
[FileName, FileType, isAnatomy] = file_fullpath( FileName );

% Get variable from workspace
[value, varname] = in_matlab_var([], 'struct');
if isempty(value)
    return
end

% Check if structure matches the file type
if (strcmpi(FileType, 'anatomy') && ~isfield(value, 'Cube')) || ...
   (ismember(lower(FileType), {'scalp', 'outerskull', 'innerskull', 'cortex', 'fem', 'other'}) && ~isfield(value, 'Vertices')) || ...
   (strcmpi(FileType, 'channel') && ~isfield(value, 'Channel')) || ...
   (strcmpi(FileType, 'headmodel') && ~isfield(value, 'Gain')) || ...
   (ismember(lower(FileType), {'data', 'rawdata'})   && ~isfield(value, 'F')) || ...
   (ismember(lower(FileType), {'results', 'kernel'}) && ~isfield(value, 'ImageGridAmp')) || ...
   (ismember(lower(FileType), {'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix'}) && ~isfield(value, 'tmap')) || ...
   (ismember(lower(FileType), {'timefreq', 'spectrum'}) && ~isfield(value, 'TF')) || ...
   (strcmpi(FileType, 'noisecov') && ~isfield(value, 'NoiseCov')) || ...
   (strcmpi(FileType, 'ndatacov') && ~isfield(value, 'NoiseCov')) || ...
   (strcmpi(FileType, 'matrix') && ~isfield(value, 'Value'))
    bst_error(['Invalid structure for file type "' FileType '".'], 'Import from Matlab', 0);
    return;
end

% History: File imported from Matlab variable
if ismember(lower(FileType), {'anatomy', 'scalp', 'outerskull', 'innerskull', 'cortex', 'fem', 'other', 'channel', 'headmodel', 'data', 'rawdata', 'results', 'kernel', 'pdata', 'presults', 'noisecov', 'ndatacov', 'dipoles', 'timefreq', 'ptimefreq', 'spectrum', 'pspectrum', 'matrix', 'pmatrix'})
    value = bst_history('add', value, 'import', ['Imported from Matlab variable: ' varname]);
end
% MAT-file format
if ismember(lower(FileType), {'data', 'rawdata', 'results', 'kernel', 'pdata', 'presults', 'timefreq', 'ptimefreq', 'spectrum', 'pspectrum', 'matrix', 'pmatrix'})
    matVersion = 'v6';
else
    matVersion = 'v7';
end

% Progress bar
bst_progress('start', 'Import from workspace variable', 'Saving file...');
% Save file
bst_save(FileName, value, matVersion);
% Reload target subject or study
if isAnatomy
    db_reload_subjects(iItem);
else
    db_reload_studies(iItem);
end
bst_progress('stop');
disp(['BST> File imported from ''' varname '''.']);

% Unload all datasets (safer)
bst_memory('UnloadAll', 'Forced');
% Save database
db_save(); 

