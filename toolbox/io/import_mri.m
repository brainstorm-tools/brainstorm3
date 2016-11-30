function [BstMriFile, sMri] = import_mri(iSubject, MriFile, FileFormat, isInteractive)
% IMPORT_MRI: Import a MRI file in a subject of the Brainstorm database
% 
% USAGE: [BstMriFile, sMri] = import_mri(iSubject, MriFile, FileFormat='ALL', isInteractive=0)
%
% INPUT:
%    - iSubject  : Indice of the subject where to import the MRI
%                  If iSubject=0 : import MRI in default subject
%    - MriFile   : Full filename of the MRI to import (format is autodetected)
%                  => if not specified : file to import is asked to the user
%    - FileFormat : String, one on the file formats in in_mri
%    - isInteractive : if 1, importation will be interactive (MRI is displayed after loading)
% OUTPUT:
%    - BstMriFile : Full path to the new file if success, [] if error

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2016

% ===== Parse inputs =====
if (nargin < 3) || isempty(FileFormat)
    FileFormat = 'ALL';
end
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 0;
end
% Initialize returned variables
BstMriFile = [];
sMri = [];
% Get Protocol information
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
% Default subject
if (iSubject == 0)
	sSubject = ProtocolSubjects.DefaultSubject;
% Normal subject 
else
    sSubject = ProtocolSubjects.Subject(iSubject);
end


%% ===== SELECT MRI FILE =====
% If MRI file to load was not defined : open a dialog box to select it
if isempty(MriFile)    
    % Get last used directories
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get last used format
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.MriIn)
        DefaultFormats.MriIn = 'ALL';
    end
    % Get MRI file
    [MriFile, FileFormat] = java_getfile( 'open', ...
        'Import MRI...', ...              % Window title
        LastUsedDirs.ImportAnat, ...      % Default directory
        'single', 'files', ...            % Selection mode
        bst_get('FileFilters', 'mri'), ...
        DefaultFormats.MriIn);
    % If no file was selected: exit
    if isempty(MriFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(MriFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.MriIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end
    
    
%% ===== LOAD MRI FILE =====
bst_progress('start', 'Import MRI', ['Loading file "' MriFile '"...']);
% Load MRI
sMri = in_mri(MriFile, FileFormat, isInteractive);
if isempty(sMri)
    bst_progress('stop');
    return
end
% History: File name
sMri = bst_history('add', sMri, 'import', ['Import from: ' MriFile]);


%% ===== MANAGE MULTIPLE MRI =====
% Add new anatomy
iAnatomy = length(sSubject.Anatomy) + 1;
% If add an extra MRI: read the first one to check that they are compatible
if (iAnatomy > 1)
    % Load the reference MRI (the first one)
    refMriFile = sSubject.Anatomy(1).FileName;
    sMriRef = in_mri_bst(refMriFile);
    % If some transformation where made to the intial volume: apply them to the new one ?
    if isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf)
        if ~isInteractive || java_dialog('confirm', ['A transformation was applied to the reference MRI.' 10 10 'Do you want to apply the same transformation to this new volume?' 10 10], 'Import MRI')
            % Apply step by step all the transformations that have been applied to the original MRI
            for it = 1:size(sMriRef.InitTransf,1)
                ttype = sMriRef.InitTransf{it,1};
                val   = sMriRef.InitTransf{it,2};
                switch (ttype)
                    case 'permute'
                        sMri.Cube = permute(sMri.Cube, val);
                        sMri.Voxsize = sMri.Voxsize(val);
                    case 'flipdim'
                        sMri.Cube = bst_flip(sMri.Cube, val(1));
                end
            end
        end
    end
    % Get volumes dimensions
    refSize = size(sMriRef.Cube);
    newSize = size(sMri.Cube);
    % Check the dimensions
    if any(refSize ~= newSize) || any(sMriRef.Voxsize ~= sMriRef.Voxsize)
        % Look for the possible permutations that would work
        allPermute = [1 3 2; 2 1 3; 2 3 1; 3 1 2; 3 2 1];
        iValid = [];
        for ip = 1:length(allPermute)
            if all(refSize == newSize(allPermute(ip,:))) && all(sMriRef.Voxsize ~= sMriRef.Voxsize(allPermute(ip,:)))
                iValid(end+1) = ip;
            end
        end
        % Error: could not find a matching combination of permutations
        errMsg = ['The size or orientation of the new MRI does not match the previous one.' 10 10 ...
                  'You can import multiple MRI volumes for a subject only if they all have exactly' 10 ...
                  'the same dimensions, voxel size, and orientation.'];
        if isempty(ip) || ~isInteractive
            if isInteractive
                bst_error(errMsg, 'Import MRI', 0);
                sMri = [];
                bst_progress('stop');
                return;
            else
                disp(['Error: ' errMsg]);
                sMri = [];
                bst_progress('stop');
                return;
            end
        % Warning: modifications have to be made
        else
            % Ask what operation to perform with this MRI
            res = java_dialog('question', [errMsg 10 10 'You need to edit this volume before using it:' 10 ...
                '- Resample: Change the size and resolution of the new MRI to match the previous one.' 10 ...
                '- Register: Compute the MNI transformation for both volumes, then register the new one.' 10 ...
                '- Ignore: Save the new MRI without modifications.'], ...
                'Import MRI', [], {'Resample', 'Register', 'Ignore'}, 'Ignore');
            % User aborted the import
            if isempty(res)
                sMri = [];
                bst_progress('stop');
                return;
            end
            % Remove the fiducials 
            sMri
            % Registration
            switch (res)
                case 'Register'
                    % Register the new MRI on the existing one
                    [sMri, errMsg] = mri_coregister(sMri, sMriRef);
                case 'Resample'
                    % Resample the new MRI using the properties of the old one
                    [sMri, Transf, errMsg] = mri_resample(sMri, size(sMriRef.Cube), sMriRef.Voxsize);
                case 'Ignore'
                    % Nothing to do
                    errMsg = [];
            end
            % Stop in case of error
            if ~isempty(errMsg)
                bst_error(errMsg, [res ' MRI'], 0);
                sMri = [];
                bst_progress('stop');
                return;
            end
        end
        isEdit = 1;
    % No need to edit: Re-use the same fiducials
    else
        isEdit = 0;
        % Copy the SCS and NCS fields
        sMri.SCS = sMriRef.SCS;
        sMri.NCS = sMriRef.NCS;
    end
else
    isEdit = 1;
end

%% ===== SAVE MRI IN BRAINSTORM FORMAT =====
% Add a Comment field in MRI structure, if it does not exist yet
if ~isfield(sMri, 'Comment')
    sMri.Comment = 'MRI';
end
% Add an index number 
if (iAnatomy > 1)
    %sMri.Comment = [sMri.Comment, sprintf(' #%d', iAnatomy)];
    [fPath, fBase, fExt] = bst_fileparts(MriFile);
    sMri.Comment = file_unique(fBase, {sSubject.Anatomy.Comment});
end
% Get subject subdirectory
subjectSubDir = bst_fileparts(sSubject.FileName);
% Get imported base name
[tmp__, importedBaseName] = bst_fileparts(MriFile);
importedBaseName = strrep(importedBaseName, 'subjectimage_', '');
importedBaseName = strrep(importedBaseName, '_subjectimage', '');
% Produce a default anatomy filename
BstMriFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['subjectimage_' importedBaseName '.mat']);
% Make this filename unique
BstMriFile = file_unique(BstMriFile);
% Save new MRI in Brainstorm format
sMri = out_mri_bst(sMri, BstMriFile);
% Clear memory
MriComment = sMri.Comment;

