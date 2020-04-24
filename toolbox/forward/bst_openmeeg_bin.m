function [Gain, errMsg] = bst_openmeeg_bin(OPTIONS)
% BST_OPENMEEG: Call OpenMEEG to compute a BEM solution for Brainstorm.
%
% USAGE:  [Gain, errMsg] = bst_openmeeg(OPTIONS)
%                          bst_openmeeg('update')
%
% INPUT: 
%     - OPTIONS: structure with the following fields
%        |- MEGMethod    : 'openmeeg', else ignored
%        |- EEGMethod    : 'openmeeg', else ignored
%        |- ECOGMethod   : 'openmeeg', else ignored
%        |- SEEGMethod   : 'openmeeg', else ignored
%        |- Channel      : Brainstorm channel structure
%        |- iMeg         : Indices of MEG sensors in the Channel structure
%        |- iEeg         : Indices of EEG sensors in the Channel structure
%        |- BemFiles     : [1,nLayers] Cell array of filenames
%        |- BemNames     : [1,nLayers] Cell array of layer names
%        |- BemCond      : [1,nLayers] Array of layer conductivities
%        |- GridLoc      : Dipoles locations
%        |- isAdjoint    : If 1, use adjoint formulation (less memory, longer)
%        |- isAdaptative : If 1, use adaptive integration (more accurate, 3x longer)
%        |- Interactive  : If 0, do not display any confirmation or error message

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
% Authors: Francois Tadel & Alexandre Gramfort, 2011-2013


%% ===== PARSE INPUTS =====
% Is trying to update the program
isUpdate = isequal(OPTIONS, 'update');
% Intialize variables
Gain = [];
errMsg = '';
% Save current folder
curdir = pwd;


%% ===== DOWNLOAD OPENMEEG =====
% Get openmeeg folder
osType = bst_get('OsType', 0);
OpenmeegDir = bst_fullfile(bst_get('BrainstormUserDir'), 'openmeeg', osType);
urlFile = bst_fullfile(OpenmeegDir, 'url');
% Force manual update: select tar.gz file
if isUpdate
    % Display information message
    java_dialog('msgbox', 'Please select the package (.tar.gz) download from the OpenMEEG website.', 'Install OpenMEEG');
    % Ask for file to install
    tgzFile = java_getfile('open', 'Select OpenMEEG package', '', 'single', 'files', ...
                           {{'.gz','.tgz'}, 'OpenMEEG package (*.tar.gz)', 'TGZ'}, 1);
    if isempty(tgzFile)
        return
    end
else
    tgzFile = [];
end
% Get default url
switch(osType)
    case 'linux32',  url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-Linux32.i386-gcc-4.3.2-static.tar.gz';
    case 'linux64',  url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-Linux64.amd64-gcc-4.3.2-OpenMP-static.tar.gz';
    case 'mac32',    url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-MacOSX-Intel-gcc-4.2.1-static.tar.gz';
    case 'mac64',    url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-MacOSX-Intel-gcc-4.2.1-static.tar.gz';
    case 'sol64',    error('Solaris system is not supported');
    case 'win32',    url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-win32-x86-cl-OpenMP-shared.tar.gz';
    case 'win64',    url = 'http://openmeeg.gforge.inria.fr/download/release-2.2/OpenMEEG-2.2.0-win64-x86_64-cl-OpenMP-shared.tar.gz';
    otherwise,       error('OpenMEEG software does not exist for your operating system.');
end
% Read the previous download url information
if isdir(OpenmeegDir) && file_exist(urlFile)
    fid = fopen(urlFile, 'r');
    prevUrl = fread(fid, [1 Inf], '*char');
    fclose(fid);
else
    prevUrl = '';
