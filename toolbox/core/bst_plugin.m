function [varargout] = bst_plugin(varargin)
% BST_PLUGIN:  Manages Brainstorm plugins
%
% USAGE:          PlugDesc = bst_plugin('GetSupported')                                      % List all the plugins supported by Brainstorm
%                 PlugDesc = bst_plugin('GetSupported',         PlugName/PlugDesc)           % Get only one specific supported plugin
%                 PlugDesc = bst_plugin('GetInstalled')                                      % Get all the installed plugins
%                 PlugDesc = bst_plugin('GetInstalled',         PlugName/PlugDesc)           % Get a specific installed plugin
%       [PlugDesc, errMsg] = bst_plugin('GetDescription',       PlugName/PlugDesc)           % Get a full structure representing a plugin
%        [Version, URLzip] = bst_plugin('GetVersionOnline',     PlugName, URLzip, isCache)   % Get the latest online version of some plugins
%                      sha = bst_plugin('GetGithubCommit',      URLzip)                      % Get SHA of the last commit of a GitHub repository from a master.zip url
%               ReadmeFile = bst_plugin('GetReadmeFile',        PlugDesc)                    % Get full path to plugin readme file
%                 LogoFile = bst_plugin('GetLogoFile',          PlugDesc)                    % Get full path to plugin logo file
%                  Version = bst_plugin('CompareVersions',      v1, v2)                      % Compare two version strings
%           [isOk, errMsg] = bst_plugin('AddUserDefDesc',       RegMethod, jsonLocation=[])  % Register user-defined plugin definition
%           [isOk, errMsg] = bst_plugin('RemoveUserDefDesc'     PlugName)                    % Remove user-defined plugin definition
% [isOk, errMsg, PlugDesc] = bst_plugin('Load',                 PlugName/PlugDesc, isVerbose=1)
% [isOk, errMsg, PlugDesc] = bst_plugin('LoadInteractive',      PlugName/PlugDesc)
% [isOk, errMsg, PlugDesc] = bst_plugin('Unload',               PlugName/PlugDesc, isVerbose=1)
% [isOk, errMsg, PlugDesc] = bst_plugin('UnloadInteractive',    PlugName/PlugDesc)
% [isOk, errMsg, PlugDesc] = bst_plugin('Install',              PlugName, isInteractive=0, minVersion=[]) % Install and Load a plugin and its dependencies
% [isOk, errMsg, PlugDesc] = bst_plugin('InstallMultipleChoice',PlugNames, isInteractive=0)  % Install at least one of the input plugins
% [isOk, errMsg, PlugDesc] = bst_plugin('InstallInteractive',   PlugName)
%           [isOk, errMsg] = bst_plugin('Uninstall',            PlugName, isInteractive=0, isDependencies=1)
%           [isOk, errMsg] = bst_plugin('UninstallInteractive', PlugName)
%                            bst_plugin('Configure',            PlugDesc)            % Execute some additional tasks after loading or installation
%                            bst_plugin('SetCustomPath',        PlugName, PlugPath)
%                            bst_plugin('List',                 Target='installed')  % Target={'supported','installed'}
%                            bst_plugin('Archive',              OutputFile=[ask])    % Archive software environment
%                            bst_plugin('MenuCreate',           jMenu)
%                            bst_plugin('MenuUpdate',           jMenu)
%                            bst_plugin('LinkCatSpm',           Action)               % 0=Delete/1=Create/2=Check a symbolic link for CAT12 in SPM12 toolbox folder
%                            bst_plugin('UpdateDescription',    PlugDesc, doDelete=0) % Update plugin description after load
%
%
% PLUGIN DEFINITION
% =================
%
%     The plugins registered in Brainstorm are listed in function GetSupported(). 
%     Each one is an entry in the PlugDesc array, following the structure defined in db_template('plugdesc'). 
%     The fields allowed are described below.
%
%     Mandatory fields
%     ================
%     - Name     : String: Plugin name = subfolder in the Brainstorm user folder
%     - Version  : String: Version of the plugin (eg. '1.2', '21a', 'github-master', 'latest')
%     - URLzip   : String: Download URL, zip or tgz file accessible over HTTP/HTTPS/FTP
%     - URLinfo  : String: Information URL = Software website
%
%     Optional fields
%     ===============
%     - AutoUpdate     : Boolean: If true, the plugin is updated automatically when there is a new version available (default: true).
%     - AutoLoad       : Boolean: If true, the plugin is loaded automatically at Brainstorm startup
%     - Category       : String: Sub-menu in which the plugin is listed
%     - ExtraMenus     : Cell matrix {Nx2}: List of entries to add to the plugins menu
%                        | ExtraMenus{i,1}: String: Label of the menu
%                        | ExtraMenus{i,2}: String: Matlab code to eval when the menu is clicked 
%     - TestFile       : String: Name of a file that should be located in one of the loaded folders of the plugin (eg. 'spm.m' for SPM12). 
%                        | This is used to test whether the plugin was correctly installed, or whether it is available somewhere else in the Matlab path.
%     - ReadmeFile     : String: Name of the text file to display after installing the plugin (must be in the plugin folder). 
%                        | If empty, it tries using brainstorm3/doc/plugin/plugname_readme.txt
%     - LogoFile       : String: Name of the image file to display during the plugin download, installation, and associated computations (must be in the plugin folder). 
%                        | Supported extensions: gif, png. If empty, try using brainstorm3/doc/plugin/<Name>_logo.[gif|png]
%     - MinMatlabVer   : Integer: Minimum Matlab version required for using this plugin, as returned by bst_get('MatlabVersion')
%     - CompiledStatus : Integer: Behavior of this plugin in the compiled version of Brainstorm:
%                        | 0: Plugin is not available in the compiled distribution of Brainstorm
%                        | 1: Plugin is available for download (only for plugins based on native compiled code)
%                        | 2: Plugin is included in the compiled distribution of Brainstorm 
%     - RequiredPlugs  : Cell-array: Additional plugins required by this plugin, that must be installed/loaded beforehand.
%                        | {Nx2} => {'plugname','version'; ...} or
%                        | {Nx1} => {'plugname'; ...} 
%     - UnloadPlugs    : Cell-array of names of incompatible plugin, to unload before loaing this one
%     - LoadFolders    : Cell-array of subfolders to add to the Matlab path when setting up the plugin. Use {'*'} to add all the plugin subfolders.
%     - GetVersionFcn  : String to eval or function handle to call to get the version after installation
%     - InstalledFcn   : String to eval or function handle to call after installing the plugin
%     - UninstalledFcn : String to eval or function handle to call after uninstalling the plugin
%     - LoadedFcn      : String to eval or function handle to call after loading the plugin
%     - UnloadedFcn    : String to eval or function handle to call after unloading the plugin
%     - DeleteFiles    : List of files to delete after installation
%
%     Fields set when installing the plugin
%     =====================================
%     - Processes  : List of process functions to be added to the pipeline manager 
%
%     Fields set when loading the plugin
%     ==================================
%     - Path       : Installation path (eg. /home/username/.brainstorm/plugins/fieldtrip)
%     - SubFolder  : If all the code is in a single subfolder (eg. /plugins/fieldtrip/fieldtrip-20210304), 
%                    this is detected and the full path to the TestFile would be typically fullfile(Path, SubFolder).
%     - isLoaded   : 0=Not loaded, 1=Loaded
%     - isManaged  : 0=Installed manually by the user, 1=Installed automatically by Brainstorm 
%

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
% Authors: Francois Tadel, 2021-2023

eval(macro_method);
end


