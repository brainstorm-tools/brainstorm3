function export_result( BstFile, OutputFile, FileFormat )
% EXPORT_RESULT: Exports a sources file to one of the supported file formats.
%
% USAGE:  export_matrix( BstFile,    OutputFile=[ask], FileFormat=[detect] )
%         export_matrix( ResultsMat, OutputFile=[ask], FileFormat=[detect] )
%         
% INPUT: 
%     - BstFile    : Full path to a Brainstorm data file to be exported
%     - ResultsMat : Brainstorm results structure to be exported
%     - OutputFile : Full path to target file (extension will determine the format)
%                    If not specified: asked to the user

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
% Authors: Francois Tadel, 2009-2014

% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 2) || isempty(OutputFile)
    OutputFile = [];
end
% CALL: export_matrix( BstFile, ... )
if ischar(BstFile) 
    ResultsMat = in_bst_results(BstFile, 1);
% CALL: export_matrix( MatrixMat, ... ) 
else 
    ResultsMat = BstFile;
    BstFile = [];
end

    
% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.ResultsOut)
        case 'BST'
            DefaultExt = '_sources.mat';
        case 'FT-SOURCES'
            DefaultExt = '.mat';
        case {'ASCII-SPC', 'ASCII-SPC-HDR'}
            DefaultExt = '.txt';
        case {'ASCII-CSV', 'ASCII-CSV-HDR', 'ASCII-CSV-HDR-TR'}
            DefaultExt = '.csv';
        case {'ASCII-TSV', 'ASCII-TSV-HDR', 'ASCII-TSV-HDR-TR'}
            DefaultExt = '.tsv';
        case {'EXCEL', 'EXCEL-TR'}
            DefaultExt = '.xlsx';
        otherwise
            DefaultExt = '_sources.mat';
    end
    % Build default output filename
    if ~isempty(BstFile)
        fileType = file_gettype(BstFile);
        if strcmp(fileType, 'link')
            [kernelFile, dataFile] = file_resolve_link(BstFile);
            [~, kernelBase] = bst_fileparts(kernelFile);
            [BstPath, BstBase, BstExt] = bst_fileparts(dataFile);
            BstBase = [kernelBase, '_' ,BstBase];
        else
            [BstPath, BstBase, BstExt] = bst_fileparts(BstFile);
        end
    else
        BstBase = file_standardize(ResultsMat.Comment);
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportData, [BstBase, DefaultExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_results', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'results_', '');

    % === Ask user filename ===
    % Put file
    [OutputFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export sources...', ...   % Window title
        DefaultOutputFile, ...     % Default directory
        'single', 'files', ...     % Selection mode
        bst_get('FileFilters', 'resultsout'), ...
        DefaultFormats.ResultsOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return
    end    
    % Save new default export path
    LastUsedDirs.ExportData = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.ResultsOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    
% Guess file format based on its extension
elseif isempty(FileFormat)
    [BstPath, BstBase, BstExt] = bst_fileparts(OutputFile);
    switch lower(BstExt)
        case '.txt',   FileFormat = 'ASCII-SPC';
        case '.csv',   FileFormat = 'ASCII-CSV-HDR';
        case '.tsv',   FileFormat = 'ASCII-TSV-HDR';
        case '.xlsx',  FileFormat = 'EXCEL';
        case '.mat',   FileFormat = 'BST';
        otherwise,     error('Unsupported file extension.');
    end
end


% ===== SAVE RESULTS FILE =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputFile);
% Show progress bar
bst_progress('start', 'Export sources', ['Export sources to file "' [OutputBase, OutputExt] '"...']);
% Switch between file formats
switch (FileFormat)
    case 'BST'
        bst_save(OutputFile, ResultsMat, 'v6');
    case 'FT-SOURCES'
        ftData = out_fieldtrip_results(BstFile);
        bst_save(OutputFile, ftData, 'v6');
    case {'ASCII-SPC', 'ASCII-CSV', 'ASCII-TSV', 'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'ASCII-TSV-HDR', 'ASCII-CSV-HDR-TR', 'ASCII-TSV-HDR-TR', 'EXCEL', 'EXCEL-TR'}
        out_matrix_ascii(OutputFile, ResultsMat.ImageGridAmp, FileFormat, 1:size(ResultsMat.ImageGridAmp,1), ResultsMat.Time, []);
    otherwise
        error(['Unsupported file format : "' FileFormat '"']);
end

% Hide progress bar
bst_progress('stop');

end


