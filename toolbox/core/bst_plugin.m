function [varargout] = bst_plugin(varargin)
% BST_PLUGIN:  Manages Brainstorm plugins
%
% USAGE:          PlugDesc = bst_plugin('GetSupported')                              % List all the plugins supported by Brainstorm
%                 PlugDesc = bst_plugin('GetSupported',         PlugName/PlugDesc)   % Get only one specific supported plugin
%                 PlugDesc = bst_plugin('GetInstalled')                              % Get all the installed plugins
%                 PlugDesc = bst_plugin('GetInstalled',         PlugName/PlugDesc)   % Get a specific installed plugin
%       [PlugDesc, errMsg] = bst_plugin('GetDescription',       PlugName/PlugDesc)   % Get a full structure representing a plugin
%                            bst_plugin('List',                 Target='installed')  % Target={'supported','installed'}
% [isOk, errMsg, PlugDesc] = bst_plugin('Load',                 PlugName/PlugDesc)
% [isOk, errMsg, PlugDesc] = bst_plugin('Unload',               PlugName/PlugDesc)
% [isOk, errMsg, PlugDesc] = bst_plugin('Install',              PlugName, isAutoUpdate=1, isInteractive=0)
% [isOk, errMsg, PlugDesc] = bst_plugin('InstallInteractive',   PlugName, isAutoUpdate=1)
%           [isOk, errMsg] = bst_plugin('Uninstall',            PlugName, isInteractive=0)
%           [isOk, errMsg] = bst_plugin('UninstallInteractive', PlugName)

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
% Authors: Francois Tadel 2021

eval(macro_method);
end


%% ===== GET SUPPORTED PLUGINS =====
% USAGE:  PlugDesc = bst_plugin('GetSupported')                      % List all the plugins supported by Brainstorm
%         PlugDesc = bst_plugin('GetSupported', PlugName/PlugDesc)   % Get only one specific supported plugin
function PlugDesc = GetSupported(SelPlug)
    % Parse inputs
    if (nargin < 1) || isempty(SelPlug)
        SelPlug = [];
    end
    % Initialized returned structure
    PlugDesc = repmat(db_template('PlugDesc'), 0);
    % Get OS
    OsType = bst_get('OsType', 0);
    
    % ================================================================================================================
    % === ADI-SDK ===      ADInstrument SDK for reading LabChart files
    PlugDesc(end+1).Name        = 'adi-sdk';
    PlugDesc(end).Version       = 'github';
    PlugDesc(end).URLinfo       = 'https://github.com/JimHokanson/adinstruments_sdk_matlab';
    PlugDesc(end).TestFile      = 'adi';
    PlugDesc(end).LoadFolders   = {'adinstruments_sdk_matlab-master'};
    switch (OsType)
        case 'win64', PlugDesc(end).URLzip = 'https://github.com/JimHokanson/adinstruments_sdk_matlab/archive/master.zip';
    end
    % === BRAIN2MESH ===
    PlugDesc(end+1).Name        = 'brain2mesh';
    PlugDesc(end).Version       = 'github';
    PlugDesc(end).URLzip        = 'https://github.com/fangq/brain2mesh/archive/master.zip';
    PlugDesc(end).URLinfo       = 'http://mcx.space/brain2mesh/';
    PlugDesc(end).ReadmeFile    = 'brain2mesh-master/README.md';
    PlugDesc(end).TestFile      = 'brain2mesh.m';
    PlugDesc(end).LoadFolders   = {'brain2mesh-master'};