%% ===== GET SUPPORTED PLUGINS =====
% USAGE:  PlugDesc = bst_plugin('GetSupported')                      % List all the plugins supported by Brainstorm
%         PlugDesc = bst_plugin('GetSupported', PlugName/PlugDesc)   % Get only one specific supported plugin
%         PlugDesc = bst_plugin('GetSupported', ..., UserDefVerbose) % Print info on user-defined plugins
function PlugDesc = GetSupported(SelPlug, UserDefVerbose)
    % Parse inputs
    if (nargin < 2) || isempty(UserDefVerbose)
        UserDefVerbose = 0;
    end
    if (nargin < 1) || isempty(SelPlug)
        SelPlug = [];
    end
    % Initialized returned structure
    PlugDesc = repmat(db_template('PlugDesc'), 0);
    % Get OS
    OsType = bst_get('OsType', 0);
    
    % Add new curated plugins by 'CATEGORY:' and alphabetic order
    % ================================================================================================================
    % === ANATOMY: BRAIN2MESH ===
    PlugDesc(end+1)              = GetStruct('brain2mesh');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).URLzip         = 'https://github.com/fangq/brain2mesh/archive/master.zip';
    PlugDesc(end).URLinfo        = 'http://mcx.space/brain2mesh/';
    PlugDesc(end).TestFile       = 'brain2mesh.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).RequiredPlugs  = {'spm12'; 'iso2mesh'};
    PlugDesc(end).DeleteFiles    = {'examples', 'brain1020.m', 'closestnode.m', 'label2tpm.m', 'slicesurf.m', 'slicesurf3.m', 'tpm2label.m', 'polylineinterp.m', 'polylinelen.m', 'polylinesimplify.m'};
        
    % === ANATOMY: CAT12 ===
    PlugDesc(end+1)              = GetStruct('cat12');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'http://www.neuro.uni-jena.de/cat12/cat12_latest.zip';
    PlugDesc(end).URLinfo        = 'http://www.neuro.uni-jena.de/cat/';
    PlugDesc(end).TestFile       = 'cat_version.m';
    PlugDesc(end).ReadmeFile     = 'Contents.txt';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).RequiredPlugs  = {'spm12'};
    PlugDesc(end).GetVersionFcn  = 'bst_getoutvar(2, @cat_version)';
    PlugDesc(end).InstalledFcn   = 'LinkCatSpm(1);';
    PlugDesc(end).UninstalledFcn = 'LinkCatSpm(0);';
    PlugDesc(end).LoadedFcn      = 'LinkCatSpm(2);';
    PlugDesc(end).ExtraMenus     = {'Online tutorial', 'web(''https://neuroimage.usc.edu/brainstorm/Tutorials/SegCAT12'', ''-browser'')'};

    % === ANATOMY: CT2MRIREG ===
    PlugDesc(end+1)              = GetStruct('ct2mrireg');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://github.com/ajoshiusc/USCCleveland/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/ajoshiusc/USCCleveland/tree/master/ct2mrireg';
    PlugDesc(end).TestFile       = 'ct2mrireg.m';
    PlugDesc(end).ReadmeFile     = 'ct2mrireg/README.md';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'ct2mrireg'};
    PlugDesc(end).DeleteFiles    = {'fmri_analysis', 'for_clio', 'mixed_atlas', 'process_script', 'reg_prepost', 'visualize_channels', '.gitignore', 'README.md'};
    
    % === ANATOMY: ISO2MESH ===
    PlugDesc(end+1)              = GetStruct('iso2mesh');
    PlugDesc(end).Version        = '1.9.8';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://github.com/fangq/iso2mesh/archive/refs/tags/v1.9.8.zip';
    PlugDesc(end).URLinfo        = 'http://iso2mesh.sourceforge.net';
    PlugDesc(end).TestFile       = 'iso2meshver.m';
    PlugDesc(end).ReadmeFile     = 'README.txt';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadedFcn      = 'assignin(''base'', ''ISO2MESH_TEMP'', bst_get(''BrainstormTmpDir''));';
    PlugDesc(end).UnloadPlugs    =  {'easyh5','jsnirfy'};

    % === ANATOMY: NEUROMAPS ===
    PlugDesc(end+1)              = GetStruct('neuromaps');
    PlugDesc(end).Version        = 'github-main';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).AutoLoad       = 0;
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).URLzip         = 'https://github.com/thuy-n/bst-neuromaps/archive/refs/heads/main.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/thuy-n/bst-neuromaps';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).TestFile       = 'process_nmp_fetch_maps.m';
    
    % === ANATOMY: ROAST ===
    PlugDesc(end+1)              = GetStruct('roast');
    PlugDesc(end).Version        = '3.0';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://www.parralab.org/roast/roast-3.0.zip';
    PlugDesc(end).URLinfo        = 'https://www.parralab.org/roast/';
    PlugDesc(end).TestFile       = 'roast.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).UnloadPlugs    = {'spm12', 'iso2mesh'};
    PlugDesc(end).LoadFolders    = {'lib/spm12', 'lib/iso2mesh', 'lib/cvx', 'lib/ncs2daprox', 'lib/NIFTI_20110921'};

    % === ANATOMY: ZEFFIRO ===
    PlugDesc(end+1)              = GetStruct('zeffiro');
    PlugDesc(end).Version        = 'github-main_development_branch';
    PlugDesc(end).Category       = 'Anatomy';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://github.com/sampsapursiainen/zeffiro_interface/archive/main_development_branch.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/sampsapursiainen/zeffiro_interface';
    PlugDesc(end).TestFile       = 'zeffiro_downloader.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).DeleteFiles    = {'.gitignore'};


    % === FORWARD: OPENMEEG ===
    PlugDesc(end+1)              = GetStruct('openmeeg');
    PlugDesc(end).Version        = '2.4.1';
    PlugDesc(end).Category       = 'Forward';
    PlugDesc(end).AutoUpdate     = 1;
    switch(OsType)
        case 'linux64'
            PlugDesc(end).URLzip   = 'https://files.inria.fr/OpenMEEG/download/OpenMEEG-2.4.1-Linux.tar.gz';
            PlugDesc(end).TestFile = 'libOpenMEEG.so';
        case 'mac64'
            PlugDesc(end).URLzip   = 'https://files.inria.fr/OpenMEEG/download/OpenMEEG-2.4.1-MacOSX.tar.gz';
            PlugDesc(end).TestFile = 'libOpenMEEG.1.1.0.dylib';
        case 'mac64arm'
            PlugDesc(end).Version  = '2.5.8';
            PlugDesc(end).URLzip   = ['https://github.com/openmeeg/openmeeg/releases/download/', PlugDesc(end).Version, '/OpenMEEG-', PlugDesc(end).Version, '-', 'macOS_M1.tar.gz'];
            PlugDesc(end).TestFile = 'libOpenMEEG.1.1.0.dylib';
        case 'win32'
            PlugDesc(end).URLzip   = 'https://files.inria.fr/OpenMEEG/download/release-2.2/OpenMEEG-2.2.0-win32-x86-cl-OpenMP-shared.tar.gz';
            PlugDesc(end).TestFile = 'om_assemble.exe';
        case 'win64'
            PlugDesc(end).URLzip   = 'https://files.inria.fr/OpenMEEG/download/OpenMEEG-2.4.1-Win64.tar.gz';
            PlugDesc(end).TestFile = 'om_assemble.exe';
    end
    PlugDesc(end).URLinfo        = 'https://openmeeg.github.io/';
    PlugDesc(end).ExtraMenus     = {'Alternate versions', 'web(''https://files.inria.fr/OpenMEEG/download/'', ''-browser'')'; ...
                                    'Download Visual C++', 'web(''http://www.microsoft.com/en-us/download/details.aspx?id=14632'', ''-browser'')'; ...
                                    'Online tutorial', 'web(''https://neuroimage.usc.edu/brainstorm/Tutorials/TutBem'', ''-browser'')'};
    PlugDesc(end).CompiledStatus = 1;
    PlugDesc(end).LoadFolders    = {'bin', 'lib'};
    
    % === FORWARD: DUNEURO ===
    PlugDesc(end+1)              = GetStruct('duneuro');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).Category       = 'Forward';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://neuroimage.usc.edu/bst/getupdate.php?d=bst_duneuro.zip';
    PlugDesc(end).URLinfo        = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Duneuro';
    PlugDesc(end).TestFile       = 'bst_duneuro_meeg_win64.exe';
    PlugDesc(end).CompiledStatus = 1;
    PlugDesc(end).LoadFolders    = {'bin'};
    
    % === INVERSE: BRAINENTROPY ===
    PlugDesc(end+1)              = GetStruct('brainentropy');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Inverse';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://github.com/multi-funkim/best-brainstorm/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutBEst';
    PlugDesc(end).TestFile       = 'process_inverse_mem.m';
    PlugDesc(end).AutoLoad       = 1;
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).GetVersionFcn  = @be_versions;
    PlugDesc(end).DeleteFiles    = {'docs', '.github'};
    
    % === I/O: ADI-SDK ===      ADInstrument SDK for reading LabChart files
    PlugDesc(end+1)              = GetStruct('adi-sdk');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    switch (OsType)
        case 'win64', PlugDesc(end).URLzip = 'https://github.com/JimHokanson/adinstruments_sdk_matlab/archive/master.zip';
    end
    PlugDesc(end).URLinfo        = 'https://github.com/JimHokanson/adinstruments_sdk_matlab';
    PlugDesc(end).TestFile       = 'adi.m';
    PlugDesc(end).CompiledStatus = 0;

    % === I/O: AXION ===
    PlugDesc(end+1)              = GetStruct('axion');
    PlugDesc(end).Version        = '1.0';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://neuroimage.usc.edu/bst/getupdate.php?d=AxionBioSystems.zip';
    PlugDesc(end).URLinfo        = 'https://www.axionbiosystems.com/products/software/neural-module';
    PlugDesc(end).TestFile       = 'AxisFile.m';
    % PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;

    % === I/O: BCI2000 ===
    PlugDesc(end+1)              = GetStruct('bci2000');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://bci2000.org/downloads/mex.zip';
    PlugDesc(end).URLinfo        = 'https://www.bci2000.org/mediawiki/index.php/User_Reference:Matlab_MEX_Files';
    PlugDesc(end).TestFile       = 'load_bcidat.m';
    PlugDesc(end).CompiledStatus = 0;

    % === I/O: BLACKROCK ===
    PlugDesc(end+1)              = GetStruct('blackrock');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/BlackrockMicrosystems/NPMK/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/BlackrockMicrosystems/NPMK/blob/master/NPMK/Users%20Guide.pdf';
    PlugDesc(end).TestFile       = 'openNSx.m';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).DeleteFiles    = {'NPMK/installNPMK.m', 'NPMK/Users Guide.pdf', 'NPMK/Versions.txt', ...
                                    'NPMK/@KTUEAImpedanceFile', 'NPMK/@KTNSPOnline', 'NPMK/@KTNEVComments', 'NPMK/@KTFigureAxis', 'NPMK/@KTFigure', 'NPMK/@KTUEAMapFile/.svn', ...
                                    'NPMK/openNSxSync.m', 'NPMK/NTrode Utilities', 'NPMK/NSx Utilities', 'NPMK/NEV Utilities', 'NPMK/LoadingEngines', ...
                                    'NPMK/Other tools/.svn', 'NPMK/Other tools/edgeDetect.m', 'NPMK/Other tools/kshuffle.m', 'NPMK/Other tools/openCCF.m', 'NPMK/Other tools/parseCCF.m', ...
                                    'NPMK/Other tools/periEventPlot.asv', 'NPMK/Other tools/periEventPlot.m', 'NPMK/Other tools/playSound.m', ...
                                    'NPMK/Dependent Functions/.svn', 'NPMK/Dependent Functions/.DS_Store', 'NPMK/Dependent Functions/bnsx.dat', 'NPMK/Dependent Functions/syncPatternDetectNEV.m', ...
                                    'NPMK/Dependent Functions/syncPatternDetectNSx.m', 'NPMK/Dependent Functions/syncPatternFinderNSx.m'};

    % === I/O: EASYH5 ===
    PlugDesc(end+1)              = GetStruct('easyh5');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/NeuroJSON/easyh5/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/NeuroJSON/easyh5';
    PlugDesc(end).TestFile       = 'loadh5.m';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).DeleteFiles    = {'examples'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).UnloadPlugs    = {'iso2mesh'};

    % === I/O: JSNIRFY ===
    PlugDesc(end+1)              = GetStruct('jsnirfy');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/NeuroJSON/jsnirfy/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/NeuroJSON/jsnirfy';
    PlugDesc(end).TestFile       = 'loadsnirf.m';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).DeleteFiles    = {'external', '.gitmodules'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).RequiredPlugs  = {'easyh5'; 'jsonlab'};
    PlugDesc(end).UnloadPlugs    = {'iso2mesh'};

    % === I/O: JSONLab ===
    PlugDesc(end+1)              = GetStruct('jsonlab');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/NeuroJSON/jsonlab/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://neurojson.org/jsonlab';
    PlugDesc(end).TestFile       = 'savejson.m';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).DeleteFiles    = {'examples', 'images', 'test', '.github', '.gitignore'};
    PlugDesc(end).ReadmeFile     = 'README.rst';
    PlugDesc(end).UnloadPlugs    = {'iso2mesh'};

    % === I/O: MFF ===
    PlugDesc(end+1)              = GetStruct('mff');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'https://github.com/arnodelorme/mffmatlabio/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/arnodelorme/mffmatlabio';
    PlugDesc(end).TestFile       = 'eegplugin_mffmatlabio.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).MinMatlabVer   = 803;   % 2014a
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadedFcn      = @Configure;
    % Stable version: https://neuroimage.usc.edu/bst/getupdate.php?d='mffmatlabio-3.5.zip'
    
    % === I/O: NEUROELECTRICS ===
    PlugDesc(end+1)              = GetStruct('neuroelectrics');
    PlugDesc(end).Version        = '1.8';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'https://sccn.ucsd.edu/eeglab/plugins/Neuroelectrics1.8.zip';
    PlugDesc(end).URLinfo        = 'https://www.neuroelectrics.com/wiki/index.php/EEGLAB';
    PlugDesc(end).TestFile       = 'pop_nedf.m';
    PlugDesc(end).ReadmeFile     = 'README.txt';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).InstalledFcn   = ['d=pwd; cd(fileparts(which(''pop_nedf''))); mkdir(''private''); ' ...
                                    'f=fopen(''private' filesep 'eeg_emptyset.m'',''wt''); fprintf(f,''function EEG=eeg_emptyset()\nEEG=struct();''); fclose(f);' ...
                                    'f=fopen(''private' filesep 'eeg_checkset.m'',''wt''); fprintf(f,''function EEG=eeg_checkset(EEG)''); fclose(f);' ...
                                    'cd(d);'];

    % === I/O: npy-matlab ===
    PlugDesc(end+1)              = GetStruct('npy-matlab');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/kwikteam/npy-matlab/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/kwikteam/npy-matlab';
    PlugDesc(end).TestFile       = 'constructNPYheader.m';
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;

    % === I/O: NWB ===
    PlugDesc(end+1)              = GetStruct('nwb');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/NeurodataWithoutBorders/matnwb/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/NeurodataWithoutBorders/matnwb';
    PlugDesc(end).TestFile       = 'nwbRead.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).MinMatlabVer   = 901;   % 2016b
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).LoadedFcn      = @Configure;

    % === I/O: PLEXON ===
    PlugDesc(end+1)              = GetStruct('plexon');
    PlugDesc(end).Version        = '1.8.4';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://plexon-prod.s3.amazonaws.com/wp-content/uploads/2017/08/OmniPlex-and-MAP-Offline-SDK-Bundle_0.zip';
    PlugDesc(end).URLinfo        = 'https://plexon.com/software-downloads/#software-downloads-SDKs';
    PlugDesc(end).TestFile       = 'plx_info.m';
    PlugDesc(end).ReadmeFile     = 'Change Log.txt';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).DownloadedFcn  = ['d = fullfile(PlugDesc.Path, ''OmniPlex and MAP Offline SDK Bundle'');' ...
                                    'unzip(fullfile(d, ''Matlab Offline Files SDK.zip''), PlugDesc.Path);' ...
                                    'file_delete(d,1,3);'];
    PlugDesc(end).InstalledFcn   = ['if (exist(''mexPlex'', ''file'') ~= 3), d = pwd;'  ...
                                    'cd(fullfile(fileparts(which(''plx_info'')), ''mexPlex''));', ...
                                    'build_and_verify_mexPlex; cd(d); end'];

    % === I/O: PLOTLY ===
    PlugDesc(end+1)              = GetStruct('plotly');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://github.com/plotly/plotly_matlab/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://plotly.com/matlab/';
    PlugDesc(end).TestFile       = 'plotlysetup_online.m';
    PlugDesc(end).ReadmeFile     = 'README.mkdn';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).ExtraMenus     = {'Online tutorial', 'web(''https://neuroimage.usc.edu/brainstorm/Tutorials/Plotly'', ''-browser'')'};
                               
    % === I/O: TDT-SDK ===      Tucker-Davis Technologies Matlab SDK
    PlugDesc(end+1)              = GetStruct('tdt-sdk');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).URLzip         = 'https://www.tdt.com/files/examples/TDTMatlabSDK.zip';
    PlugDesc(end).URLinfo        = 'https://www.tdt.com/support/matlab-sdk/';
    PlugDesc(end).TestFile       = 'TDT_Matlab_Tools.pdf';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    
    % === I/O: XDF ===
    PlugDesc(end+1)              = GetStruct('xdf');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'I/O';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'https://github.com/xdf-modules/xdf-Matlab/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/xdf-modules/xdf-Matlab';
    PlugDesc(end).TestFile       = 'load_xdf.m';
    PlugDesc(end).ReadmeFile     = 'readme.md';
    PlugDesc(end).CompiledStatus = 2;

    % === SIMULATION: SIMMEEG ===
    PlugDesc(end+1)              = GetStruct('simmeeg');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Simulation';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://github.com/branelab/SimMEEG/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://audiospeech.ubc.ca/research/brane/brane-lab-software/';
    PlugDesc(end).TestFile       = 'SimMEEG_GUI.m';
    PlugDesc(end).ReadmeFile     = 'SIMMEEG_TERMS_OF_USE.txt';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).RequiredPlugs  = {'fieldtrip', '20200911'};
    

    % === STATISTICS: FASTICA ===
    PlugDesc(end+1)              = GetStruct('fastica');
    PlugDesc(end).Version        = '2.5';
    PlugDesc(end).Category       = 'Statistics';
    PlugDesc(end).URLzip         = 'https://research.ics.aalto.fi/ica/fastica/code/FastICA_2.5.zip';
    PlugDesc(end).URLinfo        = 'https://research.ics.aalto.fi/ica/fastica/';
    PlugDesc(end).TestFile       = 'fastica.m';
    PlugDesc(end).ReadmeFile     = 'Contents.m';
    PlugDesc(end).CompiledStatus = 2;

    % === STATISTICS: LIBSVM ===
    PlugDesc(end+1)              = GetStruct('libsvm');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Statistics';
    PlugDesc(end).URLzip         = 'https://github.com/cjlin1/libsvm/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://www.csie.ntu.edu.tw/~cjlin/libsvm/';
    PlugDesc(end).TestFile       = 'svm.cpp';
    PlugDesc(end).ReadmeFile     = 'README';
    PlugDesc(end).MinMatlabVer   = 803;   % 2014a
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).InstalledFcn   = 'd=pwd; cd(fileparts(which(''make''))); make; cd(d);';

    % === STATISTICS: mTRF ===
    PlugDesc(end+1)              = GetStruct('mtrf');
    PlugDesc(end).Version        = '2.4';
    PlugDesc(end).Category       = 'Statistics';
    PlugDesc(end).URLzip         = 'https://github.com/mickcrosse/mTRF-Toolbox/archive/refs/tags/v2.4.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/mickcrosse/mTRF-Toolbox';
    PlugDesc(end).TestFile       = 'mTRFtrain.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'mtrf'};
    PlugDesc(end).DeleteFiles    = {'.gitattributes', '.github/ISSUE_TEMPLATE', 'data', 'doc', 'examples', 'img'};

    % === STATISTICS: PICARD ===
    PlugDesc(end+1)              = GetStruct('picard');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'Statistics';
    PlugDesc(end).URLzip         = 'https://github.com/pierreablin/picard/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/pierreablin/picard';
    PlugDesc(end).TestFile       = 'picard.m';
    PlugDesc(end).ReadmeFile     = 'README.rst';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'matlab_octave'};

    % === ELECTROPHYSIOLOGY: DERIVELFP ===
    PlugDesc(end+1)              = GetStruct('derivelfp');
    PlugDesc(end).Version        = '1.0';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'http://packlab.mcgill.ca/despikingtoolbox.zip';
    PlugDesc(end).URLinfo        = 'https://journals.physiology.org/doi/full/10.1152/jn.00642.2010';
    PlugDesc(end).TestFile       = 'despikeLFP.m';
    PlugDesc(end).ReadmeFile     = 'readme.txt';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'toolbox'};
    PlugDesc(end).DeleteFiles    = {'ExampleDespiking.m', 'appendixpaper.pdf', 'downsample2x.m', 'examplelfpdespiking.mat', 'sta.m', ...
                                    'toolbox/delineSignal.m', 'toolbox/despikeLFPbyChunks.asv', 'toolbox/despikeLFPbyChunks.m'};
                                
    % === ELECTROPHYSIOLOGY: Kilosort ===
    PlugDesc(end+1)              = GetStruct('kilosort');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).URLzip         = 'https://github.com/cortex-lab/KiloSort/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://papers.nips.cc/paper/2016/hash/1145a30ff80745b56fb0cecf65305017-Abstract.html';
    PlugDesc(end).TestFile       = 'fitTemplates.m';
    PlugDesc(end).ReadmeFile     = 'readme.md';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).RequiredPlugs  = {'kilosort-wrapper'; 'phy'; 'npy-matlab'};
    PlugDesc(end).InstalledFcn   = 'process_spikesorting_kilosort(''copyKilosortConfig'', bst_fullfile(bst_get(''UserPluginsDir''), ''kilosort'', ''KiloSort-master'', ''configFiles'', ''StandardConfig_MOVEME.m''), bst_fullfile(bst_get(''UserPluginsDir''), ''kilosort'', ''KiloSort-master'', ''KilosortStandardConfig.m''));';

    
    % === ELECTROPHYSIOLOGY: Kilosort Wrapper ===
    PlugDesc(end+1)              = GetStruct('kilosort-wrapper');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).URLzip         = 'https://github.com/brendonw1/KilosortWrapper/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://zenodo.org/record/3604165';
    PlugDesc(end).TestFile       = 'Kilosort2Neurosuite.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    
    % === ELECTROPHYSIOLOGY: phy ===
    PlugDesc(end+1)              = GetStruct('phy');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).URLzip         = 'https://github.com/cortex-lab/phy/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://phy.readthedocs.io/en/latest/';
    PlugDesc(end).TestFile       = 'feature_view_custom_grid.py';
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).RequiredPlugs  = {'npy-matlab'};
    
    % === ELECTROPHYSIOLOGY: ultramegasort2000 ===
    PlugDesc(end+1)              = GetStruct('ultramegasort2000');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).URLzip         = 'https://github.com/danamics/UMS2K/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/danamics/UMS2K/blob/master/UltraMegaSort2000%20Manual.pdf';
    PlugDesc(end).TestFile       = 'UltraMegaSort2000 Manual.pdf';
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;
    
    % === ELECTROPHYSIOLOGY: waveclus ===
    PlugDesc(end+1)              = GetStruct('waveclus');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'e-phys';
    PlugDesc(end).URLzip         = 'https://github.com/csn-le/wave_clus/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'https://journals.physiology.org/doi/full/10.1152/jn.00339.2018';
    PlugDesc(end).TestFile       = 'wave_clus.m';
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 0;

    % === fNIRS: NIRSTORM ===
    PlugDesc(end+1)              = GetStruct('nirstorm');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'fNIRS';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).AutoLoad       = 1;
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).URLzip         = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';
    PlugDesc(end).URLinfo        = 'https://github.com/Nirstorm/nirstorm';
    PlugDesc(end).LoadFolders    = {'bst_plugin/core','bst_plugin/forward','bst_plugin/GLM', 'bst_plugin/inverse' , 'bst_plugin/io','bst_plugin/math' ,'bst_plugin/mbll' ,'bst_plugin/misc', 'bst_plugin/OM', 'bst_plugin/preprocessing', 'bst_plugin/ppl'};
    PlugDesc(end).TestFile       = 'process_nst_mbll.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).GetVersionFcn  = 'nst_get_version';
    PlugDesc(end).RequiredPlugs  = {'brainentropy'};
    PlugDesc(end).MinMatlabVer   = 803;   % 2014a
    PlugDesc(end).DeleteFiles    = {'scripts', 'test', 'run_tests.m', 'test_suite_bak.m', '.gitignore'};
    
    % === fNIRS: MCXLAB CUDA ===
    PlugDesc(end+1)              = GetStruct('mcxlab-cuda');
    PlugDesc(end).Version        = '2024.07.23';
    PlugDesc(end).Category       = 'fNIRS';
    PlugDesc(end).AutoUpdate     = 1;
    PlugDesc(end).URLzip         = 'https://mcx.space/nightly/release/git20240723/mcxlab-allinone-git20240723.zip';
    PlugDesc(end).TestFile       = 'mcxlab.m';
    PlugDesc(end).URLinfo        = 'https://mcx.space/wiki/';
    PlugDesc(end).CompiledStatus = 0;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).UnloadPlugs    = {'mcxlab-cl'};

    % === fNIRS: MCXLAB CL ===
    PlugDesc(end+1)              = GetStruct('mcxlab-cl');
    PlugDesc(end).Version        = '2024.07.23';
    PlugDesc(end).Category       = 'fNIRS';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'https://mcx.space/nightly/release/git20240723/mcxlabcl-allinone-git20240723.zip';
    PlugDesc(end).TestFile       = 'mcxlabcl.m';
    PlugDesc(end).URLinfo        = 'https://mcx.space/wiki/';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).UnloadPlugs    = {'mcxlab-cuda'};

    % === sEEG: MIA ===
    PlugDesc(end+1)              = GetStruct('mia');
    PlugDesc(end).Version        = 'github-master';
    PlugDesc(end).Category       = 'sEEG';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).AutoLoad       = 1;
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).URLzip         = 'https://github.com/MIA-iEEG/mia/archive/refs/heads/master.zip';
    PlugDesc(end).URLinfo        = 'http://www.neurotrack.fr/mia/';
    PlugDesc(end).ReadmeFile     = 'README.md'; 
    PlugDesc(end).MinMatlabVer   = 803;   % 2014a
    PlugDesc(end).LoadFolders    = {'*'};
    PlugDesc(end).TestFile       = 'process_mia_export_db.m';
    PlugDesc(end).ExtraMenus     = {'Start MIA', 'mia', 'loaded'};
    
    % === FIELDTRIP ===
    PlugDesc(end+1)              = GetStruct('fieldtrip');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).AutoUpdate     = 0;
    PlugDesc(end).URLzip         = 'https://download.fieldtriptoolbox.org/fieldtrip-lite-20240405.zip';
    PlugDesc(end).URLinfo        = 'http://www.fieldtriptoolbox.org';
    PlugDesc(end).TestFile       = 'ft_defaults.m';
    PlugDesc(end).ReadmeFile     = 'README';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).UnloadPlugs    = {'spm12', 'roast'};
    PlugDesc(end).LoadFolders    = {'specest', 'preproc', 'forward', 'src', 'utilities'};
    PlugDesc(end).GetVersionFcn  = 'ft_version';
    PlugDesc(end).LoadedFcn      = ['global ft_default; ' ...
                                    'ft_default = []; ' ...
                                    'clear ft_defaults; ' ...
                                    'if exist(''filtfilt'', ''file''), ft_default.toolbox.signal=''matlab''; end; ' ...
                                    'if exist(''nansum'', ''file''), ft_default.toolbox.stats=''matlab''; end; ' ...
                                    'if exist(''rgb2hsv'', ''file''), ft_default.toolbox.images=''matlab''; end; ' ...
                                    'ft_defaults;'];
    
    % === SPM12 ===
    PlugDesc(end+1)              = GetStruct('spm12');
    PlugDesc(end).Version        = 'latest';
    PlugDesc(end).AutoUpdate     = 0;
    switch(OsType)
        case  'mac64arm'
            PlugDesc(end).URLzip         = 'https://github.com/spm/spm12/archive/refs/heads/maint.zip';
            PlugDesc(end).Version        = 'github-maint';
        otherwise
            PlugDesc(end).Version        = 'latest';
            PlugDesc(end).URLzip         = 'https://www.fil.ion.ucl.ac.uk/spm/download/restricted/eldorado/spm12.zip';
    end
    PlugDesc(end).URLinfo        = 'https://www.fil.ion.ucl.ac.uk/spm/';
    PlugDesc(end).TestFile       = 'spm.m';
    PlugDesc(end).ReadmeFile     = 'README.md';
    PlugDesc(end).CompiledStatus = 2;
    PlugDesc(end).UnloadPlugs    = {'fieldtrip', 'roast'};
    PlugDesc(end).LoadFolders    = {'matlabbatch'};
    PlugDesc(end).GetVersionFcn  = 'bst_getoutvar(2, @spm, ''Ver'')';
    PlugDesc(end).LoadedFcn      = 'spm(''defaults'',''EEG'');';

    % === USER DEFINED PLUGINS ===
    plugJsonFiles    = dir(fullfile(bst_get('UserPluginsDir'), 'plugin_*.json'));
    badJsonFiles     = {};
    plugUserDefNames = {};
    for ix = 1:length(plugJsonFiles)
        plugJsonText = fileread(fullfile(plugJsonFiles(ix).folder, plugJsonFiles(ix).name));
        try
            PlugUserDesc = bst_jsondecode(plugJsonText);
        catch
            badJsonFiles{end+1} = plugJsonFiles(ix).name;
            continue
        end
        % Reshape fields "ExtraMenus"
        if isfield(PlugUserDesc, 'ExtraMenus') && ~isempty(PlugUserDesc.ExtraMenus) && iscell(PlugUserDesc.ExtraMenus{1})
            PlugUserDesc.ExtraMenus = cat(2, PlugUserDesc.ExtraMenus{:})';
        end
        % Reshape fields "RequiredPlugs"
        if isfield(PlugUserDesc, 'RequiredPlugs') && ~isempty(PlugUserDesc.RequiredPlugs) && iscell(PlugUserDesc.RequiredPlugs{1})
            PlugUserDesc.RequiredPlugs = cat(2, PlugUserDesc.RequiredPlugs{:})';
        end
        % Check for uniqueness for user-defined plugin
        if ~ismember(PlugUserDesc.Name, {PlugDesc.Name})
            plugUserDefNames{end+1} = PlugUserDesc.Name;
            PlugDesc(end+1) = struct_copy_fields(GetStruct(PlugUserDesc.Name), PlugUserDesc);
        end
    end
    % Print info on user-defined plugins
    if UserDefVerbose
        if ~isempty(plugUserDefNames)
            fprintf(['BST> User-defined plugins... ' strjoin(plugUserDefNames, ' ') '\n']);
        end
        for iBad = 1 : length(badJsonFiles)
            fprintf(['BST> User-defined plugins, error reading .json file... ' badJsonFiles{iBad} '\n']);
        end
    end

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


