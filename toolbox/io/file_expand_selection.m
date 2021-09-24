function ExpFiles = file_expand_selection(FileFilter, Files)
% Expands a list of paths :
%    1) If it is a file => keep it unchanged
%    2) If they are .ds/ directory with .meg4/.res4 files,
%       or ERPCenter directories with .hdr/.erp files,
%       => keep them as "files to open"
%    3) Else : add all the data files they contains (subdirectories included)

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
% Authors: Francois Tadel, 2010-2017

% Returned variable
ExpFiles = {};
% Get file format
FileFormat = char(FileFilter.getFormatName());
% Loop on all the selected items
for i = 1:length(Files)
    % DIRECTORIES
    if isdir(Files{i})
        isDirFile = 0;
        % If CTF/ERP format
        if ismember(FileFormat, {'CTF', 'EEG-ERPCENTER', 'EEG-NEURALYNX', 'EEG-NEURONE', 'EEG-EGI-MFF'})
            switch (FileFormat)
                case 'CTF'
                    % Check if there are .meg4 or .res4 files in directory
                    dirFiles = [dir(bst_fullfile(Files{i}, '*.meg4'));
                                dir(bst_fullfile(Files{i}, '*.res4'))];
                case 'EEG-ERPCENTER'
                    % Check if there are .hdr file in directory
                    dirFiles = dir(bst_fullfile(Files{i}, '*.hdr'));
                case 'EEG-NEURALYNX'
                    % Check if there are .ncs or .nse files in directory
                    dirFiles = [dir(bst_fullfile(Files{i}, '*.ncs'));
                                dir(bst_fullfile(Files{i}, '*.nse'))];
                case 'EEG-NEURONE'
                    % Get binary files 1-9.bin
                    dirFiles = [dir(bst_fullfile(Files{i}, '1.bin')); dir(bst_fullfile(Files{i}, '2.bin')); dir(bst_fullfile(Files{i}, '3.bin')); dir(bst_fullfile(Files{i}, '4.bin')); dir(bst_fullfile(Files{i}, '5.bin'));
                                dir(bst_fullfile(Files{i}, '6.bin')); dir(bst_fullfile(Files{i}, '7.bin')); dir(bst_fullfile(Files{i}, '8.bin')); dir(bst_fullfile(Files{i}, '9.bin'))];
                case 'EEG-EGI-MFF'
                    % Check if there are .bin files in directory
                    dirFiles = dir(bst_fullfile(Files{i}, '*.bin'));
            end
            j = 1;
            while (~isDirFile && (j <= length(dirFiles)))
                if FileFilter.accept(java.io.File(bst_fullfile(Files{i}, dirFiles(j).name)))
                    isDirFile = 1;
                    ExpFiles = cat(2, ExpFiles, Files{i});
                else
                    j = j + 1;
                end
            end
        end

        % If directory is not a CTF/ERP dir to be opened
        if ~isDirFile
            % Get all files in this directory
            dirFiles = dir(bst_fullfile(Files{i}, '*'));
            % Build a new files list
            dirFullFiles = {};
            for j = 1:length(dirFiles)
                % Skip all the files that start with a '.'
                if (dirFiles(j).name(1) == '.') 
                    continue;
                end
                % Skip all the 4D system files
                if strcmpi(FileFormat, '4D') && ismember(dirFiles(j).name, {'config', 'hs_file'}) 
                    continue;
                end
                dirFullFiles{end + 1} = bst_fullfile(Files{i}, dirFiles(j).name);
            end
            % And call function recursively
            ExpFiles = cat(2, ExpFiles, file_expand_selection(FileFilter, dirFullFiles));
        end

    % SINGLE FILE
    else
        % Test if is accepted by FileFilter
        if FileFilter.accept(java.io.File(Files{i}))
            % If single file is CTF : get the parent 
            if strcmpi(FileFormat, 'CTF') || strcmpi(FileFormat, 'EEG-NEURALYNX')
                ExpFiles{end+1} = bst_fileparts(Files{i});
            else
                ExpFiles{end+1} = Files{i};
            end
        end
    end
end


