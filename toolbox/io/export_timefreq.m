function export_timefreq( BstFile, OutputFile, FileFormat )
% EXPORT_TIMEFREQ: Exports a timefreq file to one of the supported file formats.
%
% USAGE:  export_timefreq( BstFile,    OutputFile=[ask], FileFormat=[detect] )
%         export_timefreq( ResultsMat, OutputFile=[ask], FileFormat=[detect] )
%
% INPUT: 
%     - BstFile     : Full path to a Brainstorm file to be exported
%     - TimefreqMat : Brainstorm timefreq structure to be exported
%     - OutputFile  : Full path to target file (extension will determine the format)
%                     If not specified: asked to the user

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
% Authors: Francois Tadel, 2010-2014

% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 2) || isempty(OutputFile)
    OutputFile = [];
end
% CALL: export_matrix( BstFile, ... )
if ischar(BstFile) 
    TimefreqMat = in_bst_timefreq(BstFile, 1);
% CALL: export_matrix( MatrixMat, ... ) 
else 
    TimefreqMat = BstFile;
    BstFile = [];
end


% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.TimefreqOut)
        case 'BST'
            DefaultExt = '_timefreq.mat';
        case 'FT-FREQ'
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
            DefaultExt = '_timefreq.mat';
    end
    % Build default output filename
    if ~isempty(BstFile)
        [BstPath, BstBase, BstExt] = bst_fileparts(BstFile);
    else
        BstBase = file_standardize(TimefreqMat.Comment);
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportData, [BstBase, DefaultExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_timefreq', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'timefreq_', '');

    % === Ask user filename ===
    % Put file
    [OutputFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export time-freq...', ... % Window title
        DefaultOutputFile, ...     % Default directory
        'single', 'files', ...     % Selection mode
        bst_get('FileFilters', 'timefreqout'), ...
        DefaultFormats.TimefreqOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return
    end    
    % Save new default export path
    LastUsedDirs.ExportData = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.TimefreqOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    
% Guess file format based on its extension
elseif isempty(FileFormat)
    [BstPath, BstBase, BstExt] = bst_fileparts(ExportFile);
    switch lower(BstExt)
        case '.txt',   FileFormat = 'ASCII-SPC';
        case '.csv',   FileFormat = 'ASCII-CSV-HDR';
        case '.tsv',   FileFormat = 'ASCII-TSV-HDR';
        case '.xlsx',  FileFormat = 'EXCEL';
        case '.mat',   FileFormat = 'BST';
        otherwise,     error('Unsupported file extension.');
    end
end


% ===== SAVE TIMEFREQ FILE =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputFile);
% Show progress bar
bst_progress('start', 'Export time-freq', ['Export time-freq to file "' [OutputBase, OutputExt] '"...']);
% Switch between file formats
switch (FileFormat)
    case 'BST'
        bst_save(OutputFile, TimefreqMat, 'v6');
    case 'FT-FREQ'
        ftData = out_fieldtrip_timefreq(BstFile);
        bst_save(OutputFile, ftData, 'v6');
    case {'ASCII-SPC', 'ASCII-CSV', 'ASCII-TSV', 'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'ASCII-TSV-HDR', 'ASCII-CSV-HDR-TR', 'ASCII-TSV-HDR-TR', 'EXCEL', 'EXCEL-TR'}
        % Format frequency labels
        if iscell(TimefreqMat.Freqs)
            LabelFreq = TimefreqMat.Freqs(:,1)';
        else
            LabelFreq = TimefreqMat.Freqs;
        end
        % Connectivity
        if ~isempty(TimefreqMat.RefRowNames)
            % Rebuild connectivity matrix
            R = bst_memory('GetConnectMatrix', TimefreqMat);
            % If there are multiple frequency bins
            if (size(R,4) > 1)
                % Cannot have both time and frequency
                if (size(R,3) > 1)
                    error('Cannot export connectivity matrices that are changing both in time and frequency.');
                end
                % Transfer frequency dimension to 3rd dimension 
                R = permute(R, [1 2 4 3]);
            end
            % Save it to a file
            out_matrix_ascii(OutputFile, R, FileFormat, TimefreqMat.RefRowNames, TimefreqMat.RowNames, LabelFreq, '\');
        % Time-frequency / spectrum
        else
            out_matrix_ascii(OutputFile, TimefreqMat.TF, FileFormat, TimefreqMat.RowNames, TimefreqMat.Time, LabelFreq);
        end
    otherwise
        error(['Unsupported file extension : "' OutputExt '"']);
end

% Hide progress bar
bst_progress('stop');

end