%% ===== PLUGIN STRUCT =====
function s = GetStruct(PlugName)
    s = db_template('PlugDesc');
    s.Name = PlugName;
end


%% ===== ADD USER DEFINED PLUGIN DESCRIPTION =====
function [isOk, errMsg] = AddUserDefDesc(RegMethod, jsonLocation)
    isOk    = 1; 
    errMsg     = '';
    isInteractive = strcmp(RegMethod, 'manual') || nargin < 2 || isempty(jsonLocation);

    % Get json file location from user
    if ismember(RegMethod, {'file', 'url'}) && isInteractive
        if strcmp(RegMethod, 'file')
            jsonLocation = java_getfile('open', 'Plugin description JSON file...', '', 'single', 'files', {{'.json'}, 'Brainstorm plugin description (*.json)', 'JSON'}, 1);
        elseif strcmp(RegMethod, 'url')
            jsonLocation = java_dialog('input', 'Enter the URL the plugin description file (.json)', 'Plugin description JSON file...', [], '');
        end
        if isempty(jsonLocation)
            return
        end
        res = java_dialog('question', ['Warning: This plugin has not been verified.' 10 ...
                                       'Malicious plugins can alter your database, proceed with caution and only install plugins from trusted sources.' 10 ...
                                       'If any unusual behavior occurs after installation, start by uninstalling the plugins.' 10 ...
                                       'Are you sure you want to proceed?'], ...
                          'Warning', [], {'yes', 'no'});
        if strcmp(res, 'no')
            return
        end
    end

    % Get plugin description
    switch RegMethod
        case 'file'
            jsonText = fileread(jsonLocation);
            try
                PlugDesc = bst_jsondecode(jsonText);
            catch
                errMsg = sprintf(['Could not parse JSON file:' 10 '%s'], jsonLocation);
            end

        case 'url'
            % Handle GitHub links, convert the link to load the raw content
            if strcmp(jsonLocation(1:4),'http') && strcmp(jsonLocation(end-4:end),'.json')
                if ~isempty(regexp(jsonLocation, '^http[s]*://github.com', 'once'))
                    jsonLocation = strrep(jsonLocation, 'github.com','raw.githubusercontent.com');
                    jsonLocation = strrep(jsonLocation, 'blob/', '');
                end
            end
            jsonText = bst_webread(jsonLocation);
            try
                PlugDesc = bst_jsondecode(jsonText);
            catch
                errMsg = sprintf(['Could not parse JSON file at:' 10 '%s'], jsonLocation);
            end

        case 'manual'
            % Get info for user-defined plugin description from user
            res = java_dialog('input', { ['<HTML>Provide the <B>mandatory</B> fields for a user defined Brainstorm plugin<BR>' ...
                                          'See this page for further details:<BR>' ...
                                          '<FONT COLOR="#0000FF">https://neuroimage.usc.edu/brainstorm/Tutorials/Plugins</FONT>' ...
                                          '<BR><BR>' ...
                                          'Plugin name<BR>' ...
                                          '<I><FONT color="#707070">EXAMPLE: bst-users</FONT></I>'], ...
                                         ['<HTML>Version<BR>' ...
                                          '<I><FONT color="#707070">EXAMPLE: github-main or 3.1.4</FONT></I>'], ...
                                         ['<HTML>URL for zip<BR>' ...
                                          '<I><FONT color="#707070">EXAMPLE: https://github.com/brainstorm-tools/bst-users/archive/refs/heads/master.zip</FONT></I>'], ...
                                         ['<HTML>URL for information<BR>' ...
                                          '<I><FONT color="#707070">EXAMPLE: https://github.com/brainstorm-tools/bst-users</FONT></I>']}, ...
                                       'User defined plugin', [], {'', '', '', ''});
            if isempty(res) || any(cellfun(@isempty,res))
                return
            end
            PlugDesc.Name    = lower(res{1});
            PlugDesc.Version = res{2};
            PlugDesc.URLzip  = res{3};
            PlugDesc.URLinfo = res{4};
    end
    if ~isempty(errMsg)
        bst_error(errMsg);
        isOk = 0;
        return;
    end

    % Validate retrieved plugin description
    if length(PlugDesc) > 1
        errMsg = 'JSON file should contain only one plugin description';
    elseif ~all(ismember({'Name', 'Version', 'URLzip', 'URLinfo'}, fieldnames(PlugDesc)))
        errMsg = 'Plugin description must contain the fields ''Name'', ''Version'', ''URLzip'' and ''URLinfo''';
    else
        PlugDesc.Name = lower(PlugDesc.Name);
        PlugDescs = GetSupported();
        if ismember(PlugDesc.Name, {PlugDescs.Name})
            errMsg = sprintf('Plugin ''%s'' already exist in Brainstorm', PlugDesc.Name);
        end
    end
    if ~isempty(errMsg)
        bst_error(errMsg);
        isOk = 0;
        return;
    end
    % Override category
    PlugDesc.Category = 'User defined';

    % Write validated JSON file
    pluginJsonFileOut = fullfile(bst_get('UserPluginsDir'), sprintf('plugin_%s.json', file_standardize(PlugDesc.Name)));
    fid = fopen(pluginJsonFileOut, 'wt');
    jsonText = bst_jsonencode(PlugDesc, 0);
    fprintf(fid, jsonText);
    fclose(fid);

    fprintf(1, 'BST> Plugin ''%s'' was added to ''User defined'' plugins\n', PlugDesc.Name);
end


%% ===== REMOVE USER DEFINED PLUGIN DESCRIPTION =====
function [isOk, errMsg] = RemoveUserDefDesc(PlugName)
    isOk   = 1;
    errMsg = '';
    if nargin < 1 || isempty(PlugName)
        PlugDescs = GetSupported();
        PlugDescs = PlugDescs(ismember({PlugDescs.Category}, 'User defined'));
        PlugName = java_dialog('combo', 'Indicate the name of the plugin to remove:', 'Remove plugin from ''User defined'' list', [], {PlugDescs.Name});
    end
    if isempty(PlugName)
        return
    end
    PlugDesc = GetSupported(PlugName);
    if ~isempty(PlugDesc.Path) || file_exist(bst_fullfile(bst_get('UserPluginsDir'), PlugDesc.Name))
        [isOk, errMsg] = Uninstall(PlugDesc.Name, 0);
    end
    % Delete json file
    if isOk
       isOk = file_delete(fullfile(bst_get('UserPluginsDir'), sprintf('plugin_%s.json', file_standardize(PlugDesc.Name))), 1);
    end

    fprintf(1, 'BST> Plugin ''%s'' was removed from ''User defined'' plugins\n', PlugDesc.Name);
end


%% ===== CONFIGURE PLUGIN =====
function Configure(PlugDesc)
    switch (PlugDesc.Name)
        case 'mff'
            % Add .jar file to static classpath
            if ~exist('com.egi.services.mff.api.MFFFactory', 'class')
                jarList = dir(bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'MFF-*.jar'));
                jarPath = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, jarList(1).name);
                disp(['BST> Adding to Java classpath: ' jarPath]);
                warning off
                javaaddpathstatic(jarPath);
                javaaddpath(jarPath);
                warning on
            end

        case 'nwb'
            % Add .jar file to static classpath
            if ~exist('Schema', 'class')
                jarPath = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'jar', 'schema.jar');
                disp(['BST> Adding to Java classpath: ' jarPath]);
                warning off
                javaaddpathstatic(jarPath);
                javaaddpath(jarPath);
                warning on
                schema = Schema();
            end
            % Go to NWB folder
            curDir = pwd;
            cd(bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder));
            % Generate the NWB Schema (must be executed from the NWB folder)
            generateCore();
            % Restore current directory
            cd(curDir);           
    end
end


%% ===== GET ONLINE VERSION =====
% Get the latest online version of some plugins
function [Version, URLzip] = GetVersionOnline(PlugName, URLzip, isCache)
    global GlobalData;
    Version = [];
    % Parse inputs
    if (nargin < 2) || isempty(URLzip)
        URLzip = [];
    end
    % Use cache by default, to avoid fetching online too many times the same info
    if (nargin < 3) || isempty(isCache)
        isCache = 1;
    end
    % No internet: skip
    if ~GlobalData.Program.isInternet
        return;
    end
    % Check for existing plugin cache
    strCache = [PlugName, '_online_', strrep(date,'-','')];
    if isCache && isfield(GlobalData.Program.PluginCache, strCache) && isfield(GlobalData.Program.PluginCache.(strCache), 'Version')
        Version = GlobalData.Program.PluginCache.(strCache).Version;
        URLzip = GlobalData.Program.PluginCache.(strCache).URLzip;
        return;
    end
    % Get version online
    try
        switch (PlugName)
            case 'spm12'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                s = bst_webread('http://www.fil.ion.ucl.ac.uk/spm/download/spm12_updates/');
                if ~isempty(s)
                    n = regexp(s,'spm12_updates_r(\d.*?)\.zip','tokens','once');
                    if ~isempty(n) && ~isempty(n{1})
                        Version = n{1};
                    end
                end
            case 'cat12'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                s = bst_webread('http://www.neuro.uni-jena.de/cat12/');
                if ~isempty(s)
                    n = regexp(s,'cat12_r(\d.*?)\.zip','tokens');
                    if ~isempty(n)
                        Version = max(cellfun(@str2double, [n{:}]));
                        Version = num2str(Version);
                    end
                end
            case 'fieldtrip'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                s = bst_webread('https://download.fieldtriptoolbox.org');
                if ~isempty(s)
                    n = regexp(s,'fieldtrip-lite-(\d.*?)\.zip','tokens');
                    if ~isempty(n)
                        Version = max(cellfun(@str2double, [n{:}]));
                        Version = num2str(Version);
                        URLzip = ['https://download.fieldtriptoolbox.org/fieldtrip-lite-' Version '.zip'];
                    end
                end
            case 'duneuro'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                str = bst_webread('https://neuroimage.usc.edu/bst/getversion_duneuro.php');
                Version = str(1:6);
           case 'nirstorm'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                str = bst_webread('https://raw.githubusercontent.com/Nirstorm/nirstorm/master/bst_plugin/VERSION');
                Version = strtrim(str(9:end));
            case 'brainentropy'
                bst_progress('text', ['Checking latest online version for ' PlugName '...']);
                disp(['BST> Checking latest online version for ' PlugName '...']);
                str = bst_webread('https://raw.githubusercontent.com/multifunkim/best-brainstorm/master/best/VERSION.txt');
                str = strsplit(str,'\n');
                Version = strtrim(str{1});
            otherwise
                % If downloading from github: Get last GitHub commit SHA
                if isGithubMaster(URLzip)
                    Version = GetGithubCommit(URLzip);
                else
                    return;
                end
        end
        % Executed only if the version was fetched successfully: Keep cached version
        GlobalData.Program.PluginCache.(strCache).Version = Version;
        GlobalData.Program.PluginCache.(strCache).URLzip = URLzip;
    catch
        disp(['BST> Error: Could not get online version for plugin: ' PlugName]);
    end
