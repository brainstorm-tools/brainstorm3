function varargout = process_generate_fem( varargin )
% PROCESS_GENERATE_FEM: Generate tetrahedral FEM mesh.
%
% USAGE:     OutputFiles = process_generate_fem('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_generate_fem('Compute', iSubject, iAnatomy=[default])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, Takfarinas Medani, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Generate FEM mesh';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 22;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Maximum volume: Max volume of the tetra element, option used by iso2mesh, in this script it will multiplied by e-6;
    % range from 10 for corse mesh to 1e-4 or less for very fine mesh 
    sProcess.options.maxvol.Comment = 'Max tetrahedral volume (10=coarse, 0.0001=fine, default=0.1): ';
    sProcess.options.maxvol.Type    = 'value';
    sProcess.options.maxvol.Value   = {0.1, '', 4};
    % Option: keepratio: Percentage of elements being kept after the simplification
    sProcess.options.keepratio.Comment = 'Percentage of elements kept (default=100%): ';
    sProcess.options.keepratio.Type    = 'value';
    sProcess.options.keepratio.Value   = {100, '%', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    OPTIONS = struct();
    % Maximum tetrahedral volume
    OPTIONS.maxvol = sProcess.options.maxvol.Value{1};
    if isempty(OPTIONS.maxvol) || (OPTIONS.maxvol < 0.000001) || (OPTIONS.maxvol > 20)
        bst_report('Error', sProcess, [], 'Invalid maximum tetrahedral volume.');
        return
    end
    % Keep ratio (percentage 0-1)
    OPTIONS.keepratio = sProcess.options.keepratio.Value{1};
    if isempty(OPTIONS.keepratio) || (OPTIONS.keepratio < 1) || (OPTIONS.keepratio > 100)
        bst_report('Error', sProcess, [], 'Invalid kept element percentage.');
        return
    end
    OPTIONS.keepratio = OPTIONS.keepratio ./ 100;
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], 0, OPTIONS);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE FEM MESHES =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, isInteractive, OPTIONS)
    isOk = 0;
    errMsg = '';
    
    % ===== DEFAULT OPTIONS =====
    Def_OPTIONS = struct(...
        'Method',    'bemsurf', ...
        'MaxVol',    0.1, ...
        'KeepRatio', 1);
    if isempty(OPTIONS)
        OPTIONS = Def_OPTIONS;
    else
        OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
    end

    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', iSubject);
    if isempty(sSubject)
        errMsg = 'Subject does not exist.';
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        errMsg = ['No MRI available for subject "' SubjectName '".'];
        return
    end
    % Get default MRI if not specified
    if isempty(iAnatomy)
        iAnatomy = sSubject.iAnatomy;
    end
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    % Get default surfaces
    if ~isempty(sSubject.iScalp)
        HeadFile = sSubject.Surface(sSubject.iScalp).FileName;
    else
        HeadFile = [];
    end
    if ~isempty(sSubject.iOuterSkull)
        OuterFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
    else
        OuterFile = [];
    end
    if ~isempty(sSubject.iInnerSkull)
        InnerFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
    else
        InnerFile = [];
    end
    if ~isempty(sSubject.iCortex)
        CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
    else
        CortexFile = [];
    end
    % Empty output structure
    FemMat = db_template('femmat');
    
    % ===== GENERATE TETRAHEDRAL MESH =====
    switch lower(OPTIONS.Method)
        % Compute from OpenMEEG BEM layers: head, outerskull, innerskull
        case 'bemsurf'
            % Check if iso2mesh is in the path
            if ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
                errMsg = InstallIso2mesh(isInteractive);
                if ~isempty(errMsg) || ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
                    return;
                end
            end
            % Check surfaces
            if isempty(HeadFile) || isempty(OuterFile) || isempty(InnerFile)
                errMsg = ['Method "' OPTIONS.Method '" requires three surfaces: head, inner skull and outer skull.' 10 ...
                          'Create them with process "Generate BEM surfaces" first.'];
                return;
            end
            % Load surfaces
            HeadMat  = in_tess_bst(HeadFile);
            OuterMat = in_tess_bst(OuterFile);
            InnerMat = in_tess_bst(InnerFile);
            % Merge all the surfaces
            [newnode, newelem] = mergemesh(HeadMat.Vertices,  HeadMat.Faces,...
                                           OuterMat.Vertices, OuterMat.Faces,...
                                           InnerMat.Vertices, InnerMat.Faces);
            % Find the seed point for each region
            center_inner = mean(InnerMat.Vertices);
            [tmp_,tmp_,tmp_,tmp_,seedRegion1] = raysurf(center_inner, [0 0 1], InnerMat.Vertices, InnerMat.Faces);
            [tmp_,tmp_,tmp_,tmp_,seedRegion2] = raysurf(center_inner, [0 0 1], OuterMat.Vertices, OuterMat.Faces);
            [tmp_,tmp_,tmp_,tmp_,seedRegion3] = raysurf(center_inner, [0 0 1], HeadMat.Vertices, HeadMat.Faces);
            regions = [seedRegion1; seedRegion2; seedRegion3];

            % Create tetrahedral mesh
            factor_bst = 1.e-6;
            [node,elem,face] = surf2mesh(newnode, newelem, ...
                                         min(newnode), max(newnode),...
                                         OPTIONS.KeepRatio, factor_bst .* OPTIONS.MaxVol, regions, []);  

            % ######################################################################################
            % TODO: THIS PART SHOULD BE AUTOMATED
            % ######################################################################################
            elem((elem(:,5)==0),5) = 3;

            % Mesh check and repair 
            [no,el] = removeisolatednode(node,elem(:,1:4));
            % Orientation required for the FEM computation (at least with SimBio, may be not for Duneuro)
            newelem = meshreorient(no, el(:,1:4));
            elem = [newelem elem(:,5)];
            
        case 'roast'
            % Check if ROAST is in the path
            if ~exist('roast', 'file')
                errMsg = InstallRoast(isInteractive);
                if ~isempty(errMsg) || ~exist('roast', 'file')
                    return;
                end
            end
            
