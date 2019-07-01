function [errMsg, warnMsg, version, last_update]   =   be_install( varargin ) 


%% ===== DOWNLOAD SETTINGS =====
% Not available in the compiled version
if (exist('isdeployed', 'builtin') && isdeployed)
    error('This function is not available in the compiled version of Brainstorm.');
end
% Get openmeeg folder
errMsg  = '';
BEstDir = bst_fullfile( bst_get('BrainstormUserDir'), 'brainentropy' );
BEstBST = bst_fullfile( bst_get('BrainstormHomeDir'), 'external', 'brainentropy' ); 
% Set file url - temporary
url = 'https://github.com/multi-funkim/best-brainstorm/archive/2.7.1.tar.gz';
urlV= 'https://raw.githubusercontent.com/multi-funkim/best-brainstorm/master/best/VERSION.txt';

try
    addpath( genpath(BEstDir) );
    be_main_call('cMEM');
    FORCE   =   0;
catch
    FORCE   =   1;
end


%% ===== PROCESS INPUTS =====
if numel(varargin)>0
    FORCE   =   varargin{1};
end

%% ===== CHECK VERSION =====
dispMsg     =   '';
warnMsg     =   '';
oldVer      =   {'not found'};
version     =   'unknown';
last_update =   'unknown';
try
    oldVer          =   textread( fullfile(BEstDir, 'best','VERSION.txt'), '%s', 'delimiter', '\n', 'whitespace', '' );
    version         =   oldVer{1};
    last_update     =   oldVer{2};
end
if ~FORCE
    % Download file
	verFile         = bst_fullfile(BEstDir, 'VERSION.txt');
    file_delete(verFile, 1);
    warnMsg         = gui_brainstorm('DownloadFile', urlV, verFile, 'Brainentropy update');
    
    % If file was not downloaded correctly
    if isempty(warnMsg)
        % Compare the two versions
        % THIS HAS TO BE CHECKED
        newVer  =   textread( verFile, '%s', 'delimiter', '\n', 'whitespace', '' );        
        
        % This won't raise an error if declined, just a warning
        FORCE   =   ~strcmp(newVer{1}, version) * 2;  
        if numel(newVer)>2
            dispMsg     =   cellfun( @(a) [a 10], newVer(3:end), 'uni', 0 );
            dispMsg     =   [10 10 dispMsg{:}];
        end
    else
        warnMsg =   'Could not check BEst version, internet connection needed';
    end
        
end

%% ===== DOWNLOAD BrainEntropy =====

% If binary file doesnt exist: download
if ~isdir(BEstDir) || isempty(ls(BEstDir)) || FORCE 
    
    % Set download msg
    updMsg = ['BrainEntropy software is not installed on your computer.' 10 10 'Download the latest version?'];
    if FORCE==2
        updMsg = ['BrainEntropy software is out-of-date.' 10 10 'Download the latest version?' dispMsg];
    end
    % Download file from URL if not done already by user Message
    isOk = java_dialog('confirm', updMsg, 'BEst');
    if ~isOk
        if FORCE==2
            warnMsg     = 'Update declined by user';
        elseif FORCE==1
            errMsg      = 'Installation cancelled by user';
        end
        return;
    end
    
    % If folder exists: delete
    if isdir(BEstDir)
        warning('OFF')
        file_delete(BEstDir, 1, 3);
        warning('ON')
    end
    % Create folder
    res = mkdir(BEstDir);
    if ~res
        errMsg = ['Error: Cannot create folder' BEstDir];
        return
    end
    
    % Download file
    tgzFile = bst_fullfile(BEstDir, 'brainentropy.tar.gz');
    errMsg = gui_brainstorm('DownloadFile', url, tgzFile, 'Brainstorm update');
    % If file was not downloaded correctly
    if ~isempty(errMsg)
        errMsg = ['Impossible to download BEst: ' 10 errMsg];
        return
    end

    % Display again progress bar
    bst_progress('start', 'BrainEntropy', 'Installing BrainEntropy...');
    % Unzip file
    if ispc
        untar(tgzFile, BEstDir);
    else
        curdir = pwd;
        cd(fileparts(tgzFile));
        system(['tar -xf ' tgzFile]);
        cd(curdir);
    end
    % Delete files
    file_delete(tgzFile, 1);  
    if file_exist(fullfile(BEstDir, 'pax_global_header'))
        file_delete(fullfile(BEstDir, 'pax_global_header'), 1);
    end
    file_move(fullfile(BEstDir, 'best-brainstorm-2.7.1', '*'), fullfile(BEstDir));
    file_delete(fullfile(BEstDir, 'best-brainstorm-2.7.1'), 1, 3);
    
    % Move process to appropriate location
    file_copy( fullfile(BEstDir, 'processes', '*'), fullfile( strrep(BEstDir, 'brainentropy', 'process') ) );
        
    % Make sure version is updated in the package 
    % Download file
    verFile         =   bst_fullfile(BEstDir, 'VERSION.txt');
    file_delete(verFile, 1);
    warnMsg         =   gui_brainstorm('DownloadFile', urlV, verFile, 'Brainentropy update');
    newVer          =   textread( verFile, '%s', 'delimiter', '\n', 'whitespace', '' );
    file_move( verFile, fullfile(BEstDir, 'best','VERSION.txt') );
    
    % Set ouput arguments
    try
        version         =   newVer{1};
        last_update     =   newVer{2};
    catch
        warnMsg         =   'Cannot read version of last update date from VERSION.txt. This file might be corrupted';
    end
    
end

% Clean after update
if exist( bst_fullfile(BEstDir, 'VERSION.txt'), 'file' )
    file_delete( bst_fullfile(BEstDir, 'VERSION.txt'), 1 );
end

% Add to path
addpath( genpath(BEstDir) );

bst_progress('stop');

return