end


%% ===== IS GITHUB MASTER ======
% Returns 1 if the URL is a github master/main branch
function isMaster = isGithubMaster(URLzip)
    isMaster = ~isempty(strfind(URLzip, 'https://github.com/')) && (~isempty(strfind(URLzip, 'master.zip')) || ~isempty(strfind(URLzip, 'main.zip')));
end


%% ===== GET GITHUB COMMIT =====
% Get SHA of the GitHub HEAD commit
function sha = GetGithubCommit(URLzip)
    zipUri = matlab.net.URI(URLzip);
    % Primary branch name: master or main
    [~, primaryBranch] = bst_fileparts(char(zipUri.Path(end)));
    % Default result
    sha = ['github-', primaryBranch];
    % Only available after Matlab 2016b (because of matlab.net.http.RequestMessage)
    if (bst_get('MatlabVersion') < 901)
        return;
    end
    % Try getting the SHA from the GitHub API
    try
        % Get GitHub repository path
        zipUri = matlab.net.URI(URLzip);
        gitUser = char(zipUri.Path(2));
        gitRepo = char(zipUri.Path(3));
        % Request last commit SHA with GitHub API
        apiUri = matlab.net.URI(['https://api.github.com/repos/' gitUser '/' gitRepo '/commits/' primaryBranch]);
        request = matlab.net.http.RequestMessage;
        request = request.addFields(matlab.net.http.HeaderField('Accept', 'application/vnd.github.VERSION.sha'));
        r = send(request, apiUri);
        sha = char(r.Body.Data);
    catch
        disp(['BST> Warning: Could not get GitHub version for URL: ' zipUrl]);
    end
end


%% ===== COMPARE VERSIONS =====
% Returns:  0: v1==v2
%          -1: v1<v2
%           1: v1>v2
function res = CompareVersions(v1, v2)
    % Get numbers 
    iNum1 = find(ismember(v1, '0123456789'));
    iNum2 = find(ismember(v2, '0123456789'));
    iDot1 = find(v1 == '.');
    iDot2 = find(v2 == '.');
    % Equality (or one input empty)
    if isequal(v1,v2) || isempty(v1) || isempty(v2)
        res = 0;
    % Only numbers
    elseif (length(iNum1) == length(v1)) && (length(iNum2) == length(v2))
        n1 = str2double(v1);
        n2 = str2double(v2);
        if (n1 > n2)
            res = 1;
        elseif (n1 < n2)
            res = -1;
        else
            res = 0;
        end
    % Format '1.2.3'
    elseif (~isempty(iDot1) || ~isempty(iDot2)) && ~isempty(iNum1) && ~isempty(iNum2)
        % Get subversions 1
        split1 = str_split(v1, '.');
        sub1 = [];
        for i = 1:length(split1)
            t = str2num(split1{i}(ismember(split1{i},'0123456789')));
            if ~isempty(t)
                sub1(end+1) = t;
            else
                break;
            end
        end
        % Get subversions 1
        split2 = str_split(v2, '.');
        sub2 = [];
        for i = 1:length(split2)
            t = str2num(split2{i}(ismember(split2{i},'0123456789')));
            if ~isempty(t)
                sub2(end+1) = t;
            else
                break;
            end
        end
        % Add extra zeros to the shortest (so that "1.2" is higher than "1")
        if (length(sub1) < length(sub2))
            tmp = sub1;
            sub1 = zeros(size(sub2));
            sub1(1:length(tmp)) = tmp;
        elseif (length(sub1) > length(sub2))
            tmp = sub2;
            sub2 = zeros(size(sub1));
            sub2(1:length(tmp)) = tmp;
        end
        % Compare number by number
        for i = 1:length(sub1)
            if (sub1(i) > sub2(i))
                res = 1;
                return;
            elseif (sub1(i) < sub2(i))
                res = -1;
                return;
            else
                res = 0;
            end
        end
    % Mixture of numbers and digits: natural sorting of strings
    else
        [s,I] = sort_nat({v1, v2});
        if (I(1) == 1)
            res = -1;
        else
            res = 1;
        end  
    end
end


%% ===== EXECUTE CALLBACK =====
function [isOk, errMsg] = ExecuteCallback(PlugDesc, f)
    isOk = 0;
    errMsg = '';
    if ~isempty(PlugDesc.(f))
        try
            if ischar(PlugDesc.(f))
                disp(['BST> Executing callback ' f ': ' PlugDesc.(f)]);
                eval(PlugDesc.(f));
            elseif isa(PlugDesc.(f), 'function_handle')
                disp(['BST> Executing callback ' f ': ' func2str(PlugDesc.(f))]);
                feval(PlugDesc.(f), PlugDesc);
            end
        catch
            errMsg = ['Error executing callback ' f ': ' 10 lasterr];
            return;
        end
    end
    isOk = 1;
end


%% ===== GET INSTALLED PLUGINS =====
% USAGE:  [PlugDesc, SearchPlugs] = bst_plugin('GetInstalled', PlugName/PlugDesc)  % Get one installed plugin
%         [PlugDesc, SearchPlugs] = bst_plugin('GetInstalled')                     % Get all installed plugins
function [PlugDesc, SearchPlugs] = GetInstalled(SelPlug)
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
    UserPluginsDir = bst_get('UserPluginsDir');
    % Custom plugin paths
    PluginCustomPath = bst_get('PluginCustomPath');
    % Matlab path
    matlabPath = str_split(path, pathsep);
    % Compiled distribution
    isCompiled = bst_iscompiled();
    
    % === LOOK FOR SUPPORTED PLUGINS ===
    % Empty plugin structure
    PlugDesc = repmat(db_template('PlugDesc'), 0);
    % Look for each plugin in the search list
    for iSearch = 1:length(SearchPlugs)
        % Compiled: skip plugins that are not available
        if isCompiled && (SearchPlugs(iSearch).CompiledStatus == 0)
            continue;
        end
        % Theoretical plugin path
        PlugName = SearchPlugs(iSearch).Name;
        PlugPath = bst_fullfile(UserPluginsDir, PlugName);
        % Check if test function is available in the Matlab path
        TestFilePath = GetTestFilePath(SearchPlugs(iSearch));
        % If installed software found in Matlab path
        if ~isempty(TestFilePath)
            % Register loaded plugin
            iPlug = length(PlugDesc) + 1;
            PlugDesc(iPlug) = SearchPlugs(iSearch);
            PlugDesc(iPlug).isLoaded = 1;
            % Check if the file is inside the Brainstorm user folder (where it is supposed to be) => Managed plugin
            if ~isempty(strfind(TestFilePath, PlugPath))
                PlugDesc(iPlug).isManaged = 1;
            % Process compiled together with Brainstorm
            elseif isCompiled && ~isempty(strfind(TestFilePath, ['.brainstorm' filesep 'plugins' filesep PlugName]))
                compiledDir = ['.brainstorm' filesep 'plugins' filesep PlugName];
                iPath = strfind(TestFilePath, compiledDir);
                PlugPath = [TestFilePath(1:iPath-2), filesep, compiledDir];
            % Otherwise: Custom installation
            else
                % If the test file was found in a defined subfolder: remove the subfolder from the plugin path
                PlugPath = TestFilePath;
                for iSub = 1:length(PlugDesc(iPlug).LoadFolders)
                    subDir = strrep(PlugDesc(iPlug).LoadFolders{iSub}, '/', filesep);
                    if (length(PlugPath) > length(subDir)) && isequal(PlugPath(end-length(subDir)+1:end), subDir)
                    	PlugPath = PlugPath(1:end - length(subDir) - 1);
                        break;
                    end
                end
                PlugDesc(iPlug).isManaged = 0;
            end
            PlugDesc(iPlug).Path = PlugPath;
        % Plugin installed: Managed by Brainstorm
        elseif isdir(PlugPath) && file_exist(bst_fullfile(PlugPath, 'plugin.mat'))
            iPlug = length(PlugDesc) + 1;
            PlugDesc(iPlug) = SearchPlugs(iSearch);
            PlugDesc(iPlug).Path = PlugPath;
            PlugDesc(iPlug).isLoaded = 0;
            PlugDesc(iPlug).isManaged = 1;
        % Plugin installed: Custom path
        elseif isfield(PluginCustomPath, PlugName) && ~isempty(PluginCustomPath.(PlugName)) && file_exist(PluginCustomPath.(PlugName))
            iPlug = length(PlugDesc) + 1;
            PlugDesc(iPlug) = SearchPlugs(iSearch);
            PlugDesc(iPlug).Path = PluginCustomPath.(PlugName);
            PlugDesc(iPlug).isLoaded = 0;
            PlugDesc(iPlug).isManaged = 0;
        end
    end
    
    % === LOOK FOR UNREFERENCED PLUGINS ===
    % Compiled: do not look for unreferenced plugins
    if isCompiled
        PlugList = [];
    % Get a specific unlisted plugin
    elseif ~isempty(SelPlug)
        % Get plugin name
        if ischar(SelPlug)
            PlugName = lower(SelPlug);
        else
            PlugName = SelPlug.Name;
        end
        % If plugin is already referenced: skip
        if ismember(PlugName, {PlugDesc.Name})
            PlugList = [];
        % Else: Try to get target plugin as unreferenced
        else
            PlugList = struct('name', PlugName);
        end
    % Get all folders in Brainstorm plugins folder
    else
        PlugList = dir(UserPluginsDir);
    end
    % Process folders containing a plugin.mat file
    for iDir = 1:length(PlugList)
        % Ignore entry if plugin name is already in list of documented plugins
        PlugName = PlugList(iDir).name;
        if ismember(PlugName, {PlugDesc.Name})
            continue;
        end
        % Process only folders
        PlugDir = bst_fullfile(UserPluginsDir, PlugName);
        if ~isdir(PlugDir) || (PlugName(1) == '.')
            continue;
        end
        % Process only folders containing a 'plugin.mat' file
        PlugMatFile = bst_fullfile(PlugDir, 'plugin.mat');
        if ~file_exist(PlugMatFile)
            continue;
        end
        % If selecting only one plugin
        if ~isempty(SelPlug) && ischar(SelPlug) && ~strcmpi(PlugName, SelPlug)
            continue;
        end
        % Add plugin to list
        iPlug = length(PlugDesc) + 1;
        PlugDesc(iPlug)           = GetStruct(PlugList(iDir).name);
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
            excludedFields = {'Name', 'Path', 'isLoaded', 'isManaged', 'LoadedFcn', 'UnloadedFcn', 'DownloadedFcn', 'InstalledFcn', 'UninstalledFcn'};
            loadFields = setdiff(fieldnames(db_template('PlugDesc')), excludedFields);
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


%% ===== GET TEST FILE PATH =====
function TestFilePath = GetTestFilePath(PlugDesc)
    % If a test file is defined
    if ~isempty(PlugDesc.TestFile)
        % Try to find the test function in the path
        whichTest = which(PlugDesc.TestFile);
        % If it was found: use the parent folder
        if ~isempty(whichTest)
            % Get the test file path
            TestFilePath = bst_fileparts(whichTest);
            % FieldTrip: Ignore if found embedded in SPM12
            if strcmpi(PlugDesc.Name, 'fieldtrip')
                p = which('spm.m');
                if ~isempty(p) && ~isempty(strfind(TestFilePath, bst_fileparts(p)))
                    TestFilePath = [];
                end
            % SPM12: Ignore if found embedded in ROAST or in FieldTrip
            elseif strcmpi(PlugDesc.Name, 'spm12')
                p = which('roast.m');
                q = which('ft_defaults.m');
                if (~isempty(p) && ~isempty(strfind(TestFilePath, bst_fileparts(p)))) || (~isempty(q) && ~isempty(strfind(TestFilePath, bst_fileparts(q))))
                    TestFilePath = [];
                end
            % Iso2mesh: Ignore if found embedded in ROAST
            elseif strcmpi(PlugDesc.Name, 'iso2mesh')
                p = which('roast.m');
                if ~isempty(p) && ~isempty(strfind(TestFilePath, bst_fileparts(p)))
                    TestFilePath = [];
                end
            % jsonlab and jsnirfy: Ignore if found embedded in iso2mesh
            elseif strcmpi(PlugDesc.Name, 'jsonlab') || strcmpi(PlugDesc.Name, 'jsnirfy')
                p = which('iso2meshver.m');
                if ~isempty(p) && ~isempty(strfind(TestFilePath, bst_fileparts(p)))
                    TestFilePath = [];
                end
            % easyh5: Ignore if found embedded in iso2mesh or jsonlab
            elseif strcmpi(PlugDesc.Name, 'easyh5')
                p = which('iso2meshver.m');
                q = which('savejson.m');
                if (~isempty(p) && ~isempty(strfind(TestFilePath, bst_fileparts(p)))) || (~isempty(q) && ~isempty(strfind(TestFilePath, bst_fileparts(q))))
                    TestFilePath = [];
                end
            end
        else
            TestFilePath = [];
        end
    else
        TestFilePath = [];
    end
end


%% ===== GET README FILE ====
% Get full path to the readme file
function ReadmeFile = GetReadmeFile(PlugDesc)
    ReadmeFile = [];
    % If readme file is defined in the plugin structure
    if ~isempty(PlugDesc.ReadmeFile)
        % If full path already set: use it
        if file_exist(PlugDesc.ReadmeFile)
            ReadmeFile = PlugDesc.ReadmeFile;
        % Else: check in the plugin Path/SubFolder
        else
            tmpFile = bst_fullfile(PlugDesc.Path, PlugDesc.ReadmeFile);
            if file_exist(tmpFile)
                ReadmeFile = tmpFile;
            elseif ~isempty(PlugDesc.SubFolder)
                tmpFile = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, PlugDesc.ReadmeFile);
                if file_exist(tmpFile)
                    ReadmeFile = tmpFile;
                end
            end
        end
    end
    % Search for default readme
    if isempty(ReadmeFile)
        tmpFile = bst_fullfile(bst_get('BrainstormDocDir'), 'plugins', [PlugDesc.Name '_readme.txt']);
        if file_exist(tmpFile)
            ReadmeFile = tmpFile;
        end
    end
end


%% ===== GET LOGO FILE ====
% Get full path to the logo file
function LogoFile = GetLogoFile(PlugDesc)
    LogoFile = [];
    % If logo file is defined in the plugin structure
    if ~isempty(PlugDesc.LogoFile)
        % If full path already set: use it
        if file_exist(PlugDesc.LogoFile)
            LogoFile = PlugDesc.LogoFile;
        % Else: check in the plugin Path/SubFolder
        else
            tmpFile = bst_fullfile(PlugDesc.Path, PlugDesc.LogoFile);
            if file_exist(tmpFile)
                LogoFile = tmpFile;
            elseif ~isempty(PlugDesc.SubFolder)
                tmpFile = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, PlugDesc.LogoFile);
                if file_exist(tmpFile)
                    LogoFile = tmpFile;
                end
            end
        end
    end
    % Search for default logo
    if isempty(LogoFile)
        tmpFile = bst_fullfile(bst_get('BrainstormDocDir'), 'plugins', [PlugDesc.Name '_logo.gif']);
        if file_exist(tmpFile)
            LogoFile = tmpFile;
        end
    end
    if isempty(LogoFile)
        tmpFile = bst_fullfile(bst_get('BrainstormDocDir'), 'plugins', [PlugDesc.Name '_logo.png']);
        if file_exist(tmpFile)
            LogoFile = tmpFile;
        end
    end
end


