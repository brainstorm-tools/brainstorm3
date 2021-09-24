function iNewFiles = import_video(iStudy, VideoFiles)
% IMPORT_VIDEO Link video files to the database.
% 
% USAGE:  iNewFiles = import_dipoles(iStudy, VideoFiles=[ask])
%
% INPUT:
%    - iStudy       : Index of the study where to import the DipolesFiles
%    - DipolesFiles : Full filename, or cell array of filenames, of video files to import

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
% Authors: Francois Tadel, 2015-2019

%% ===== PARSE INPUTS =====
if (nargin < 2)
    VideoFiles = [];
elseif ~iscell(VideoFiles)
    VideoFiles = {VideoFiles};
end
% Returned variables
iNewFiles = [];


%% ===== SELECT FILES =====
% If file to load was not defined : open a dialog box to select it
if isempty(VideoFiles)
    % Get default import directory and formats
    LastUsedDirs   = bst_get('LastUsedDirs');
    % Get Dipoles file
    [VideoFiles, FileFormat] = java_getfile('open', ...
            'Import dipoles...', ...   % Window title
            LastUsedDirs.ImportData, ...    % Last used directory
            'multiple', 'files', ...        % Selection mode
            {{'.avi','.mpg','.mpeg','.mp4','.mp2','.mkv','.wmv','.divx','.mov'}, 'Video files (*.avi;*.mpg;*.mpeg;*.mp4;*.mp2;*.mkv;*.wmv;*.divx;*.mov)', 'VIDEO'}, []);
    % If no file was selected: exit
    if isempty(VideoFiles)
        return
    % Make sure it's an array of files
    elseif ~iscell(VideoFiles)
        VideoFiles = {VideoFiles};
    end
    % Save default import directory
    LastUsedDirs.ImportData = bst_fileparts(VideoFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
end


%% ===== GET RECORDINGS SYNCHRO =====
RecStart = 0;
% Get study structure
sStudy = bst_get('Study', iStudy);
% Look for the first RAW file in the folder
if ~isempty(sStudy.Data)
    iDataRaw = find(strcmpi({sStudy.Data.DataType}, 'raw'),1);
else
    iDataRaw = [];
end
% Read the syncro information from the RAW link
if ~isempty(iDataRaw)
    % Read raw link
    DataMat = in_bst_data(sStudy.Data(iDataRaw).FileName, 'F');
    sFile = DataMat.F;
    % Get the start time of the recordings
    if isfield(sFile, 'header') && isfield(sFile.header, 'FirstTimeStamp') && ~isempty(sFile.header.FirstTimeStamp)
        RecStart = double(sFile.header.FirstTimeStamp) * 1e-6;
    end
end


%% ===== CREATE LINKS =====
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Get output study
sStudy = bst_get('Study', iStudy);
% Loop on each file
for iFile = 1:length(VideoFiles)
    % === SYNCHRO WITH SUBTITLES ===
    VideoStart = [];
    % Get file name
    [fPath, fBase, fExt] = bst_fileparts(VideoFiles{iFile});
    % Try to find an .smi file corresponding to the video and use it for the synchronization
    SmiFile = bst_fullfile(fPath, [fBase, '.smi']);
    if file_exist(SmiFile)
        % Open the file 
        fid = fopen(SmiFile, 'r');
        if (fid < 0)
            disp(['BST> Error: Cannot open file "' SmiFile '"']);
            continue;
        end
        % Read the file line by line to get the first syncro tag
        while ~feof(fid)
            % Read one line
            newLine = fgetl(fid);
            if ~ischar(newLine)
                break;
            end
            % Look for line: "<SYNC Start=0><P Class=ENUSCC>XXXXX</SYNC>"
            if (length(newLine) > 21) && strcmpi(newLine(1:14), '<SYNC Start=0>')
                VideoStart = str2num(str_striptag(newLine)) .* 1e-6;
                break;
            end
        end
        % Close the file
        fclose(fid);
    end
    
    % === CREATE STRUCTURE ===
    % Create new empty videolink structure
    VideoLinkMat = struct();
    VideoLinkMat.LinkTo     = VideoFiles{iFile};
    VideoLinkMat.Comment    = fBase;
    VideoLinkMat.VideoStart = VideoStart - RecStart;
    % Add History field
    VideoLinkMat = bst_history('add', VideoLinkMat, 'import', ['Import from: ' VideoFiles{iFile}]);
    
    % === SAVE NEW FILE ===
    % Create output filename
    OutputFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName), ['videolink_', file_standardize(fBase), '.mat']);
    OutputFile = file_unique(OutputFile);
    % Save new file in Brainstorm format
    bst_save(OutputFile, VideoLinkMat, 'v7');
   
    % === UPDATE DATABASE ===
    % Create structure
    sImage = db_template('image');
    sImage.FileName = file_short(OutputFile);
    sImage.Comment  = VideoLinkMat.Comment;
    % Add to study
    iImage = length(sStudy.Image) + 1;
    sStudy.Image(iImage) = sImage;
    iNewFiles = [iNewFiles, iImage];
end

% Save study
bst_set('Study', iStudy, sStudy);
% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();



