function sSubject = db_parse_subject( subjectsDir, subjectSubDir, sizeProgress )
% DB_PARSE_SUBJECT: Parse a subject directory.
%
% USAGE:  sSubject = db_parse_subject(subjectsDir, subjectSubDir, sizeProgress);
% 
% INPUT:  
%     - subjectsDir   : Top-level subjects directory (protocol/anatomy/)
%     - subjectSubDir : Study subdirectory
%     - sizeProgress : The full process increments the available progress bar by this amount
% OUTPUT: 
%     - sSubject : array of Subject structures (one entry for each subdirectory with a brainstormsubject file), 
%                  or [] if no brainstormsubject.mat file was found in directory.

% NOTES:
%    In a subject subdirectory there is :
%        - One and only one 'brainstormsubject*.mat' file,
%        - All the files associated with this subject :
%             - Surfaces (cortex, scalp, inner skull, outer skull, ...)
%             - Anatomical MRI
%    All the .MAT files in the directory are associated with the subject.
%    The files that are pointed by the 'Anatomy' and surfaces fields 
%        ('Scalp','Cortex',...) in the brainstormsubject.mat file are the 
%        current files for each category.
%
% WARNING: This function ignores the <DirDefaultSubject> directories. 
%          These directories must be parsed independently.
%
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
% Authors: Francois Tadel, 2008-2021


%% ===== PARSE INPUTS =====
if ~file_exist(bst_fullfile(subjectsDir, subjectSubDir))
    error('Path in argument does not exist, or is not a directory');
end
if (nargin < 3) || isempty(sizeProgress)
    sizeProgress = [];
end

%% ===== LOOK FOR SUBJECT DEFINITION =====
% List 'brainstormsubject*.mat' files in the subjectSubDir directory
subjectFiles = dir(bst_fullfile(subjectsDir, subjectSubDir, 'brainstormsubject*.mat'));
% If there is no subject definition file : ignore the directory
if isempty(subjectFiles)
    subjMat = [];
% If there is more that one subject definition file : warning and ignore the directory
elseif (length(subjectFiles) > 1)
    subjMat = [];
    bst_error(sprintf('There is more than one brainstormsubject file in directory ''%s'' : ignoring directory.', bst_fullfile(subjectsDir, subjectSubDir)), ...
             'Parsing subject directory', 0);
% Else there is only one file in subjectFiles list
else
    subjectFile = subjectFiles(1);
    % Open file and get subject description
    try
        subjMat = load(bst_fullfile(subjectsDir, subjectSubDir, subjectFile.name));
    catch
        warning('Brainstorm:CannotOpenFile', 'Cannot open file ''%s'' : ignoring subject', bst_fullfile(subjectsDir, subjectSubDir, subjectFile.name));
        subjMat = [];
    end
end

  
%% ===== READ SUBJECT DESCRIPTION =====
% Copy fields of loaded subject matrix into the sSubject structure (output variable)
% IMPORTANT : All the filenames in the subject description matrix
%             must be relative to the SUBJECTS directory.
if ~isempty(subjMat)
    % Define structure templates
    sSubject = db_template('Subject');
    % Store subject's .MAT filename
    sSubject.FileName = bst_fullfile(subjectSubDir, subjectFile.name);
    sSubject.Name     = subjectSubDir;
    % Comments
    if isfield(subjMat, 'Comments')
        sSubject.Comments = subjMat.Comments;
    end
    % DateOfAcquisition
    if isfield(subjMat, 'DateOfAcquisition')
        sSubject.DateOfAcquisition = subjMat.DateOfAcquisition;
    end
    % UseDefaultAnat
    if isfield(subjMat, 'UseDefaultAnat')
        sSubject.UseDefaultAnat = subjMat.UseDefaultAnat;
    end
    % UseDefaultChannel
    if isfield(subjMat, 'UseDefaultChannel')
        sSubject.UseDefaultChannel = subjMat.UseDefaultChannel;
    end
else
    % Define structure templates
    sSubject = repmat(db_template('Subject'), 0);
end


%% ===== READ ALL FILES IN FOLDER =====
% List all '*.mat' files in the subjectSubDir directory
allFiles = dir(bst_fullfile(subjectsDir, subjectSubDir, '*'));
% Exclude files starting with a '.' 
dirFiles = repmat(allFiles,0);
for iFile = 1:length(allFiles)
    if (allFiles(iFile).name(1) ~= '.')
        dirFiles(end+1,1) = allFiles(iFile);
    end