%% ===== INSTALL =====
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('Install', PlugName, isInteractive=0, minVersion=[])
function [isOk, errMsg, PlugDesc] = Install(PlugName, isInteractive, minVersion)
    % Returned variables
    isOk = 0;
    % Parse inputs
    if (nargin < 3) || isempty(minVersion)
        minVersion = [];
    elseif isnumeric(minVersion)
        minVersion = num2str(minVersion);
    end
    if (nargin < 2) || isempty(isInteractive)
        isInteractive = 0;
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
    % Check if plugin is supported on Apple silicon
    OsType = bst_get('OsType', 0);
    if strcmpi(OsType, 'mac64arm') && ismember(PlugName, PluginsNotSupportAppleSilicon())
        errMsg = ['Plugin ', PlugName ' is not supported on Apple silicon yet.'];
        PlugDesc = [];
        return;
    end
    % Check if there is a URL to download
    if isempty(PlugDesc.URLzip)
        errMsg = ['No download URL for ', OsType, ': ', PlugName ''];
        return;
    end
    % Compiled version
    isCompiled = bst_iscompiled();
    if isCompiled && (PlugDesc.CompiledStatus == 0)
        errMsg = ['Plugin ', PlugName ' is not available in the compiled version of Brainstorm.'];
        return;
    end
    % Minimum Matlab version
    if ~isempty(PlugDesc.MinMatlabVer) && (PlugDesc.MinMatlabVer > 0) && (bst_get('MatlabVersion') < PlugDesc.MinMatlabVer)
        strMinVer = sprintf('%d.%d', ceil(PlugDesc.MinMatlabVer / 100), mod(PlugDesc.MinMatlabVer, 100));
        errMsg = ['Plugin ', PlugName ' is not supported for versions of Matlab <= ' strMinVer];
        return;
    end
    % Get online update (use existing cache)
    [newVersion, newURLzip] = GetVersionOnline(PlugName, PlugDesc.URLzip, 1);
    if ~isempty(newVersion)
        PlugDesc.Version = newVersion;
    end
    if ~isempty(newURLzip)
        PlugDesc.URLzip = newURLzip;
    end
      
    % === PROCESS DEPENDENCIES ===
    % Check required plugins
    if ~isempty(PlugDesc.RequiredPlugs)
        bst_progress('text', ['Processing dependencies for ' PlugName '...']);
        disp(['BST> Processing dependencies: ' PlugName ' requires: ' sprintf('%s ', PlugDesc.RequiredPlugs{:,1})]);
        % Get the list of plugins that need to be installed
        installPlugs = {};
        installVer = {};
        strInstall = '';
        for iPlug = 1:size(PlugDesc.RequiredPlugs,1)
            PlugCheck = GetInstalled(PlugDesc.RequiredPlugs{iPlug,1});
            % Plugin not install: Install it
            if isempty(PlugCheck)
                installPlugs{end+1} = PlugDesc.RequiredPlugs{iPlug,1};
                installVer{end+1} = [];
                strInstall = [strInstall, '<B>' installPlugs{end} '</B> '];
            % Plugin installed: check version
            elseif (size(PlugDesc.RequiredPlugs,2) == 2) 
                minVerDep = PlugDesc.RequiredPlugs{iPlug,2};
                if ~isempty(minVerDep) && (CompareVersions(minVerDep, PlugCheck.Version) > 0)
                    installPlugs{end+1} = PlugDesc.RequiredPlugs{iPlug,1};
                    installVer{end+1} = PlugDesc.RequiredPlugs{iPlug,2};
                    strInstall = [strInstall, '<B>' installPlugs{end} '</B>(' installVer{end} ') '];
                end
            end
        end
        % If there are plugins to install
        if ~isempty(installPlugs)
            if isInteractive
                java_dialog('msgbox', ['<HTML>Plugin <B>' PlugName '</B> requires: ' strInstall ...
                    '<BR><BR>Brainstorm will now install these plugins.' 10 10], 'Plugin manager');
            end
            for iPlug = 1:length(installPlugs)
                [isInstalled, errMsg] = Install(installPlugs{iPlug}, isInteractive, installVer{iPlug});
                if ~isInstalled
                    errMsg = ['Error processing dependency: ' PlugDesc.RequiredPlugs{iPlug,1} 10 errMsg];
                    return;
                end
            end
        end
    end
    
    % === UPDATE: CHECK PREVIOUS INSTALL ===
    % Check if installed
    OldPlugDesc = GetInstalled(PlugName);
    % If already installed
    if ~isempty(OldPlugDesc)
        % If the plugin is not managed by Brainstorm: do not check versions
        if ~OldPlugDesc.isManaged
            isUpdate = 0;
        % If the requested version is higher
        elseif ~isempty(minVersion) && (CompareVersions(minVersion, OldPlugDesc.Version) > 0)
            isUpdate = 1;
            strUpdate = ['the installed version is outdated.<BR>Minimum version required: <I>' minVersion '</I>'];
        % If an update is available and auto-updates are requested
        elseif (PlugDesc.AutoUpdate == 1) && bst_get('AutoUpdates') && ...                                            % If updates are enabled
                ((isGithubMaster(PlugDesc.URLzip) && ~strcmpi(PlugDesc.Version, OldPlugDesc.Version)) || ...          % GitHub-master: update if different commit SHA strings
                 (~isGithubMaster(PlugDesc.URLzip) && (CompareVersions(PlugDesc.Version, OldPlugDesc.Version) > 0)))  % Regular stable version: update if online version is newer
            isUpdate = 1;
            strUpdate = 'an update is available online.';
        else
            isUpdate = 0;
        end
        % Update plugin
        if isUpdate
            % Compare versions
            strCompare = ['<FONT color="#707070">' ...
                          'Old version : &nbsp;&nbsp;&nbsp;&nbsp;<I>' OldPlugDesc.Version '</I><BR>' ...
                          'New version : &nbsp;&nbsp;<I>' PlugDesc.Version '</I></FONT><BR><BR>'];
            % Ask user for updating
            if isInteractive
                isConfirm = java_dialog('confirm', ...
                    ['<HTML>Plugin <B>' PlugName '</B>: ' strUpdate '<BR>' ...
                    'Download and install the latest version?<BR><BR>' strCompare], 'Plugin manager');
                % If update not confirmed: simply load the existing plugin
                if ~isConfirm
                    [isOk, errMsg, PlugDesc] = Load(PlugDesc);
                    return;
                end
            end
            disp(['BST> Plugin ' PlugName ' is outdated and will be updated.']);
            % Uninstall existing plugin
            [isOk, errMsg] = Uninstall(PlugName, 0, 0);
            if ~isOk
                errMsg = ['An error occurred while updating plugin ' PlugName ':' 10 10 errMsg 10];
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
            isOk = 1;
            return;
        end
    else
        % Get user confirmation
        if isInteractive
            if ~isempty(PlugDesc.Version) && ~isequal(PlugDesc.Version, 'github-master') && ~isequal(PlugDesc.Version, 'latest')
                strVer = ['<FONT color="#707070">Latest version: ' PlugDesc.Version '</FONT><BR><BR>'];
            else
                strVer = '';
            end
            isConfirm = java_dialog('confirm', ...
                ['<HTML>Plugin <B>' PlugName '</B> is not installed on your computer.<BR>' ...
                '<B>Download</B> the latest version of ' PlugName ' now?<BR><BR>' ...
                strVer, ...
                '<FONT color="#707070">If this program is available on your computer,<BR>' ...
                'cancel this installation and use the menu: Plugins > <BR>' ...
                PlugName ' > Custom install > Set installation folder.</FONT><BR><BR>'], 'Plugin manager');
            if ~isConfirm
                errMsg = 'Installation aborted by user.';
                return;
            end
        end
    end
    
    % === INSTALL PLUGIN ===
    bst_progress('text', ['Installing plugin ' PlugName '...']);
    % Managed plugin folder
    PlugPath = bst_fullfile(bst_get('UserPluginsDir'), PlugName);    
    % Delete existing folder
    if isdir(PlugPath)
        file_delete(PlugPath, 1, 3);
    end
    % Create folder
    if ~isdir(PlugPath)
        res = mkdir(PlugPath);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 PlugPath];
            return
        end
    end
    % Setting progressbar image
    LogoFile = GetLogoFile(PlugDesc);
    if ~isempty(LogoFile)
        bst_progress('setimage', LogoFile);
    end
    % Get package file format
    if strcmpi(PlugDesc.URLzip(end-3:end), '.zip')
        pkgFormat = 'zip';
    elseif strcmpi(PlugDesc.URLzip(end-6:end), '.tar.gz') || strcmpi(PlugDesc.URLzip(end-3:end), '.tgz')
        pkgFormat = 'tgz';
    else
        disp('BST> Could not guess file format, trying ZIP...');
        pkgFormat = 'zip';
    end
    % Download file
    pkgFile = bst_fullfile(PlugPath, ['plugin.' pkgFormat]);
    disp(['BST> Downloading URL : ' PlugDesc.URLzip]);
    disp(['BST> Saving to file  : ' pkgFile]);
    errMsg = gui_brainstorm('DownloadFile', PlugDesc.URLzip, pkgFile, ['Download plugin: ' PlugName], LogoFile);
    % If file was not downloaded correctly
    if ~isempty(errMsg)
        errMsg = ['Impossible to download ' PlugName ' automatically:' 10 errMsg];
        if ~isCompiled
            errMsg = [errMsg 10 10 ...
                'Alternative download solution:' 10 ...
                '1) Copy the URL below from the Matlab command window: ' 10 ...
                '     ' PlugDesc.URLzip 10 ...
                '2) Paste it in a web browser' 10 ...
                '3) Save the file and unzip it' 10 ...
                '4) Add to the Matlab path the folder containing ' PlugDesc.TestFile '.'];
        end
        bst_progress('removeimage');
        return;
    end
    % Update progress bar
    bst_progress('text', ['Installing plugin: ' PlugName '...']);
    if ~isempty(LogoFile)
        bst_progress('setimage', LogoFile);
    end
    % Unzip file
    switch (pkgFormat)
        case 'zip'
            bst_unzip(pkgFile, PlugPath);
        case 'tgz'
            if ispc
                untar(pkgFile, PlugPath);
            else
                curdir = pwd;
                cd(PlugPath);
                system(['tar -xf ' pkgFile]);
                cd(curdir);
            end
    end
    file_delete(pkgFile, 1, 3);

    % === SAVE PLUGIN.MAT ===
    PlugDesc.Path = PlugPath;
    PlugMatFile = bst_fullfile(PlugDesc.Path, 'plugin.mat');
    excludedFields = {'LoadedFcn', 'UnloadedFcn', 'DownloadedFcn', 'InstalledFcn', 'UninstalledFcn', 'Path', 'isLoaded', 'isManaged'};
    PlugDescSave = rmfield(PlugDesc, excludedFields);
    bst_save(PlugMatFile, PlugDescSave, 'v6');

    % === CALLBACK: POST-DOWNLOADED ===
    [isOk, errMsg] = ExecuteCallback(PlugDesc, 'DownloadedFcn');
    if ~isOk
        return;
    end
    
    % === LOAD PLUGIN ===
    % Load plugin
    [isOk, errMsg, PlugDesc] = Load(PlugDesc);
    if ~isOk
        bst_progress('removeimage');
        return;
    end
    % Update plugin description after first load, and delete unwanted files
    [isOk, errMsg, PlugDesc] = UpdateDescription(PlugDesc, 1);
    if ~isOk
        return;
    end
    
    % === SHOW PLUGIN INFO ===
    % Log install
    bst_webread(['https://neuroimage.usc.edu/bst/pluglog.php?c=K8Yda7B&plugname=' PlugDesc.Name '&action=install']);
    % Show plugin information (interactive mode only)
    if isInteractive
        % Hide progress bar
        isProgress = bst_progress('isVisible');
        if isProgress
            bst_progress('hide');
        end
        % Message box: aknowledgements
        java_dialog('msgbox', ['<HTML>Plugin <B>' PlugName '</B> was sucessfully installed.<BR><BR>' ...
            'This software is not distributed by the Brainstorm developers.<BR>' ...
            'Please take a few minutes to read the license information,<BR>' ...
            'check the authors'' website and register online if recommended.<BR><BR>' ...
            '<B>Cite the authors</B> in your publications if you are using their software.<BR><BR>'], 'Plugin manager');
        % Show the readme file
        if ~isempty(PlugDesc.ReadmeFile)
            view_text(PlugDesc.ReadmeFile, ['Installed plugin: ' PlugName], 1, 1);
        end
        % Open the website
        if ~isempty(PlugDesc.URLinfo)
            web(PlugDesc.URLinfo, '-browser')
        end
        % Restore progress bar
        if isProgress
            bst_progress('show');
        end
    end
    % Remove logo
    bst_progress('removeimage');
    % Return success
    isOk = 1;
end


