function bst_deploy_java_2016b(IS_BIN)
% BST_DEPLOY_JAVA - Brainstorm deployment script.
%
% USAGE:  bst_deploy_java_2016b(IS_BIN=0)
%
% INPUTS:
%    - IS_BIN : 0=Package the sources and push the modifications to github
%               1=Compile Brainstorm using the MCC compiler
%               2=Compile including SPM and FieldTrip functions
%
% STEPS:
%    - Update doc/version.txt
%    - Update doc/license.html (update block: "Version: ...")
%    - Update *.m inital comments (replace block "@=== ... ===@" with deploy/autocomment.txt)
%    - Remove *.asv files
%    - Zip brainstorm3 directory (output file: <bstMakeDir>/brainstorm_yymmdd.zip)
%    - Restore defaults/* directories
%    (optional)
%    - Build stand-alone application
%    - Zip stand-alone directory  (output file: <bstMakeDir>/bst_bin_os_yymmdd.zip)
%    - Zip <bstDefDir> directory (output file: <bstMakeDir>/bst_defaults_yymmdd.zip)

% @=============================================================================
% This software is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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


%% ===== PARSE INPUTS =====
if (nargin < 1) || isempty(IS_BIN)
    IS_BIN = 0;
    IS_FT_SPM = 0;
elseif ischar(IS_BIN)
    switch(IS_BIN)
        case '0'
            IS_BIN = 0;
            IS_FT_SPM = 0;
        case '1'
            IS_BIN = 1;
            IS_FT_SPM = 0;
        case '2'
            IS_BIN = 1;
            IS_FT_SPM = 1;
        otherwise,  error('Invalid value for IS_BIN.');
    end
end
% Check if compiler is available
if IS_BIN && ~exist('deploytool', 'file')
    disp('DEPLOY> No compiler available: cannot produce standalone application.');
    IS_BIN = 0;
    IS_FT_SPM = 0;
end
% Get Matlab version
ReleaseName = bst_get('MatlabReleaseName');


%% ===== CONFIGURATION =====
% Get date string
c = clock;
strDate = sprintf('%02d%02d%02d', c(1)-2000, c(2), c(3));
bstVersion = ['3.' strDate];
% Root brainstorm directory
bstDir        = bst_get('BrainstormHomeDir');
bstToolboxDir = fullfile(bstDir, 'toolbox');
% Deploy folder
deployDir = fullfile(fileparts(bstDir), 'brainstorm3_deploy');
% Get file names
versionFile     = fullfile(bstDir, 'doc', 'version.txt');
licenseFile     = fullfile(bstDir, 'doc', 'license.html');
autoCommentFile = fullfile(bstDir, 'deploy', 'autocomment.txt');
% Start timer
tic;

% Compiler configuration   
if IS_BIN
    % Clear command window
    clc
        
    % FieldTrip / SPM
    if IS_FT_SPM
        compilerFile = fullfile(bstDir, 'deploy', 'bst_javabuilder_2016b_spm.prj');
    else
        compilerFile = fullfile(bstDir, 'deploy', 'bst_javabuilder_2016b.prj');
    end
    
    % JDK folder
    jdkDir = 'C:\Program Files\Java\jdk1.7.0_80';
    % Set JAVA_HOME environment variable
    setenv('JAVA_HOME', jdkDir);
    % Javabuilder output
    compilerDir = fullfile(deployDir, ReleaseName, 'bst_javabuilder');
    compilerOutputDir = fullfile(compilerDir, 'for_testing');
    % Packaging folders
    packageDir = fullfile(deployDir, ReleaseName, 'package');
    % Create the folders for the packaging
    binDir = fullfile(bstDir, 'bin', ReleaseName);
    jarDir = fullfile(packageDir, 'jar');
    % Delete existing folders
    if exist(compilerDir, 'dir')
        try
            rmdir(compilerDir, 's');
        catch
            disp(['DEPLOY> Error: Could not delete folder: ' compilerDir ]);
        end
    end
    if exist(packageDir, 'dir')
        try
            rmdir(packageDir, 's');
        catch
            disp(['DEPLOY> Error: Could not delete folder: ' packageDir ]);
        end
    end
end


%% ===== MAKE DIRECTORIES =====
if IS_BIN
    dirToCreate = {deployDir, fullfile(deployDir, ReleaseName), jarDir, binDir};
else
    dirToCreate = {deployDir};
end
% For each directory
for i=1:length(dirToCreate)
    % Create directory if it does not exist yet
    if ~exist(dirToCreate{i}, 'file')
        isCreated = mkdir(dirToCreate{i});
        if ~isCreated
            error(['Cannot create output directory:' dirToCreate{i}]);
        end
    end
end


%% ===== GET ALL DIRECTORIES =====
% Get all the Brainstorm subdirectories
bstPath = GetPath(bstDir);
% Split string
jPath = java.lang.String(bstPath);
jSplitPath = jPath.split(';');


%% ===== UPDATE VERSION.TXT =====
disp([10 'DEPLOY> Updating: ', strrep(versionFile, bstDir, '')]);
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
disp(['DEPLOY> Reading: ', strrep(autoCommentFile, bstDir, '')]);
% Read file
autoComment = ReadAsciiFile(autoCommentFile);
if isempty(autoComment)
    error('Auto-comment file not found.');
end
% Convert to Unix-like string
% autoComment = strrep(autoComment, char([13 10]), char(10));
% Initialize line counts
nFiles   = 0;
nCode    = 0;
nComment = 0;
% Updating the M-files
if IS_BIN
    disp('DEPLOY> Updating: Comments in all *.m files...');
end
disp('DEPLOY> Statistics:');
for iPath = 1:length(jSplitPath)
    curPath = char(jSplitPath(iPath));
    % Remove ASV files
    delete(fullfile(curPath, '*.asv'));
    
    % === PROCESS M-FILES (EDIT COMMENT, COUNT LINES) ===
    % List all .m files in current directory
    mFiles = dir(fullfile(curPath, '*.m'));
    % Process each m-file
    for iFile = 1:length(mFiles)
        % Build full file name
        fName = fullfile(curPath, mFiles(iFile).name);
        % Binary + toolbox directory: Update comment
        if IS_BIN && ~isempty(strfind(curPath, bstToolboxDir)) || strcmpi(curPath, bstDir)
            % Replace comment block in file
            ReplaceBlock(fName, '% @===', '===@', autoComment);
        end
        % Count files and lines
        [tmpComment, tmpCode] = CountLines(fName, autoComment);
        nFiles   = nFiles + 1;
        nCode    = nCode + tmpComment;
        nComment = nComment + tmpCode;
    end
end
disp(['DEPLOY>     Number of files  : ' num2str(nFiles)]);
disp(['DEPLOY>     Lines of code    : ' num2str(nCode)]);
disp(['DEPLOY>     Lines of comment : ' num2str(nComment)]);


%% ===== COPY TO GIT FOLDER =====
% Copy all the subfolders
disp('DEPLOY> Copying to GIT folder...');
!xcopy C:\Work\Dev\brainstorm3\brainstorm.m C:\Work\Dev\brainstorm_git\brainstorm3\brainstorm.m /y /q
!xcopy C:\Work\Dev\brainstorm3\defaults C:\Work\Dev\brainstorm_git\brainstorm3\defaults /s /e /y /q
!xcopy C:\Work\Dev\brainstorm3\deploy   C:\Work\Dev\brainstorm_git\brainstorm3\deploy   /s /e /y /q
!xcopy C:\Work\Dev\brainstorm3\doc      C:\Work\Dev\brainstorm_git\brainstorm3\doc      /s /e /y /q
!xcopy C:\Work\Dev\brainstorm3\external C:\Work\Dev\brainstorm_git\brainstorm3\external /s /e /y /q
!xcopy C:\Work\Dev\brainstorm3\java     C:\Work\Dev\brainstorm_git\brainstorm3\java     /s /e /y /q
!xcopy C:\Work\Dev\brainstorm3\toolbox  C:\Work\Dev\brainstorm_git\brainstorm3\toolbox  /s /e /y /q
% Start GIT GUI in the deployment folder
system('start /b cmd /c ""C:\Program Files\Git\cmd\git-gui.exe" --working-dir "C:\Work\Dev\brainstorm_git\brainstorm3""');


%% ===== MATLAB COMPILER =====
if IS_BIN
    % === COMPILING ===
    disp('DEPLOY> Starting Matlab Compiler...');
    % Starting compiler
%     deploytool('-build', compilerFile);
    system(['deploytool -build ', compilerFile]);
%     % This stupid call is asynchronous: have to wait manually until it's done
%     % Get the text in the command window, until there is that "Build finished" text in it
%     while(1)
%         pause(2);
%         cmdWinDoc = com.mathworks.mde.cmdwin.CmdWinDocument.getInstance;
%         jString   = cmdWinDoc.getText(cmdWinDoc.getStartPosition.getOffset, cmdWinDoc.getLength);
%         if ~isempty(strfind(char(jString), 'Build finished'))
%             break;
%         elseif ~isempty(strfind(char(jString), 'Build failed'))
%             return;
%         end
%         fprintf(1, '.');
%     end

    % === PACKAGING ===
    disp('DEPLOY> Packaging binary distribution...');
    % Compiled jar
    compiledJar = fullfile(compilerOutputDir, 'bst_javabuilder_2016b.jar');
    % Find the JAR created by the compiler
    if ~file_exist(compiledJar)
        error('Compilation is incomplete: cannot package the binary distribution.');
    end
    % JavaBuilder .jar file
    javabuilderJar = fullfile(matlabroot, 'toolbox', 'javabuilder', 'jar', 'javabuilder.jar');
    % Unjar everything in package dir
    unzip(javabuilderJar, jarDir);
    unzip(compiledJar, jarDir);

    % Write manifest
    manifestFile = fullfile(jarDir, 'manifest.txt');
    fid = fopen(manifestFile, 'w');
    fwrite(fid, ['Manifest-Version: 1.0' 13 10 ...
                 'Main-Class: org.brainstorm.RunCompiled' 13 10 ...
                 'Created-By: Brainstorm (' date ')' 13 10]);
    fclose(fid);
    
    % Brainstorm application .jar file
    appJar = fullfile(bstDir, 'java', 'brainstorm.jar');
    % Unjar in "javabuilder" folder, just to get the SelectMcr class
    unzip(appJar, compilerDir);
    classFile = fullfile('org', 'brainstorm', 'file', 'SelectMcr2016b.class');
    destFolder = fullfile(jarDir, fileparts(classFile));
    mkdir(destFolder);
    copyfile(fullfile(compilerDir, classFile), destFolder);
    % Copy application runner
    classFile = fullfile(deployDir, ReleaseName, 'brainstorm_run', 'org', 'brainstorm', 'RunCompiled.class');
    destFolder = fullfile(jarDir, 'org', 'brainstorm');
    copyfile(classFile, destFolder);
    % Re-jar files together
    bstJar = fullfile(binDir, 'brainstorm3.jar');
    if file_exist(bstJar)
        delete(bstJar);
    end
    system(['cd "' jarDir '" & "' jdkDir '\bin\jar.exe" cmf manifest.txt "' bstJar '" bst_javabuilder_2016b org com']);
end


%% ===== CREATE ZIP ===== 
% Output files 
zipFileBst = fullfile(deployDir, ['brainstorm_' strDate '.zip']);
disp(['DEPLOY> Creating final zip file: ' zipFileBst]);
% Get all the subfolders except for "bin"
pkgDirs = {fullfile('brainstorm3', 'defaults'), ...
           fullfile('brainstorm3', 'deploy'), ...
           fullfile('brainstorm3', 'doc'), ...
           fullfile('brainstorm3', 'external'), ...
           fullfile('brainstorm3', 'java'), ...
           fullfile('brainstorm3', 'toolbox'), ...
           fullfile('brainstorm3', 'brainstorm.m')};
% Create zip file
curDir = pwd;
cd(fileparts(bstDir));
zip(zipFileBst, pkgDirs);
cd(curDir);
% Done
stopTime = toc;
if (stopTime > 60)
    disp(sprintf('DEPLOY> Done in %dmin\n', round(stopTime/60)));
else
    disp(sprintf('DEPLOY> Done in %ds\n', round(stopTime)));
end


%% ===== PACKAGE BINARY =====
if IS_BIN
    bst_package_bin(ReleaseName);
end


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
    fContents = char(fread(fid, Inf, 'char')');
    % Close file
    fclose(fid);
end

%% ===== WRITE ASCII FILE =====
function writeAsciiFile(filename, fContents)
    % Open ascii file
    fid = fopen(filename, 'w');
    if (fid < 0)
        return;
    end
    % Write file
    fwrite(fid, fContents, 'char');
    % Close file
    fclose(fid);
end

%% ===== GET PATH =====
function p = GetPath(d)
    % Generate path based on given root directory
    files = dir(d);
    if isempty(files)
        return
    end
    % Base path: input dir
    p = [d pathsep];
    % Set logical vector for subdirectory entries in d
    isdir = logical(cat(1,files.isdir));
    % Recursively descend through directories
    dirs = files(isdir); % select only directory entries from the current listing
    for i=1:length(dirs)
       dirname = dirs(i).name;
       % Ignore directories starting with '.' and 'defaults' folder
       if (dirname(1) ~= '.') && ~strcmpi(dirname, 'defaults')
           p = [p GetPath(fullfile(d, dirname))]; % recursive calling of this function.
       end
    end
end

%% ===== REPLACE BLOCK IN FILE =====
function ReplaceBlock(fName, strStart, strStop, strNew)
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

    % Replace file block with new one
    fContents = [fContents(1:iStart - 1), ...
        strNew, ...
        fContents(iStop:end)];
    % Re-write file
    writeAsciiFile(fName, fContents);
end


%% ===== COUNT LINES =====
function [nComment, nCode] = CountLines(fName, strExclude)
    nComment = 0;
    nCode = 0;
    % Read file
    fContents = ReadAsciiFile(fName);
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