%     PlugDesc(end).RequiredPlugs = {'spm12', 'iso2mesh'};
    PlugDesc(end).RequiredPlugs = {'iso2mesh'};
    % === ISO2MESH ===
    PlugDesc(end+1).Name        = 'iso2mesh';
    PlugDesc(end).Version       = '1.9.2';
    PlugDesc(end).URLinfo       = 'http://iso2mesh.sourceforge.net/cgi-bin/index.cgi';
    PlugDesc(end).ReadmeFile    = 'iso2mesh/README.txt';
    PlugDesc(end).TestFile      = 'iso2meshver.m';
    PlugDesc(end).LoadFolders   = {'iso2mesh'};
    PlugDesc(end).LoadedFcn     = 'assignin(''base'', ''ISO2MESH_TEMP'', bst_get(''BrainstormTmpDir''));';
    switch (OsType)
        case 'linux64', PlugDesc(end).URLzip = 'https://github.com/fangq/iso2mesh/releases/download/v1.9.2/iso2mesh-1.9.2-linux64.zip';
        case 'mac32',   PlugDesc(end).URLzip = 'https://github.com/fangq/iso2mesh/releases/download/v1.9.2/iso2mesh-1.9.2-osx32.zip';
        case 'mac64',   PlugDesc(end).URLzip = 'https://github.com/fangq/iso2mesh/releases/download/v1.9.2/iso2mesh-1.9.2-osx64.zip';
        case 'win32',   PlugDesc(end).URLzip = 'https://github.com/fangq/iso2mesh/releases/download/v1.9.2/iso2mesh-1.9.2-win32.zip';
        case 'win64',   PlugDesc(end).URLzip = 'https://github.com/fangq/iso2mesh/releases/download/v1.9.2/iso2mesh-1.9.2-win32.zip';
    end
    % === SPM12 ===
    PlugDesc(end+1).Name        = 'spm12';
    PlugDesc(end).URLzip        = 'https://github.com/JimHokanson/adinstruments_sdk_matlab/archive/master.zip';
    PlugDesc(end).TestFile      = 'spm';
    PlugDesc(end).UnloadPlugs   = {'fieldtrip'};
    % === CAT12 ===
    PlugDesc(end+1).Name        = 'cat12';
    PlugDesc(end).URLzip        = 'https://github.com/JimHokanson/adinstruments_sdk_matlab/archive/master.zip';
    PlugDesc(end).TestFile      = 'cat_version';
    PlugDesc(end).UnloadPlugs   = {'fieldtrip'};
    PlugDesc(end).RequiredPlugs = {'spm12'};
    % ================================================================================================================
    
    % Select only one plugin
    if ~isempty(SelPlug)
        % Get plugin name
        if ischar(SelPlug)
            PlugName = SelPlug;
        else
            PlugName = SelPlug.Name;
        end
        % Find in the list of plugins
        iPlug = find(strcmpi({PlugDesc.Name}, PlugName));
        if ~isempty(iPlug)
            PlugDesc = PlugDesc(iPlug);
        else
            PlugDesc = [];
        end
    end
end


%% ===== GET INSTALLED PLUGINS =====
% USAGE:  PlugDesc = bst_plugin('GetInstalled', PlugName/PlugDesc)  % Get one installed plugin
%         PlugDesc = bst_plugin('GetInstalled')                     % Get all installed plugins
function PlugDesc = GetInstalled(SelPlug)
    % Parse inputs
    if (nargin < 1) || isempty(SelPlug)
        SelPlug = [];
    end
    
    % === DEFINE SEARCH LIST ===
    % Looking for a single plugin
    if ~isempty(SelPlug)
        SearchPlugs = GetSupported(SelPlug);
    % Looking for all supported plugins
    else
        SearchPlugs = GetSupported();
    end
    % Brainstorm plugin folder
    BstUserDir = bst_get('BrainstormUserDir');
    % Matlab path
    matlabPath = str_split(path, ';');
    
    % === LOOK FOR SUPPORTED PLUGINS ===
    % Empty plugin structure
    PlugDesc = repmat(db_template('PlugDesc'), 0);
    % Look for each plugin in the search list
    for iSearch = 1:length(SearchPlugs)
        % Theoretical plugin path
        PlugPath = bst_fullfile(BstUserDir, SearchPlugs(iSearch).Name);
        % Check if test function is available in the Matlab path
        if ~isempty(SearchPlugs(iSearch).TestFile) && ~isempty(which(SearchPlugs(iSearch).TestFile))
            % Get the test file path
            TestFilePath = bst_fileparts(which(SearchPlugs(iSearch).TestFile));
            % Register loaded plugin
            iPlug = length(PlugDesc) + 1;
            PlugDesc(iPlug) = SearchPlugs(iSearch);
            PlugDesc(iPlug).isLoaded = 1;
            % Check if the file is inside the Brainstorm user folder (where it is supposed to be)
            if ~isempty(strfind(TestFilePath, PlugPath))
                PlugDesc(iPlug).Path = PlugPath;
                PlugDesc(iPlug).isManaged = 1;
            else
                PlugDesc(iPlug).Path = TestFilePath;
                PlugDesc(iPlug).isManaged = 0;
            end
        % Check if the plugin is installed
        elseif isdir(PlugPath) && file_exist(bst_fullfile(PlugPath, 'plugin.mat'))
            % Register managed but unloaded plugin
            iPlug = length(PlugDesc) + 1;
            PlugDesc(iPlug) = SearchPlugs(iSearch);
            PlugDesc(iPlug).Path = PlugPath;
            PlugDesc(iPlug).isLoaded = 0;
            PlugDesc(iPlug).isManaged = 1;
        end
    end
    
    % === LOOK FOR UNREFERENCED PLUGINS ===
    % Get folders in Brainstorm user folder
    if ~isempty(SelPlug)
        if ischar(SelPlug)
            PlugList = dir(bst_fullfile(BstUserDir, SelPlug));
        else
            PlugList = dir(bst_fullfile(BstUserDir, SelPlug.Name));
        end
    else
        PlugList = dir(BstUserDir);
    end
    % Process folders containing a plugin.mat file
    for iDir = 1:length(PlugList)
        % Process only folders containing a 'plugin.mat' file and not already referenced
        PlugDir = bst_fullfile(BstUserDir, PlugList(iDir).name);
        PlugMatFile = bst_fullfile(PlugDir, 'plugin.mat');
        if ~isdir(PlugDir) || (PlugList(iDir).name(1) == '.') || ~file_exist(PlugMatFile) || ismember(PlugList(iDir).name, {PlugDesc.Name})
            continue;
        end
        % If selecting only one plugin
        if ~isempty(SelPlug) && ~strcmpi(PlugList(iDir).name, SelPlug)
            continue;
        end
        % Add plugin to list
        iPlug = length(PlugDesc) + 1;
        PlugDesc(iPlug).Name      = PlugList(iDir).name;
        PlugDesc(iPlug).Path      = PlugDir;
        PlugDesc(iPlug).isManaged = 1;
        PlugDesc(iPlug).isLoaded  = ismember(PlugDir, matlabPath);
    end
    
    % === READ PLUGIN.MAT ===
    for iPlug = 1:length(PlugDesc)
        % Try to load the plugin.mat file in the plugin folder
        PlugMatFile = bst_fullfile(PlugDesc(iPlug).Path, 'plugin.mat');
        if file_exist(PlugMatFile)
            try
                PlugMat = load(PlugMatFile);
            catch
                PlugMat = struct();
            end
            % Copy fields
            loadFields = setdiff(fieldnames(db_template('PlugDesc')), {'Name', 'Path', 'isLoaded', 'isManaged'});
            for iField = 1:length(loadFields)
                if isfield(PlugMat, loadFields{iField}) && ~isempty(PlugMat.(loadFields{iField}))
                    PlugDesc(iPlug).(loadFields{iField}) = PlugMat.(loadFields{iField});
                end
            end
        else
            PlugDesc(iPlug).URLzip = []; 
        end
    end
