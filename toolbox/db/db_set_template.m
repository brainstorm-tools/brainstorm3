function db_set_template( iSubject, sTemplate, isInteractive )
% DB_SET_TEMPLATE: Copy all the files from an anatomy template in any anatomy directory.
%
% USAGE:  db_set_template( iSubject, sTemplate, isInteractive=1 );
%
% INPUT: 
%    - iSubject      : Subject indice in protocol definition (default anatomy: iSubject=0)
%    - sTemplate     : Path to the anatomy template (zip file, folder or URL)
%    - isInteractive : If 1, asks for confirmation and open the MRI Viewer for fiducials verification (default is 1)

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
% Authors: Francois Tadel, 2008-2013


%% ===== TARGET SUBJECT =====
% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
% Get default subject directory
sSubject = bst_get('Subject', iSubject);
ProtocolInfo = bst_get('ProtocolInfo');
targetDir = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(sSubject.FileName));
% Ask for confirmation if existing anatomy
if isInteractive && (~isempty(sSubject.Anatomy) || ~isempty(sSubject.Surface))
    if ~java_dialog('confirm', ['Warning: There is already an anatomy defined for this subject.' 10 10 ...
        'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Use default anatomy');
        return;
    end
end


%% ===== GET TEMPLATE =====
% Directory: just copy from it
if isdir(sTemplate.FilePath)
    templateDir = sTemplate.FilePath;
    isDeleteDir = 0;
else
    % Create to temporary folder
    templateDir = bst_fullfile(bst_get('BrainstormTmpDir'), sTemplate.Name);
    if file_exist(templateDir)
        file_delete(templateDir, 1, 3);
    end
    mkdir(templateDir);
    % URL: Download zip file
    if ~isempty(strfind(sTemplate.FilePath, 'http://')) || ~isempty(strfind(sTemplate.FilePath, 'https://')) || ~isempty(strfind(sTemplate.FilePath, 'ftp://'))
        % Output file
        ZipFile = bst_fullfile(bst_get('UserDefaultsDir'), 'anatomy', [sTemplate.Name '.zip']);
        % Download file
        errMsg = gui_brainstorm('DownloadFile', sTemplate.FilePath, ZipFile, 'Download template');
        % Error message
        if ~isempty(errMsg)
            bst_error(['Impossible to download template:' 10 errMsg], 'Download error', 0);
            return
        end
    elseif ~isempty(strfind(sTemplate.FilePath, '.zip'))
        ZipFile = sTemplate.FilePath;
    else
        error('Invalid template.');
    end
    % Progress bar
    bst_progress('start', 'Import template', 'Unzipping file...');
    % URL: Download zip file
    try
        unzip(ZipFile, templateDir);
    catch
        errMsg = ['Could not unzip anatomy template: ' 10 10 lasterr];
        disp(['BST> Error: ' errMsg]);
        if isInteractive
            if java_dialog('confirm', [errMsg 10 10 'Delete invalid template file?' 10 10], 'Use default anatomy');
                file_delete(ZipFile, 1);
            end
        end
        bst_progress('stop');
        return;
    end
    isDeleteDir = 1;
end


%% ===== COPY TEMPLATE =====
% Unload everything
bst_memory('UnloadAll', 'Forced');
% Check template directory
if isempty(templateDir) || ~isdir(templateDir) || isempty(dir(bst_fullfile(templateDir, 'brainstormsubject*.mat')))
    error(['Invalid template directory : "' strrep(templateDir, '\', '\\') '".']);
end
% Progress bar
bst_progress('start', 'Import template', 'Copying template files...');
% Remove all the files of the previous default anatomy
file_delete(bst_fullfile(targetDir, '*.bin'), 1);
file_delete(bst_fullfile(targetDir, '*.bak'), 1);
file_delete(bst_fullfile(targetDir, '*_openmeeg.mat'), 1);
dirFiles = dir(bst_fullfile(targetDir, '*.mat'));
for i = 1:length(dirFiles)
    fileType = file_gettype(dirFiles(i).name);
    if ~strcmpi(fileType, 'brainstormsubject')
        file_delete(bst_fullfile(targetDir, dirFiles(i).name), 1);
    end
end
% Copy all files of the template in target directory
dirFiles = dir(bst_fullfile(templateDir, '*.mat'));
for i = 1:length(dirFiles)
    fileType = file_gettype(dirFiles(i).name);
    % Subject description: get the default surfaces and MRIs
    if strcmpi('brainstormsubject', fileType)
        % Load template subject mat
        tempSubjMat = load(bst_fullfile(templateDir, dirFiles(i).name));
        % Load target subject mat
        targetSubjFile = file_fullpath(sSubject.FileName);
        targetSubjMat = load(targetSubjFile);
        % Copy default filenames
        for f = {'Anatomy', 'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'FEM'}
            if isfield(tempSubjMat, f{1}) && ~isempty(tempSubjMat.(f{1}))
                [tmp, fBase, fExt] = bst_fileparts(tempSubjMat.(f{1}));
                targetSubjMat.(f{1}) = [bst_fileparts(sSubject.FileName), '/', [fBase, fExt]];
            end
        end
        % Save updated subject mat
        bst_save(targetSubjFile, targetSubjMat, 'v7');
    % Else: plain copy of the file
    else
        file_copy(bst_fullfile(templateDir, dirFiles(i).name), targetDir);
    end
end

% Reload default subject 
db_reload_subjects(iSubject);
% Get subject again
sSubject = bst_get('Subject', iSubject);
% Close process bar
bst_progress('stop');
% Delete unzipped template folder
if isDeleteDir
    file_delete(templateDir, 1, 3);
end

%% ===== CHECK FIDUCIALS =====
if isInteractive && ~isempty(sSubject.Anatomy)
    % DEFAULT ANAT: Check if the positions of the fiducials have been validated
     figure_mri('FiducialsValidation', sSubject.Anatomy(1).FileName);
end




