function [DataSetName, meg4_files, res4_file, marker_file, pos_file, hc_file] = ctf_get_files( ds_directory )
% CTF_GET_FILES: Get the name and files of a CTF .DS directory.
%
% INPUT: 
%     - ds_directory : Full path to a .ds CTF directory
% OUTPUT:
%     - DataSetName  : Name of the input CTF dataset
%     - meg4_files   : Cell array of full paths to the recordings files (.meg4, .1_meg4, .2_meg4, ...)
%     - res4_file    : Full path to the header file (.res4)
%     - marker_file  : Full path to the marker file in this folder (.mrk)
%     - pos_file     : Full path to the polhemus digitized head points
%     - hc_file      : Full path to the original measured head coordinates

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2011

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
[tmp___, DataSetName] = bst_fileparts(meg4list.name);

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
if ~exist(marker_file,'file'); 
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
% Return polhemus file
if isempty(posDir)
    pos_file = [];
elseif (length(posDir) > 1)
    error('Two Polhemus files in the same folder.');
else
    pos_file = bst_fullfile(ds_directory, posDir(1).name);
end


% ===== .HC =====
% Get .hc files
hc_file = bst_fullfile(ds_directory, [DataSetName,'.hc']);
% Check that both files are accessible
if ~file_exist(hc_file)
   disp(['CTF> Warning: ' hc_file ' missing.']);
   hc_file = [];
end


