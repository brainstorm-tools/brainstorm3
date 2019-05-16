function NewFiles = import_raw_to_db( DataFile )
% IMPORT_RAW_TO_DB: Import in the database some blocks of recordings from a continuous file already linked to the database.
%
% USAGE:  NewFiles = import_raw_to_db( DataFile )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2011-2019


% ===== GET FILE INFO =====
% Get study description
[sStudy, iStudy, iData] = bst_get('DataFile', DataFile);
if isempty(sStudy)
    error('File is not registered in the database.');
end
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
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
NewFiles = import_data(sFile, ChannelMat, sFile.format, [], iSubject, [], sStudy.DateOfStudy);


% ===== COPY VIDEO LINKS =====
% If only one file imported: Copy linked videos in destination folder
if (length(NewFiles) == 1) && ~isempty(sStudy.Image)
    % Get new and old time start
    NewMat = in_bst_data(NewFiles{1}, {'Time', 'History'});
    oldStart = NewMat.Time(1);
    offsetStart = 0;
    iEntry = find(strcmpi(NewMat.History(:,2), 'import_time'), 1, 'last');
    if ~isempty(iEntry)
        newTime = str2num(NewMat.History{iEntry,3});
        if ~isempty(newTime)
            offsetStart = oldStart - newTime(1);
        end
    end
    % Get destination file info
    [sStudyOut, iStudyOut, iData] = bst_get('DataFile', NewFiles{1});
    % Copy all the links
    for iFile = 1:length(sStudy.Image)
        if strcmpi(file_gettype(sStudy.Image(iFile).FileName), 'videolink')
            % Read link
            VideoLinkMat = load(file_fullpath(sStudy.Image(iFile).FileName));
            % Modify comment
            VideoLinkMat.Comment = [VideoLinkMat.Comment, ' | ', sStudyOut.Data(iData).Comment];
            % Set start time
            if ~isfield(VideoLinkMat, 'VideoStart') || isempty(VideoLinkMat.VideoStart)
                VideoLinkMat.VideoStart = 0;
            end
            VideoLinkMat.VideoStart = VideoLinkMat.VideoStart + offsetStart;
            % Create output filename
            [fPath, fBase] = bst_fileparts(sStudy.Image(iFile).FileName);
            OutputFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudyOut.FileName), ['videolink_', file_standardize(fBase), '.mat']);
            OutputFile = file_unique(OutputFile);
            % Save new file in Brainstorm format
            bst_save(OutputFile, VideoLinkMat, 'v7');

            % === UPDATE DATABASE ===
            % Create structure
            sImage = db_template('image');
            sImage.FileName = file_short(OutputFile);
            sImage.Comment  = VideoLinkMat.Comment;
            % Add to study
            iImage = length(sStudyOut.Image) + 1;
            sStudyOut.Image(iImage) = sImage;
        end
    end
    % Save study
    bst_set('Study', iStudyOut, sStudyOut);
    % Update tree
    panel_protocols('UpdateNode', 'Study', iStudyOut);
    % Save database
    db_save();
end


