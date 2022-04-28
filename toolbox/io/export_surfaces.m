function export_surfaces( BstFile, OutputFile, FileFormat )
% EXPORT_SURFACES: Export a surface to one of the supported file formats.
%
% USAGE: export_surfaces( BstFile, OutputFile, FileFormat )
%        export_surfaces( BstFile )                 : OutputFile is asked to the user
% INPUT: 
%     - BstFile    : Full path to input Brainstorm MRI file to be exported
%     - OutputFile : Full path to target file (extension will determine the format)

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

% ===== PASRSE INPUTS =====
if (nargin < 3)
    FileFormat = [];
end
if (nargin < 2)
    OutputFile = [];
end
if (nargin < 1) || isempty(BstFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_surfaces()');
end
FileFormat = [];

% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile) || isempty(FileFormat)
    % Get default directories
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Output format
    if isempty(DefaultFormats.SurfaceOut)
        DefaultFormats.SurfaceOut = 'MESH';
    end
    % Build default output filename
    [BstPath, BstBase, BstExt] = bst_fileparts(BstFile);
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportAnat, [BstBase '.' lower(DefaultFormats.SurfaceOut)]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_tess', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'tess_', '');
    % Put surface file
    [OutputFile, FileFormat] = java_getfile( 'save', ...
        'Export surface...', ...     % Window title
        DefaultOutputFile, ...       % Default directory
        'single', 'files', ...       % Selection mode
        bst_get('FileFilters', 'surfaceout'), ...
        DefaultFormats.SurfaceOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportAnat = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.SurfaceOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end

% ===== GET SUBJECT MRI =====
% Get subject
sSubject = bst_get('SurfaceFile', BstFile);
if isempty(sSubject)
    error('Surface file is not registered in database.');
end
% Load MRI
if ~isempty(sSubject.Anatomy)
    sMri = bst_memory('LoadMri', sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
    sMri = [];
end

% ===== SAVE FILE =====
out_tess(BstFile, OutputFile, FileFormat, sMri);