end


%% ===== GET DESCRIPTION =====
% USAGE:  [PlugDesc, errMsg] = GetDescription(PlugName/PlugDesc)
function [PlugDesc, errMsg] = GetDescription(PlugName)
    % Initialize returned values
    errMsg = '';
    PlugDesc = [];
    % CALL: GetDescription(PlugDesc)
    if isstruct(PlugName)
        % Add the missing fields
        PlugDesc = struct_copy_fields(PlugName, db_template('PlugDesc'), 0);
    % CALL: GetDescription(PlugName)
    elseif ischar(PlugName)
        % Get supported plugins
        AllPlugs = GetSupported();
        % Find plugin in supported plugins
        iPlug = find(strcmpi({AllPlugs.Name}, PlugName));
        if isempty(iPlug)
            errMsg = ['Unknown plugin: ' PlugName];
            return;
        end
        % Return found plugin
        PlugDesc = AllPlugs(iPlug);
    else
        errMsg = 'Invalid call to GetDescription().';
    end
end


%% ===== GET README FILE ====
% Fill full paths to the readme and logo files
function PlugDesc = GetReadMe(PlugDesc)
    % Check the existence of target logo and readme
    if ~isempty(PlugDesc.ReadmeFile) && ~file_exist(PlugDesc.ReadmeFile)
        ReadmeFile = bst_fullfile(PlugDesc.Path, PlugDesc.ReadmeFile);
        if file_exist(ReadmeFile)
            PlugDesc.ReadmeFile = ReadmeFile;
        end
    end
    if ~isempty(PlugDesc.LogoFile) && ~file_exist(PlugDesc.LogoFile)
        LogoFile = bst_fullfile(PlugDesc.Path, PlugDesc.LogoFile);
        if file_exist(LogoFile)
            PlugDesc.LogoFile = LogoFile;
        end
    end
    % Search for default logo and readme
    if isempty(PlugDesc.ReadmeFile)
        ReadmeFile = bst_fullfile(bst_get('BrainstormHomeDir'), 'doc', 'plugins', [PlugDesc.Name '_readme.txt']);
        if file_exist(ReadmeFile)
            PlugDesc.ReadmeFile = ReadmeFile;
        end
    end
    if isempty(PlugDesc.LogoFile)
        LogoFile = bst_fullfile(bst_get('BrainstormHomeDir'), 'doc', 'plugins', [PlugDesc.Name '_logo.gif']);
        if file_exist(LogoFile)
            PlugDesc.LogoFile = LogoFile;
        end
    end
    if isempty(PlugDesc.LogoFile)
        LogoFile = bst_fullfile(bst_get('BrainstormHomeDir'), 'doc', 'plugins', [PlugDesc.Name '_logo.png']);
        if file_exist(LogoFile)
            PlugDesc.LogoFile = LogoFile;
        end
    end
