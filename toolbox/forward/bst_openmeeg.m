function [Gain, errMsg] = bst_openmeeg(OPTIONS)
% BST_OPENMEEG: Call OpenMEEG to compute a BEM solution for Brainstorm.
%
% USAGE:  [Gain, errMsg] = bst_openmeeg(OPTIONS)
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
% Authors: Francois Tadel & Alexandre Gramfort, 2011-2021


%% ===== PARSE INPUTS =====

% Intialize variables
Gain = [];
errMsg = '';
% Save current folder
curdir = pwd;

%% ===== SET UP OPENMEEG =====
% Install/Load OpenMEEG
[isOk, errMsg, PlugDesc] = bst_plugin('Install', 'openmeeg', OPTIONS.Interactive);
if ~isOk
    return;
end
% Progress bar
bst_progress('text', 'OpenMEEG', 'OpenMEEG: Initialization...');
bst_plugin('SetProgressLogo', 'openmeeg');

% Binary path
OpenmeegDir = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder);
binDir = bst_fullfile(OpenmeegDir, 'bin');
% Library path: Linux and MacOS
if ~ispc
    % Get variable name
    if strcmpi(bst_get('OsType'), 'mac64')
        varname = 'DYLD_LIBRARY_PATH';
    else
        varname = 'LD_LIBRARY_PATH';
    end
    libDir = bst_fullfile(OpenmeegDir, 'lib');
    % Get current library path
    libpath = getenv(varname);
    % If OpenMEEG is not already in the env variable
    if isempty(strfind(libpath, libDir))
        if ~isempty(libpath)
            libpath = [libpath ':'];
        end
        setenv(varname, [libpath, OpenmeegDir, ':', libDir]);
    end
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
% SEEG and adjoint incompatible
if isSeeg && OPTIONS.isAdjoint
    errMsg = 'The option "Use adjoint formulation" is not available for SEEG sensors yet.';
    return;
end
% Get temp folder
TmpDir = bst_get('BrainstormTmpDir');
% Open log file
logFile = bst_fullfile(TmpDir, 'openmeeg_log.txt');
fid_log = fopen(logFile, 'w');
% Filenames
geomfile     = bst_fullfile(TmpDir, 'openmeeg.geom');
condfile     = bst_fullfile(TmpDir, 'openmeeg.cond');
dipfile      = bst_fullfile(TmpDir, 'openmeeg_dipoles.txt');
dsmfile      = bst_fullfile(TmpDir, 'openmeeg_dsm.mat');
% EEG
eegloc_file  = bst_fullfile(TmpDir, 'openmeeg_loc_eeg.txt');
h2emfile     = bst_fullfile(TmpDir, 'openmeeg_h2em.mat');
eeggain_file = bst_fullfile(TmpDir, 'openmeeg_gain_eeg.mat');
% MEG
megloc_file  = bst_fullfile(TmpDir, 'openmeeg_loc_meg.squids');
h2mmfile     = bst_fullfile(TmpDir, 'openmeeg_h2mm.mat');
ds2megfile   = bst_fullfile(TmpDir, 'openmeeg_ds2meg.mat');
meggain_file = bst_fullfile(TmpDir, 'openmeeg_gain_meg.mat');
% ECOG
ecogloc_file = bst_fullfile(TmpDir, 'openmeeg_loc_ecog.txt');
h2ecogmfile  = bst_fullfile(TmpDir, 'openmeeg_h2ecogm.mat');
ecoggain_file= bst_fullfile(TmpDir, 'openmeeg_gain_ecog.mat');
% SEEG
seegloc_file = bst_fullfile(TmpDir, 'openmeeg_loc_seeg.txt');
h2ipmfile    = bst_fullfile(TmpDir, 'openmeeg_h2ipm.mat');
ds2ipmfile   = bst_fullfile(TmpDir, 'openmeeg_ds2ipm.mat');
seeggain_file= bst_fullfile(TmpDir, 'openmeeg_gain_seeg.mat');

