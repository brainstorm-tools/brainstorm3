function [sAllAtlas, Messages] = import_label(SurfaceFile, LabelFiles, isNewAtlas, GridLoc, FileFormat)
% IMPORT_LABEL: Import an atlas segmentation for a given surface
% 
% USAGE: import_label(SurfaceFile, LabelFiles, isNewAtlas=1, GridLoc=[], FileFormat=[]) : Add label information to SurfaceFile
%        import_label(SurfaceFile)                                                      : Ask the user for the label file to import

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
% Authors: Francois Tadel, 2012-2022

import sun.misc.BASE64Decoder;


%% ===== GET FILES =====
sAllAtlas = repmat(db_template('Atlas'), 0);
Messages = [];
% Parse inputs
if (nargin < 5) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 4) || isempty(GridLoc)
    GridLoc = [];
end
if (nargin < 3) || isempty(isNewAtlas)
    isNewAtlas = 1;
end
if (nargin < 2) || isempty(LabelFiles)
    LabelFiles = [];
end

% CALL: import_label(SurfaceFile)
if isempty(LabelFiles)
    % Get last used folder
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get label files
    [LabelFiles, FileFormat] = java_getfile( 'open', ...
       'Import labels...', ...        % Window title
       LastUsedDirs.ImportAnat, ...   % Default directory
       'multiple', 'files', ...       % Selection mode
       bst_get('FileFilters', 'labelin'), ...
       DefaultFormats.LabelIn);
    % If no file was selected: exit
    if isempty(LabelFiles)
        return
    end
	% Save last used dir
    LastUsedDirs.ImportAnat = bst_fileparts(LabelFiles{1});
    bst_set('LastUsedDirs',  LastUsedDirs);
    % Save default export format
    DefaultFormats.LabelIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    % Warning if trying to import volume atlases on surfaces
    if isempty(GridLoc) && ismember(FileFormat, {'MRI-MASK', 'MRI-MASK-MNI', 'MRI-MASK-NOOVERLAP', 'MRI-MASK-NOOVERLAP-MNI'})
        isConfirm = java_dialog('confirm', ['You are trying to import a volume parcellation on a cortex surface.' 10 ...
            'This usually results in very poor results, with incomplete cortex parcels.' 10 ...
            'Using volume parcellations is only recommended with volume source models.' 10 10 ...
            'Proceed anyways?'], 'Warning');
        if ~isConfirm
            return;
        end
    end
% CALL: import_label(SurfaceFile, LabelFiles, ...)
else
    % Force cell input
    if ~iscell(LabelFiles)
        LabelFiles = {LabelFiles};
    end
    % Detect file format based on file extension
    if isempty(FileFormat)
        [fPath, fBase, fExt] = bst_fileparts(LabelFiles{1});
        switch (fExt)
            case '.annot',  FileFormat = 'FS-ANNOT';
            case '.label',  FileFormat = 'FS-LABEL-SINGLE';
            case '.gii',    FileFormat = 'GII-TEX';
            case '.dfs',    FileFormat = 'DFS';
            case '.dset',   FileFormat = 'DSET';
            case '.mat'
                switch (file_gettype(LabelFiles{1}))
                    case 'scout',        FileFormat = 'BST';
                    case 'subjectimage', FileFormat = 'MRI-MASK-NOOVERLAP';
                    otherwise,           Messages = 'Unsupported Brainstorm file type.'; return;
                end
            otherwise,  Messages = 'Unknown file extension.'; return;
        end
    end
end


%% ===== READ FILES =====
% Read destination surface
sSurf = bst_memory('GetSurface', file_short(SurfaceFile));
if isempty(sSurf)
    isLoadedHere = 1;
    sSurf = bst_memory('LoadSurface', file_short(SurfaceFile));
    panel_scout('SetCurrentSurface', sSurf.FileName);
else
    isLoadedHere = 0;