%% ===== STORE NEW MRI IN DATABASE ======
% New anatomy structure
sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
sSubject.Anatomy(iAnatomy).FileName = file_short(BstMriFile);
sSubject.Anatomy(iAnatomy).Comment  = MriComment;
% Default anatomy: do not change
if isempty(sSubject.iAnatomy)
    sSubject.iAnatomy = iAnatomy;
end

% == Update database ==
% Default subject
if (iSubject == 0)
	ProtocolSubjects.DefaultSubject = sSubject;
% Normal subject 
else
    ProtocolSubjects.Subject(iSubject) = sSubject;
end
bst_set('ProtocolSubjects', ProtocolSubjects);


%% ===== UPDATE GUI =====
% Refresh tree
panel_protocols('UpdateNode', 'Subject', iSubject);
panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
% Save database
db_save();
% Unload MRI (if a MRI with the same name was previously loaded)
bst_memory('UnloadMri', BstMriFile);


%% ===== MRI VIEWER =====
if isInteractive
    % Edit MRI
    if isEdit
        % MRI Visualization and selection of fiducials (in order to align surfaces/MRI)
        hFig = view_mri(BstMriFile, 'EditMri');
        drawnow;
        bst_progress('stop');
        % Display help message: ask user to select fiducial points
        if (iAnatomy == 1)
            jHelp = bst_help('MriSetup.html', 0);
        else
            jHelp = [];
        end
        % Wait for the MRI Viewer to be closed
        if ishandle(hFig)
            waitfor(hFig);
        end
        % Close help window
        if ~isempty(jHelp)
            jHelp.close();
        end
    % Display MRI
    else
        hFig = view_mri(BstMriFile);
    end
else
    bst_progress('stop');
end





    