% Write BEM layers files
trifiles = {};
nVert    = [];
nFaces   = [];
for i = 1:length(OPTIONS.BemFiles)
    % Output MESH file
    trifiles{i} = bst_fullfile(TmpDir, sprintf('openmeeg_%d.tri', i));
    % Write MESH in tmp folder
    [nVert(i), nFaces(i), TessMat] = out_tess_tri(OPTIONS.BemFiles{i}, trifiles{i}, 1);
    % Center all the points on the center of the envelope
    bfs_center = bst_bfs(TessMat.Vertices);
    vDipoles = bst_bsxfun(@minus, OPTIONS.GridLoc, bfs_center(:)');
    vLayer = bst_bsxfun(@minus, TessMat.Vertices, bfs_center(:)');
    % Check if any dipole is outside this BEM layer
    iDipOutside = find(~inpolyhd(vDipoles, vLayer, TessMat.Faces));
    if ~isempty(iDipOutside)
        errMsg = sprintf(['WARNING: %d dipole(s) outside the BEM layer "%s".\n' ...
                          'The leadfield for these dipoles could be incorrect.\n\n'], length(iDipOutside), OPTIONS.BemNames{i});
        if strcmpi(OPTIONS.HeadModelType, 'surface')
            errMsg = [errMsg, 'First, try to recompute BEM surfaces with more vertices.' 10 ...
                'Otherwise, right-click on the cortex file > Force inside skull.' 10 ...
                'See the OpenMEEG BEM tutorial, section "Warning: dipoles outside".'];
        end
        disp([10 errMsg 10]);
        if OPTIONS.Interactive
            isConfirm = java_dialog('confirm', [errMsg 10 10 'Do you want to run OpenMEEG anyway?'], 'OpenMEEG BEM');
            if ~isConfirm
                errMsg = [];
                return;
            end
        end
    end
    % Check if any SEEG contact is outside this BEM layer
    if isSeeg
        iIntra = OPTIONS.iSeeg;
        chLoc = bst_bsxfun(@minus, [OPTIONS.Channel(iIntra).Loc]', bfs_center(:)');
        iChanOutside = iIntra(~inpolyhd(chLoc, vLayer, TessMat.Faces));
        if ~isempty(iChanOutside)
            errMsg = sprintf(['WARNING: %d SEEG contact(s) outside the BEM layer "%s" (see list in command window).\n' ...
                              'The leadfield for these sensors could be incorrect, or OpenMEEG could crash.\n' ...
                              'Edit the channel file and change their type to exclude them.'], length(iChanOutside), OPTIONS.BemNames{i});
            disp([10 errMsg 10]);
            disp(['Sensors outside "' OPTIONS.BemNames{i} '": ' sprintf('%s ', OPTIONS.Channel(iChanOutside).Name), 10]);
            if OPTIONS.Interactive
                isConfirm = java_dialog('confirm', [errMsg 10 10 'Do you want to run OpenMEEG anyway?'], 'OpenMEEG BEM');
                if ~isConfirm
                    errMsg = [];
                    return;
                end
            end
        end
    end
end
% Write geometry file
om_write_geom(geomfile, trifiles, OPTIONS.BemNames);
% Write conductivities file
om_write_cond(condfile, OPTIONS.BemCond, OPTIONS.BemNames);
% Write dipoles file
dipdata = [kron(OPTIONS.GridLoc,ones(3,1)), kron(ones(nv,1), eye(3))];
save(dipfile, 'dipdata', '-ASCII', '-double');  
% Go to openmeeg folder
cd(binDir);


%% ===== GET EXISTING HM FILE =====
% % % TEMPORARY STORAGE OF HM FILE IS DISABLED TO ALLOW UPGRADE OF OPENMEEG
% % % % Compute signature of current combination of files
% % % sig = [num2str(OPTIONS.isAdjoint), sprintf('_%1.07f',OPTIONS.BemCond)];
% % % for i = 1:length(OPTIONS.BemFiles)
% % %     fileinfo = dir(OPTIONS.BemFiles{i});
% % %     sig = [sig '_' fileinfo.name '_' num2str(nVert(i)), '_' num2str(nFaces(i))];
% % % end
% % % 
% % % % Inner skull file
% % % InnerSkullFile = OPTIONS.BemFiles{end};
% % % % Load file
% % % warning off
% % % TessMat = load(InnerSkullFile, 'OpenMEEG');
% % % warning on
% % % % If HM-FILE file already exists and signature matches
% % % hminvfile = '';
% % % hmfile = '';
% % % if isfield(TessMat, 'OpenMEEG') && ~isempty(TessMat.OpenMEEG) && isfield(TessMat.OpenMEEG, 'HmFile') && ~isempty(TessMat.OpenMEEG.HmFile) && isequal(TessMat.OpenMEEG.Signature, sig)
% % %     tmpfile = bst_fullfile(bst_fileparts(InnerSkullFile), TessMat.OpenMEEG.HmFile);
% % %     if file_exist(tmpfile)
% % %         if OPTIONS.isAdjoint 
% % %             hmfile = tmpfile;
% % %         else
% % %             hminvfile = tmpfile;
% % %         end
% % %     end
% % % end

% % % REPLACED WITH HARD CODED HMINV FILES
hmfile    = bst_fullfile(TmpDir, 'openmeeg_hm.mat');
hminvfile = bst_fullfile(TmpDir, 'openmeeg_hminv.mat');



%% ===== COMPUTE HM-INV FILE =====
% % % if isempty(hminvfile) && isempty(hmfile)
% % %     % Filenames
% % %     if OPTIONS.isAdjoint
% % %         hmfile = strrep(InnerSkullFile, '.mat', '_openmeeg.mat');
% % %         [tmp__, fBase, fExt] = bst_fileparts(hmfile);
% % %     else
% % %         hmfile = bst_fullfile(TmpDir, 'openmeeg_hm.mat');
% % %         hminvfile = strrep(InnerSkullFile, '.mat', '_openmeeg.mat');
% % %         [tmp__, fBase, fExt] = bst_fileparts(hminvfile);
% % %     end
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
% % %     % === ADD REFERENCE IN INNER SKULL ===
% % %     % Build reference structure
% % %     OpenMEEG.HmFile = [fBase, fExt];
% % %     OpenMEEG.Signature = sig;
% % %     % Add it to inner skull file
% % %     s.OpenMEEG = OpenMEEG;
% % %     bst_save(InnerSkullFile, s, 'v7', 1);
% % % end


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
            fprintf(fid, 'MEG%03d %g %g %g %g %g %g %g %g', iChan, sChan.Loc(:,iInteg)', sChan.Orient(:,iInteg)', sChan.Weight(iInteg));
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
    if  OPTIONS.isAdjoint
        res = om_call('om_gain -EEGadjoint', ['"' geomfile '" "' condfile '" "' dipfile '" "' hmfile '" "' h2ecogmfile '"'], ecoggain_file, 'Assembling ECOG leadfield...');
    else
        res = om_call('om_gain -EEG', ['"' hminvfile '" "' dsmfile '" "' h2ecogmfile '"'], ecoggain_file, 'Assembling ECOG leadfield...');
    end
    if ~res
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
    if  OPTIONS.isAdjoint
        error('Option "Adjoint" not supported yet for SEEG');
    else
        res = om_call('om_gain -IP', ['"' hminvfile '" "' dsmfile '" "' h2ipmfile '" "' ds2ipmfile '"'], seeggain_file, 'Assembling SEEG leadfield...');
    end
    if ~res
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
bst_plugin('SetProgressLogo', []);




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
                      'For help with OpenMEEG errors, please refer to the online tutorial:' 10 ...
                      'https://neuroimage.usc.edu/brainstorm/Tutorials/TutBem#Errors'];
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
    switch lower(filename(end-2:end))
        case 'mat'
            % Load the entire file
            mat = load(filename);
            % Get the fieldnames
            vars = fieldnames(mat);
            if (length(vars) > 1)
                error(['Unsupported structure: ' filename]);
            end
            % Try to list the different possibilities used by OpenMEEG
            if isnumeric(mat.(vars{1}))
                data = mat.(vars{1});
            elseif isstruct(mat.vars{1}) && isfield(mat.vars{1}, 'data')
                data = mat.(vars{1}).data;
            else
                error(['Unsupported structure: ' filename]);
            end
        case 'bin'
            file = fopen(filename,'r');
            dims = fread(file,2,'uint32','ieee-le');
            data = fread(file,prod(dims),'double','ieee-le');
            data = reshape(data,dims');
            fclose(file);
    end
end


    
    
