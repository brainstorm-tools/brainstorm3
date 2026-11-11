function [DataSetName, meg4_files, res4_file, marker_file, pos_file, hc_file, badseg_file] = ctf_get_files( ds_directory, verbose, isInteractive)
% CTF_GET_FILES: Get the name and files of a CTF .DS directory.
%
% INPUT: 
%     - ds_directory  : Full path to a .ds CTF directory
%     - verbose       : Whether to display information in the command window (by default)
%     - isInteractive : Whether the caller can show interactive dialogs (e.g. when several .pos
%                       files are found). If not provided, default to the current GUI state
%                       (Brainstorm GUI running and verbose>=1), for backwards compatibility.
% OUTPUT:
%     - DataSetName  : Name of the input CTF dataset
%     - meg4_files   : Cell array of full paths to the recordings files (.meg4, .1_meg4, .2_meg4, ...)
%     - res4_file    : Full path to the header file (.res4)
%     - marker_file  : Full path to the marker file in this folder (.mrk)
%     - pos_file     : Full path to the polhemus digitized head points
%     - hc_file      : Full path to the original measured head coordinates
%     - badseg_file  : Full path to the bad segments file (bad.segments)

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
% Authors: Francois Tadel, 2008-2020

% Parse arguments
if nargin < 2
    verbose = 1;
end
if (nargin < 3) || isempty(isInteractive)
    % Backwards compatible default: interactive only if a Brainstorm GUI session is running
    global GlobalData;
    isInteractive = (verbose >= 1) && ~isempty(GlobalData) && isstruct(GlobalData) && ...
                    isfield(GlobalData, 'Program') && isfield(GlobalData.Program, 'GuiLevel') && ...
                    (GlobalData.Program.GuiLevel >= 0);
end

% ===== .MEG4 =====
% Find the first .meg4 file in this directory
meg4list = dir(bst_fullfile(ds_directory, '*.meg4'));
% Remove the filenames that start with "."
iHidden = [];
for i = 1:length(meg4list)
    if (meg4list(i).name(1) == '.')
        iHidden(end+1) = i;
    end
end
if ~isempty(iHidden)
    meg4list(iHidden) = [];
end
% If there is not one single meg4 file
if isempty(meg4list)
    error('No .meg4 file in CTF directory');
elseif (length(meg4list) > 1)
    error('There is more than one .meg4 file in CTF directory');
end
% Only one .meg4 in .ds directory : OK
meg4_files = {fullfile(ds_directory, meg4list.name)};
% Get dataset name
[tmp__, DataSetName] = bst_fileparts(meg4list.name);

% ===== .X_MEG4 =====
% Look for all the *.i_meg4 files in the folder (the first of the list is actually the .meg4 file)
% Each one contains an integer number of trials, and cannot exceed 2Gb
i = 1;
stop = false;
while ~stop
    dirMeg4 = dir(bst_fullfile(ds_directory, sprintf('*.%d_meg4', i)));
    if (length(dirMeg4) ~= 1)
        stop = true;
    else
        meg4_files{i+1} = bst_fullfile(ds_directory, dirMeg4.name);
        i = i + 1;
    end
end

% ===== .RES4 =====
% Get .res4 files
res4_file = bst_fullfile(ds_directory, [DataSetName,'.res4']);
% Check that both files are accessible
if ~file_exist(res4_file) || ~file_exist(meg4_files{1}) 
   error([res4_file ' or ' meg4_files{1} ' missing']);
end

% ===== .MRK =====
% Get marker file
marker_file = bst_fullfile(ds_directory, 'MarkerFile.mrk');
% No default marker file available in current data set
if ~exist(marker_file,'file')
    % Try to look for another marker file
    mrkFiles = dir(bst_fullfile(ds_directory, '*.mrk'));
    % Remove the filenames that start with "."
    iHidden = [];
    for i = 1:length(mrkFiles)
        if (mrkFiles(i).name(1) == '.')
            iHidden(end+1) = i;
        end
    end
    if ~isempty(iHidden)
        mrkFiles(iHidden) = [];
    end
    % Return marker file
    if isempty(mrkFiles)
        marker_file = [];
    else
        marker_file = bst_fullfile(ds_directory, mrkFiles(1).name);
    end