end
if isempty(dirFiles)
    return;
end
% Progress bar?
isProgressBar = bst_progress('isvisible') && ~isempty(sizeProgress);
startValue = bst_progress('get');
% Process all the files
for iFile = 1:length(dirFiles)
    % Increment progress bar
    if isProgressBar
        bst_progress('set',  round(startValue + iFile/length(dirFiles) * sizeProgress));
    end
    % Process sub-directories recursively (excluding the 'DirDefaultSubject' directories)
    if (dirFiles(iFile).isdir) && ~strcmpi(dirFiles(iFile).name, bst_get('DirDefaultSubject'))
        % Append subjects in the subdirectory to the sSubject array
        sSubject = [sSubject, db_parse_subject(subjectsDir, bst_fullfile(subjectSubDir, dirFiles(iFile).name))];
    % Files (only if there is a brainstormsubject file in current directory)
    elseif ~isempty(subjMat) 
        % Reconstruct filename
        filenameRelative = bst_fullfile(subjectSubDir, dirFiles(iFile).name);
        filenameFull     = bst_fullfile(subjectsDir, subjectSubDir, dirFiles(iFile).name);
        % Skip "_openmeeg.mat" files (related with the BEM computation)
        if ~isempty(strfind(filenameRelative, '_openmeeg.mat'))
            continue;
        end
        % Determine filetype
        fileType = file_gettype(filenameFull);
        if isempty(fileType)
            continue;
        end
        % Process file
        switch(fileType)
            case 'subjectimage'
                % Try to load Anatomy info
                tempAnatomy = io_getAnatomyInfo(filenameRelative);
                % If an anatomy was identified : add it to the subject structure
                if ~isempty(tempAnatomy)
                    sSubject(1).Anatomy(end+1) = tempAnatomy;
                end
            case {'scalp', 'cortex', 'innerskull', 'outerskull', 'fibers', 'fem', 'tess'}
                tempSurface = io_getSurfaceInfo(filenameRelative);
                if ~isempty(tempSurface)
                    switch(fileType)
                        case 'scalp',       tempSurface.SurfaceType = 'Scalp';
                        case 'cortex',      tempSurface.SurfaceType = 'Cortex';
                        case 'innerskull',  tempSurface.SurfaceType = 'InnerSkull';
                        case 'outerskull',  tempSurface.SurfaceType = 'OuterSkull';
                        case 'fibers',      tempSurface.SurfaceType = 'Fibers';
                        case 'fem',         tempSurface.SurfaceType = 'FEM';
                        case 'tess',        tempSurface.SurfaceType = 'Other';
                    end
                    sSubject(1).Surface(end+1) = tempSurface;
                end
        end
    end
end
% Set progress bar to the end
if isProgressBar
    bst_progress('set', round(startValue + sizeProgress));
end


%% ===== DEFAULT ANATOMY/SURFACES =====
if ~isempty(subjMat)
    % The brainstormsubject.mat can define what are the defaults files for the different 
    % file categories : Anatomy, Scalp, Cortex, InnerSkull, OuterSkull, Fibers, FEM
    % Now we are going to read those brainstormsubject fields look for
    % the pointed files in the sSubject structure

    % ==== ANATOMY ====
    % By default : use the first anatomy in list (which is not a volume atlas)
    if ~isempty(sSubject(1).Anatomy)
        iNoAtlas = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject(1).Anatomy.FileName}));
        if (length(sSubject(1).Anatomy) == 1) || isempty(iNoAtlas)
            sSubject(1).iAnatomy = 1;
        else
            sSubject(1).iAnatomy = iNoAtlas(1);
        end
    else
        sSubject(1).iAnatomy = [];
    end
    % Anatomy field : filename of the current/default Anatomy for this subject (subjectimage.mat)
    % => If there are more than one MRI in subject directory, 
    %    this one will be used by default for all the processes.
    if (isfield(subjMat, 'Anatomy') && ~isempty(subjMat.Anatomy))
        ind = find(file_compare({sSubject(1).Anatomy.FileName}, subjMat.Anatomy), 1);
        if ~isempty(ind)
            % Reorder anatomy entries
            sSubject(1).Anatomy = sSubject(1).Anatomy([ind, setdiff(1:length(sSubject(1).Anatomy), ind)]);
            sSubject(1).iAnatomy = 1;
        end
    end

    % ==== SURFACE ====
    % Sort surfaces by categories
    subjectSurfaces = db_surface_sort(sSubject(1).Surface);
    % Select one surface in each category
    for surfaceCatergory = {'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'}
        % By default : use the last surface in list
        if ~isempty(subjectSurfaces.(surfaceCatergory{1}))
            sSubject(1).(['i' (surfaceCatergory{1})]) = subjectSurfaces.(['Index' surfaceCatergory{1}])(end);
        else
            sSubject(1).(['i' (surfaceCatergory{1})]) = [];
        end
        % If a default was defined in the brainstormsubject*.mat
        if (isfield(subjMat, surfaceCatergory{1}) && ~isempty(subjMat.(surfaceCatergory{1})) && ischar(subjMat.(surfaceCatergory{1})))
            ind = find(file_compare({sSubject(1).Surface.FileName}, subjMat.(surfaceCatergory{1})), 1);
            if (ind > 0)
                sSubject(1).(['i' (surfaceCatergory{1})]) = ind;
            end
        end
    end