%             % === SAVE MRI AS NII ===
%             % Empty temporary folder, otherwise it reuses previous files in the folder
%             gui_brainstorm('EmptyTempFolder');
%             % Create temporary folder for ROAST files
%             roastDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'roast');
%             mkdir(roastDir);
%             % Save MRI in .nii format
%             NiiFile = bst_fullfile(roastDir, 'roast.nii');
%             out_mri_nii(sMri, NiiFile);
%             % === CALL ROAST PIPELINE ===
% 
%             % === IMPORT OUTPUT FOLDER ===
%             % Import FEM mesh
%             % ...
%             % Delete temporary folder
%             file_delete(roastDir, 1, 3);

        otherwise
            errMsg = ['Invalid method "' OPTIONS.Method '".'];
            return;
    end

    % ===== SAVE FEM MESH =====
    % Create output structure
    FemMat.Comment = sprintf('FEM %dV (%s)', length(node), OPTIONS.Method);
    FemMat.Vertices = node;
    FemMat.Elements = elem(:,1:4);
    FemMat.Tissue = elem(:,5);
    FemMat.TissueLabels = {'Inner','Outer','Scalp'};
    % Add history
    FemMat = bst_history('add', FemMat, 'process_generate_fem', [...
        'Method=',    OPTIONS.Method, '', ...
        'MaxVol=',    num2str(OPTIONS.MaxVol), ...
        'KeepRatio=', num2str(OPTIONS.KeepRatio)]);
    % Save to database
    FemFile = file_unique(bst_fullfile(bst_fileparts(file_fullpath(MriFile)), sprintf('tess_fem_%s_%dV.mat', OPTIONS.Method, length(FemMat.Vertices))));
    bst_save(FemFile, FemMat, 'v7');
    db_add_surface(iSubject, FemFile, FemMat.Comment);
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    % Ask for method
    Method = java_dialog('question', [...
        '<HTML><B>BEM</B>:<BR>Calls iso2mesh to create a tetrahedral mesh from the BEM layers<BR>' ...
        'generated with Brainstorm (head, inner skull, outer skull).<BR><BR>' ...
        '<B>ROAST</B>:<BR>Calls the ROAST pipeline to segment and mesh the T1 MRI.<BR><BR>'], ...
        'FEM mesh generation method', [], {'BEM','ROAST'}, 'BEM');
    if isempty(Method)
        return
    end
    
    % Other options: Switch depending on the method
    switch (Method)
        case 'BEM'
            % Ask BEM meshing options
            res = java_dialog('input', {'Max tetrahedral volume (10=coarse, 0.0001=fine):', 'Percentage of elements kept (1-100%):'}, ...
                              'FEM mesh', [], {'0.1', '100'});
            % If user cancelled: return
            if isempty(res)
                return
            end
            % Get new values
            OPTIONS.MaxVol    = str2num(res{1});
            OPTIONS.KeepRatio = str2num(res{2}) ./ 100;
            if isempty(OPTIONS.MaxVol) || (OPTIONS.MaxVol < 0.000001) || (OPTIONS.MaxVol > 20) || ...
               isempty(OPTIONS.KeepRatio) || (OPTIONS.KeepRatio < 0.01) || (OPTIONS.KeepRatio > 1)
                bst_error('Invalid options.', 'FEM mesh', 0);
                return
            end
            OPTIONS.Method = 'bemsurf';
            % Open progress bar
            bst_progress('start', 'FEM mesh', 'FEM mesh generation (iso2mesh)...');
            
        case 'ROAST'
            bst_error('Not implemented yet', 'FEM mesh', 0);
            return;
            
            OPTIONS.Method = 'roast';
            % Open progress bar
            bst_progress('start', 'ROAST', 'FEM mesh generation (ROAST)...');
            bst_progress('setimage', 'logo_splash_roast.gif');
    end

    % Compute surfaces
    [isOk, errMsg] = Compute(iSubject, iAnatomy, 1, OPTIONS);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FEM mesh', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end