end

% ===== .POS =====
% Get Polhemus file
posDir = dir(bst_fullfile(ds_directory, '*.pos'));
% Remove the filenames that start with "."
iHidden = [];
for i = 1:length(posDir)
    if (posDir(i).name(1) == '.')
        iHidden(end+1) = i;
    end
end
if ~isempty(iHidden)
    posDir(iHidden) = [];
end

% Get dataset name and path
[dspath, dsname] = bst_fileparts(ds_directory);
% Candidate head shape files for this dataset (several are possible)
posCandidates = [];
if (length(posDir) == 1)
    posCandidates = {bst_fullfile(ds_directory, posDir(1).name)};
elseif (length(posDir) > 1)
    % Several Polhemus files in the same folder
    posCandidates = cellfun(@(c)bst_fullfile(ds_directory, c), {posDir.name}, 'UniformOutput', 0);
% Check for BIDS version: .pos is in the same folder as the .ds
else
    % Attempt #1: sub-subid_headshape.pos
    iUnder = find(dsname == '_', 1);
    if ~isempty(iUnder) && (iUnder > 1) && file_exist(bst_fullfile(dspath, [dsname(1:iUnder-1), '_headshape.pos']))
        posCandidates = {bst_fullfile(dspath, [dsname(1:iUnder-1), '_headshape.pos'])};
    end
    % Attempt #2: Any .pos with a name that starts with the .ds name (excluded "_meg")
    % Only for BIDS-style "*_meg.ds" folders: otherwise the pattern would be the directory
    % itself and dir() would return all its contents, not just .pos files.
    if isempty(posCandidates)
        posPattern = strrep(ds_directory, '_meg.ds', '_*.pos');
        if ~strcmp(posPattern, ds_directory)
            posDir = dir(posPattern);
            if ~isempty(posDir)
                posCandidates = cellfun(@(c)bst_fullfile(dspath, c), {posDir.name}, 'UniformOutput', 0);
            end
        end
    end
    % Attempt #3: Any .pos with a name that starts with the subject id
    % (e.g. BIDS: sub-subid_ses-sesid_headshape.pos and sub-subid_ses-sesid_electrodes.pos
    %  next to the .ds folder)
    if isempty(posCandidates)
        posDir = dir(bst_fullfile(dspath, [dsname(1:iUnder-1), '*.pos']));
        if ~isempty(posDir)
            posCandidates = cellfun(@(c)bst_fullfile(dspath, c), {posDir.name}, 'UniformOutput', 0);
        end
    end
end
% Select the head shape file: if several candidates are found, pick the best one
% (see select_pos_file for details); interactive sessions confirm with the user.
pos_file = [];
if (length(posCandidates) == 1)
    pos_file = posCandidates{1};
elseif (length(posCandidates) > 1)
    pos_file = select_pos_file('SelectPosFile', posCandidates, verbose, isInteractive);
end

% Report which file is used
if verbose
    if ~isempty(pos_file)
        disp(['CTF> Using head shape file: ' pos_file]);
    else
        disp(['CTF> Warning: No head shape imported for dataset: ' dsname]);
    end
end

% ===== .HC =====
% Get .hc file
hc_file = bst_fullfile(ds_directory, [DataSetName,'.hc']);
% Check that file is accessible
if ~file_exist(hc_file)
    if verbose
        disp(['CTF> Warning: ' hc_file ' missing.']);
    end
    hc_file = [];
end

% ===== BAD.SEGMENTS =====
% Get file bad.segments
badseg_file = bst_fullfile(ds_directory, 'bad.segments');
% Check that file is accessible
if ~file_exist(badseg_file)
    % Not always present, and that's ok.
    %     if verbose
    %         disp(['CTF> Warning: ' badseg_file ' missing.']);
    %     end
    badseg_file = [];
end


