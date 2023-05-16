function varargout = brainstorm( varargin )
% BRAINSTORM Brainstorm startup function.
%
% USAGE: brainstorm                 : Start Brainstorm
%        brainstorm start           : Start Brainstorm
%        brainstorm nogui           : Start Brainstorm with hidden interface (for scripts)
%        brainstorm server          : Start Brainstorm on a distant server (completely headless)
%        brainstorm [script] [args] : Start Brainstorm in server mode and execute the input script
%        brainstorm ... local       : Start Brainstorm with a local database (in .brainstorm folder)
%        brainstorm stop            : Quit Brainstorm
%        brainstorm reset           : Re-inialize Brainstorm (delete preferences and database)
%        brainstorm digitize        : Digitize points using a Polhemus system
%        brainstorm update          : Download and install latest Brainstorm update
%        brainstorm autopilot ...   : Call bst_autopilot with the following arguments
%        brainstorm setpath         : Add Brainstorm subdirectories to current path
%        brainstorm startjava       : Add Brainstorm Java classes to dynamic classpath
%        brainstorm info            : Open Brainstorm website
%        brainstorm license         : Displays license agreement window
%        brainstorm tutorial name   : Run the validation script attached to a tutorial (ctf, neuromag, raw, resting, yokogawa
%        brainstorm tutorial all    : Run all the validation scripts
%        brainstorm test            : Run a coverage test
%        brainstorm deploy          : Cleanup files and copy to git repository
%        brainstorm compile         : Compile Brainstorm with Matlab mcc compiler, including all plugins
%        brainstorm compile noplugs : Compile Brainstorm with Matlab mcc compiler, without the plugins
%        brainstorm workshop        : Download OpenMEEG and the SPM atlases, and run some small tests
%  res = brainstorm('status')       : Return brainstorm status (1=running, 0=stopped)

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
% Authors: Francois Tadel, 2008-2022

% Make sure that "more" is off
more off

% Compiled version
isCompiled = exist('isdeployed', 'builtin') && isdeployed;
if isCompiled
    BrainstormHomeDir = fileparts(fileparts(which(mfilename)));
    % Some versions of the compiler use different subfolders: search for the doc folder
    if ~exist(bst_fullfile(BrainstormHomeDir, 'doc'), 'file')
        docDir = file_find(BrainstormHomeDir, 'doc', 4, 1);
        if ~isempty(docDir)
            BrainstormHomeDir = fileparts(docDir);
        end
    end
else
    % Assume we are in the Brainstorm folder
    BrainstormHomeDir = fileparts(which(mfilename));
    % Add path to the core subfolders, used in this function
    corePath = fullfile(BrainstormHomeDir, 'toolbox', 'core');
    if ~exist(corePath, 'dir')
        error(['Unable to find ' corePath ' directory.']);
    end
    % Test if the folders are already in the path first
    p = path();
    if isempty(strfind(p, corePath))
        addpath(corePath, '-BEGIN');
        addpath(fullfile(BrainstormHomeDir, 'toolbox', 'io'), '-BEGIN');
        addpath(fullfile(BrainstormHomeDir, 'toolbox', 'misc'), '-BEGIN');
    end
end

% Set dynamic JAVA CLASS PATH
if ~exist('org.brainstorm.tree.BstNode', 'class')
    % Brainstorm jar file
    BstJar = fullfile(BrainstormHomeDir, 'java', 'brainstorm.jar');
    UpdateFile = fullfile(BrainstormHomeDir, 'java', 'outdated_jar.txt');
    % If there is a flag file indicating that brainstorm.jar should be deleted (see bst_update.m)
    if exist(UpdateFile, 'file')
        delete(BstJar);
        delete(UpdateFile);
        if exist(UpdateFile, 'file') || exist(BstJar, 'file')
            errordlg(['The following files could not be deleted automatically:' 10 BstJar 10 UpdateFile 10 10 ...
                      'An error occurred during the Brainstorm update.' 10 ...
                      'Delete this brainstorm3 folder and download manually' 10 ...
                      'a new one from the Brainstorm website.']);
        end
    end
    % Download brainstorm.jar if missing
    if ~exist(BstJar, 'file')
        disp('BST> Downloading brainstorm.jar...');
        bst_webread('https://github.com/brainstorm-tools/bst-java/raw/master/brainstorm/dist/brainstorm.jar', BstJar);
    end
    % Add Brainstorm JARs to classpath
    javaaddpath(fullfile(BrainstormHomeDir, 'java', 'RiverLayout.jar'));
    javaaddpath(BstJar);
end

% Default action : start
if (nargin == 0)
    action = 'start';
    BrainstormDbDir = [];
else
    action = lower(varargin{1});
    % Local start
    if ismember(action, {'start', 'nogui', 'server'}) && (nargin == 2) && strcmpi(varargin{2}, 'local')
        BrainstormDbDir = 'local';
    else
        BrainstormDbDir = [];
    end
end

res = 1;
switch action
    case 'start'
        bst_set_path(BrainstormHomeDir);
        bst_startup(BrainstormHomeDir, 1, BrainstormDbDir);
    case 'nogui'
        bst_set_path(BrainstormHomeDir);
        bst_startup(BrainstormHomeDir, 0, BrainstormDbDir);
    case 'server'
        bst_set_path(BrainstormHomeDir);
        bst_startup(BrainstormHomeDir, -1, BrainstormDbDir);
    case 'autopilot'
        if ~isappdata(0, 'BrainstormRunning')
            bst_set_path(BrainstormHomeDir);
            bst_startup(BrainstormHomeDir, 2, BrainstormDbDir);
        end
        res = bst_autopilot(varargin{2:end});
    case 'digitize'
        brainstorm nogui
        panel_digitize('Start');
    case {'status', 'isstarted', 'isrunning'}
        res = isappdata(0, 'BrainstormRunning');
    case {'exit', 'stop', 'quit'}
        bst_exit();
    case 'reset'
        bst_reset();
    case 'setpath'
        disp('Adding all Brainstorm directories to local path...');
        bst_set_path(BrainstormHomeDir);
    case 'startjava'
        disp('Starting Java...');
    case {'info', 'website'}
        web('https://neuroimage.usc.edu/brainstorm/', '-browser');
    case 'forum'
        web('https://neuroimage.usc.edu/forums/', '-browser');
    case 'license'
        bst_set_path(BrainstormHomeDir);
        bst_set('BrainstormHomeDir', BrainstormHomeDir);
        bst_license();
    case 'update'
        % Add path to java_dialog function
        addpath(fullfile(BrainstormHomeDir, 'toolbox', 'gui'));
        % Update
        bst_update(0);
    case 'tutorial'
        bst_set_path(BrainstormHomeDir);
        tutonames = varargin{2};
        % Tutorial folder
        if (nargin < 3)
            tutorial_dir = 'C:\Work\RawData\Tutorials';
        else
            tutorial_dir = varargin{3};
        end
        % Run all the tutorial scripts
        if isequal(tutonames, 'all')
            tutonames = {'ctf', 'raw', 'epilepsy', 'resting', 'neuromag', 'yokogawa', 'auditory'};
        elseif ischar(tutonames)
            tutonames = {tutonames};
        elseif ~iscell(tutonames)
            error('Invalid call.');
        end
        % Run all the requested validation scripts
        for i = 1:length(tutonames)
            disp([10 '===== TUTORIAL: ' upper(tutonames{i}) ' =====']);
            startTime = tic;
            if (length(varargin) == 4)
                eval(['tutorial_' lower(tutonames{i}) '(''' tutorial_dir ''', ''' varargin{4} ''');']);
            else
                eval(['tutorial_' lower(tutonames{i}) '(''' tutorial_dir ''');']);
            end
            % Done
            stopTime = toc(startTime);
            if (stopTime > 60)
                disp(sprintf('BST> Done in %dmin\n', round(stopTime/60)));
            else
                disp(sprintf('BST> Done in %ds\n', round(stopTime)));
            end
            % Close report viewer if it is not the last tutorial to run
            if (i < length(tutonames))
                bst_report('Close');
            end
        end
        
    case 'test'
        bst_set_path(BrainstormHomeDir);
        if (nargin < 2)
            error(['You must specify an empty test folder.' 10 'Usage: brainstorm test test_dir']);
        end
        test_dir = varargin{2};
        test_all(test_dir);
        
    case 'workshop'
        % Runs Brainstorm normally (asks for brainstorm_db)
        if ~isappdata(0, 'BrainstormRunning')
            bst_set_path(BrainstormHomeDir);
            bst_startup(BrainstormHomeDir, 1, BrainstormDbDir);
        end
        % Message
        java_dialog('msgbox', 'Brainstorm will now download additional files needed for the workshop.', 'Workshop');
        % Downloads OpenMEEG
        bst_plugin('Install', 'openmeeg', 1);
        % Downloads the TMP.nii SPM atlas
        bst_normalize_mni('install');
        % Message
        java_dialog('msgbox', ['Brainstorm will now test your display and open a 3D figure:' 10 10 ... 
                               ' - You should see two surfaces: a brain surface and a transparent head.' 10 ...
                               ' - Make sure you can rotate the brain with your mouse, ' 10 ...
                               ' - Then close the figure.' 10 10], 'Workshop');
        % Creates an empty test protocol
        ProtocolName = 'TestWorkshop';
        gui_brainstorm('DeleteProtocol', ProtocolName);
        gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
        % Display the default anatomy cortex and head 
        hFig = view_surface('@default_subject/tess_cortex_pial_low.mat');
        hFig = view_surface('@default_subject/tess_head.mat', [], [], hFig);
        waitfor(hFig);
        % Delete test protocol
        gui_brainstorm('DeleteProtocol', ProtocolName);
        % Confirmation message
        java_dialog('msgbox', 'You computer is ready for the workshop.', 'Workshop');
        
    case 'deploy'
        % Add path to deploy function
        bst_set_path(BrainstormHomeDir);
        addpath(fullfile(BrainstormHomeDir, 'deploy'));
        bst_set('BrainstormHomeDir', BrainstormHomeDir);
        % Deploy Braintorm
        bst_deploy();

    case 'compile'
        % Add path to deploy function
        bst_set_path(BrainstormHomeDir);
        addpath(fullfile(BrainstormHomeDir, 'deploy'));
        % Options
        if (nargin > 1)
            if strcmpi(varargin{2}, 'noplugs')
                isPlugs = 0;
            else
                error('Usage: brainstorm compile [noplugs]');
            end
        else
            isPlugs = 1;
        end
        % Matlab < 2020a: Old compilation function using deploytool
        if (bst_get('MatlabVersion') < 908)
            addpath(fullfile(BrainstormHomeDir, 'deploy', 'deprecated'));
            if isPlugs
                bst_deploy_java('2');
            else
                bst_deploy_java('1');
            end
        else
            bst_compile(isPlugs);
        end
        
    otherwise
        % Check if trying to execute a script
        if file_exist(varargin{1})
            ScriptFile = varargin{1};
        elseif file_exist(fullfile(pwd, varargin{1}))
            ScriptFile = fullfile(pwd, varargin{1});
        else
            ScriptFile = [];
        end
        % Execute script
        if ~isempty(ScriptFile)
            % Start brainstorm in server mode (local database or not)
            % With extra parameters
            if (length(varargin) > 1)
                params = varargin(2:end);
                if any(cellfun(@(c)isequal(c,'local'), varargin(2:end)))
                    brainstorm server local;
                    params(cellfun(@(c)isequal(c,'local'), params)) = [];
                else
                    brainstorm server;
                end
            % Without extra parameters
            else
                brainstorm server;
                params = [];
            end
            % Execute script
            if ~isempty(params)
                bst_call(@panel_command, 'ExecuteScript', ScriptFile, params{:});
            else
                bst_call(@panel_command, 'ExecuteScript', ScriptFile);
            end
            % Quit
            brainstorm stop;
            
        % Display usage
        else
            disp(' ');
            disp('Usage : brainstorm start           : Start Brainstorm');
            disp('        brainstorm nogui           : Start Brainstorm with hidden interface (for scripts)');
            disp('        brainstorm server          : Start Brainstorm on a distant server (completely headless)');
            disp('        brainstorm <script> <args> : Start Brainstorm in server mode, execute the input script and quit');
            disp('        brainstorm ... local       : Start Brainstorm with a local database (in .brainstorm folder)');
            disp('        brainstorm stop            : Quit Brainstorm');
            disp('        brainstorm update          : Download and install latest Brainstorm update (see bst_update)');
            disp('        brainstorm reset           : Re-initialize Brainstorm database and preferences');
            disp('        brainstorm digitize        : Digitize electrodes positions and head shape using a Polhemus system');
            disp('        brainstorm setpath         : Add Brainstorm subdirectories to current path');
            disp('        brainstorm startjava       : Add Brainstorm Java classes to dynamic classpath');
            disp('        brainstorm info            : Open Brainstorm website');
            disp('        brainstorm forum           : Open Brainstorm forum');
            disp('        brainstorm license         : Display license');
            disp('        brainstorm tutorial name   : Run the validation script attached to a tutorial (ctf, neuromag, raw, resting, yokogawa)');
            disp('        brainstorm tutorial all    : Run all the validation scripts');
            disp('        brainstorm packagebin      : Create separate zip files for all the currently available binary distributions');
            disp('  res = brainstorm(''status'')     : Return brainstorm status (1=running, 0=stopped)');
            disp(' ');
        end
end

% Return value
if (nargout >= 1)
    varargout{1} = res;
end

end


%% ===== SET PATH =====
function bst_set_path(BrainstormHomeDir)
    % Cancel add path in case of deployed application
    if bst_iscompiled()
        return
    end
    % Brainstorm folder itself
    addpath(BrainstormHomeDir, '-BEGIN'); % make sure the main brainstorm folder is in the path
    % List of folders to add
    NEXTDIR = {'external','toolbox'}; % in reverse order of priority
    for i = 1:length(NEXTDIR)
        nextdir = fullfile(BrainstormHomeDir,NEXTDIR{i});
        % Reset the last warning to blank
        lastwarn('');
        % Check that directory exist
        if ~isdir(nextdir)
            error(['Directory "' NEXTDIR{i} '" does not exist in Brainstorm path.' 10 ...
                   'Please re-install Brainstorm.']);
        end
        % Recursive search for subfolders in each main folder
        P = genpath(nextdir);
        % Add directory and subdirectories
        addpath(P, '-BEGIN');
    end
    % Adding user's mex path
    userMexDir = bst_get('UserMexDir');
    addpath(userMexDir, '-BEGIN');
    % Adding user's custom process path
    userProcessDir = bst_get('UserProcessDir');
    addpath(userProcessDir, '-BEGIN');
end