%% ===== INSTALL ROAST =====
function errMsg = InstallRoast(isInteractive)
    % Initialize variables
    errMsg = [];
    curdir = pwd;
    % Download URL
    url = 'https://www.parralab.org/roast/roast-3.0.zip';
    
    % Check if already available in path
    if exist('roast', 'file')
        disp([10, 'ROAST path: ', bst_fileparts(which('roast')), 10]);
        return;
    end
    % Local folder where to install ROAST
    roastDir = bst_fullfile(bst_get('BrainstormUserDir'), 'roast');
    exePath = bst_fullfile(roastDir, 'roast-3.0', 'roast.m');
    % If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
    if ~isdir(roastDir)
        roastDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'roast');
        if isdir(roastDirMaster)
            roastDir = roastDirMaster;
        end
    end

    % URL file defines the current version
    urlFile = bst_fullfile(roastDir, 'url');
    % Read the previous download url information
    if isdir(roastDir) && file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end
    % If file doesnt exist: download
    if ~isdir(roastDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
        % If folder exists: delete
        if isdir(roastDir)
            file_delete(roastDir, 1, 3);
        end
        % Create folder
        res = mkdir(roastDir);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 roastDir];
            return
        end
        % Message
        if isInteractive
            isOk = java_dialog('confirm', ...
                ['ROAST is not installed on your computer (or out-of-date).' 10 10 ...
                 'Download and the latest version of ROAST?'], 'ROAST');
            if ~isOk
                errMsg = 'Download aborted by user';
                return;
            end
        end
        % Download file
        zipFile = bst_fullfile(roastDir, 'roast.zip');
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download ROAST');
        % If file was not downloaded correctly
        if ~isempty(errMsg)
            errMsg = ['Impossible to download ROAST:' 10 errMsg1];
            return;
        end
        % Display again progress bar
        bst_progress('text', 'Installing ROAST...');
        % Unzip file
        cd(roastDir);
        unzip(zipFile);
        file_delete(zipFile, 1, 3);
        cd(curdir);
        % Save download URL in folder
        fid = fopen(urlFile, 'w');
        fwrite(fid, url);
        fclose(fid);
    end
    % If installed but not in path: add roast to path
    if ~exist('roast', 'file')
        addpath(bst_fileparts(exePath));
        disp([10, 'ROAST path: ', bst_fileparts(roastDir), 10]);
    % If the executable is still not accessible
    else
        errMsg = ['ROAST could not be installed in: ' roastDir];
    end