end


%% ===== LIST =====
% USAGE:  bst_plugin('List', Target='installed')   % Target={'supported','installed'}
function List(Target)
    % Parse inputs
    if (nargin < 1) || isempty(Target)
        Target = 'Installed';
    else
        Target = [upper(Target(1)), lower(Target(2:end))];
    end
    % Print banner
    BstUserDir = bst_get('BrainstormUserDir');
    fprintf(1, '\n%s plugins:\n\n', Target);
    % Get plugins to list
    switch (Target)
        case 'Installed'
            PlugDesc = GetInstalled();
            isInstalled = 1;
        case 'Supported'
            PlugDesc = GetSupported();
            isInstalled = 0;
        otherwise,          error(['Invalid target: ' Target]);
    end
    if isempty(PlugDesc)
        return;
    end
    % Max lengths
    headerName = 'Name';
    headerVersion = 'Version';
    headerPath = 'Installation path';
    headerUrl = 'Downloaded from';
    maxName = max(cellfun(@length, {PlugDesc.Name, headerName}));
    maxVer  = max(cellfun(@length, {PlugDesc.Version, headerVersion}));
    maxUrl  = max(cellfun(@length, {PlugDesc.URLzip, headerUrl}));
    if isInstalled
        maxPath = max(cellfun(@length, {PlugDesc.Path, headerPath}));
        strPath = [' | ', headerPath, repmat(' ', 1, maxPath-length(headerPath))];
        strPathSep = ['-|-', repmat('-',1,maxPath)];
    else
        strPath = '';
        strPathSep = '';
    end
    % Print column headers
    disp(['    ', ...
        headerName, repmat(' ', 1, maxName-length(headerName)) ...
        ' | ', headerVersion, repmat(' ', 1, maxVer-length(headerVersion)), ...
        strPath, ...
        ' | ' headerUrl]);
    disp(['    ', repmat('-',1,maxName), '-|-', repmat('-',1,maxVer), strPathSep, '-|-', repmat('-',1,maxUrl)]);
    % Print installed plugins to standard output
    for iPlug = 1:length(PlugDesc)
        if isInstalled
            strPath = [' | ', PlugDesc(iPlug).Path, repmat(' ', 1, maxPath-length(PlugDesc(iPlug).Path))];
        else
            strPath = '';
        end
        disp(['    ', ...
            PlugDesc(iPlug).Name, repmat(' ', 1, maxName-length(PlugDesc(iPlug).Name)) ...
            ' | ', PlugDesc(iPlug).Version, repmat(' ', 1, maxVer-length(PlugDesc(iPlug).Version)), ...
            strPath, ...
            ' | ' PlugDesc(iPlug).URLzip]);
    end
    disp('   ');
end