end
% If binary file doesnt exist: download
if ~isdir(OpenmeegDir) || isempty(dir(bst_fullfile(OpenmeegDir, 'om_gain*'))) || ~strcmpi(prevUrl, url) || isUpdate
    % If folder exists: delete
    if isdir(OpenmeegDir)
        file_delete(OpenmeegDir, 1, 3);
    end
    % Create folder
    res = mkdir(OpenmeegDir);
    if ~res
        errMsg = ['Error: Cannot create folder' 10 OpenmeegDir];
        return
    end
    % Download file from URL if not done already by user
    if isempty(tgzFile)
        % Message
        if OPTIONS.Interactive
            isOk = java_dialog('confirm', ...
                ['OpenMEEG software is not installed on your computer (or out-of-date).' 10 10 ...
                 'Download and the latest version?'], 'OpenMEEG');
            if ~isOk
                return;
            end
        end
        % Download file
        tgzFile = bst_fullfile(OpenmeegDir, 'openmeeg.tar.gz');
        errMsg = gui_brainstorm('DownloadFile', url, tgzFile, 'OpenMEEG update');
        % If file was not downloaded correctly
        if ~isempty(errMsg)
            errMsg = ['Impossible to download OpenMEEG:' 10 errMsg];
            return;
        end
    % Copy TGZ file to download folder
    else
        origTgzFile = tgzFile;
        [fPath, fName, fExt] = bst_fileparts(origTgzFile);
        tgzFile = bst_fullfile(OpenmeegDir, [fName, fExt]);
        file_copy(origTgzFile, tgzFile);
    end
    % Display again progress bar
    bst_progress('start', 'OpenMEEG', 'Installing OpenMEEG...');
    % Unzip file
    if ispc
        untar(tgzFile, OpenmeegDir);
    else
        cd(fileparts(tgzFile));
        system(['tar -xf ' tgzFile]);
        cd(curdir);
    end
    % Get parent folder of the unzipped files
    diropen = dir(fullfile(OpenmeegDir, 'OpenMEEG*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    unzipDir = bst_fullfile(OpenmeegDir, diropen(idir).name);
    % Move all files to OpenmeegDir
    file_move(bst_fullfile(unzipDir, 'bin', '*'), OpenmeegDir);
    file_move(bst_fullfile(unzipDir, 'lib', '*'), OpenmeegDir);
    try
        file_move(bst_fullfile(unzipDir, 'doc', '*'), OpenmeegDir);
    catch
    end
    % Delete files
    file_delete({tgzFile, unzipDir}, 1, 3);
    % Save download URL in OpenMEEG folder
    fid = fopen(urlFile, 'w');
    fwrite(fid, url);
    fclose(fid);
end
% If only updating: exit
if isUpdate
    bst_progress('stop');
    return;
end


%% ===== OPENMEEG LIBRARY PATH =====
% Progress bar
bst_progress('text', 'OpenMEEG', 'OpenMEEG: Initialization...');
bst_progress('setimage', 'logo_openmeeg.gif');
bst_progress('setlink', 'http://openmeeg.github.io');
% Library path
if ~ispc
    if ismember(osType, {'linux32', 'linux64', 'sol64'})
        varname = 'LD_LIBRARY_PATH';
    else
        varname = 'DYLD_LIBRARY_PATH';
    end
    libpath = getenv(varname);
    if ~isempty(libpath)
        libpath = [libpath ':'];
    end
    setenv(varname, [libpath  OpenmeegDir]);
end
% Set number of cores used
try
    numcores = feature('numcores');
catch 
    numcores = 4;
end
setenv('OMP_NUM_THREADS', num2str(numcores));


%% ===== PREPARE GEOMETRY =====
nv = size(OPTIONS.GridLoc, 1);
isEeg  = strcmpi(OPTIONS.EEGMethod, 'openmeeg')  && ~isempty(OPTIONS.iEeg);
isMeg  = strcmpi(OPTIONS.MEGMethod, 'openmeeg')  && ~isempty(OPTIONS.iMeg);
isEcog = strcmpi(OPTIONS.ECOGMethod, 'openmeeg') && ~isempty(OPTIONS.iEcog);
isSeeg = strcmpi(OPTIONS.SEEGMethod, 'openmeeg') && ~isempty(OPTIONS.iSeeg);
% Get temp folder
TmpDir = bst_get('BrainstormTmpDir');
% Open log file
logFile = bst_fullfile(TmpDir, 'openmeeg_log.txt');
fid_log = fopen(logFile, 'w');
% Filenames
geomfile     = bst_fullfile(TmpDir, 'openmeeg.geom');
condfile     = bst_fullfile(TmpDir, 'openmeeg.cond');
dipfile      = bst_fullfile(TmpDir, 'openmeeg_dipoles.txt');
dsmfile      = bst_fullfile(TmpDir, 'openmeeg_dsm.bin');
% EEG
eegloc_file  = bst_fullfile(TmpDir, 'openmeeg_loc_eeg.txt');
h2emfile     = bst_fullfile(TmpDir, 'openmeeg_h2em.bin');
eeggain_file = bst_fullfile(TmpDir, 'openmeeg_gain_eeg.bin');
% MEG
megloc_file  = bst_fullfile(TmpDir, 'openmeeg_loc_meg.squids');
h2mmfile     = bst_fullfile(TmpDir, 'openmeeg_h2mm.bin');
ds2megfile   = bst_fullfile(TmpDir, 'openmeeg_ds2meg.bin');
meggain_file = bst_fullfile(TmpDir, 'openmeeg_gain_meg.bin');
% ECOG
ecogloc_file = bst_fullfile(TmpDir, 'openmeeg_loc_ecog.txt');
h2ecogmfile  = bst_fullfile(TmpDir, 'openmeeg_h2ecogm.bin');
ecoggain_file= bst_fullfile(TmpDir, 'openmeeg_gain_ecog.bin');
% SEEG
seegloc_file = bst_fullfile(TmpDir, 'openmeeg_loc_seeg.txt');
h2ipmfile    = bst_fullfile(TmpDir, 'openmeeg_h2ipm.bin');
ds2ipmfile   = bst_fullfile(TmpDir, 'openmeeg_ds2ipm.bin');
seeggain_file= bst_fullfile(TmpDir, 'openmeeg_gain_seeg.bin');

% Write BEM layers files
trifiles = {};
nVert    = [];
nFaces   = [];
for i = 1:length(OPTIONS.BemFiles)
    % Output MESH file
    trifiles{i} = bst_fullfile(TmpDir, sprintf('openmeeg_%d.tri', i));
    % Write MESH in tmp folder
    [nVert(i),nFaces(i)] = out_tess_tri(OPTIONS.BemFiles{i}, trifiles{i}, 1);
end
% Write geometry file
om_write_geom(geomfile, trifiles, OPTIONS.BemNames);
% Write conductivities file
om_write_cond(condfile, OPTIONS.BemCond, OPTIONS.BemNames);
% Write dipoles file
dipdata = [kron(OPTIONS.GridLoc,ones(3,1)), kron(ones(nv,1), eye(3))];
save(dipfile, 'dipdata', '-ASCII', '-double');  
% Go to openmeeg folder
cd(OpenmeegDir);
%system(['cd "' OpenmeegDir '"']);


%% ===== GET EXISTING HM FILE =====
% Compute signature of current combination of files
sig = [num2str(OPTIONS.isAdjoint), sprintf('_%1.07f',OPTIONS.BemCond)];
for i = 1:length(OPTIONS.BemFiles)
    fileinfo = dir(OPTIONS.BemFiles{i});
    sig = [sig '_' fileinfo.name '_' num2str(nVert(i)), '_' num2str(nFaces(i))];
end
% Inner skull file
InnerSkullFile = OPTIONS.BemFiles{end};
% Load file
warning off
TessMat = load(InnerSkullFile, 'OpenMEEG');
warning on
% If HM-FILE file already exists and signature matches
hminvfile = '';
hmfile = '';
if isfield(TessMat, 'OpenMEEG') && ~isempty(TessMat.OpenMEEG) && isfield(TessMat.OpenMEEG, 'HmFile') && ~isempty(TessMat.OpenMEEG.HmFile) && isequal(TessMat.OpenMEEG.Signature, sig)
    tmpfile = bst_fullfile(bst_fileparts(InnerSkullFile), TessMat.OpenMEEG.HmFile);
    if file_exist(tmpfile)
        if OPTIONS.isAdjoint 
            hmfile = tmpfile;
        else
            hminvfile = tmpfile;
        end
    end
end


%% ===== COMPUTE HM-INV FILE =====
if isempty(hminvfile) && isempty(hmfile)
    % Filenames
    if OPTIONS.isAdjoint
        hmfile = strrep(InnerSkullFile, '.mat', '_openmeeg.bin');
        [tmp__, fBase, fExt] = bst_fileparts(hmfile);
    else
        hmfile = bst_fullfile(TmpDir, 'openmeeg_hm.bin');
        hminvfile = strrep(InnerSkullFile, '.mat', '_openmeeg.bin');
        [tmp__, fBase, fExt] = bst_fileparts(hminvfile);
    end
    % === BUILD HM FILE ===
    % Build HM file
    if ~om_call('om_assemble -HM', ['"' geomfile '" "' condfile '"'], hmfile, 'Assembling head matrix...')
        return;
    end
    % === INVERSE HM ===
    if ~OPTIONS.isAdjoint
        if ~om_call('om_minverser', ['"' hmfile '"'], hminvfile, 'Inverting head matrix...')
            return;
        end
    end
    % === ADD REFERENCE IN INNER SKULL ===
    % Build reference structure
    OpenMEEG.HmFile = [fBase, fExt];
    OpenMEEG.Signature = sig;
    % Add it to inner skull file
    s.OpenMEEG = OpenMEEG;
    bst_save(InnerSkullFile, s, 'v7', 1);
end


%% ===== COMPUTE DSM =====
% Only needed in the non-adjoint mode
if ~OPTIONS.isAdjoint
    % Adaptative?
    if OPTIONS.isAdaptative
        strDsm = '-DSM';
    else
        strDsm = '-DSMNA';
    end
    % Call OpenMEEG function for computing DSM
    if ~om_call(['om_assemble ' strDsm], ['"' geomfile '" "' condfile '" "' dipfile '"'], dsmfile, 'Assembling dipoles source matrix...')
        return;
    end
end


%% ===== INTERPOLATION OPERATOR =====
% === EEG ===
if isEeg
    % Save electrodes file
    eegloc = cat(2, OPTIONS.Channel(OPTIONS.iEeg).Loc)';
    save(eegloc_file, 'eegloc', '-ASCII', '-double');
    % Compute HE2EM
    if ~om_call('om_assemble -H2EM', ['"' geomfile '" "' condfile '" "' eegloc_file '"'], h2emfile, 'Assembling EEG interpolation operator...')
        return;
    end
end
% === MEG ===
if isMeg
    % Save electrodes file
    fid = fopen(megloc_file, 'w');
    for iChan = 1:length(OPTIONS.iMeg)
        sChan = OPTIONS.Channel(OPTIONS.iMeg(iChan));
        for iInteg = 1:size(sChan.Loc, 2)
            fprintf(fid, '%d %g %g %g %g %g %g %g %g', iChan, sChan.Loc(:,iInteg)', sChan.Orient(:,iInteg)', sChan.Weight(iInteg));
            fprintf(fid, '\n');
        end
    end
    fclose(fid);
    % Compute H2MM
    if ~om_call('om_assemble -H2MM', ['"' geomfile '" "' condfile '" "' megloc_file '"'], h2mmfile, 'Assembling MEG interpolation operator...')
        return;
    end
end
% === ECOG ===
if isEcog
    % Save electrodes file
    ecogloc = cat(2, OPTIONS.Channel(OPTIONS.iEcog).Loc)';
    save(ecogloc_file, 'ecogloc', '-ASCII', '-double');
    % Compute H2ECOGM
    if ~om_call('om_assemble -H2ECOGM', ['"' geomfile '" "' condfile '" "' ecogloc_file '"'], h2ecogmfile, 'Assembling ECOG interpolation operator...')
        return;
    end
end
% === SEEG ===
if isSeeg
    % Save electrodes file
    seegloc = cat(2, OPTIONS.Channel(OPTIONS.iSeeg).Loc)';
    save(seegloc_file, 'seegloc', '-ASCII', '-double');
    % Compute H2IPM 
    if ~om_call('om_assemble -H2IPM', ['"' geomfile '" "' condfile '" "' seegloc_file '"'], h2ipmfile, 'Assembling SEEG interpolation operator...')
        return;
    end
end



%% ===== LEADFIELD COMPUTATION =====
% Initializations
Gain = NaN * zeros(length(OPTIONS.Channel), 3 * nv);
% === EEG ===
if isEeg
    % Compute EEG leadfield
    if  OPTIONS.isAdjoint
        res = om_call('om_gain -EEGadjoint', ['"' geomfile '" "' condfile '" "' dipfile '" "' hmfile '" "' h2emfile '"'], eeggain_file, 'Assembling EEG leadfield...');
    else
        res = om_call('om_gain -EEG', ['"' hminvfile '" "' dsmfile '" "' h2emfile '"'], eeggain_file, 'Assembling EEG leadfield...');
    end
    if ~res
        return;
    end
    % Read EEG leadfield
    bst_progress('text', 'OpenMEEG: Reading EEG leadfield...');
    Gain(OPTIONS.iEeg, :) = om_load_full(eeggain_file);
end
% === MEG ===
if isMeg
    % Compute DS2MM
    if ~om_call('om_assemble -DS2MM', [' "' dipfile '" "' megloc_file '"'], ds2megfile, 'Assembling MEG dipoles source matrix...')
        return
    end
    % Compute MEG leadfield
    if OPTIONS.isAdjoint
        res = om_call('om_gain -MEGadjoint', ['"' geomfile '" "' condfile '" "' dipfile '" "' hmfile '" "' h2mmfile '" "' ds2megfile '"'], meggain_file, 'Assembling MEG leadfield...');
    else
        res = om_call('om_gain -MEG', ['"' hminvfile '" "' dsmfile '" "' h2mmfile '" "' ds2megfile '"'], meggain_file, 'Assembling MEG leadfield...');
    end
    if ~res
        return
    end
    % Read MEG leadfield
    bst_progress('text', 'OpenMEEG: Reading MEG leadfield...');
    Gain(OPTIONS.iMeg, :) = om_load_full(meggain_file);
end
% === ECOG ===
if isEcog
    % Compute ECOG leadfield
    if ~om_call('om_gain -EEG', ['"' hminvfile '" "' dsmfile '" "' h2ecogmfile '"'], ecoggain_file, 'Assembling ECOG leadfield...')
        return
    end
    % Read ECOG leadfield
    bst_progress('text', 'OpenMEEG: Reading ECOG leadfield...');
    Gain(OPTIONS.iEcog, :) = om_load_full(ecoggain_file);
end
% === SEEG ===
if isSeeg
    % Compute DS2IPM
    if ~om_call('om_assemble -DS2IPM', ['"' geomfile '" "' condfile '" "' dipfile '" "' seegloc_file '"'], ds2ipmfile, 'Assembling SEEG sensor matrix...')
        return
    end
    % Compute SEEG leadfield
    if ~om_call('om_gain -IP', ['"' hminvfile '" "' dsmfile '" "' h2ipmfile '" "' ds2ipmfile '"'], seeggain_file, 'Assembling SEEG leadfield...')
        return
    end
    % Read SEEG leadfield
    bst_progress('text', 'OpenMEEG: Reading SEEG leadfield...');
    Gain(OPTIONS.iSeeg, :) = om_load_full(seeggain_file);
end


%% ===== CLEANUP =====
bst_progress('text', 'OpenMEEG: Emptying temporary folder...');
% Close log file
if ~isempty(fid_log) && (fid_log >= 0) && ~isempty(fopen(fid_log))
    fclose(fid_log);
end
% Go back to initial folder
cd(curdir);
% Delete intermediary files
allfiles = setdiff({geomfile, condfile, dipfile, dsmfile, ...
                    eegloc_file, h2emfile, eeggain_file, ...
                    megloc_file, h2mmfile, ds2megfile, meggain_file, ...
                    ecogloc_file, h2ecogmfile, ecoggain_file, ...
                    seegloc_file, h2ipmfile, ds2ipmfile, seeggain_file}, {''});
if ~OPTIONS.isAdjoint && ~isempty(hmfile)
    allfiles{end+1} = hmfile;
end
file_delete(cat(2, trifiles, allfiles), 1);
% Remove OpenMEEG image
bst_progress('removeimage');




%% =================================================================================
%  ===== HELPER FUNCTIONS ==========================================================
%  =================================================================================
    %% ===== OPENMEEG CALL =====
    function isOk = om_call(omFunc, omInput, omOutput, strProgress)
        % Progress bar
        bst_progress('text', ['OpenMEEG: ' strProgress]);
        % System call
        strCall = [omFunc ' ' omInput ' "' omOutput '"'];
        [status, result] = bst_system(strCall);
        % Append to log file file
        if ~isempty(fid_log) && (fid_log >= 0) && ~isempty(fopen(fid_log))
            fwrite(fid_log, [result 10 10], 'char');
        end
        % If OpenMEEG returned an error
        if (status ~= 0)
            % Detail error
            errMsg = ['OpenMEEG call: ',  strrep(strCall, ' "', [10 '      "']),  10 10 ...
                      'OpenMEEG error #' num2str(status) ': ' 10 result 10 10 ...
                      'Many OpenMEEG crashes are due to a lack of memory.' 10 ...
                      'Reduce the number of vertices on each BEM layer and try again.'];
            % Check status for standard errors
            if (status == -1073741515)
                errMsg = [errMsg 10 'This error is probably due to incompatible binaries or missing libraries.' 10 ...
                          ' 1) Win64 users: Try installing the Visual C++ libraries:' 10 ...
                          '       Help> Update OpenMEEG> Download Visual C++' 10 ...
                          ' 2) Try installing a different OpenMEEG package:' 10 ...
                          '       Help> Update OpenMEEG> Download/Install' 10 ...
                          ' 3) Read the forum posts listed on the tutorial page:' 10 ...
                          '       Help> Update OpenMEEG> OpenMEEG help'];

            end
            isOk = 0;
        % If there was no error but the output file was not generated: probably a system crash
        elseif ~isempty(omOutput) && ~file_exist(omOutput)
            % Detail error
            errMsg = ['OpenMEEG call: ',  strrep(strCall, ' "', [10 '      "']),  10 10 ...
                      'OpenMEEG crashed and did not return an error code.' 10 10 ...
                'One common cause for this error type is a lack of memory.' 10 ...
                'First, make sure that the default surfaces to use and the sensors are defined correctly.' 10 ...
                'Then try to decrease the number of vertices used for the different layers' 10 ...
                '(for instance 600 or 1000 per surface instead of the default value 1922).' 10 10 ...
                'If the computation finishes with less vertices, it is a memory issue.'];
            isOk = 0;
        else
            isOk = 1;
        end
        % If an error occurred: restore folder and return an empty matrix
        if ~isOk
            cd(curdir);
            Gain = [];
            if ~isempty(fid_log) && (fid_log >= 0) && ~isempty(fopen(fid_log))
                fclose(fid_log);
            end
        end
    end
end


%% ===== SYSTEM CALL =====
function [status, result] = bst_system(strcall)
    % Non-windows systems: add "./" in front of the commands to execute
    if ~ispc
        strcall = ['./' strcall]; 
    end
    % Call
    if isunix
        % If tcsh: stderr and stdout are redirected to the same place anyway
        if ~isempty(strfind(getenv('SHELL'), 'csh'))
            [status, result] = system(strcall);
        else
            [status, result] = system([strcall ' 2>&1']);
        end
    else
        [status, result] = system([strcall ' 2>&1']);
    end
end


%% ===== LOAD FULL MATRIX =====
function data = om_load_full(filename)
    file = fopen(filename,'r');
    dims = fread(file,2,'uint32','ieee-le');
    data = fread(file,prod(dims),'double','ieee-le');
    data = reshape(data,dims');
    fclose(file);
end


    
    
