function bst_deploy(GitDir, GitExe)
% BST_DEPLOY - Brainstorm deployment script
%
% INPUTS:
%    - GitDir : Path to the local Brainstorm git folder (Windows only) - Set to [] to ignore GIT copy
%    - GitExe : Path to the git-gui executable (Windows only) - Set to [] to ignore execution of git-gui
%
% STEPS:
%    - Update doc/version.txt
%    - Update doc/license.html (update block: "Version: ...")
%    - Update *.m inital comments (replace block "@=== ... ===@" with deploy/autocomment.txt)
%    - Remove *.asv files
%    - Optional: Copy files to GIT folder and open GitGUI

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
% Authors: Francois Tadel, 2011-2021


%% ===== CONFIGURATION =====
% Default GIT directory (windows only)
if ~ispc
    GitDir = [];
    GitExe = [];
else
    if (nargin < 1)
        GitDir = 'C:\Work\Dev\brainstorm_git\brainstorm3';
    end
    if (nargin < 2)
        GitExe = 'C:\Program Files\Git\cmd\git-gui.exe';
    end
end


%% ===== GET FILES =====
% Start brainstorm without the GUI
isNogui = ~brainstorm('status');
if isNogui
    brainstorm nogui
end
% Get files
bstDir = bst_get('BrainstormHomeDir');
versionFile = fullfile(bstDir, 'doc', 'version.txt');
licenseFile = fullfile(bstDir, 'doc', 'license.html');
commentFile = fullfile(bstDir, 'deploy', 'autocomment.txt');


%% ===== UPDATE VERSION.TXT =====
disp(['DEPLOY> Updating: ', strrep(versionFile, bstDir, '')]);
% Get date string
c = clock;
strDate = sprintf('%02d%02d%02d', c(1)-2000, c(2), c(3));
bstVersion = ['3.' strDate];
% Version.txt contents
strVersion = ['% Brainstorm' 10 ...
              '% v. ' bstVersion ' (' date ')'];
% Write version.txt
writeAsciiFile(versionFile, strVersion);


%% ===== UPDATE LICENSE.HTML =====
disp(['DEPLOY> Updating: ', strrep(licenseFile, bstDir, '')]);
% Read previous file
strLicense = ReadAsciiFile(licenseFile);
% Find block to replace
blockToFind = 'Version: ';
iStart = strfind(strLicense, blockToFind);
% If block was found
if ~isempty(iStart)
    % Start replacing after the block
    iStart = iStart(1) + length(blockToFind) - 1;
    % Stops replacing at the first HTML tag after the block
    iStop = iStart;
    while (strLicense(iStop) ~= '<')
        iStop = iStop + 1;
    end
    % Replace block
    strLicense = [strLicense(1:iStart), ...
                  bstVersion ' (' date ')', ...
                  strLicense(iStop:end)];
    % Save file
    writeAsciiFile(licenseFile, strLicense);
end


%% ===== PROCESS DIRECTORIES =====
disp(['DEPLOY> Reading: ', strrep(commentFile, bstDir, '')]);
% Read file
autoComment = ReadAsciiFile(commentFile);
if isempty(autoComment)
    error('Auto-comment file not found.');
end
% Get all the Brainstorm subdirectories
splitPath = cat(2, ...
    {bstDir}, ...
    str_split(genpath(fullfile(bstDir, 'toolbox')), ';'), ...
    str_split(genpath(fullfile(bstDir, 'deploy')), ';'));
% Initialize line counts
nFiles   = 0;
nCode    = 0;
nComment = 0;
% Updating the M-files + count lines
disp('DEPLOY> Updating: Comments in all *.m files...');
for p = splitPath
    % Remove ASV files
    delete(fullfile(p{1}, '*.asv'));
    % List all .m files in current directory
    mFiles = dir(fullfile(p{1}, '*.m'));
    % Process each m-file
    for iFile = 1:length(mFiles)
        % Build full file name
        fName = fullfile(p{1}, mFiles(iFile).name);
        % Binary + toolbox directory: Update comment
        strFile = ReplaceBlock(fName, '% @===', '===@', autoComment);
        % Count files and lines
        [tmpComment, tmpCode] = CountLines(strFile, autoComment);
        nFiles   = nFiles + 1;
        nCode    = nCode + tmpComment;
        nComment = nComment + tmpCode;
    end