%% ===== INSTALL =====
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('Install', PlugName, isAutoUpdate=1, isInteractive=0)
function [isOk, errMsg, PlugDesc] = Install(PlugName, isAutoUpdate, isInteractive)
    % Returned variables
    isOk = 0;
    % Parse inputs
    if (nargin < 3) || isempty(isInteractive)
        isInteractive = 0;
    end
    if (nargin < 2) || isempty(isAutoUpdate)
        isAutoUpdate = 1;
    end
    if ~ischar(PlugName)
        errMsg = 'Invalid call to Install()';
        PlugDesc = [];
        return;
    end
    % Get plugin structure from name
    [PlugDesc, errMsg] = GetDescription(PlugName);
    if ~isempty(errMsg)
        return;
    end
    % Check if there is a URL to download
    if isempty(PlugDesc.URLzip)
        errMsg = ['No download URL for ', bst_get('OsType', 0), ': ', PlugName ''];
        return;
    end
      
    % === PROCESS DEPENDENCIES ===
    if ~isempty(PlugDesc.RequiredPlugs)
        disp(['BST> Processing dependencies: ' PlugName ' requires: ' sprintf('%s ', PlugDesc.RequiredPlugs{:})]);
        for iPlug = 1:length(PlugDesc.RequiredPlugs)
            [isInstalled, errMsg] = Install(PlugDesc.RequiredPlugs{iPlug}, isAutoUpdate, isInteractive);
            if ~isInstalled
                errMsg = ['Error processing dependency: ' PlugDesc.RequiredPlugs{iPlug} 10 errMsg];
                return;
            end
        end
    end
    
    % === CHECK PREVIOUS INSTALL ===
    % Check if installed
    OldPlugDesc = GetInstalled(PlugName);
    % If already installed
    if ~isempty(OldPlugDesc)
        % If an update is requested
        if isAutoUpdate && ...
                ((~isempty(OldPlugDesc.URLzip) && ~isequal(PlugDesc.URLzip, OldPlugDesc.URLzip)) || ...
                 (~isempty(OldPlugDesc.Version) && ~isequal(PlugDesc.Version, OldPlugDesc.Version)))
            % Compare versions
            if (~isempty(PlugDesc.Version) && ~isequal(PlugDesc.Version, OldPlugDesc.Version))
                strCompare = ['Installed version: ' OldPlugDesc.Version 10 'Latest version: ' PlugDesc.Version 10];
            elseif ~isequal(PlugDesc.URLzip, OldPlugDesc.URLzip)
                strCompare = ['Installed version: ' OldPlugDesc.URLzip 10 'Latest version: ' PlugDesc.URLzip 10];
            else
                strCompare = '';
            end
            % Managed by Brainstorm: uninstall and re-install
            if OldPlugDesc.isManaged
                % Ask user for updating
                if isInteractive
                    isConfirm = java_dialog('confirm', ...
                        ['Plugin ' PlugName ': an update is available online.' 10 strCompare 10 ...
                        'Download and install the latest version?'], 'Plugin manager');
                    if ~isConfirm
                        errMsg = 'Installation aborted by user.';
                        return;
                    end
                end
                disp(['BST> Plugin ' PlugName ' is outdated and will be updated.']);
            else
                if isInteractive
                    java_dialog('msgbox', ['Plugin ' PlugName ': an update is available online.' 10 strCompare 10 ...
                        'Brainstorm cannot update it automatically because it was installed manually.' 10 ...
                        'It is recommended you delete the existing installation: ' 10 OldPlugDesc.Path 10 ...
                        'and then let Brainstorm install the updated version automatically.'], 'Plugin manager');
                end
                disp(['BST> Plugin ' PlugName ' is outdated and should be removed: ' 10 OldPlugDesc.Path]);
                return;
            end
        % No update: Load existing plugin and return
        else
            % Load plugin
            if ~OldPlugDesc.isLoaded
                [isLoaded, errMsg, PlugDesc] = Load(OldPlugDesc);
                if ~isLoaded
                    errMsg = ['Could not load plugin ' PlugName ':' 10 errMsg];
                    return;
                end
            else
                disp(['BST> Plugin ' PlugName ' already loaded: ' OldPlugDesc.Path]);
            end
            % Return old plugin
            PlugDesc = OldPlugDesc;
            PlugDesc = GetReadMe(PlugDesc);
            isOk = 1;
            return;
        end
    else
        % Get user confirmation
        if isInteractive
            isConfirm = java_dialog('confirm', ...
                ['Plugin ' PlugName ' is not installed on your computer.' 10 10 ...
                'Download the latest version of ' PlugName '?'], 'Plugin manager');
            if ~isConfirm
                errMsg = 'Installation aborted by user.';
                return;
            end
        end
    end
    
    % === INSTALL PLUGIN ===
    % Managed plugin folder
    PlugPath = bst_fullfile(bst_get('BrainstormUserDir'), PlugName);    
    % Delete existing folder
    if isdir(PlugDesc.Path)
        file_delete(PlugPath, 1, 3);
    end
    % Create folder
    res = mkdir(PlugPath);
    if ~res
        errMsg = ['Error: Cannot create folder' 10 PlugPath];
        return
    end
    % Download file
    ZipFile = bst_fullfile(PlugPath, 'plugin.zip');
    disp(['BST> Downloading file: ' ZipFile]);
    errMsg = gui_brainstorm('DownloadFile', PlugDesc.URLzip, ZipFile, ['Download plugin: ' PlugName]);
    % If file was not downloaded correctly
    if ~isempty(errMsg)
        errMsg = ['Impossible to download ' PlugName ' automatically:' 10 errMsg];
        if ~exist('isdeployed', 'builtin') || ~isdeployed
            errMsg = [errMsg 10 10 ...
                'Alternative download solution:' 10 ...
                '1) Copy the URL below from the Matlab command window: ' 10 ...
                '     ' PlugDesc.URLzip 10 ...
                '2) Paste it in a web browser' 10 ...
                '3) Save the file and unzip it' 10 ...
                '4) Add to the Matlab path the folder containing ' PlugDesc.TestFile '.'];
        end
        return;
    end
    % Update progress bar
    bst_progress('text', ['Installing plugin: ' PlugName '...']);
    % Unzip file
    unzip(ZipFile, PlugPath);
    file_delete(ZipFile, 1, 3);
    % Save plugin.mat
    PlugDesc.Path = PlugPath;
    PlugMatFile = bst_fullfile(PlugDesc.Path, 'plugin.mat');
    bst_save(PlugMatFile, PlugDesc, 'v6');
    
    % === LOAD PLUGIN ===
    % Load plugin
    [PlugDesc.isLoaded, errMsg, PlugDesc] = Load(PlugDesc);
    if ~isempty(errMsg)
        return;
    end
    % Show the readme file
    if isInteractive && ~isempty(PlugDesc.ReadmeFile) && file_exist(PlugDesc.ReadmeFile)
        view_text(PlugDesc.ReadmeFile, ['Installed plugin: ' PlugName], 1, 1);
    end
    % Return success
    isOk = 1;
