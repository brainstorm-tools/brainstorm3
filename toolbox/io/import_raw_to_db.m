function NewFiles = import_raw_to_db( DataFile )
% IMPORT_RAW_TO_DB: Import in the database some blocks of recordings from a continuous file already linked to the database.
%
% USAGE:  NewFiles = import_raw_to_db( DataFile )

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
% Authors: Francois Tadel, 2011-2022


% ===== GET FILE INFO =====
% Get study description
[sStudy, iStudy, iData] = bst_get('DataFile', DataFile);
if isempty(sStudy)
    error('File is not registered in the database.');
end
% Is it a "link to raw file" or not
isRaw = strcmpi(sStudy.Data(iData).DataType, 'raw');
% Get subject index
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
% Progress bar
bst_progress('start', 'Import raw file', 'Processing file header...');
% Read file descriptor
DataMat = in_bst_data(DataFile);
% Read channel file
ChannelFile = bst_get('ChannelFileForStudy', DataFile);
ChannelMat = in_bst_channel(ChannelFile);
% Get sFile structure
if isRaw
    sFile = DataMat.F;
else
    sFile = in_fopen(DataFile, 'BST-DATA');
end
% Import file
[NewFiles, iStudyImport] = import_data(sFile, ChannelMat, sFile.format, [], iSubject, [], sStudy.DateOfStudy);

% If only one file imported: Copy linked videos in destination folder
if (length(NewFiles) == 1) && ~isempty(sStudy.Image)
    process_import_data_event('CopyVideoLinks', NewFiles{1}, sStudy);
end

% Copy noise covariance, if any
if ~isempty(iStudyImport) && ~isempty(sStudy.NoiseCov) && ~isempty(sStudy.NoiseCov(1).FileName)
    iStudyCopy = unique(iStudyImport);
    for i = 1:length(iStudyCopy)
        sStudyCopy = bst_get('Study', iStudyCopy(i));
        if isempty(sStudyCopy.NoiseCov) || isempty(sStudyCopy.NoiseCov(1).FileName)
            db_set_noisecov(iStudy, iStudyCopy(i), 0, 0);
        end
    end
end

% Save database
db_save();