end
% Process one after the other
for iFile = 1:length(LabelFiles)
    LabelsTable = [];
    % Get updated atlases after the first iteration
    if (iFile > 1)
        sSurf = bst_memory('LoadSurface', file_short(SurfaceFile));
    end
    % Use the grid of points provided in input if available
    if ~isempty(GridLoc)
        Vertices = GridLoc;
        isVolumeAtlas = 1;
    % Otherwise, use the vertices of the cortex surface
    else
        Vertices = sSurf.Vertices;
        isVolumeAtlas = 0;
    end
    % Get filename
    [fPath, fBase, fExt] = bst_fileparts(LabelFiles{iFile});
    % Is it a Brainstorm volume atlas from the subject anatomy?
    isVolatlas = strcmpi(fExt, '.mat') && ~isempty(strfind(fBase, '_volatlas'));
    % New atlas structure: use filename as the atlas name
    if isNewAtlas || isempty(sSurf.Atlas) || isempty(sSurf.iAtlas)
        sAtlas = db_template('Atlas');
        iAtlas = 'Add';
        % Volume sources file
        if ~isempty(GridLoc)
            if isVolatlas
                sAtlas.Name = sprintf('Volume %d: ', length(GridLoc));
            else
                sAtlas.Name = sprintf('Volume %d: %s', length(GridLoc), fBase);
            end
            sAtlas.Name = file_unique(sAtlas.Name, {sSurf.Atlas.Name});
        % Surface sources file
        else
            % Get atlas name for standard FreeSurfer and MarsAtlas files
            if isVolatlas
                sAtlas.Name = 'From volume: ';
            else
                sAtlas.Name = GetAtlasName(fBase);
            end
        end
    % Existing atlas structure
    else
        iAtlas = sSurf.iAtlas;
        sAtlas = sSurf.Atlas(iAtlas);
        % For volume source files: Can only import volume scouts
        if ~isempty(GridLoc)
            % Can only work with volume scouts
            [isVolumeAtlas, nAtlasGrid] = panel_scout('ParseVolumeAtlas', sAtlas.Name);
            if ~isVolumeAtlas
                Messages = [Messages, 'Error: You can only load volume scouts for this sources file.'];
                return;
            end
            % Check the number of sources
            if (length(GridLoc) ~= nAtlasGrid)
                Messages = [Messages, sprintf('Error: The number of grid points in this sources file (%d) does not match the selected atlas (%d).', length(GridLoc), nAtlasGrid)];
                return;
            end
        end
    end
    % Check that atlas have the correct structure
    if isempty(sAtlas.Scouts)
        sAtlas.Scouts = repmat(db_template('scout'), 0);
    end
    % Switch based on file format
    switch (FileFormat)
        % ===== FREESURFER ANNOT =====
        case 'FS-ANNOT'
            % === READ FILE ===
            % Read .annot file
            % Number of labels (and vertices) in annot file can be different from number of vertices in surface
            try
                [vertices, labels, colortable] = read_annotation(LabelFiles{iFile}, 0);
            catch
                Messages = [Messages, sprintf('%s: read_annotation crashed: %s\n', [fBase, fExt], lasterr)];
                continue
            end

            % === CONVERT TO SCOUTS ===
            % Convert to scouts structures
            lablist = unique(labels);
            % Loop on each label
            for i = 1:length(lablist)
                % Find entry in the colortable
                iTable = find(colortable.table(:,5) == lablist(i));
                % If correspondence not defined: ignore label
                if (length(iTable) ~= 1)
                    continue;
                end             
                % New scout index
                iScout = length(sAtlas.Scouts) + 1;
                sAtlas.Scouts(iScout).Vertices = 1 + vertices(labels == lablist(i))';
                if ~isempty(colortable.struct_names{iTable})
                    % Strip uselss parts of Schaeffer labels
                    Label = colortable.struct_names{iTable};
                    Label = strrep(Label, '17Networks_LH_', '');
                    Label = strrep(Label, '17Networks_RH_', '');
                    Label = strrep(Label, '7Networks_LH_', '');
                    Label = strrep(Label, '7Networks_RH_', '');
                    sAtlas.Scouts(iScout).Label = file_unique(Label, {sAtlas.Scouts.Label});
                else
                    sAtlas.Scouts(iScout).Label = file_unique('Unknown', {sAtlas.Scouts.Label});
                end
                sAtlas.Scouts(iScout).Color    = colortable.table(iTable,1:3) ./ 255;
                sAtlas.Scouts(iScout).Function = 'Mean';
                sAtlas.Scouts(iScout).Region   = 'UU';
            end
            if isempty(sAtlas.Scouts)
                Messages = [Messages, fBase, ': Could not match labels and color table.' 10];
                continue;
            end

        % ==== FREESURFER LABEL ====
        case {'FS-LABEL', 'FS-LABEL-SINGLE'}
            % === READ FILE ===
            % Read label file
            LabelMat = mne_read_label_file(LabelFiles{iFile});
            % Convert indices from 0-based to 1-based
            LabelMat.vertices = LabelMat.vertices + 1;
            % Check sizes
            if (max(LabelMat.vertices) > length(Vertices))
                Messages = [Messages, sprintf('%s: Numbers of vertices in the label file (%d) exceeds the number of vertices in the surface (%d)\n', fBase, max(LabelMat.vertices), length(Vertices))];
                continue
            end
            % === CONVERT TO SCOUTS ===
            % Number of ROIs
            if strcmpi(FileFormat, 'FS-LABEL-SINGLE')
                uniqueValues = 1;
            else
                uniqueValues = unique(LabelMat.values);
                minmax = [min(uniqueValues), max(uniqueValues)];
            end
            % Loop on each label
            for i = 1:length(uniqueValues)
                % New scout index
                iScout = length(sAtlas.Scouts) + 1;
                % Single ROI
                if strcmpi(FileFormat, 'FS-LABEL-SINGLE')
                    ScoutVert = sort(double(LabelMat.vertices));
                    Label = GetAtlasName(fBase);
                    Color = [];
                % Probability map
                else
                    % Calculate intensity [0,1]
                    if (minmax(1) == minmax(2))
                        c = 0;
                    else
                        c = (uniqueValues(i) - minmax(1)) ./ (minmax(2) - minmax(1));
                    end
                    ScoutVert = sort(double(LabelMat.vertices(LabelMat.values == uniqueValues(i))));
                    Label = file_unique(num2str(uniqueValues(i)), {sAtlas.Scouts.Label});
                    Color = [1 c 0];
                end
                % Create structure
                sAtlas.Scouts(iScout).Vertices = ScoutVert(:)';
                sAtlas.Scouts(iScout).Seed     = [];
                sAtlas.Scouts(iScout).Label    = Label;
                sAtlas.Scouts(iScout).Color    = Color;
                sAtlas.Scouts(iScout).Function = 'Mean';
                sAtlas.Scouts(iScout).Region   = 'UU';
            end
            if isempty(sAtlas.Scouts)
                Messages = [Messages, fBase, ': Could not match labels and color table.' 10];
                continue;
            end
            
        % ==== BRAINVISA GIFTI =====
        case 'GII-TEX'
            % Remove the "L" and "R" strings from the name
            AtlasName = sAtlas.Name;
            AtlasName = strrep(AtlasName, 'R', '');
            AtlasName = strrep(AtlasName, 'L', '');
            % Get labels
            LabelsTable = mri_getlabels(LabelFiles{iFile});
            % Read .gii file
            [sXml, Values] = in_gii(LabelFiles{iFile});
            % If there is more than one entry: force adding
            if (length(Values) > 1)
                iAtlas = 'Add';
            end
            % Process all the entries
            for ia = 1:length(Values)
                % Atlas name
                if (length(Values) > 1) && isNewAtlas
                    sAtlas(ia).Name = sprintf('%s #%d', AtlasName, ia);
                    sAtlas(ia).Scouts = repmat(db_template('scout'), 0);
                end
                % Check sizes
                if (length(Values{ia}) ~= length(Vertices))
                    Messages = [Messages, sprintf('%s: Entry #%d: Numbers of vertices in the surface (%d) and the label file (%d) do not match\n', fBase, ia, length(Vertices), length(Values{ia}))];
                    continue;
                elseif (all(size(Values{ia}) > 1))
                    Messages = [Messages, sprintf('%s: Entry #%d: Not a list of labels\n', fBase, ia)];
                    continue;
                end
                % Round the label values
                Values{ia} = round(Values{ia} * 1e3) / 1e3;
                % Convert to scouts structures
                lablist = unique(Values{ia});
                % Loop on each label
                for i = 1:length(lablist)
                    % Scout label: atlas or simply value converted to strinf
                    if ~isempty(LabelsTable) && ismember(lablist(i), [LabelsTable{:,1}])
                        scoutLabel = LabelsTable{lablist(i) == [LabelsTable{:,1}], 2};
                        scoutColor = LabelsTable{lablist(i) == [LabelsTable{:,1}], 3} ./ 255;
                    else
                        scoutLabel = num2str(lablist(i));
                        scoutColor = [];
                    end
                    % New scout index
                    iScout = length(sAtlas(ia).Scouts) + 1;
                    % Get the vertices for this annotation
                    sAtlas(ia).Scouts(iScout).Vertices = reshape(find(Values{ia} == lablist(i)), 1, []);
                    sAtlas(ia).Scouts(iScout).Seed     = [];
                    sAtlas(ia).Scouts(iScout).Label    = file_unique(scoutLabel, {sAtlas(ia).Scouts.Label});
                    sAtlas(ia).Scouts(iScout).Color    = scoutColor;
                    sAtlas(ia).Scouts(iScout).Function = 'Mean';
                    sAtlas(ia).Scouts(iScout).Region   = 'UU';
                end
            end
            
        % ===== SUMA DSET ROIs =====
        case 'DSET'
            % Read file
            sAtlas.Scouts = in_label_dset(LabelFiles{iFile});
            % Force adding new atlas
            iAtlas = 'Add';
            
        % ===== MRI VOLUMES =====
        case {'MRI-MASK', 'MRI-MASK-MNI', 'MRI-MASK-NOOVERLAP', 'MRI-MASK-NOOVERLAP-MNI'}
            bst_progress('text', 'Reading atlas...');
            % If the file that is loaded has to be interpreted in MNI space
            isMni = strcmpi(FileFormat, 'MRI-MASK-MNI') || strcmpi(FileFormat, 'MRI-MASK-NOOVERLAP-MNI');
            isOverlap = strcmpi(FileFormat, 'MRI-MASK') || strcmpi(FileFormat, 'MRI-MASK-MNI');
            % Read MRI volume  (do not normalize values when reading an atlas)
            if isVolatlas
                sMriMask = in_mri_bst(LabelFiles{iFile});
                sAtlas.Name = [sAtlas.Name, str_remove_parenth(sMriMask.Comment)];
            elseif isMni
                sMriMask = in_mri(LabelFiles{iFile}, 'ALL-MNI', [], 0);
            else
                sMriMask = in_mri(LabelFiles{iFile}, 'ALL', [], 0);
            end
            if isempty(sMriMask)
                return;
            end
            % Select only the first volume (if more than one) 
            sMriMask.Cube = double(sMriMask.Cube(:,:,:,1));
            % Display warning when no MNI transformation available
            if isMni && (~isfield(sMriMask, 'NCS') || ...
                ((~isfield(sMriMask.NCS, 'R') || ~isfield(sMriMask.NCS, 'T') || isempty(sMriMask.NCS.R) || isempty(sMriMask.NCS.T)) && ... 
                 (~isfield(sMriMask.NCS, 'iy') || isempty(sMriMask.NCS.iy))))
                isMni = 0;
                disp('Error: No MNI normalization available in this file.');
            end
            % Get all the values in the MRI
            bst_progress('text', 'Extract regions...');
            allValues = unique(sMriMask.Cube);
            % If values are not integers, it is not a mask or an atlas: it has to be binarized first
            if any(allValues ~= round(allValues))
                % Warning: not a binary mask
                isConfirm = java_dialog('confirm', ['Warning: This is not a binary mask.' 10 'Try to import this MRI as a surface anyway?'], 'Import binary mask');
                if ~isConfirm
                    return;
                end
                % Analyze MRI histogram
                Histogram = mri_histogram(sMriMask.Cube);
                % Binarize based on background level
                sMriMask.Cube = (sMriMask.Cube > Histogram.bgLevel);
                allValues = [0,1];
            end
            % Skip the first value (background)
            allValues(1) = [];
            % Load the subject SCS coordinates
            sSubject = bst_get('SurfaceFile', SurfaceFile);
            sMriSubj = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
            % Converting the sSurf vertices to the loaded MRI volume
            if isMni
                % The original volume is in subject space and and the atlas volume is in MNI space
                vertMni = cs_convert(sMriSubj, 'scs', 'mni', Vertices);
                if isempty(vertMni)
                    Messages = [Messages, 'Error: Compute the MNI transformation first.'];
                    return
                end
                vertMri = round(cs_convert(sMriMask, 'mni', 'voxel', vertMni));
            else
                % Check the compatibility of MRI sizes
                if ~isequal(size(sMriSubj.Cube), size(sMriMask.Cube))
                    Messages = [Messages, 'Error: The selected MRI file does not match the size of the subject''s MRI.' 10 10 ...
                                          'If the MRI is an atlas in a normalized MNI space, use the file format ' 10 ...
                                          '"Volume mask or atlas (MNI space)".' 10 10];
                    return;
                end
                % Both the original volume and the atlas volume and in the same subject space
                vertMri = round(cs_convert(sMriSubj, 'scs', 'voxel', Vertices));
            end
            % Get the corresponding MRI labels
            indMri = sub2ind(size(sMriMask.Cube), ...
                        bst_saturate(vertMri(:,1), [1, size(sMriMask.Cube,1)]), ...
                        bst_saturate(vertMri(:,2), [1, size(sMriMask.Cube,2)]), ...
                        bst_saturate(vertMri(:,3), [1, size(sMriMask.Cube,3)]));
            % Try to get volume labels for this atlas
            if isVolatlas
                VolumeLabels = sMriMask.Labels;
            else
                VolumeLabels = mri_getlabels(LabelFiles{iFile});
            end
            % Create one scout for each value in the volume
            for i = 1:length(allValues)
                bst_progress('text', sprintf('Creating scouts... [%d/%d]', i, length(allValues)));
                % Get the binary mask of the current region
                mask = (sMriMask.Cube == allValues(i));
                % Dilate mask
                if isOverlap
                    mask = mri_dilate(mask);
                    mask = mri_dilate(mask);
                end
                % Get the vertices in this mask
                iScoutVert = find(mask(indMri));
                if isempty(iScoutVert)
                    continue;
                end
                
                % New scout index
                iScout = length(sAtlas.Scouts) + 1;
                sAtlas.Scouts(iScout).Seed     = [];
                sAtlas.Scouts(iScout).Color    = [];
                sAtlas.Scouts(iScout).Function = 'Mean';
                sAtlas.Scouts(iScout).Region   = 'UU';
                % Use an existing label for the loaded atlas
                if ~isempty(VolumeLabels)
                    iLabel = find([VolumeLabels{:,1}] == allValues(i));
                    if ~isempty(iLabel)
                        sAtlas.Scouts(iScout).Label = file_unique(VolumeLabels{iLabel,2}, {sAtlas.Scouts.Label});
                        if (length(VolumeLabels{iLabel,2}) > 2)
                            if (VolumeLabels{iLabel,2}(end-1:end) == ' L')
                                sAtlas.Scouts(iScout).Region = 'LU';
                            elseif (VolumeLabels{iLabel,2}(end-1:end) == ' R')
                                sAtlas.Scouts(iScout).Region = 'RU';
                            end
                        end
                        if (size(VolumeLabels,2) >= 3) && (length(VolumeLabels{iLabel,3}) == 3)
                            sAtlas.Scouts(iScout).Color = VolumeLabels{iLabel,3} ./ 255;
                        end
                    else
                        sAtlas.Scouts(iScout).Label = file_unique(num2str(allValues(i)), {sAtlas.Scouts.Label});
                    end
                else
                    sAtlas.Scouts(iScout).Label = file_unique(num2str(allValues(i)), {sAtlas.Scouts.Label});
                end
                
                % If importing an atlas in MNI coordinates
                if isMni
                    % Get the coordinates of all the points in the mask
                    Pvox = [];
                    [Pvox(:,1),Pvox(:,2),Pvox(:,3)] = ind2sub(size(mask), indMri(iScoutVert));
                    % Convert to MNI coordinates
                    Pmni = cs_convert(sMriMask, 'voxel', 'mni', Pvox);
                    % Find left and right areas
                    iL = find(Pmni(:,1) < 0);
                    iR = find(Pmni(:,1) >= 0);
                    % If there is about the same number of points in the two sides: consider it's a bilateral region
                    if isempty(iL) || isempty(iR)
                        isSplit = 0;
                    elseif (length(iL) / length(iR) < 1.6) && (length(iL) / length(iR) > 0.4)
                        isSplit = 1;
                    % If the name starts with "S_", "G_" or "N_", it's also a bilateral region
                    elseif (length(sAtlas.Scouts(iScout).Label) >= 3) && ismember(sAtlas.Scouts(iScout).Label(1:2), {'S_', 'G_', 'N_'})
                        isSplit = 1;
                    else
                        isSplit = 0;
                    end
                    % If this is a bilateral region: split in two
                    if isSplit
                        % Duplicate scout
                        sAtlas.Scouts(iScout+1) = sAtlas.Scouts(iScout);
                        % Left scout
                        sAtlas.Scouts(iScout).Vertices = reshape(iScoutVert(iL), 1, []);
                        sAtlas.Scouts(iScout).Label    = [sAtlas.Scouts(iScout).Label, ' L'];
                        sAtlas.Scouts(iScout).Region   = 'LU';
                        % Right scout
                        sAtlas.Scouts(iScout+1).Vertices = reshape(iScoutVert(iR), 1, []);
                        sAtlas.Scouts(iScout+1).Label    = [sAtlas.Scouts(iScout+1).Label, ' R'];
                        sAtlas.Scouts(iScout+1).Region   = 'RU';
                    % Do not split
                    else
                        sAtlas.Scouts(iScout).Vertices = iScoutVert(:)';
                    end
                % Importing regular subject volume: Select all the vertices
                else
                    sAtlas.Scouts(iScout).Vertices = iScoutVert(:)';
                end
            end
            bst_progress('text', 'Saving atlas...');
            
        % ===== BRAINSTORM SCOUTS =====
        case 'BST'
            % Load file
            ScoutMat = load(LabelFiles{iFile});
            % Convert old scouts structure to new one
            if isfield(ScoutMat, 'Scout')
                ScoutMat.Scouts = ScoutMat.Scout;
            elseif isfield(ScoutMat, 'Scouts')
                % Ok
            else
                Messages = [Messages, fBase, ': Invalid scouts file.' 10];
                continue;
            end
            % Check the number of vertices
            if ~isVolumeAtlas && (length(Vertices) ~= ScoutMat.TessNbVertices)
                Messages = [Messages, sprintf('%s: Numbers of vertices in the surface (%d) and the scout file (%d) do not match\n', fBase, length(Vertices), ScoutMat.TessNbVertices)];
                continue;
            end
            % If name is not defined: use the filename
            if isNewAtlas
                if isfield(ScoutMat, 'Name') && ~isempty(ScoutMat.Name)
                    sAtlas.Name = ScoutMat.Name;
                else
                    [fPath,fBase] = bst_fileparts(LabelFiles{iFile});
                    sAtlas.Name = strrep(fBase, 'scout_', '');
                end
            end
            % Copy the new scouts
            for i = 1:length(ScoutMat.Scouts)
                iScout = length(sAtlas.Scouts) + 1;
                sAtlas.Scouts(iScout).Vertices = ScoutMat.Scouts(i).Vertices(:)';
                sAtlas.Scouts(iScout).Seed     = ScoutMat.Scouts(i).Seed;
                sAtlas.Scouts(iScout).Color    = ScoutMat.Scouts(i).Color;
                sAtlas.Scouts(iScout).Label    = file_unique(ScoutMat.Scouts(i).Label, {sAtlas.Scouts.Label});
                sAtlas.Scouts(iScout).Function = ScoutMat.Scouts(i).Function;
                if isfield(ScoutMat.Scouts(i), 'Region')
                    sAtlas.Scouts(iScout).Region = ScoutMat.Scouts(i).Region; 
                else
                    sAtlas.Scouts(iScout).Region = 'UU';
                end
            end

        % ===== BrainSuite/SVReg surface file =====
        case 'DFS'
            % === READ FILE ===
            [VertexLabelIds, labelMap, AtlasName] = in_label_bs(LabelFiles{iFile});
            
            % === CONVERT TO SCOUTS ===
            % Convert to scouts structures
            lablist = unique(VertexLabelIds);
            if isNewAtlas
                if isempty(AtlasName)
                    sAtlas.Name = 'SVReg';
                else
                    sAtlas.Name = AtlasName;
                end
            end

            % Loop on each label
            if isempty(labelMap)
                new_colors = distinguishable_colors(length(lablist), [0,0,0]);
                new_colors(1,:) = [0.5,0.5,0.5];
            end

            for i = 1:length(lablist)
                % Find label ID
                id = lablist(i);
                % Skip if label id is not in labelMap
                if isempty(labelMap)
                    labelInfo.Name = num2str(id);
                    labelInfo.Color = new_colors(i,:)';                    
                    %continue;
                elseif ~labelMap.containsKey(num2str(id))
                    labelInfo.Name = num2str(id);
                    labelInfo.Color = [0,0,0]';                                    
                else
                    entry = labelMap.get(num2str(id));
                    labelInfo.Name = entry(1);
                    labelInfo.Color = entry(2);
                end
                % Transpose color vector
                labelInfo.Color = labelInfo.Color(:)';
                % Skip the "background" scout
                if strcmpi(labelInfo.Name, 'background')
                    labelInfo.Color = [0.5,0.5,0.5]';
                    continue;
                end
                % New scout index
                iScout = length(sAtlas.Scouts) + 1;
                sAtlas.Scouts(iScout).Vertices = reshape(find(VertexLabelIds == id), 1, []);
                sAtlas.Scouts(iScout).Label    = file_unique(labelInfo.Name, {sAtlas.Scouts.Label});
                sAtlas.Scouts(iScout).Color    = labelInfo.Color;
                sAtlas.Scouts(iScout).Function = 'Mean';
                sAtlas.Scouts(iScout).Region   = 'UU';
            end
            if isempty(sAtlas.Scouts)
                Messages = [Messages, fBase, ': Could not match vertex labels and label description file.' 10];
                continue;
            end

        % ===== Unknown file =====
        otherwise
            Messages = [Messages, fBase, ': Unknown file extension.' 10];
            continue;
    end
    
    % Get the scouts colortable
    ColorTable = panel_scout('GetScoutsColorTable');
    % Loop on all the loaded atlases
    for ia = 1:length(sAtlas)
        if isempty(sAtlas(ia).Scouts)
            continue;
        end
        % Brodmann atlas: remove the "Unknown" scout
        iUnknown = find(strcmpi({sAtlas(ia).Scouts.Label}, 'unknown') | strcmpi({sAtlas(ia).Scouts.Label}, 'medial.wall') | strcmpi({sAtlas(ia).Scouts.Label}, 'freesurfer_defined_medial_wall'));
        if ~isempty(iUnknown)
            sAtlas(ia).Scouts(iUnknown) = [];
        end
        % Fix all the scouts seeds and identify regions
        for i = 1:length(sAtlas(ia).Scouts)
            % Fix seed
            if isempty(sAtlas(ia).Scouts(i).Seed) || ~ismember(sAtlas(ia).Scouts(i).Seed, sAtlas(ia).Scouts(i).Vertices)
                sAtlas(ia).Scouts(i) = panel_scout('SetScoutsSeed', sAtlas(ia).Scouts(i), Vertices);
            end
            % Fix regions
            if isempty(sAtlas(ia).Scouts(i).Region) || strcmpi(sAtlas(ia).Scouts(i).Region, 'UU')
                sAtlas(ia).Scouts(i) = tess_detect_region(sAtlas(ia).Scouts(i));
            end
            % Fix color
            if isempty(sAtlas(ia).Scouts(i).Color)
                iColor = mod(i-1, length(ColorTable)) + 1;
                sAtlas(ia).Scouts(i).Color = ColorTable(iColor,:);
            end
        end
        % Sort scouts by alphabetical order
        if ~strcmpi(FileFormat, 'BST')
            [tmp,I] = sort(lower({sAtlas(ia).Scouts.Label}));
            sAtlas(ia).Scouts = sAtlas(ia).Scouts(I);
        end
        % Return new atlas
        sAllAtlas(end+1) = sAtlas(ia);
        % Add atlas to the surface
        panel_scout('SetAtlas', SurfaceFile, iAtlas, sAtlas(ia));
    end