end


%% ===== INSTALL INTERACTIVE =====
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('InstallInteractive', PlugName, isAutoUpdate=[])
function [isOk, errMsg, PlugDesc] = InstallInteractive(PlugName, isAutoUpdate)
    % Parse inputs
    if (nargin < 2) || isempty(isAutoUpdate)
        isAutoUpdate = [];
    end
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Initialization...');
    end
    % Call silent function
    [isOk, errMsg, PlugDesc] = Install(PlugName, isAutoUpdate, 1);
    % Handle errors
    if ~isOk
        bst_error(['Installation error:' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Installation message:' 10 10 errMsg 10], 'Plugin manager');
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end


%% ===== UNINSTALL =====
% USAGE:  [isOk, errMsg] = bst_plugin('Uninstall', PlugName, isInteractive=0)
function [isOk, errMsg] = Uninstall(PlugName, isInteractive)
    % Returned variables
    isOk = 0;
    errMsg = '';
    % Parse inputs
    if (nargin < 2) || isempty(isInteractive)
        isInteractive = 0;
    end
    if ~ischar(PlugName)
        errMsg = 'Invalid call to Uninstall()';
        return;
    end
    
    % === CHECK INSTALLATION ===
    % Get installation
    PlugDesc = GetInstalled(PlugName);
    % External plugin
    if ~isempty(PlugDesc) && ~isequal(PlugDesc.isManaged, 1)
        errMsg = ['Plugin ' PlugName ' is not managed by Brainstorm.' 10 'Delete folder manually:' 10 PlugDesc.Path];
        return;
    % Plugin not installed: check if folder exists
    elseif isempty(PlugDesc) || isempty(PlugDesc.Path)
        % Get plugin structure from name
        [PlugDesc, errMsg] = GetDescription(PlugName);
        if ~isempty(errMsg)
            return;
        end
        % Managed plugin folder
        PlugPath = bst_fullfile(bst_get('BrainstormUserDir'), PlugName);
    else
        PlugPath = PlugDesc.Path;
    end
    % Plugin not installed
    if ~file_exist(PlugPath)
        errMsg = ['Plugin ' PlugName ' is not installed.'];
        return;
    end
    
    % === USER CONFIRMATION ===
    if isInteractive
        isConfirm = java_dialog('confirm', ['Delete permanently plugin ' PlugName '?' 10 10 PlugPath 10 10], 'Plugin manager');
        if ~isConfirm
            errMsg = 'Uninstall aborted by user.';
            return;
        end
    end

    % === PROCESS DEPENDENCIES ===
    % Uninstall dependent plugins
    AllPlugs = GetSupported();
    for iPlug = 1:length(AllPlugs)
        if ~isempty(AllPlugs(iPlug).RequiredPlugs) && ismember(PlugDesc.Name, AllPlugs(iPlug).RequiredPlugs)
            disp(['BST> Uninstalling dependent plugin: ' AllPlugs(iPlug).Name]);
            Uninstall(AllPlugs(iPlug).Name, isInteractive);
        end
    end
    
    % === UNLOAD ===
    if isequal(PlugDesc.isLoaded, 1)
        [isUnloaded, errMsgUnload] = Unload(PlugDesc);
        if ~isempty(errMsgUnload)
            disp(['BST> Error unloading plugin ' PlugName ': ' errMsgUnload]);
        end
    end
    
    % === UNINSTALL ===
    disp(['BST> Deleting plugin ' PlugName ': ' PlugPath]);
    % Delete plugin folder
    isDeleted = file_delete(PlugPath, 1, 3);
    if ~isDeleted
        errMsg = ['Could not delete plugin folder.' 10 'Restart Matlab and try again, or delete it manually.'];
        return;
    end
    % Return success
    isOk = 1;
end


%% ===== UNINSTALL INTERACTIVE =====
% USAGE:  [isOk, errMsg] = bst_plugin('UninstallInteractive', PlugName)
function [isOk, errMsg] = UninstallInteractive(PlugName)
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Initialization...');
    end
    % Call silent function
    [isOk, errMsg] = Uninstall(PlugName, 1);
    % Handle errors
    if ~isOk
        bst_error(['An error occurred while uninstalling plugin ' PlugName ':' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Uninstall message:' 10 10 errMsg 10], 'Plugin manager');
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end



%% ===== LOAD =====
% USAGE:  [isOk, errMsg, PlugDesc] = Load(PlugName/PlugDesc)
function [isOk, errMsg, PlugDesc] = Load(PlugDesc)
    % Initialize returned variables 
    isOk = 0;
    % Get plugin structure from name
    [PlugDesc, errMsg] = GetDescription(PlugDesc);
    if ~isempty(errMsg)
        return;
    end
    
    % === ALREADY LOADED ===
    % If plugin is already full loaded
    if isequal(PlugDesc.isLoaded, 1) && ~isempty(PlugDesc.Path)
        errMsg = ['Plugin ' PlugDesc.Name ' already loaded: ' PlugDesc.Path];
        return;
    end
    % Managed plugin path
    PlugPath = bst_fullfile(bst_get('BrainstormUserDir'), PlugDesc.Name);
    % Check if test function already available in the path
    if ~isempty(PlugDesc.TestFile)
        TestFilePath = bst_fileparts(which(PlugDesc.TestFile));
        if ~isempty(TestFilePath)
            PlugDesc.isLoaded = 1;
            PlugDesc.isManaged = ~isempty(strfind(which(PlugDesc.TestFile), PlugPath));
            if PlugDesc.isManaged
                PlugDesc.Path = PlugPath;
            else
                PlugDesc.Path = TestFilePath;
            end
            PlugDesc = GetReadMe(PlugDesc);
            disp(['BST> Plugin ' PlugDesc.Name ' already loaded: ' PlugDesc.Path]);
            isOk = 1;
            return;
        end
    end
    
    % === CHECK LOADABILITY ===
    % Unmanaged plugins: can't be loaded from this function, must be added by user to Matlab path
    if ~isempty(PlugDesc.isManaged) && ~isempty(PlugDesc.Path)
        if ~PlugDesc.isManaged
            errMsg = ['Plugin ' PlugDesc.Name ' not managed by Brainstorm: ' PlugDesc.Path];
            return;
        end
    else
        PlugDesc.Path = PlugPath;
        PlugDesc.isManaged = 1;
    end
    % Check plugin path
    if ~file_exist(PlugDesc.Path)
        errMsg = ['Plugin ' PlugDesc.Name ' not installed.' 10 'Missing folder: ' PlugDesc.Path];
        return;
    end

    % === PROCESS DEPENDENCIES ===
    if ~isempty(PlugDesc.UnloadPlugs) || ~isempty(PlugDesc.RequiredPlugs)
        disp('BST> Processing dependencies...');
    end
    % Unload incompatible plugins
    if ~isempty(PlugDesc.UnloadPlugs)
        for iPlug = 1:length(PlugDesc.UnloadPlugs)
            disp(['BST> Unloading incompatible plugin: ' PlugDesc.UnloadPlugs{iPlug}]);
            Unload(PlugDesc.UnloadPlugs{iPlug});
        end
    end
    % Load required plugins
    if ~isempty(PlugDesc.RequiredPlugs)
        for iPlug = 1:length(PlugDesc.RequiredPlugs)
            disp(['BST> Loading required plugin: ' PlugDesc.RequiredPlugs{iPlug}]);
            [isOk, errMsg] = Load(PlugDesc.RequiredPlugs{iPlug});
            if ~isOk
                errMsg = ['Error processing dependencies: ', PlugDesc.Name, 10, errMsg];
                return;
            end
        end
    end
    
    % === LOAD PLUGIN ===
    % Add plugin folder to path
    addpath(PlugPath);
    disp(['BST> Adding plugin ' PlugDesc.Name ' to path: ' PlugPath]);
    % Add specific subfolders to path
    for i = 1:length(PlugDesc.LoadFolders)
        subDir = PlugDesc.LoadFolders{i};
        if isequal(filesep, '\')
            subDir = strrep(subDir, '/', '\');
        end
        addpath([PlugPath, filesep, subDir]);
        disp(['BST> Adding plugin ' PlugDesc.Name ' to path: ', PlugPath, filesep, subDir]);
    end
    
    % === TEST FUNCTION ===
    % Check if test function is available on path
    if ~isempty(PlugDesc.TestFile) && isempty(which(PlugDesc.TestFile))
        errMsg = ['Plugin ' PlugDesc.Name ' successfully loaded from:' 10 PlugPath 10 10 ...
            'However, the function ' PlugDesc.TestFile ' is not accessible in the Matlab path.' 10 ...
            'Try restarting Matlab and Brainstorm.'];
        return;
    end
    % Load readme+logo files
    PlugDesc = GetReadMe(PlugDesc);
    % Call loaded function
    if ~isempty(PlugDesc.LoadedFcn)
        if ischar(PlugDesc.LoadedFcn)
            disp(['BST> Executing loaded callback: ' PlugDesc.LoadedFcn]);
            eval(PlugDesc.LoadedFcn);
        end
    end
    % Return success
    PlugDesc.isLoaded = 1;
    isOk = 1;
end


%% ===== UNLOAD =====
% USAGE:  [isOk, errMsg, PlugDesc] = Unload(PlugName/PlugDesc)
function [isOk, errMsg, PlugDesc] = Unload(PlugDesc)
    % Initialize returned variables 
    isOk = 0;
    errMsg = '';
    % Get installation
    InstPlugDesc = GetInstalled(PlugDesc);
    % External plugin
    if ~isempty(InstPlugDesc) && ~isequal(InstPlugDesc.isManaged, 1)
        disp(['BST> Warning: Plugin ' InstPlugDesc.Name ' is not managed by Brainstorm.']);
        disp(['BST> Removing plugin ' InstPlugDesc.Name ' from path: ' InstPlugDesc.Path]);
        rmpath(InstPlugDesc.Path);
        return;
    % Plugin not installed: check if folder exists
    elseif isempty(InstPlugDesc) || isempty(InstPlugDesc.Path)
        % Get plugin structure from name
        [PlugDesc, errMsg] = GetDescription(PlugDesc);
        if ~isempty(errMsg)
            return;
        end
        % Managed plugin folder
        PlugPath = bst_fullfile(bst_get('BrainstormUserDir'), PlugDesc.Name);
    else
        PlugDesc = InstPlugDesc;
        PlugPath = PlugDesc.Path;
    end
    % Plugin not installed
    if ~file_exist(PlugPath)
        errMsg = ['Plugin ' PlugDesc.Name ' is not installed.' 10 'Missing folder: ' PlugPath];
        return;
    end
    
    % Get plugin structure from name
    [PlugDesc, errMsg] = GetDescription(PlugDesc);
    if ~isempty(errMsg)
        return;
    end
    % Check plugin path
    PlugPath = bst_fullfile(bst_get('BrainstormUserDir'), PlugDesc.Name);
    
    % === PROCESS DEPENDENCIES ===
    % Unload dependent plugins
    AllPlugs = GetSupported();
    for iPlug = 1:length(AllPlugs)
        if ~isempty(AllPlugs(iPlug).RequiredPlugs) && ismember(PlugDesc.Name, AllPlugs(iPlug).RequiredPlugs)
            Unload(AllPlugs(iPlug));
        end
    end
    
    % === UNLOAD PLUGIN ===
    matlabPath = str_split(path, ';');
    % Remove plugin folder and subfolders from path
    allSubFolders = str_split(genpath(PlugPath), ';');
    for i = 1:length(allSubFolders)
        if ismember(allSubFolders{i}, matlabPath)
            rmpath(allSubFolders{i});
            disp(['BST> Removing plugin ' PlugDesc.Name ' from path: ' allSubFolders{i}]);
        end
    end
    
    % === TEST FUNCTION ===
    % Check if test function is still available on path
    if ~isempty(PlugDesc.TestFile) && ~isempty(which(PlugDesc.TestFile))
        errMsg = ['Plugin ' PlugDesc.Name ' successfully unloaded from: ' 10 PlugPath 10 10 ...
            'However, another version is still accessible on the Matlab path:' 10 which(PlugDesc.TestFile) 10 10 ...
            'Please remove this folder from the Matlab path.'];
        return;
    end
    % Return success
    PlugDesc.isLoaded = 0;
    isOk = 1;
end


