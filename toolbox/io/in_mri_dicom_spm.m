function NiiFiles = in_mri_dicom_spm(DicomFiles, OutputFolder, isInteractive)
% IN_MRI_DICOM_SPM: Convert DICOM volumes to .nii using the SPM converter.
%
% USAGE:  NiiFiles = in_mri_dicom_spm(DicomFiles, OutputFolder=[tmp], isInteractive=1)
%
% INPUT: 
%     - DicomFiles    : Cell array of full paths to DICOM files
%     - OutputFolder  : Folder where to save the output .nii files
%     - isInteractive : If 1, asks which volume to import
%                       If 0, converts all the volumes
% OUTPUT:
%     - NiiFiles      : Full path to .nii files

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
% Authors: Francois Tadel, 2017-2023

% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2) || isempty(OutputFolder)
    OutputFolder = pwd;
end

% Initialize SPM
[isInstalled, errMsg] = bst_plugin('Install', 'spm12');
if ~isInstalled
    error(errMsg);
end

% Progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'DICOM converter (SPM)', 'Loading DICOM headers...', 0, length(DicomFiles));
bst_plugin('SetProgressLogo', 'spm12');

% Read SPM DICOM dictionnary
disp(['BST> DICOM dictionnary: ' fullfile(spm('Dir'),'spm_dicom_dict.txt')])
dictFile = fullfile(fileparts(which('spm_dicom_convert')), 'spm_dicom_dict.txt');
dict = spm_dicom_text_to_dict(dictFile);

% Read DICOM headers
hdr = {};
for i = 1:length(DicomFiles)
    tmp = spm_dicom_header(DicomFiles{i}, dict);
    if ~isempty(tmp)
        hdr{end+1} = tmp;
    end
    bst_progress('inc', 1);
end
if isempty(hdr)
    error('No valid DICOM headers found in the selected files.');
end

% Convert DICOM to .nii
bst_progress('text', 'Converting DICOM images...');
out = spm_dicom_convert(hdr, 'all', 'patid_date', 'nii', OutputFolder);
% Return output files
NiiFiles = out.files;
if isempty(NiiFiles)
    error('No DICOM volume returned by the SPM converter.');
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

% If there is more than one file and in interactive mode: Offer to select various volumes
if (length(NiiFiles) > 1) && isInteractive
    % Get volume representation based on the folder structures
    strFiles = cell(1, length(NiiFiles));
    for i = 1:length(NiiFiles)
        fInfo = dir(NiiFiles{i});
        fPath = fileparts(NiiFiles{i});
        [tmp, strProtocol] = fileparts(fPath);
        [tmp, strDate] = fileparts(tmp);
        [tmp, strId] = fileparts(tmp);
        % Comment representing the volume
        strFiles{i} = [strId ' | ' strDate ' | ' strProtocol ' | ' num2str(fInfo.bytes/1024/1024,'%1.1f') 'Mb'];
        % Rename file to Date-Protocol.nii
        newFile = file_unique(fullfile(fPath, [strDate, '_', strProtocol, '.nii']));
        file_move(NiiFiles{i}, newFile);
        NiiFiles{i} = newFile;
    end
    % Ask user which volumes to import
    res = java_dialog('checkbox', 'Available volumes:  ID | Date | Protocol | Size', 'DICOM converter (SPM)', [], strFiles, zeros(1,length(NiiFiles)));
    if isempty(res)
        NiiFiles = [];
        return;
    end
    % Keep only the selected files
    NiiFiles = NiiFiles(logical(res));
end