%% ===== UPDATE DESCRIPTION =====
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('UpdateDescription', PlugDesc, doDelete=0)
function [isOk, errMsg, PlugDesc] = UpdateDescription(PlugDesc, doDelete)
    isOk        = 1;
    errMsg      = '';
    PlugPath    = PlugDesc.Path;
    PlugName    = PlugDesc.Name;

    if nargin < 2
        doDelete = 0;
    end

    % Plug in needs to be installed
    if isempty(bst_plugin('GetInstalled', PlugDesc.Name))
        isOk = 0;
        errMsg = ['Cannot update description, plugin ''' PlugDesc.Name ''' needs to be installed'];
        return
    end

    % === DELETE UNWANTED FILES ===
    if doDelete && ~isempty(PlugDesc.DeleteFiles) && iscell(PlugDesc.DeleteFiles)
        warning('off', 'MATLAB:RMDIR:RemovedFromPath');
        for iDel = 1:length(PlugDesc.DeleteFiles)
            if ~isempty(PlugDesc.SubFolder)
                fileDel = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, PlugDesc.DeleteFiles{iDel});
            else
                fileDel = bst_fullfile(PlugDesc.Path, PlugDesc.DeleteFiles{iDel});
            end
            if file_exist(fileDel)
                try
                    file_delete(fileDel, 1, 3);
                catch
                    disp(['BST> Plugin ' PlugName ': Could not delete file: ' PlugDesc.DeleteFiles{iDel}]);
                end
            else
                disp(['BST> Plugin ' PlugName ': Missing file: ' PlugDesc.DeleteFiles{iDel}]);
            end
        end
        warning('on', 'MATLAB:RMDIR:RemovedFromPath');
    end

    % === SEARCH PROCESSES ===
    % Look for process_* functions in the process folder
    PlugProc = file_find(PlugPath, 'process_*.m', Inf, 0);
    if ~isempty(PlugProc)
        % Remove absolute path: use only path relative to the plugin Path
        PlugDesc.Processes = cellfun(@(c)file_win2unix(strrep(c, [PlugPath, filesep], '')), PlugProc, 'UniformOutput', 0);
    end
    
    % === SAVE PLUGIN.MAT ===
    % Save installation date
    c = clock();
    PlugDesc.InstallDate = datestr(datenum(c(1), c(2), c(3), c(4), c(5), c(6)), 'dd-mmm-yyyy HH:MM:SS');
    % Get readme and logo
    PlugDesc.ReadmeFile = GetReadmeFile(PlugDesc);
    PlugDesc.LogoFile = GetLogoFile(PlugDesc);
    % Update plugin.mat
    excludedFields = {'LoadedFcn', 'UnloadedFcn', 'DownloadedFcn', 'InstalledFcn', 'UninstalledFcn', 'Path', 'isLoaded', 'isManaged'};
    PlugDescSave = rmfield(PlugDesc, excludedFields);
    PlugMatFile = bst_fullfile(PlugDesc.Path, 'plugin.mat');
    bst_save(PlugMatFile, PlugDescSave, 'v6');
    
    % === CALLBACK: POST-INSTALL ===
    [isOk, errMsg] = ExecuteCallback(PlugDesc, 'InstalledFcn');
    if ~isOk
        return;
    end
    
    % === GET INSTALLED VERSION ===
    % Get installed version
    if ~isempty(PlugDesc.GetVersionFcn)
        testVer = [];
        try
            if ischar(PlugDesc.GetVersionFcn)
                testVer = eval(PlugDesc.GetVersionFcn);
            elseif isa(PlugDesc.GetVersionFcn, 'function_handle')
                testVer = feval(PlugDesc.GetVersionFcn);
            end
        catch
            disp(['BST> Could not get installed version with callback: ' PlugDesc.GetVersionFcn]);
        end
        if ~isempty(testVer)
            PlugDesc.Version = testVer;
            % Update plugin.mat
            PlugDescSave.Version = testVer;
            bst_save(PlugMatFile, PlugDescSave, 'v6');
        end
    end
end

%% ===== INSTALL INTERACTIVE =====
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('InstallInteractive', PlugName)
function [isOk, errMsg, PlugDesc] = InstallInteractive(PlugName)
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Initialization...');
    end
    % Call silent function
    [isOk, errMsg, PlugDesc] = Install(PlugName, 1);
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


%% ===== INSTALL MULTIPLE CHOICE =====
% If multiple plugins provide the same functions (eg. FieldTrip and SPM): make sure at least one is installed
% USAGE:  [isOk, errMsg, PlugDesc] = bst_plugin('InstallMultipleChoice', PlugNames, isInteractive)
function [isOk, errMsg, PlugDesc] = InstallMultipleChoice(PlugNames, isInteractive)
    % Check if one of the plugins is loaded
    for iPlug = 1:length(PlugNames)
        PlugInst = GetInstalled(PlugNames{iPlug});
        if ~isempty(PlugInst)
            [isOk, errMsg, PlugDesc] = Load(PlugNames{iPlug});
            if isOk
                return;
            end
        end
    end
    % If no plugin is loaded: Install the first in the list
    [isOk, errMsg, PlugDesc] = Install(PlugNames{1}, isInteractive);
end


%% ===== UNINSTALL =====
% USAGE:  [isOk, errMsg] = bst_plugin('Uninstall', PlugName, isInteractive=0, isDependencies=1)
function [isOk, errMsg] = Uninstall(PlugName, isInteractive, isDependencies)
    % Returned variables
    isOk = 0;
    errMsg = '';
    % Parse inputs
    if (nargin < 3) || isempty(isDependencies)
        isDependencies = 1;
    end
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
        errMsg = ['<HTML>Plugin <B>' PlugName '</B> is not managed by Brainstorm.' 10 'Delete folder manually:' 10 PlugDesc.Path];
        return;
    % Plugin not installed: check if folder exists
    elseif isempty(PlugDesc) || isempty(PlugDesc.Path)
        % Get plugin structure from name
        [PlugDesc, errMsg] = GetDescription(PlugName);
        if ~isempty(errMsg)
            return;
        end
        % Managed plugin folder
        PlugPath = bst_fullfile(bst_get('UserPluginsDir'), PlugName);
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
        isConfirm = java_dialog('confirm', ['<HTML>Delete permanently plugin <B>' PlugName '</B>?' 10 10 PlugPath 10 10], 'Plugin manager');
        if ~isConfirm
            errMsg = 'Uninstall aborted by user.';
            return;
        end
    end

    % === PROCESS DEPENDENCIES ===
    % Uninstall dependent plugins
    if isDependencies
        AllPlugs = GetSupported();
        for iPlug = 1:length(AllPlugs)
            if ~isempty(AllPlugs(iPlug).RequiredPlugs) && ismember(PlugDesc.Name, AllPlugs(iPlug).RequiredPlugs(:,1))
                disp(['BST> Uninstalling dependent plugin: ' AllPlugs(iPlug).Name]);
                Uninstall(AllPlugs(iPlug).Name, isInteractive);
            end
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
    if (isDeleted ~= 1)
        errMsg = ['Could not delete plugin folder: ' 10 PlugPath 10 10 ... 
                  'There is probably a file in that folder that is currently ' 10 ...
                  'loaded in Matlab, but that cannot be unloaded dynamically.' 10 10 ...
                  'Brainstorm will now close Matlab.' 10 ... 
                  'Restart Matlab and install again the plugin.' 10 10];
        if isInteractive
            java_dialog('error', errMsg, 'Restart Matlab');
        else
            disp([10 10 'BST> ' errMsg]);
        end
        quit('force');
    end
    
    % === CALLBACK: POST-UNINSTALL ===
    [isOk, errMsg] = ExecuteCallback(PlugDesc, 'UninstalledFcn');
    if ~isOk
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


%% ===== UPDATE INTERACTIVE =====
% USAGE:  [isOk, errMsg] = bst_plugin('UpdateInteractive', PlugName)
function [isOk, errMsg] = UpdateInteractive(PlugName)
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Initialization...');
    end
    % Get new plugin
    [PlugRef, errMsg] = GetDescription(PlugName);
    isOk = isempty(errMsg);
    % Get installed plugin
    if isOk
        PlugInst = GetInstalled(PlugName);
        if isempty(PlugInst) || ~PlugInst.isManaged
            isOk = 0;
            errMsg = ['Plugin ' PlugName ' is not installed or not managed by Brainstorm.'];
        end
    end
    % Get online update (use cache when available)
    [newVersion, newURLzip] = GetVersionOnline(PlugName, PlugRef.URLzip, 1);
    if ~isempty(newVersion)
        PlugRef.Version = newVersion;
    end
    if ~isempty(newURLzip)
        PlugRef.URLzip = newURLzip;
    end
    % User confirmation
    if isOk
        isOk = java_dialog('confirm', ['<HTML>Update plugin <B>' PlugName '</B> ?<BR><BR><FONT color="#707070">' ...
            'Old version : &nbsp;&nbsp;&nbsp;&nbsp;<I>' PlugInst.Version '</I><BR>' ...
            'New version : &nbsp;&nbsp;<I>' PlugRef.Version '</I><BR><BR></FONT>'], 'Plugin manager');
        if ~isOk
            errMsg = 'Update aborted by user.';
        end
    end
    % Uninstall old
    if isOk
        [isOk, errMsg] = Uninstall(PlugName, 0, 0);
    end
    % Install new
    if isOk
        [isOk, errMsg, PlugDesc] = Install(PlugName, 0);
    else
        PlugDesc = [];
    end
    % Handle errors
    if ~isOk
        bst_error(['An error occurred while updating plugin ' PlugName ':' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Update message:' 10 10 errMsg 10], 'Plugin manager');
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
    % Plugin was updated successfully
    if ~isempty(PlugDesc)
        % Show the readme file
        if ~isempty(PlugDesc.ReadmeFile)
            view_text(PlugDesc.ReadmeFile, ['Installed plugin: ' PlugName], 1, 1);
        end
        % Open the website
        if ~isempty(PlugDesc.URLinfo)
            web(PlugDesc.URLinfo, '-browser')
        end
    end
end


%% ===== LOAD =====
% USAGE:  [isOk, errMsg, PlugDesc] = Load(PlugDesc, isVerbose=1)
function [isOk, errMsg, PlugDesc] = Load(PlugDesc, isVerbose)
    % Parse inputs
    if (nargin < 2) || isempty(isVerbose)
        isVerbose = 1;
    end
    % Initialize returned variables 
    isOk = 0;
    % Get plugin structure from name
    [PlugDesc, errMsg] = GetDescription(PlugDesc);
    if ~isempty(errMsg)
        return;
    end
    % Check if plugin is supported on Apple silicon
    OsType = bst_get('OsType', 0);
    if strcmpi(OsType, 'mac64arm') && ismember(PlugDesc.Name, PluginsNotSupportAppleSilicon())
        errMsg = ['Plugin ', PlugDesc.Name ' is not supported on Apple silicon yet.'];
        return;
    end
    % Minimum Matlab version
    if ~isempty(PlugDesc.MinMatlabVer) && (PlugDesc.MinMatlabVer > 0) && (bst_get('MatlabVersion') < PlugDesc.MinMatlabVer)
        strMinVer = sprintf('%d.%d', ceil(PlugDesc.MinMatlabVer / 100), mod(PlugDesc.MinMatlabVer, 100));
        errMsg = ['Plugin ', PlugDesc.Name ' is not supported for versions of Matlab <= ' strMinVer];
        return;
    end
    
    % === PROCESS DEPENDENCIES ===
    % Unload incompatible plugins
    if ~isempty(PlugDesc.UnloadPlugs)
        for iPlug = 1:length(PlugDesc.UnloadPlugs)
            % disp(['BST> Unloading incompatible plugin: ' PlugDesc.UnloadPlugs{iPlug}]);
            Unload(PlugDesc.UnloadPlugs{iPlug}, isVerbose);
        end
    end

    % === ALREADY LOADED ===
    % If plugin is already full loaded
    if isequal(PlugDesc.isLoaded, 1) && ~isempty(PlugDesc.Path)
        if isVerbose
            errMsg = ['Plugin ' PlugDesc.Name ' already loaded: ' PlugDesc.Path];
        end
        return;
    end
    % Managed plugin path
    PlugPath = bst_fullfile(bst_get('UserPluginsDir'), PlugDesc.Name);
    if file_exist(PlugPath)
        PlugDesc.isManaged = 1;
    % Custom installation
    else
        PluginCustomPath = bst_get('PluginCustomPath');
        if isfield(PluginCustomPath, PlugDesc.Name) && ~isempty(bst_fullfile(PluginCustomPath.(PlugDesc.Name))) && file_exist(bst_fullfile(PluginCustomPath.(PlugDesc.Name)))
            PlugPath = PluginCustomPath.(PlugDesc.Name);
        end
        PlugDesc.isManaged = 0;
    end
    % Managed install: Detect if there is a single subfolder containing all the files
    if PlugDesc.isManaged && ~isempty(PlugDesc.TestFile) && ~file_exist(bst_fullfile(PlugPath, PlugDesc.TestFile))
        dirList = dir(PlugPath);
        for iDir = 1:length(dirList)
            % Not folder or . : skip
            if (dirList(iDir).name(1) == '.') || ~dirList(iDir).isdir
                continue;
            end
            % Check if test file is in the folder
            if file_exist(bst_fullfile(PlugPath, dirList(iDir).name, PlugDesc.TestFile))
                PlugDesc.SubFolder = dirList(iDir).name;
                break;
            % Otherwise, check in any of the subfolders
            elseif ~isempty(PlugDesc.LoadFolders)
                for iSubDir = 1:length(PlugDesc.LoadFolders)
                    if file_exist(bst_fullfile(PlugPath, dirList(iDir).name, PlugDesc.LoadFolders{iSubDir}, PlugDesc.TestFile))
                        PlugDesc.SubFolder = dirList(iDir).name;
                        break;
                    end
                end
            end
        end
    end
    % Check if test function already available in the path
    TestFilePath = GetTestFilePath(PlugDesc);
    if ~isempty(TestFilePath)
        PlugDesc.isLoaded = 1;
        PlugDesc.isManaged = ~isempty(strfind(which(PlugDesc.TestFile), PlugPath));
        if PlugDesc.isManaged
            PlugDesc.Path = PlugPath;
        else
            PlugDesc.Path = TestFilePath;
        end
        if isVerbose
            disp(['BST> Plugin ' PlugDesc.Name ' already loaded: ' PlugDesc.Path]);
        end
        isOk = 1;
        return;
    end
    
    % === CHECK LOADABILITY ===
    PlugDesc.Path = PlugPath;
    if ~file_exist(PlugDesc.Path)
        errMsg = ['Plugin ' PlugDesc.Name ' not installed.' 10 'Missing folder: ' PlugDesc.Path];
        return;
    end
    % Set logo
    LogoFile = GetLogoFile(PlugDesc);
    if ~isempty(LogoFile)
        bst_progress('setimage', LogoFile);
    end
    
    % Load required plugins
    if ~isempty(PlugDesc.RequiredPlugs)
        for iPlug = 1:size(PlugDesc.RequiredPlugs,1)
            % disp(['BST> Loading required plugin: ' PlugDesc.RequiredPlugs{iPlug,1}]);
            [isOk, errMsg] = Load(PlugDesc.RequiredPlugs{iPlug,1}, isVerbose);
            if ~isOk
                errMsg = ['Error processing dependencies: ', PlugDesc.Name, 10, errMsg];
                bst_progress('removeimage');
                return;
            end
        end
    end
    
    % === LOAD PLUGIN ===
    % Add plugin folder to path
    if ~isempty(PlugDesc.SubFolder)
        PlugHomeDir = bst_fullfile(PlugPath, PlugDesc.SubFolder);
    else
        PlugHomeDir = PlugPath;
    end
    % Do not modify path in compiled mode
    isCompiled = bst_iscompiled();
    if ~isCompiled
        addpath(PlugHomeDir);
        if isVerbose
            disp(['BST> Adding plugin ' PlugDesc.Name ' to path: ' PlugHomeDir]);
        end
        % Add specific subfolders to path
        if ~isempty(PlugDesc.LoadFolders)
            % Load all all subfolders
            if isequal(PlugDesc.LoadFolders, '*') || isequal(PlugDesc.LoadFolders, {'*'})
                if isVerbose
                    disp(['BST> Adding plugin ' PlugDesc.Name ' to path: ', PlugHomeDir, filesep, '*']);
                end
                addpath(genpath(PlugHomeDir));
            % Load specific subfolders
            else
                for i = 1:length(PlugDesc.LoadFolders)
                    subDir = PlugDesc.LoadFolders{i};
                    if isequal(filesep, '\')
                        subDir = strrep(subDir, '/', '\');
                    end
                    if ~isempty(dir([PlugHomeDir, filesep, subDir]))
                        if isVerbose
                            disp(['BST> Adding plugin ' PlugDesc.Name ' to path: ', PlugHomeDir, filesep, subDir]);
                        end
                        if regexp(subDir, '\*[/\\]*$')
                            subDir = regexprep(subDir, '\*[/\\]*$', '');
                            addpath(genpath([PlugHomeDir, filesep, subDir]));
                        else
                            addpath([PlugHomeDir, filesep, subDir]);
                        end
                    end
                end
            end
        end
    end
    
    % === TEST FUNCTION ===
    % Check if test function is available on path
    if ~isCompiled && ~isempty(PlugDesc.TestFile) && (exist(PlugDesc.TestFile, 'file') == 0)
        errMsg = ['Plugin ' PlugDesc.Name ' successfully loaded from:' 10 PlugHomeDir 10 10 ...
            'However, the function ' PlugDesc.TestFile ' is not accessible in the Matlab path.' 10 ...
            'Try restarting Matlab and Brainstorm.'];
        bst_progress('removeimage')
        return;
    end
    
    % === CALLBACK: POST-LOAD ===
    [isOk, errMsg] = ExecuteCallback(PlugDesc, 'LoadedFcn');
    
    % Remove logo
    bst_progress('removeimage');
    % Return success
    PlugDesc.isLoaded = isOk;
end


%% ===== LOAD INTERACTIVE =====
% USAGE:  [isOk, errMsg, PlugDesc] = LoadInteractive(PlugName/PlugDesc)
function [isOk, errMsg, PlugDesc] = LoadInteractive(PlugDesc)
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Loading plugin...');
    end
    % Call silent function
    [isOk, errMsg, PlugDesc] = Load(PlugDesc);
    % Handle errors
    if ~isOk
        bst_error(['Load error:' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Load message:' 10 10 errMsg 10], 'Plugin manager');
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end


%% ===== UNLOAD =====
% USAGE:  [isOk, errMsg, PlugDesc] = Unload(PlugName/PlugDesc, isVerbose)
function [isOk, errMsg, PlugDesc] = Unload(PlugDesc, isVerbose)
    % Parse inputs
    if (nargin < 2) || isempty(isVerbose)
        isVerbose = 1;
    end
    % Initialize returned variables 
    isOk = 0;
    errMsg = '';
    % Get installation
    InstPlugDesc = GetInstalled(PlugDesc);
    % Plugin not installed: check if folder exists
    if isempty(InstPlugDesc) || isempty(InstPlugDesc.Path)
        % Get plugin structure from name
        [PlugDesc, errMsg] = GetDescription(PlugDesc);
        if ~isempty(errMsg)
            return;
        end
        % Managed plugin folder
        PlugPath = bst_fullfile(bst_get('UserPluginsDir'), PlugDesc.Name);
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
    
    % === PROCESS DEPENDENCIES ===
    % Unload dependent plugins
    AllPlugs = GetSupported();
    for iPlug = 1:length(AllPlugs)
        if ~isempty(AllPlugs(iPlug).RequiredPlugs) && ismember(PlugDesc.Name, AllPlugs(iPlug).RequiredPlugs(:,1))
            Unload(AllPlugs(iPlug));
        end
    end
    
    % === UNLOAD PLUGIN ===
    % Do not modify path in compiled mode
    if ~bst_iscompiled()
        matlabPath = str_split(path, pathsep);
        % Remove plugin folder and subfolders from path
        allSubFolders = str_split(genpath(PlugPath), pathsep);
        for i = 1:length(allSubFolders)
            if ismember(allSubFolders{i}, matlabPath)
                rmpath(allSubFolders{i});
                if isVerbose
                    disp(['BST> Removing plugin ' PlugDesc.Name ' from path: ' allSubFolders{i}]);
                end
            end
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
    
    % === CALLBACK: POST-UNLOAD ===
    [isOk, errMsg] = ExecuteCallback(PlugDesc, 'UnloadedFcn');
    if ~isOk
        return;
    end
    
    % Return success
    PlugDesc.isLoaded = 0;
    isOk = 1;
end


%% ===== UNLOAD INTERACTIVE =====
% USAGE:  [isOk, errMsg, PlugDesc] = UnloadInteractive(PlugName/PlugDesc)
function [isOk, errMsg, PlugDesc] = UnloadInteractive(PlugDesc)
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Plugin manager', 'Unloading plugin...');
    end
    % Call silent function
    [isOk, errMsg, PlugDesc] = Unload(PlugDesc);
    % Handle errors
    if ~isOk
        bst_error(['Unload error:' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Unload message:' 10 10 errMsg 10], 'Plugin manager');
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end


%% ===== LIST =====
% USAGE:  strList = bst_plugin('List', Target='installed', isGui=0)    % Target={'supported','installed', 'loaded'}
function strList = List(Target, isGui)
    % Parse inputs
    if (nargin < 2) || isempty(isGui)
        isGui = 0;
    end
    if (nargin < 1) || isempty(Target)
        Target = 'Installed';
    else
        Target = [upper(Target(1)), lower(Target(2:end))];
    end
    % Get plugins to list
    strTitle = sprintf('%s plugins', Target);
    switch (Target)
        case 'Supported'
            PlugDesc = GetSupported();
            isInstalled = 0;
        case 'Installed'
            strTitle = [strTitle '   (*=Loaded)'];
            PlugDesc = GetInstalled();
            isInstalled = 1;
        case 'Loaded'
            PlugDesc = GetInstalled();
            PlugDesc = PlugDesc([PlugDesc.isLoaded] == 1);
            isInstalled = 1;
        otherwise
            error(['Invalid target: ' Target]);
    end
    if isempty(PlugDesc)
        return;
    end
    % Sort by plugin names
    [tmp,I] = sort({PlugDesc.Name});
    PlugDesc = PlugDesc(I);

    % Get Brainstorm info
    bstVer = bst_get('Version');
    bstDir = bst_get('BrainstormHomeDir');
    % Cut version string (short github SHA)
    if (length(bstVer.Commit) > 13)
        bstGit = ['git @', bstVer.Commit(1:7)];
        bstURL = ['https://github.com/brainstorm-tools/brainstorm3/archive/' bstVer.Commit '.zip'];
        structVer = bstGit;
    else
        bstGit = '';
        bstURL = '';
        structVer = bstVer.Version;
    end

    % Max lengths
    headerName = '  Name';
    headerVersion = 'Version';
    headerPath = 'Install path';
    headerUrl = 'Downloaded from';
    headerDate = 'Install date';
    maxName = max(cellfun(@length, {PlugDesc.Name, headerName, 'brainstorm'}));
    maxVer  = min(13, max(cellfun(@length, {PlugDesc.Version, headerVersion, bstGit})));
    maxUrl  = max(cellfun(@length, {PlugDesc.URLzip, headerUrl, bstURL}));
    maxDate = 12;
    if isInstalled
        strDate = [' | ', headerDate, repmat(' ', 1, maxDate-length(headerDate))];
        strDateSep = ['-|-', repmat('-',1,maxDate)];
        maxPath = max(cellfun(@length, {PlugDesc.Path, headerPath}));
        strPath = [' | ', headerPath, repmat(' ', 1, maxPath-length(headerPath))];
        strPathSep = ['-|-', repmat('-',1,maxPath)];
        strBstVer = [' | ', bstVer.Date, repmat(' ', 1, maxDate-length(bstVer.Date))];
        strBstDir = [' | ', bstDir, repmat(' ', 1, maxPath-length(bstDir))];
    else
        strDate = '';
        strDateSep = '';
        strPath = '';
        strPathSep = '';
        strBstVer = '';
        strBstDir = '';
    end
    % Print column headers
    strList = [headerName, repmat(' ', 1, maxName-length(headerName) + 2) ...
        ' | ', headerVersion, repmat(' ', 1, maxVer-length(headerVersion)), ...
        strDate, strPath, ...
        ' | ' headerUrl 10 ...
        repmat('-',1,maxName + 2), '-|-', repmat('-',1,maxVer), strDateSep, strPathSep, '-|-', repmat('-',1,maxUrl) 10];

    % Print Brainstorm information
    strList = [strList '* ', ...
        'brainstorm', repmat(' ', 1, maxName-length('brainstorm')) ...
        ' | ', bstGit, repmat(' ', 1, maxVer-length(bstGit)), ...
        strBstVer, strBstDir, ...
        ' | ' bstURL 10];

    % Print installed plugins to standard output
    for iPlug = 1:length(PlugDesc)
        % Loaded plugin
        if PlugDesc(iPlug).isLoaded
            strLoaded = '* ';
        else
            strLoaded = '  ';
        end
        % Cut installation date: Only date, no time
        if (length(PlugDesc(iPlug).InstallDate) > 11)
            plugDate = PlugDesc(iPlug).InstallDate(1:11);
        else
            plugDate = PlugDesc(iPlug).InstallDate;
        end
        % Installed listing
        if isInstalled
            strDate = [' | ', plugDate, repmat(' ', 1, maxDate-length(plugDate))];
            strPath = [' | ', PlugDesc(iPlug).Path, repmat(' ', 1, maxPath-length(PlugDesc(iPlug).Path))];
        else
            strDate = '';
            strPath = '';
        end
        % Get installed version
        if (length(PlugDesc(iPlug).Version) > 13)   % Cut version string (short github SHA)
            plugVer = ['git @', PlugDesc(iPlug).Version(1:7)];
        else
            plugVer = PlugDesc(iPlug).Version;
        end
        % Get installed version with GetVersionFcn
        if isempty(plugVer) && isfield(PlugDesc(iPlug),'GetVersionFcn') && ~isempty(PlugDesc(iPlug).GetVersionFcn)
            % Load plugin if needed
            tmpLoad = 0;
            if ~PlugDesc(iPlug).isLoaded
                tmpLoad = 1;
                Load(PlugDesc(iPlug), 0);
            end
            try
                if ischar(PlugDesc(iPlug).GetVersionFcn)
                    plugVer = eval(PlugDesc(iPlug).GetVersionFcn);
                elseif isa(PlugDesc(iPlug).GetVersionFcn, 'function_handle')
                    plugVer = feval(PlugDesc(iPlug).GetVersionFcn);
                end
            catch 
                disp(['BST> Could not get installed version with callback: ' PlugDesc(iPlug).GetVersionFcn]);
            end
            % Unload plugin
            if tmpLoad
                Unload(PlugDesc(iPlug), 0);
            end
        end
        % Assemble plugin text row
        strList = [strList strLoaded, ...
            PlugDesc(iPlug).Name, repmat(' ', 1, maxName-length(PlugDesc(iPlug).Name)) ...
            ' | ', plugVer, repmat(' ', 1, maxVer-length(plugVer)), ...
            strDate, strPath, ...
            ' | ' PlugDesc(iPlug).URLzip 10];
    end
    % Display output
    if isGui
        view_text(strList, strTitle);
    % No string returned: display it in the command window
    elseif (nargout == 0)
        disp([10 strTitle 10 10 strList]);
    end
end


%% ===== MENUS: CREATE =====
function j = MenuCreate(jMenu, jPlugsPrev, PlugDesc, fontSize)
    import org.brainstorm.icon.*;
    % Get all the supported plugins
    if isempty(PlugDesc)
        PlugDesc = GetSupported();
    end
    % Get Matlab version
    MatlabVersion = bst_get('MatlabVersion');
    isCompiled = bst_iscompiled();
    % Submenus array
    jSub = {};
    % Generate submenus array from existing menu
    if ~isCompiled && jMenu.getMenuComponentCount > 0
        for iItem = 0 : jMenu.getItemCount-1
            if ~isempty(regexp(jMenu.getMenuComponent(iItem).class, 'JMenu$', 'once'))
                jSub(end+1,1:2) = {char(jMenu.getMenuComponent(iItem).getText), jMenu.getMenuComponent(iItem)};
            end
        end
    end
    % Editing an existing menu?
    if isempty(jPlugsPrev)
        isNewMenu = 1;
        j = repmat(struct(), 0);
    else
        isNewMenu = 0;
        j = repmat(jPlugsPrev(1), 0);
    end
    % Process each plugin
    for iPlug = 1:length(PlugDesc)
        Plug = PlugDesc(iPlug);
        % Skip if Matlab is too old
        if ~isempty(Plug.MinMatlabVer) && (Plug.MinMatlabVer > 0) && (MatlabVersion < Plug.MinMatlabVer)
            continue;
        end
        % Skip if not supported in compiled version
        if isCompiled && (Plug.CompiledStatus == 0)
            continue;
        end
        % === Add menus for each plugin ===
        % One menu per plugin
        ij = length(j) + 1;
        j(ij).name = Plug.Name;
        % Skip if it is already a menu item
        if ~isNewMenu
            iPlugPrev = ismember({jPlugsPrev.name}, Plug.Name);
            if any(iPlugPrev)
                j(ij) = jPlugsPrev(iPlugPrev);
                continue
            end
        end
        % Category=submenu
        if ~isempty(Plug.Category)
            if isempty(jSub) || ~ismember(Plug.Category, jSub(:,1))
                jParent = gui_component('Menu', jMenu, [], Plug.Category, IconLoader.ICON_FOLDER_OPEN, [], [], fontSize);
                jSub(end+1,1:2) = {Plug.Category, jParent}; 
            else
                iSub = find(strcmpi(jSub(:,1), Plug.Category));
                jParent = jSub{iSub,2};
            end
        else
            jParent = jMenu;
        end
        % Compiled and included: Simple static menu
        if isCompiled && (Plug.CompiledStatus == 2)
            j(ij).menu = gui_component('MenuItem', jParent, [], Plug.Name, [], [], [], fontSize);
        % Do not create submenus for compiled version
        else
            % Main menu
            j(ij).menu = gui_component('Menu', jParent, [], Plug.Name, [], [], [], fontSize);
            % Version
            j(ij).version = gui_component('MenuItem', j(ij).menu, [], 'Version', [], [], [], fontSize);
            j(ij).versep = java_create('javax.swing.JSeparator');
            j(ij).menu.add(j(ij).versep);
            % Install
            j(ij).install = gui_component('MenuItem', j(ij).menu, [], 'Install', IconLoader.ICON_DOWNLOAD, [], @(h,ev)InstallInteractive(Plug.Name), fontSize);
            % Update
            j(ij).update = gui_component('MenuItem', j(ij).menu, [], 'Update', IconLoader.ICON_RELOAD, [], @(h,ev)UpdateInteractive(Plug.Name), fontSize);
            % Uninstall
            j(ij).uninstall = gui_component('MenuItem', j(ij).menu, [], 'Uninstall', IconLoader.ICON_DELETE, [], @(h,ev)UninstallInteractive(Plug.Name), fontSize);
            j(ij).menu.addSeparator();
            % Custom install
            j(ij).custom = gui_component('Menu', j(ij).menu, [], 'Custom install', IconLoader.ICON_FOLDER_OPEN, [], [], fontSize);
            j(ij).customset = gui_component('MenuItem', j(ij).custom, [], 'Select installation folder', [], [], @(h,ev)SetCustomPath(Plug.Name), fontSize);
            j(ij).custompath = gui_component('MenuItem', j(ij).custom, [], 'Path not set', [], [], [], fontSize);
            j(ij).custompath.setEnabled(0);
            j(ij).custom.addSeparator();
            j(ij).customdel = gui_component('MenuItem', j(ij).custom, [], 'Ignore local installation', [], [], @(h,ev)SetCustomPath(Plug.Name, 0), fontSize);
            j(ij).menu.addSeparator();
            % Load
            j(ij).load = gui_component('MenuItem', j(ij).menu, [], 'Load', IconLoader.ICON_GOOD, [], @(h,ev)LoadInteractive(Plug.Name), fontSize);
            j(ij).unload = gui_component('MenuItem', j(ij).menu, [], 'Unload', IconLoader.ICON_BAD, [], @(h,ev)UnloadInteractive(Plug.Name), fontSize);
            j(ij).menu.addSeparator();
            % Website
            j(ij).web = gui_component('MenuItem', j(ij).menu, [], 'Website', IconLoader.ICON_EXPLORER, [], @(h,ev)web(Plug.URLinfo, '-browser'), fontSize);
            j(ij).usage = gui_component('MenuItem', j(ij).menu, [], 'Usage statistics', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)bst_userstat(0,Plug.Name), fontSize);
            % Extra menus
            if ~isempty(Plug.ExtraMenus)
                j(ij).menu.addSeparator();
                for iMenu = 1:size(Plug.ExtraMenus,1)
                    j(ij).extra(iMenu) = gui_component('MenuItem', j(ij).menu, [], Plug.ExtraMenus{iMenu,1}, IconLoader.ICON_EXPLORER, [], @(h,ev)bst_call(@eval, Plug.ExtraMenus{iMenu,2}), fontSize);
                end
            end
        end
    end
    % === Remove menus for plugins with description ===
    if ~isempty(jPlugsPrev)
        [~, iOld] = setdiff({jPlugsPrev.name}, {PlugDesc.Name});
        for ix = 1 : length(iOld)
            % Find category menu component
            jMenuCat = jPlugsPrev(iOld(ix)).menu.getParent.getInvoker;
            % Find index in parent
            iDel = [];
            for ic = 0 : jMenuCat.getMenuComponentCount-1
                if jPlugsPrev(iOld(ix)).menu == jMenuCat.getMenuComponent(ic)
                    iDel = ic;
                    break
                end
            end
            % Remove from parent
            if ~isempty(iDel)
                jMenuCat.remove(iDel);
            end
        end
    end
    % Create options for adding user-defined plugins
    if ~isCompiled && isNewMenu
        menuCategory = 'User defined';
        jMenuUserDef = [];
        for iMenuItem = 0 : jMenu.getItemCount-1
             if ~isempty(regexp(jMenu.getMenuComponent(iMenuItem).class, 'JMenu$', 'once')) && strcmp(char(jMenu.getMenuComponent(iMenuItem).getText), menuCategory)
                 jMenuUserDef = jMenu.getMenuComponent(iMenuItem);
             end
        end
        if isempty(jMenuUserDef)
            jMenuUserDef = gui_component('Menu', jMenu, [], menuCategory, IconLoader.ICON_FOLDER_OPEN, [], [], fontSize);
        end
        jAddUserDefMan  = gui_component('MenuItem', [], [], 'Add manually',  IconLoader.ICON_EDIT,   [], @(h,ev)AddUserDefDesc('manual'), fontSize);
        jAddUserDefFile = gui_component('MenuItem', [], [], 'Add from file', IconLoader.ICON_EDIT,   [], @(h,ev)AddUserDefDesc('file'),   fontSize);
        jAddUserDefUrl  = gui_component('MenuItem', [], [], 'Add from URL',  IconLoader.ICON_EDIT,   [], @(h,ev)AddUserDefDesc('url'),    fontSize);
        jRmvUserDefMan  = gui_component('MenuItem', [], [], 'Remove plugin', IconLoader.ICON_DELETE, [], @(h,ev)RemoveUserDefDesc,        fontSize);
        % Insert "Add" options at the begining of the 'User defined' menu
        jMenuUserDef.insert(jAddUserDefMan,  0);
        jMenuUserDef.insert(jAddUserDefFile, 1);
        jMenuUserDef.insert(jAddUserDefUrl,  2);
        jMenuUserDef.insert(jRmvUserDefMan,  3);
        jMenuUserDef.insertSeparator(4);
    end
    % List
    if ~isCompiled && isNewMenu
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'List', IconLoader.ICON_EDIT, [], @(h,ev)List('Installed', 1), fontSize);
    end
end


%% ===== MENUS: UPDATE =====
function MenuUpdate(jMenu, fontSize)
    import org.brainstorm.icon.*;
    global GlobalData
    % Get installed and supported plugins
    [PlugsInstalled, PlugsSupported]= GetInstalled();
    % Get previous menu entries
    jPlugs = GlobalData.Program.GUI.pluginMenus;
    % Regenerate plugin menu to look for new plugins
    jPlugs = MenuCreate(jMenu, jPlugs, PlugsSupported, fontSize);
    % Update menu entries
    GlobalData.Program.GUI.pluginMenus = jPlugs;
    % If compiled: disable most menus
    isCompiled = bst_iscompiled();
    % Interface scaling
    InterfaceScaling = bst_get('InterfaceScaling');
    % Update all the plugins
    for iPlug = 1:length(jPlugs)
        j = jPlugs(iPlug);
        PlugName = j.name;
        Plug    = PlugsInstalled(ismember({PlugsInstalled.Name}, PlugName));
        PlugRef = PlugsSupported(ismember({PlugsSupported.Name}, PlugName));
        % Is installed?
        if ~isempty(Plug)
            isInstalled = 1;
        elseif ~isempty(PlugRef)
            Plug = PlugRef;
            isInstalled = 0;
        else
            disp(['BST> Error: Description not found for plugin: ' PlugName]);
            continue;
        end
        isLoaded = isInstalled && Plug.isLoaded;
        isManaged = isInstalled && Plug.isManaged;
        % Compiled included: no submenus
        if isCompiled && (PlugRef.CompiledStatus == 2)
            j.menu.setEnabled(1);
            if (InterfaceScaling ~= 100)
                j.menu.setIcon(IconLoader.scaleIcon(IconLoader.ICON_GOOD, InterfaceScaling / 100));
            else
                j.menu.setIcon(IconLoader.ICON_GOOD);
            end
        % Otherwise: all available
        else
            % Main menu: Available/Not available
            j.menu.setEnabled(isInstalled || ~isempty(Plug.URLzip));
            % Current version
            if ~isInstalled
                j.version.setText('<HTML><FONT color="#707070"><I>Not installed</I></FONT>');
            elseif ~isManaged && ~isempty(Plug.Path)
                j.version.setText('<HTML><FONT color="#707070"><I>Custom install</I></FONT>')
            elseif ~isempty(Plug.Version) && ischar(Plug.Version)
                strVer = Plug.Version;
                % If downloading from github
                if isGithubMaster(Plug.URLzip)
                    % Show installation date, if available
                    if ~isempty(Plug.InstallDate)
                        strVer = Plug.InstallDate(1:11);
                    % Show only the short SHA (7 chars)
                    elseif (length(Plug.Version) >= 30)
                        strVer = Plug.Version(1:7);
                    end
                end
                j.version.setText(['<HTML><FONT color="#707070"><I>Installed version: ' strVer '</I></FONT>'])
            elseif isInstalled
                j.version.setText('<HTML><FONT color="#707070"><I>Installed</I></FONT>');
            end
            % Main menu: Icon
            if isCompiled && isInstalled
                menuIcon = IconLoader.ICON_GOOD;
            elseif isLoaded   % Loaded
                menuIcon = IconLoader.ICON_GOOD;
            elseif isInstalled   % Not loaded
                menuIcon = IconLoader.ICON_BAD;
            else
                menuIcon = IconLoader.ICON_NEUTRAL;
            end
            if (InterfaceScaling ~= 100)
                j.menu.setIcon(IconLoader.scaleIcon(menuIcon, InterfaceScaling / 100));
            else
                j.menu.setIcon(menuIcon);
            end
            % Install
            j.install.setEnabled(~isInstalled);
            if ~isInstalled && ~isempty(PlugRef.Version) && ischar(PlugRef.Version)
                j.install.setText(['<HTML>Install &nbsp;&nbsp;&nbsp;<FONT color="#707070"><I>(' PlugRef.Version ')</I></FONT>'])
            else
                j.install.setText('Install');
            end
            % Update
            j.update.setEnabled(isManaged);
            if isInstalled && ~isempty(PlugRef.Version) && ischar(PlugRef.Version)
                j.update.setText(['<HTML>Update &nbsp;&nbsp;&nbsp;<FONT color="#707070"><I>(' PlugRef.Version ')</I></FONT>'])
            else
                j.update.setText('Update');
            end
            % Uninstall
            j.uninstall.setEnabled(isManaged);
            % Custom install
            j.custom.setEnabled(~isManaged);
            if ~isempty(Plug.Path)
                j.custompath.setText(Plug.Path);
            else
                j.custompath.setText('Path not set');
            end
            % Load/Unload
            j.load.setEnabled(isInstalled && ~isLoaded && ~isCompiled);
            j.unload.setEnabled(isLoaded && ~isCompiled);
            % Web
            j.web.setEnabled(~isempty(Plug.URLinfo));
            % Extra menus: Update availability
            if ~isempty(Plug.ExtraMenus)
                for iMenu = 1:size(Plug.ExtraMenus,1)
                    if (size(Plug.ExtraMenus,2) == 3) && ~isempty(Plug.ExtraMenus{3})
                        if (strcmpi(Plug.ExtraMenus{3}, 'loaded') && isLoaded) ...
                        || (strcmpi(Plug.ExtraMenus{3}, 'installed') && isInstalled) ...
                        || (strcmpi(Plug.ExtraMenus{3}, 'always'))
                            j.extra(iMenu).setEnabled(1);
                        else
                            j.extra(iMenu).setEnabled(0);
                        end
                    end
                end
            end
        end
    end
    j.menu.repaint()
    j.menu.getParent().repaint()
end


%% ===== SET CUSTOM PATH =====
function SetCustomPath(PlugName, PlugPath)
    % Parse inputs
    if (nargin < 2) || isempty(PlugPath)
        PlugPath = [];
    end
    % Custom plugin paths
    PluginCustomPath = bst_get('PluginCustomPath');
    % Get plugin description
    PlugDesc = GetSupported(PlugName);
    if isempty(PlugDesc)
        return;
    end
    % Get installed plugin
    PlugInst = GetInstalled(PlugName);
    isInstalled = ~isempty(PlugInst);
    isManaged = isInstalled && PlugInst.isManaged;
    if isManaged
        bst_error(['Plugin ' PlugName ' is already installed by Brainstorm, uninstall it first.'], 0);
        return;
    end
    % Ask install path to user
    isWarning = 1;
    if isempty(PlugPath)
        PlugPath = uigetdir(PlugInst.Path, ['Select ' PlugName ' directory.']);
        if isequal(PlugPath, 0)
            PlugPath = [];
        end
    % If removal is requested
    elseif isequal(PlugPath, 0)
        PlugPath = [];
        isWarning = 0;
    end
    % If the directory did not change: nothing to do
    if (isInstalled && isequal(PlugInst.Path, PlugPath)) || (~isInstalled && isempty(PlugPath))
        return;
    end   
    % Unload previous version
    if isInstalled && ~isempty(PlugInst.Path) && PlugInst.isLoaded
        Unload(PlugName);
    end
    % Check if this is a valid plugin folder
    if isempty(PlugPath) || ~file_exist(PlugPath)
        PlugPath = [];
    end
    if ~isempty(PlugPath) && ~isempty(PlugDesc.TestFile)
        isValid = 0;
        if file_exist(bst_fullfile(PlugPath, PlugDesc.TestFile))
            isValid = 1;
        elseif ~isempty(PlugDesc.LoadFolders)
            for iFolder = 1:length(PlugDesc.LoadFolders)
                if file_exist(bst_fullfile(PlugPath, PlugDesc.LoadFolders{iFolder}, PlugDesc.TestFile))
                    isValid = 1;
                end
            end
        end
        if ~isValid
            PlugPath = [];
        end
    end
    % Save path
    PluginCustomPath.(PlugName) = PlugPath;
    bst_set('PluginCustomPath', PluginCustomPath);
    % Load plugin
    if ~isempty(PlugPath)
        [isOk, errMsg, PlugDesc] = Load(PlugName);
    % Ignored warnings
    elseif ~isWarning
        isOk = 1;
        errMsg = [];
    % Invalid path
    else
        isOk = 0;
        if ~isempty(PlugDesc.TestFile)
            errMsg = ['The file ' PlugDesc.TestFile ' could not be found in selected folder.'];
        else
            errMsg = 'No valid folder was found.';
        end
    end
    % Handle errors
    if ~isOk
        bst_error(['An error occurred while configuring plugin ' PlugName ':' 10 10 errMsg 10], 'Plugin manager', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Configuration message:' 10 10 errMsg 10], 'Plugin manager');
    elseif isWarning
        java_dialog('msgbox', ['Plugin ' PlugName ' successfully loaded.']);
    end
end


%% ===== ARCHIVE SOFTWARE ENVIRONMENT =====
% USAGE:  Archive(OutputFile=[ask])
function Archive(OutputFile)
    % Parse inputs
    if (nargin < 1) || isempty(OutputFile)
        OutputFile = [];
    end
    % Get date string
    c = clock();
    strDate = sprintf('%02d%02d%02d', c(1)-2000, c(2), c(3));
    % Get output filename
    if isempty(OutputFile)
        % Get default directories
        LastUsedDirs = bst_get('LastUsedDirs');
	    % Default output filename
        OutputFile = bst_fullfile(LastUsedDirs.ExportScript, ['bst_env_' strDate '.zip']);
        % File selection
        OutputFile = java_getfile('save', 'Export environment', OutputFile, 'single', 'files', ...
                                  {{'.zip'}, 'Zip files (*.zip)', 'ZIP'}, 1);
        if isempty(OutputFile)
            return
        end
        % Save new default export path
        LastUsedDirs.ExportScript = bst_fileparts(OutputFile);
        bst_set('LastUsedDirs', LastUsedDirs);
    end

    % ===== TEMP FOLDER =====
    bst_progress('start', 'Export environment', 'Creating temporary folder...');

    % ===== COPY BRAINSTORM =====
    bst_progress('text', 'Copying: brainstorm...');
    % Get Brainstorm path and version
    bstVer = bst_get('Version');
    bstDir = bst_get('BrainstormHomeDir');
    % Create temporary folder for storing all the files to package
    TmpDir = bst_get('BrainstormTmpDir', 0, 'bstenv');
    % Get brainstorm3 destination folder: add version number
    if ~isempty(bstVer.Version) && ~any(bstVer.Version == '?')
        envBst = bst_fullfile(TmpDir, ['brainstorm', bstVer.Version]);
    else
        [tmp, bstName] = bst_fileparts(bstDir);
        envBst = bst_fullfile(TmpDir, bstName);
    end
    % Add git commit hash
    if (length(bstVer.Commit) >= 30)
        envBst = [envBst, '_', bstVer.Commit(1:7)];
    end
    % Copy brainstorm3 folder
    isOk = file_copy(bstDir, envBst);
    if ~isOk
        error(['Cannot copy folder: "' bstDir '" to "' envBst '"']);
    end

    % ===== COPY DEFAULTS =====
    bst_progress('text', 'Copying: user defaults...');
    % Get user defaults folder
    userDef = bst_get('UserDefaultsDir');
    envDef = bst_fullfile(envBst, 'defaults');
    isOk = file_copy(userDef, envDef);
    if ~isOk
        error(['Cannot merge folder: "' userDef '" into "' envDef '"']);
    end   

    % ===== COPY USER PROCESSES =====
    bst_progress('text', 'Copying: user processes...');
    % Get user process folder
    userProc = bst_get('UserProcessDir');
    envProc = bst_fullfile(envBst, 'toolbox', 'process', 'functions');
    isOk = file_copy(userProc, envProc);
    if ~isOk
        error(['Cannot merge folder: "' userProc '" into "' envProc '"']);
    end
    
    % ===== COPY PLUGINS ======
    % Get list of plugins to package
    PlugDesc = GetInstalled();
    % Destination plugin directory
    envPlugins = bst_fullfile(envBst, 'plugins');
    % Copy each installed plugin
    for iPlug = 1:length(PlugDesc)
        bst_progress('text', ['Copying plugin: ' PlugDesc(iPlug).Name '...']);
        envPlug = bst_fullfile(envPlugins, PlugDesc(iPlug).Name);
        isOk = file_copy(PlugDesc(iPlug).Path, envPlug);
        if ~isOk
            error(['Cannot copy folder: "' PlugDesc(iPlug).Path '" into "' envProc '"']);
        end
    end
    % Copy user-defined JSON files
    PlugJson = dir(fullfile(bst_get('UserPluginsDir'), 'plugin_*.json'));
    for iPlugJson = 1:length(PlugJson)
        bst_progress('text', ['Copying use-defined plugin JSON file: ' PlugJson(iPlugJson).name '...']);
        plugJsonFile = bst_fullfile(PlugJson(iPlugJson).folder, PlugJson(iPlugJson).name);
        envPlugJson = bst_fullfile(envPlugins, PlugJson(iPlugJson).name);
        isOk = file_copy(plugJsonFile, envPlugJson);
        if ~isOk
            error(['Cannot copy file: "' plugJsonFile '" into "' envProc '"']);
        end
    end

    % ===== SAVE LIST OF VERSIONS =====
    strList = bst_plugin('List', 'installed', 0);
    % Open file versions.txt
    VersionFile = bst_fullfile(TmpDir, 'versions.txt');
    fid = fopen(VersionFile, 'wt');
    if (fid < 0)
        error(['Cannot save file: ' VersionFile]);
    end
    % Save Brainstorm plugins list
    fwrite(fid, strList);
    % Save Matlab ver command
    strMatlab = evalc('ver');
    fwrite(fid, [10 10 strMatlab]);
    % Close file
    fclose(fid);

    % ===== ZIP FILES =====
    bst_progress('text', 'Zipping environment...');
    % Zip files with bst_env_* being the first level
    zip(OutputFile, TmpDir, bst_fileparts(TmpDir));
    % Delete the temporary files
    file_delete(TmpDir, 1, 1);
    % Close progress bar
    bst_progress('stop');
end


%% ============================================================================
%  ===== PLUGIN-SPECIFIC FUNCTIONS ============================================
%  ============================================================================

%% ===== LINK CAT-SPM =====
% USAGE: bst_plugin('LinkCatSpm', Action)               
%        0=Delete/1=Create/2=Check a symbolic link for CAT12 in SPM12 toolbox folder
function LinkCatSpm(Action)
    % Get SPM12 plugin
    PlugSpm = GetInstalled('spm12');
    if isempty(PlugSpm)
        error('Plugin SPM12 is not loaded.');
    elseif ~PlugSpm.isLoaded
        [isOk, errMsg, PlugSpm] = Load('spm12');
        if ~isOk
            error('Plugin SPM12 cannot be loaded.');
        end
    end
    % Get SPM plugin path
    if ~isempty(PlugSpm.SubFolder)
        spmToolboxDir = bst_fullfile(PlugSpm.Path, PlugSpm.SubFolder, 'toolbox');
    else
        spmToolboxDir = bst_fullfile(PlugSpm.Path, 'toolbox');
    end
    if ~file_exist(spmToolboxDir)
        error(['Could not find SPM12 toolbox folder: ' spmToolboxDir]);
    end
    % CAT12 plugin path
    spmCatDir = bst_fullfile(spmToolboxDir, 'cat12');
    % Check link
    if (Action == 2)
        % Link exists and works: return here
        if file_exist(bst_fullfile(spmCatDir, 'cat12.m'))
            return;
        % Link doesn't exist: Create it
        else
            Action = 1;
        end
    end
    % If folder already exists
    if file_exist(spmCatDir)
        % If setting install and SPM is not managed by Brainstorm: do not risk deleting user's install of CAT12
        if (Action == 1) && ~PlugSpm.isManaged
            error(['CAT12 seems already set up: ' spmCatDir]);
        end
        % All the other cases: delete existing CAT12 folder
        if ispc
            rmCall = ['rmdir /q /s "' spmCatDir '"'];
        else
            rmCall = ['rm -rf "' spmCatDir '"'];
        end
        disp(['BST> Deleting existing SPM12 toolbox: ' rmCall]);
        [status,result] = system(rmCall);
        if (status ~= 0)
            error(['Error deleting link: ' result]);
        end
    end
    % Create new link
    if (Action == 1)
        % Get CAT12 plugin
        PlugCat = GetInstalled('cat12');
        if isempty(PlugCat) || ~PlugCat.isLoaded
            error('Plugin CAT12 is not loaded.');
        end
        % Return if installation is not complete yet (first load before installation ends)
        if isempty(PlugCat.InstallDate)
            return
        end
        % Define source and target for the link
        if ~isempty(PlugCat.SubFolder)
            linkTarget = bst_fullfile(PlugCat.Path, PlugCat.SubFolder);
        else
            linkTarget = PlugCat.Path;
        end
        linkFile = spmCatDir;
        % Create link
        if ispc
            linkCall = ['mklink /D "' linkFile '" "' linkTarget '"'];
        else
            linkCall = ['ln -s "' linkTarget '" "' linkFile '"'];
        end
        disp(['BST> Creating symbolic link: ' linkCall]);
        [status,result] = system(linkCall);
        if (status ~= 0)
            error(['Error creating link: ' result]);
        end
    end
end


%% ===== SET PROGRESS LOGO =====
% USAGE:  SetProgressLogo(PlugDesc/PlugName)  % Set progress bar image
%         SetProgressLogo([])                 % Remove progress bar image
function SetProgressLogo(PlugDesc)
    % Remove image
    if (nargin < 1) || isempty(PlugDesc)
        bst_progress('removeimage');
        bst_progress('removelink');
    % Set image
    else
        % Get plugin description
        if ischar(PlugDesc)
            PlugDesc = GetSupported(PlugDesc);
        end
        % Set logo file
        if isempty(PlugDesc.LogoFile)
            PlugDesc.LogoFile = GetLogoFile(PlugDesc);
        end
        if ~isempty(PlugDesc.LogoFile)
            bst_progress('setimage', PlugDesc.LogoFile);
        end
        % Set link
        if ~isempty(PlugDesc.URLinfo)
            bst_progress('setlink', PlugDesc.URLinfo);
        end
    end
end


%% ===== NOT SUPPORTED APPLE SILICON =====
% Return list of plugins not supported on Apple silicon
function pluginNames = PluginsNotSupportAppleSilicon()
    pluginNames = { 'duneuro', 'mcxlab-cuda'};
end