end


%% ===================================================================================
%  === HELPER FUNCTIONS ==============================================================
%  ===================================================================================
    % Load an Anatomy from a relative filename
    % Return an Anatomy structure :
    %    |- FileName
    %    |- Comment
    % or an empty structure if anatomy is not or badly defined.
    function Anatomy = io_getAnatomyInfo(relativeFilename)
        Anatomy = repmat(db_template('Anatomy'), 0);
        % Check if the file exists, and load Comment field
        if file_exist(bst_fullfile(subjectsDir, relativeFilename))
            try
                % Load MRI 'Comment' field from SUBJECTIMAGE.MAT
                warning off MATLAB:load:variableNotFound;
                anatomyMat = load(bst_fullfile(subjectsDir, relativeFilename), 'Comment');
                warning on MATLAB:load:variableNotFound;
                % If 'Comment' not defined or empty
                if (length(fieldnames(anatomyMat)) == 0)
                    [fpath, basename] = bst_fileparts(relativeFilename);
                    Anatomy(1).Comment = basename;
                else
                    Anatomy(1).Comment = anatomyMat.Comment;
                end
                Anatomy(1).FileName = relativeFilename;
            catch
                % An error occured during the 'load' operation
                warning('Brainstorm:CannotOpenFile', 'Cannot open anatomy file ''%s''.', bst_fullfile(subjectsDir, relativeFilename));
            end
        else
            % File does not exist
            warning('Brainstorm:FileNotFound', 'Anatomy file ''%s'' was not found.', bst_fullfile(subjectsDir, relativeFilename));
        end
    end

    % Load a surface from a relative filename
    % surfaceType = {'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'}
    % Return a Surface structure :
    %    |- FileName
    %    |- Comment
    % or an empty structure if surface is not or badly defined
    function Surface = io_getSurfaceInfo(relativeFilename)
        Surface = repmat(db_template('Surface'), 0);
        % Check if the file exists, and load Comment field
        if file_exist(bst_fullfile(subjectsDir, relativeFilename))
            try
                % Load Surface 'Comment' field from SUBJECTIMAGE.MAT
                surfaceMat = load(bst_fullfile(subjectsDir, relativeFilename), 'Comment');
                % If 'Comment' not defined or empty
                if (isempty(surfaceMat))
                    Surface(1).Comment = '';
                elseif iscell(surfaceMat.Comment)
                    Surface(1).Comment = surfaceMat.Comment{1};
                elseif ischar(surfaceMat.Comment)
                    Surface(1).Comment = surfaceMat.Comment;
                end
                Surface(1).FileName = relativeFilename;
            catch
                % An error occured during the 'load' operation
                warning('Brainstorm:CannotOpenFile', 'Cannot open surface file ''%s''. Adding ''.bak'' to the filename.', relativeFilename);
                fullfilename = bst_fullfile(subjectsDir, relativeFilename);
                file_move(fullfilename, [fullfilename, '.bak']);
            end
        else
            % File does not exist
            warning('Brainstorm:FileNotFound', 'Surface file ''%s'' was not found.', bst_fullfile(subjectsDir, relativeFilename));
        end
    end        
end