end


%% ===== INSTALL ISO2MESH =====
function errMsg = InstallIso2mesh(isInteractive)
    % Initialize variables
    errMsg = [];
    curdir = pwd;
    % Check if already available in path
    if exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
        disp([10, 'Iso2mesh path: ', bst_fileparts(which('iso2meshver')), 10]);
        return;
    end
    
    % Get default url
    osType = bst_get('OsType', 0);
    switch(osType)
        case 'linux32',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux32.zip%2Fdownload&ts=1568212532';
        case 'linux64',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux64.zip%2Fdownload&ts=1568212566';
        case 'mac32',    error('MacOS 32bit systems are not supported');
        case 'mac64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-osx64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-osx64.zip%2Fdownload&ts=1568212596';
        case 'sol64',    error('Solaris system is not supported');
        case 'win32',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
        case 'win64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
        otherwise,       error('OpenMEEG software does not exist for your operating system.');
    end

    % Local folder where to install ROAST
    isoDir = bst_fullfile(bst_get('BrainstormUserDir'), 'iso2mesh', osType);
    exePath = bst_fullfile(isoDir, 'iso2mesh', 'iso2meshver.m');
    % If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
    if ~isdir(isoDir)
        isoDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'iso2mesh');
        if isdir(isoDirMaster)
            isoDir = isoDirMaster;
        end
    end

    % URL file defines the current version
    urlFile = bst_fullfile(isoDir, 'url');
    % Read the previous download url information
    if isdir(isoDir) && file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end
    % If file doesnt exist: download
    if ~isdir(isoDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
        % If folder exists: delete
        if isdir(isoDir)
            file_delete(isoDir, 1, 3);
        end
        % Create folder
        res = mkdir(isoDir);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 isoDir];
            return
        end
        % Message
        if isInteractive
            isOk = java_dialog('confirm', ...
                ['Iso2mesh is not installed on your computer (or out-of-date).' 10 10 ...
                 'Download and the latest version of Iso2mesh?'], 'Iso2mesh');
            if ~isOk
                errMsg = 'Download aborted by user';
                return;
            end
        end
        % Download file
        zipFile = bst_fullfile(isoDir, 'iso2mesh.zip');
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download Iso2mesh');
        % If file was not downloaded correctly
        if ~isempty(errMsg)
            errMsg = ['Impossible to download Iso2mesh:' 10 errMsg1];
            return;
        end
        % Display again progress bar
        bst_progress('text', 'Installing Iso2mesh...');
        % Unzip file
        cd(isoDir);
        unzip(zipFile);
        file_delete(zipFile, 1, 3);
        cd(curdir);
        % Save download URL in folder
        fid = fopen(urlFile, 'w');
        fwrite(fid, url);
        fclose(fid);
    end
    % If installed but not in path: add to path
    if ~exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
        addpath(bst_fileparts(exePath));
        disp([10, 'Iso2mesh path: ', bst_fileparts(isoDir), 10]);
    % If the executable is still not accessible
    else
        errMsg = ['Iso2mesh could not be installed in: ' isoDir];
    end
end

