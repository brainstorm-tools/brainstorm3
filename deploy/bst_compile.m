 function bst_compile(isPlugs)
% BST_COMPILE - Brainstorm compilation script (MATLAB >= 2020a)
%
% USAGE:  bst_compile(isPlugins=1)
%
% INPUTS:
%    - isPlugs : If 1, include all the registered plugins
%
% REQUIREMENTS:
%    - Installation of OpenJDK 8 (Matlab doesn't support anything later than this)
%      https://adoptopenjdk.net/?variant=openjdk8

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

      
%% ===== PARSE INPUTS =====
if (nargin < 1) || isempty(isPlugs)
    isPlugs = 1;
end


%% ===== START BRAINSTORM =====
% Get JDK installation dir
JdkDir = getenv('JAVA_HOME');
if isempty(JdkDir) || ~exist(fullfile(JdkDir, 'bin'), 'file')
    error(['You must install OpenJDK 8 and set the environment variable JAVA_HOME to point at it.' 10 ...
        'Download: https://adoptopenjdk.net/?variant=openjdk8' 10 ...
        'Set environment from Matlab: setenv(''JAVA_HOME'', ''C:\Program Files\Eclipse Foundation\jdk-8.0.302.8-hotspot'')']);
end
disp([10 'COMPILE> JAVA_HOME=' JdkDir]);
% Check if compiler is available
if ~exist('mcc', 'file')
    error('You must install the toolboxes "Matlab Compiler" and "Matlab Compiler SDK" to run this function.');
end
% Start brainstorm without the GUI
isNogui = ~brainstorm('status');
if isNogui
    brainstorm nogui
end
% Remove .brainstorm from the path
rmpath(bst_get('UserMexDir'));
rmpath(bst_get('UserProcessDir'));


%% ===== DIRECTORIES =====
% Root brainstorm directory
bstDir = bst_get('BrainstormHomeDir');
% Deploy folder: .brainstorm/tmp/deploy
deployDir = fullfile(bst_get('BrainstormTmpDir'), 'deploy');
% Get Matlab version
ReleaseName = bst_get('MatlabReleaseName');
% Javabuilder output
compilerDir = fullfile(deployDir, ReleaseName, 'bst_javabuilder');
outputDir = fullfile(compilerDir, 'for_testing');
% Packaging folders
packageDir = fullfile(deployDir, ReleaseName, 'package');
binDir = fullfile(bstDir, 'bin', ReleaseName);
jarDir = fullfile(packageDir, 'jar');
% Delete existing folders
if exist(compilerDir, 'dir')
    try
        rmdir(compilerDir, 's');
    catch
        disp(['COMPILE> Error: Could not delete folder: ' compilerDir]);
    end
end
if exist(packageDir, 'dir')
    try
        rmdir(packageDir, 's');
    catch
        disp(['COMPILE> Error: Could not delete folder: ' packageDir]);
    end
end
% Create new folders
dirToCreate = {deployDir, fullfile(deployDir, ReleaseName), jarDir, binDir, outputDir};
for i = 1:length(dirToCreate)    
    if ~exist(dirToCreate{i}, 'file')
        isCreated = mkdir(dirToCreate{i});
        if ~isCreated
            error(['Cannot create output directory:' dirToCreate{i}]);
        end
    end
end


%% ===== COPY CLASS: SELECTMCR =====
% Located in the Brainstorm application .jar file
appJar = fullfile(bstDir, 'java', 'brainstorm.jar');
% Unjar in "javabuilder" folder, just to get the SelectMcr class
unzip(appJar, compilerDir);
classFile = fullfile('org', 'brainstorm', 'file', ['SelectMcr' ReleaseName(2:end) '.class']);
classFileFull = fullfile(compilerDir, classFile);
if ~file_exist(classFileFull)
    error(['Missing class in bst-java: SelectMcr' ReleaseName(2:end) '.class']);
end
% Copy SelectMcrXXXXX.class to output package folder
destFolder = fullfile(jarDir, fileparts(classFile));
mkdir(destFolder);
copyfile(classFileFull, destFolder);


%% ===== COPY CLASS: RUN COMPILED =====
% Located in the deploy folder, must be compiled from the corresponding bst-java package after compiling Brainstorm a first time
classFile = fullfile(bstDir, 'deploy', ['RunCompiled_' ReleaseName(2:end) '.class']);
% Copy application runner
if file_exist(classFile)
    destFile = fullfile(jarDir, 'org', 'brainstorm', 'RunCompiled.class');
    copyfile(classFile, destFile);
else
    disp(['WARNING: Packaging without the installation runner, you must:' 10 ... 
          ' - Create and compile the Java project brainstorm_run_' ReleaseName(2:end) 10 ...
          ' - Copy RunCompiled.class to the deploy folder: ' 10 classFile]);
end


%% ===== CREATE SPMTRIP FOLDER =====
% Extract some functions from SPM12 and FieldTrip to be compiled with Brainstorm
spmtripDir = fullfile(bst_get('BrainstormUserDir'), 'spmtrip');
if isPlugs && ~exist(fullfile(spmtripDir, 'ft_defaults.m'), 'file')
    disp(['COMPILE> SPMTRIP folder not found: ' spmtripDir]);
    disp('COMPILE> Running bst_spmtrip... (to disable this, call bst_compile with argument "noplugs")');
    % Windows only
    if ~ispc
        error('Preparing the folder spmtrip with bst_spmtrip.m is available only for Windows (for the moment).');
    end
    % Initialize FieldTrip
    [isInstalled, errMsg, PlugFt] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        error(['Could not install FieldTrip: ' errMsg]);
    end
    FieldTripDir = fullfile(PlugFt.Path, PlugFt.SubFolder);
    % Install SPM
    [isInstalled, errMsg, PlugSpm] = bst_plugin('Install', 'spm12');
    if ~isInstalled
        error(['Could not install SPM12: ' errMsg]);
    end
    SpmDir = fullfile(PlugSpm.Path, PlugSpm.SubFolder);
    % Extract functions to compile from SPM and Fieldtrip
    bst_spmtrip(SpmDir, FieldTripDir, spmtripDir);
    addpath(spmtripDir);
end



% === COMPILING ===
% Start timer
tCompile = tic;
disp('COMPILE> Starting Matlab Compiler...');
% Assemble mcc command line
strCall = ['mcc ' ...
    '-W "java:bst_javabuilder_' ReleaseName(2:end) ',Run" ' ...
    '-T "link:lib" ' ...
    '-d "' outputDir '" ' ...
    '"class{Run:' fullfile(bstDir, 'brainstorm.m') '}" ' ...
    '-a "' appJar '" ' ...
    '-a "' fullfile(bstDir, 'defaults') '" ' ...
    '-a "' fullfile(bstDir, 'doc') '" ' ...
    '-a "' fullfile(bstDir, 'external') '" ' ...
    '-a "' fullfile(bstDir, 'java') '" ' ...
    '-a "' fullfile(bstDir, 'toolbox') '" '];
% Add plugins folders
if isPlugs
    % Add SPM+FieldTrip
    strCall = [strCall '-a "' spmtripDir '" '];
    % Get plugins to compile with the application
    PlugDesc = bst_plugin('GetSupported');
    for iPlug = 1:length(PlugDesc)
        % Add only the plugins designed only the plugins designed to be compiled with Brainstorm
        if (PlugDesc(iPlug).CompiledStatus == 2) && ~ismember(PlugDesc(iPlug).Name, {'fieldtrip', 'spm12'})
            % Install plugin (if not installed yet)
            [isInstalled, errMsg, PlugInst] = bst_plugin('Install', PlugDesc(iPlug).Name);
            if ~isInstalled
                error(['Could not install plugin "' PlugDesc(iPlug).Name '": ' 10 errMsg]);
            end
            % Add to list of compiled folders
            strCall = [strCall '-a "' fullfile(PlugInst.Path, PlugInst.SubFolder) '" '];
            strCall = [strCall '-a "' fullfile(PlugInst.Path, 'plugin.mat') '" '];
            % Load plugin
            bst_plugin('Load', PlugDesc(iPlug).Name);
        % Unload all the other plugins (to avoid mixups in the dependency search)
        else
            bst_plugin('Unload', PlugDesc(iPlug).Name);
        end
    end
end
disp(['COMPILE> System call: ' strCall]);
% Execute MCC
[status, result] = system(strCall);
if (status ~= 0)
    error(['COMPILE> MCC returned an error: ' 10 result]);
end


%% ===== PACKAGING JAR =====
disp('COMPILE> Packaging binary distribution...');
% Compiled jar
compiledJar = fullfile(outputDir, ['bst_javabuilder_' ReleaseName(2:end) '.jar']);
if ~file_exist(compiledJar)
    error(['Compilation is incomplete, missing output jar: ' 10 compiledJar]);
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
% Re-jar files together
bstJar = fullfile(binDir, 'brainstorm3.jar');
if file_exist(bstJar)
    delete(bstJar);
end
if ispc
    cmdSeparator = '&';
    jarExePath = '\bin\jar.exe'; 
else   
    cmdSeparator = ';';
    jarExePath = '/bin/jar'; 
end
system(['cd "' jarDir '" ' cmdSeparator ' "' JdkDir, jarExePath '" cmf manifest.txt "' bstJar '" bst_javabuilder_' ReleaseName(2:end) ' org com']);



%% ===== PACKAGE ZIP =====
% Deploy folder
baseDir = fullfile(deployDir, 'brainstorm3');
destDir = fullfile(deployDir, 'brainstorm3', 'bin', ReleaseName);
% Delete existing folder brainstorm3_deploy/brainstorm3
if isdir(baseDir)
    try
        rmdir(baseDir, 's');
    catch
        error(['Could not delete folder: "' baseDir '"']);
    end
end
% Create dir
if ~mkdir(destDir)
    error(['Cannot create output directory:' destDir]);
end
% Copy everything from binDir to destDir
copyfile(fullfile(binDir, '*.*'), destDir);
% Create output filename
c = clock;
strDate = sprintf('%02d%02d%02d', c(1)-2000, c(2), c(3));
zipFile = fullfile(deployDir, ['bst_bin_' ReleaseName '_' strDate '.zip']);
% Zip folder
zip(zipFile, baseDir, fileparts(baseDir));
% Delete newly created dir
try
    rmdir(baseDir, 's');
catch
    disp(['ERROR: Could not delete folder: "' baseDir '"']);
end


%% ===== TERMINATION =====
% Close Brainstorm (if it was started in this script)
if isNogui
    brainstorm stop;
end
% Done
stopTime = toc(tCompile);
if (stopTime > 60)
    disp(sprintf('COMPILE> Done in %dmin\n', round(stopTime/60)));
else
    fprintf('COMPILE> Done in %ds\n\n', round(stopTime));
end


