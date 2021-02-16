function export_default_anat(iSubject, DefaultName, IncludeChannels)
% EXPORT_DEFAULT_ANAT: Export a subject anatomy as a user template in a .zip file.
%
% USAGE:  export_mri( iSubject, DefaultName=[ask], IncludeChannels=[ask] )

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
% Authors: Francois Tadel, 2013-2020

% ===== GET DEFAULT NAME =====
% Get subject 
sSubject = bst_get('Subject', iSubject);
% Ask template name
if (nargin < 2) || isempty(DefaultName)
    DefaultName = java_dialog('input', [...
        'This menu generates a new default anatomy, saved in:', 10 ...
        '$HOME/.brainstorm/defaults/anatomy/TemplateName.zip' 10 10 ...
        'To use it afterwards from the interface: ' 10 ...
        'Right-click on a subject > Use default > TemplateName' 10 10 ...
        'Enter the name of the new default anatomy:'], 'Create new template', [], sSubject.Name);
    if isempty(DefaultName)
        return;
    end
end
% Ask channels
if (nargin < 3) || isempty(IncludeChannels)
    IncludeChannels = [];
end
% Standardize file name
DefaultName = file_standardize(DefaultName);
% Check if this default already exists
if ~isempty(bst_get('AnatomyDefaults', DefaultName))
	bst_error(['Template "' DefaultName '" aleady exists.'], 'Create new template', 0);
    return;
end

% ===== PROCESS FILES =====
% Show progress bar
bst_progress('start', 'Export template', ['Creating template "' DefaultName '"...']);
% Initialize list of files to export
AllFiles = {file_fullpath(sSubject.FileName)};
% Clean MRIs
for i = 1:length(sSubject.Anatomy)
    % Load file 
    MriFile = file_fullpath(sSubject.Anatomy(i).FileName);
    sMri = load(MriFile);
    % Copy to new structure
    sMriNew = db_template('mrimat');
    sMriNew.Comment = sMri.Comment;
    sMriNew.Cube    = sMri.Cube;
    sMriNew.Voxsize = sMri.Voxsize;
    sMriNew.SCS     = sMri.SCS;
    sMriNew.NCS     = sMri.NCS;
    if isfield(sMri, 'Header')
        sMriNew.Header = sMri.Header;
    end
    if isfield(sMri, 'InitTransf')
        sMriNew.InitTransf = sMri.InitTransf;
    end
    % Save file back
    bst_save(MriFile, sMriNew, 'v7');
    % Add file to export list
    AllFiles{end+1} = MriFile;
end
% Clean surfaces
for i = 1:length(sSubject.Surface)
    % Load file 
    TessFile = file_fullpath(sSubject.Surface(i).FileName);
    sTess = load(TessFile);
    % Copy to new structure
    sTessNew = db_template('surfacemat');
    sTessNew.Comment  = sTess.Comment;
    sTessNew.Vertices = double(sTess.Vertices);
    sTessNew.Faces    = sTess.Faces;
    % Copy atlases
    if isfield(sTess, 'Atlas') && ~isempty(sTess.Atlas)
        sTessNew.Atlas = sTess.Atlas;
    end
    % Select "user scouts" (for cortex) or "structures" (for aseg)
    if ~isempty(strfind(sTessNew.Comment, 'aseg')) || ~isempty(strfind(sTessNew.Comment, 'subcortical'))
        sTessNew.iAtlas = find(strcmpi({sTessNew.Atlas.Name}, 'Structures'));
    else
        sTessNew.iAtlas = 1;
    end
    % Compress Reg
    if isfield(sTess, 'Reg')
        sTessNew.Reg = sTess.Reg;
        if isfield(sTessNew.Reg, 'Sphere') && isfield(sTessNew.Reg.Sphere, 'Vertices') && ~isempty(sTessNew.Reg.Sphere.Vertices)
            sTessNew.Reg.Sphere.Vertices = single(sTessNew.Reg.Sphere.Vertices);
        end
    end
    % Save file back
    bst_save(TessFile, sTessNew, 'v7');
    % Add file to export list
    AllFiles{end+1} = TessFile;
end

% Add extra text files
SubjectPath = bst_fileparts(AllFiles{1});
dirTxt = dir(bst_fullfile(SubjectPath, '*.txt'));
for i = 1:length(dirTxt)
    AllFiles{end+1} = bst_fullfile(SubjectPath, dirTxt(i).name);
end

% Get channel files associated with this subject
iChanStudies = bst_get('ChannelStudiesWithSubject', iSubject);
ChannelFiles = {};
for i = 1:length(iChanStudies)
    sChanStudy = bst_get('Study', iChanStudies(i));
    if ~isempty(sChanStudy.Channel)
        ChannelFiles{end+1} = sChanStudy.Channel(1).FileName;
    end
end
% Add channel files
if ~sSubject.UseDefaultChannel && ~isempty(ChannelFiles) 
    if isempty(IncludeChannels)
        IncludeChannels = java_dialog('confirm', ['Include the channel files in the template?' 10 10 sprintf('%s\n', ChannelFiles{:}) 10], 'Create new template');
    end
    if IncludeChannels
        AllFiles = cat(2, AllFiles, file_fullpath(ChannelFiles));
    end
end

% Zip all the files in $HOME/.brainstorm/defaults/anatomy/DefaultName.zip
ZipFile = bst_fullfile(bst_get('UserDefaultsDir'), 'anatomy', [DefaultName '.zip']);
zip(ZipFile, AllFiles);
% Display file name
disp(['BST> New template saved in: ' ZipFile]);

% Hide progress bar
bst_progress('stop');






