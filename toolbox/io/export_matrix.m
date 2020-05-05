function export_matrix( BstFile, OutputFile, FileFormat )
% EXPORT_MATRIX: Exports a matrix file to one of the supported file formats.
%
% USAGE:  export_matrix( BstFile,   OutputFile=[ask], FileFormat=[detect] )
%         export_matrix( MatrixMat, OutputFile=[ask], FileFormat=[detect] )
%         
% INPUT: 
%     - BstFile     : Full path to a Brainstorm file to be exported
%     - MatrixMat   : Brainstorm matrix structure to be exported
%     - OutputFile  : Full path to target file (extension will determine the format)
%                     If not specified: asked to the user

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
% Authors: Francois Tadel, 2014

% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 2) || isempty(OutputFile)
    OutputFile = [];
end
% CALL: export_matrix( BstFile, ... )
if ischar(BstFile) 
    MatrixMat = in_bst_matrix(BstFile);
% CALL: export_matrix( MatrixMat, ... ) 
else 
    MatrixMat = BstFile;
    BstFile = [];
end

% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.MatrixOut)
        case 'BST'
            DefaultExt = '_matrix.mat';
        case 'FT-TIMELOCK'
            DefaultExt = '.mat';
        case {'ASCII-SPC', 'ASCII-SPC-HDR'}
            DefaultExt = '.txt';
        case {'ASCII-CSV', 'ASCII-CSV-HDR'}
            DefaultExt = '.csv';
        case 'EXCEL'
            DefaultExt = '.xlsx';
        otherwise
            DefaultExt = '_matrix.mat';
    end
    % Build default output filename
    if ~isempty(BstFile)
        [BstPath, BstBase, BstExt] = bst_fileparts(BstFile);
    else
        BstBase = file_standardize(MatrixMat.Comment);
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportData, [BstBase, DefaultExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_matrix', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'matrix_', '');

    % === Ask user filename ===
    % Put file
    [OutputFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export matrix...', ... % Window title
        DefaultOutputFile, ...     % Default directory
        'single', 'files', ...     % Selection mode
        bst_get('FileFilters', 'matrixout'), ...
        DefaultFormats.MatrixOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return
    end    
    % Save new default export path
    LastUsedDirs.ExportData = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.MatrixOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    
% Guess file format based on its extension
elseif isempty(FileFormat)
    [BstPath, BstBase, BstExt] = bst_fileparts(ExportFile);
    switch lower(BstExt)
        case '.txt',   FileFormat = 'ASCII-CSV';
        case '.csv',   FileFormat = 'ASCII-SPC';
        case '.xlsx',  FileFormat = 'EXCEL';
        case '.mat',   FileFormat = 'BST';
        otherwise,     error('Unsupported file extension.');
    end
end


% ===== SAVE MATRIX FILE =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputFile);
% Show progress bar
bst_progress('start', 'Export time-freq', ['Export matrix to file "' [OutputBase, OutputExt] '"...']);
% Switch between file formats
switch (FileFormat)
    case 'BST'
        bst_save(OutputFile, MatrixMat, 'v6');
    case 'FT-TIMELOCK'
        ftData = out_fieldtrip_matrix(MatrixMat);
        bst_save(OutputFile, ftData, 'v6');
    case {'ASCII-SPC', 'ASCII-CSV', 'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'EXCEL'}
        out_matrix_ascii(OutputFile, MatrixMat.Value, FileFormat, MatrixMat.Description, MatrixMat.Time, []);
    otherwise
        error(['Unsupported file extension : "' OutputExt '"']);
end

% Hide progress bar
bst_progress('stop');

end


