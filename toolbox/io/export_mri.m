function export_mri( BstMriFile, OutputMriFile )
% EXPORT_MRI: Export a MRI to one of the supported file formats.
%
% USAGE:  export_mri( BstMriFile, OutputMriFile=[ask] )
%         export_mri( sMri,       OutputMriFile=[ask] )
% INPUT: 
%     - BstMriFile    : Full path to input Brainstorm MRI file to be exported
%     - sMri          : Brainstorm MRI structure
%     - OutputMriFile : Full path to target file (extension will determine the format)

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
% Authors: Francois Tadel, 2008-2016

% ===== PARSE INPUTS =====
if (nargin < 1) || isempty(BstMriFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_mri()');
end
if (nargin < 2)
    OutputMriFile = [];
end

% ===== LOAD MRI FILE =====
% Show progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Export MRI', 'Loading input file');
end
% Load MRI
if ischar(BstMriFile)
    sMri = in_mri_bst(BstMriFile);
else
    sMri = BstMriFile;
    BstMriFile = [];
end
if ~isProgress
    bst_progress('stop'); 
end

% ===== SELECT OUTPUT FILE =====
if isempty(OutputMriFile)
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Export extension
    if isempty(DefaultFormats.MriOut)
        DefaultFormats.MriOut = 'Analyze';
    end
    switch DefaultFormats.MriOut
        case 'GIS',     ExportExt = '.ima';
        case 'Analyze', ExportExt = '.img';
        case 'CTF',     ExportExt = '.mri';
        case 'Nifti1',  ExportExt = '.nii';
        case 'FT-MRI',  ExportExt = '.mat';
        otherwise,      ExportExt = '.nii';
    end
    % Build default output filename
    if ~isempty(BstMriFile)
        [BstPath, BstBase, BstExt] = bst_fileparts(BstMriFile);
    else
        BstBase = 'export';
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportAnat, [BstBase, ExportExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_subjectimage', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'subjectimage_', '');
    % Put MRI file
    [OutputMriFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export MRI...', ...             % Window title
        DefaultOutputFile, ...       % Default directory
        'single', 'files', ...           % Selection mode
        bst_get('FileFilters', 'mriout'), ...
        DefaultFormats.MriOut);
    % If no file was selected: exit
    if isempty(OutputMriFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportAnat = bst_fileparts(OutputMriFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.MriOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end

% ===== SAVE MRI =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputMriFile);
% Show progress bar
if ~isProgress
    bst_progress('start', 'Export MRI', ['Export MRI to file "' [OutputBase, OutputExt] '"...']);
end
% Switch between file formats
switch lower(OutputExt)
    case '.ima'
        out_mri_gis(sMri, OutputMriFile);
    case {'.img', '.nii'}
        out_mri_nii(sMri, OutputMriFile);
    case '.mri'
        out_mri_ctf(sMri, OutputMriFile);
    case '.mat'
        ftMri = out_fieldtrip_mri(sMri);
        bst_save(OutputMriFile, ftMri, 'v7');
    otherwise
        error(['Unsupported file extension : "' OutputExt '"']);
end
% Hide progress bar
if ~isProgress
    bst_progress('stop');
end