end
disp('DEPLOY> Statistics:');
disp(['DEPLOY>  - Number of files  : ' num2str(nFiles)]);
disp(['DEPLOY>  - Lines of code    : ' num2str(nCode)]);
disp(['DEPLOY>  - Lines of comment : ' num2str(nComment)]);


%% ===== COPY TO GIT FOLDER =====
% Copy all the subfolders
if ~isempty(GitDir)
    disp('DEPLOY> Copying to GIT folder...');
    system(['xcopy ' fullfile(bstDir, 'brainstorm.m') ' ' fullfile(GitDir, 'brainstorm.m') '/y /q']);
    system(['xcopy ' fullfile(bstDir, 'defaults')     ' ' fullfile(GitDir, 'defaults')     '/s /e /y /q']);
    system(['xcopy ' fullfile(bstDir, 'deploy')       ' ' fullfile(GitDir, 'deploy')       '/s /e /y /q']);
    system(['xcopy ' fullfile(bstDir, 'doc')          ' ' fullfile(GitDir, 'doc')          '/s /e /y /q']);
    system(['xcopy ' fullfile(bstDir, 'external')     ' ' fullfile(GitDir, 'external')     '/s /e /y /q']);
    system(['xcopy ' fullfile(bstDir, 'java')         ' ' fullfile(GitDir, 'java')         '/s /e /y /q']);
    system(['xcopy ' fullfile(bstDir, 'toolbox')      ' ' fullfile(GitDir, 'toolbox')      '/s /e /y /q']);
    % Start GIT GUI in the deployment folder
    system(['start /b cmd /c ""' GitExe '" --working-dir "' GitDir '""']);
end

% Close Brainstorm (if it was started in this script)
if isNogui
    brainstorm stop;
end
disp('DEPLOY> Done.');

end




%% =================================================================================================
%  ===== HELPER FUNCTIONS ==========================================================================
%  =================================================================================================

%% ===== READ ASCII FILE =====
function fContents = ReadAsciiFile(filename)
    fContents = '';
    % Open ascii file
    fid = fopen(filename, 'r');
    if (fid < 0)
        return;
    end
    % Read file
    fContents = char(fread(fid, Inf, 'uint8')');
    % Close file
    fclose(fid);
end

%% ===== WRITE ASCII FILE =====
function writeAsciiFile(filename, fContents)
    % Open ascii file
    fid = fopen(filename, 'wb');
    if (fid < 0)
        return;
    end
    % Write file
    fwrite(fid, uint8(fContents), 'uint8');
    % Close file
    fclose(fid);
end


%% ===== REPLACE BLOCK IN FILE =====
function fContents = ReplaceBlock(fName, strStart, strStop, strNew)
    % Read file
    fContents = ReadAsciiFile(fName);
    % Detect block markers (strStart, strStop)
    % => Start
    iStart = strfind(fContents, strStart);
    if isempty(iStart)
        disp(['*** Block not found in file: "', fName, '"']);
        return;
    end
    iStart = iStart(1);
    % => Stop
    iStop = strfind(fContents(iStart:end), strStop) + length(strStop) + iStart - 1;
    if isempty(iStop)
        disp(['*** Block not found in file: "', strrep(fName,'\','\\'), '"']);
        return;
    end
    iStop = iStop(1);
    % If no change: exit
    if strcmp(strNew, fContents(iStart:iStop-1))
        return;
    end
    % Replace file block with new one
    fContents = [fContents(1:iStart - 1), strNew, fContents(iStop:end)];
    % Re-write file
    writeAsciiFile(fName, fContents);
end


%% ===== COUNT LINES =====
function [nComment, nCode] = CountLines(fContents, strExclude)
    nComment = 0;
    nCode = 0;
    % Remove the CR characters
    fContents(fContents == 13) = [];
    % Remove header comment block
    fContents = strrep(fContents, strExclude, '');    
    % Split in lines
    fSplit = str_split(fContents, 10);
    % Loop on lines
    for i = 1:1:length(fSplit)
        fLine = strtrim(fSplit{i});
        if (length(fLine) < 3)
            % Skip
        elseif (fLine(1) == '%')
            nComment = nComment + 1;
        else
            nCode = nCode + 1;
        end
    end
end