end


%% ===== SAVE IN SURFACE =====
% Unload surface to save it
if isLoadedHere
    bst_memory('UnloadSurface', SurfaceFile);
end


end

    
%% ===== GET ATLAS NAME =====
function AtlasName = GetAtlasName(fBase)
    fBase = lower(fBase);
    switch (fBase)
        case {'lh.aparc.a2009s', 'rh.aparc.a2009s'}
            AtlasName = 'Destrieux';
        case {'lh.aparc', 'rh.aparc'}
            AtlasName = 'Desikan-Killiany';
        case {'lh.ba', 'rh.ba', 'lh.ba_exvivo', 'rh.ba_exvivo'}
            AtlasName = 'Brodmann';
        case {'lh.ba.thresh', 'rh.ba.thresh', 'lh.ba_exvivo.thresh', 'rh.ba_exvivo.thresh'}
            AtlasName = 'Brodmann-thresh';
        case {'lh.aparc.dktatlas40', 'rh.aparc.dktatlas40'}
            AtlasName = 'DKT40';
        case {'lh.aparc.dktatlas', 'rh.aparc.dktatlas', 'lh.aparc.mapped', 'rh.aparc.mapped'}  % FreeSurfer, FastSurfer
            AtlasName = 'DKT';
        case {'lh.pals_b12_brodmann', 'rh.pals_b12_brodmann'}
            AtlasName = 'PALS-B12 Brodmann';
        case {'lh.pals_b12_lobes', 'rh.pals_b12_lobes'}
            AtlasName = 'PALS-B12 Lobes';
        case {'lh.pals_b12_orbitofrontal', 'rh.pals_b12_orbitofrontal'}
            AtlasName = 'PALS-B12 Orbito-frontal';
        case {'lh.pals_b12_visuotopic', 'rh.pals_b12_visuotopic'}
            AtlasName = 'PALS-B12 Visuotopic';
        case {'lh.yeo2011_7networks_n1000', 'rh.yeo2011_7networks_n1000'}
            AtlasName = 'Yeo 7 Networks';
        case {'lh.yeo2011_17networks_n1000', 'rh.yeo2011_17networks_n1000'}
            AtlasName = 'Yeo 17 Networks';
        case {'lh.prf', 'rh.prf'}
            AtlasName = 'Retinotopy';
        case {'lh.myaparc_36', 'rh.myaparc_36'}
            AtlasName = 'Lausanne-S33';
        case {'lh.myaparc_60', 'rh.myaparc_60'}
            AtlasName = 'Lausanne-S60';
        case {'lh.myaparc_125', 'rh.myaparc_125'}
            AtlasName = 'Lausanne-S125';
        case {'lh.myaparc_250', 'rh.myaparc_250'}
            AtlasName = 'Lausanne-S250';
        case {'lh.bn_atlas', 'rh.bn_atlas'}
            AtlasName = 'Brainnetome';
        case {'lh.oasis.chubs', 'rh.oasis.chubs'}
            AtlasName = 'OASIS cortical hubs';
        case {'lh.mpm.vpnl', 'rh.mpm.vpnl'}
            AtlasName = 'vcAtlas';
        otherwise
            % CAT12 / FreeSurfer
            if ~isempty(strfind(fBase, 'aparc_a2009s'))
                AtlasName = 'Destrieux';
            elseif ~isempty(strfind(fBase, 'dk40'))
                AtlasName = 'Desikan-Killiany';
            elseif ~isempty(strfind(fBase, 'hcp_mmp')) || ~isempty(strfind(fBase, 'hcp-mmp'))
                AtlasName = 'HCP_MMP1';
            elseif ~isempty(strfind(fBase, 'schaefer2018_100parcels_17'))
                AtlasName = 'Schaefer_100_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_200parcels_17'))
                AtlasName = 'Schaefer_200_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_400parcels_17'))
                AtlasName = 'Schaefer_400_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_600parcels_17'))
                AtlasName = 'Schaefer_600_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_800parcels_17'))
                AtlasName = 'Schaefer_800_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_1000parcels_17'))
                AtlasName = 'Schaefer_1000_17net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_100parcels_7'))
                AtlasName = 'Schaefer_100_7net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_200parcels_7'))
                AtlasName = 'Schaefer_200_7net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_400parcels_7'))
                AtlasName = 'Schaefer_400_7net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_600parcels_7'))
                AtlasName = 'Schaefer_600_7net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_800parcels_7'))
                AtlasName = 'Schaefer_800_7net';
            elseif ~isempty(strfind(fBase, 'schaefer2018_1000parcels_7'))
                AtlasName = 'Schaefer_1000_7net';
            % FreeSurfer left/right
            elseif (length(fBase) > 3) && (strcmpi(fBase(1:3), 'lh.') || strcmpi(fBase(1:3), 'rh.'))
                AtlasName = fBase(4:end);
            % BrainVISA/MarsAtlas
            elseif (~isempty(strfind(fBase, '_lwhite_parcels_marsatlas')) || ~isempty(strfind(fBase, '_rwhite_parcels_marsatlas')))
                AtlasName = 'MarsAtlas';
            elseif (~isempty(strfind(fBase, '_lwhite_parcels_model')) || ~isempty(strfind(fBase, '_rwhite_parcels_model')))
                AtlasName = 'MarsAtlas model';
            elseif (~isempty(strfind(fBase, '_lwhite_pole_cingular')) || ~isempty(strfind(fBase, '_rwhite_pole_cingular')))
                AtlasName = 'MarsAtlas pole cingular';
            elseif (~isempty(strfind(fBase, '_lwhite_pole_insula')) || ~isempty(strfind(fBase, '_rwhite_pole_insula')))
                AtlasName = 'MarsAtlas pole insula';
            elseif (~isempty(strfind(fBase, '_lwhite_sulcalines')) || ~isempty(strfind(fBase, '_rwhite_sulcalines')))
                AtlasName = 'MarsAtlas sulcal lines';
            else
                AtlasName = fBase;
            end
    end
end
