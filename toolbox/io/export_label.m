function export_label(SurfaceFile, Atlas, OutputFile, FileFormat)
% EXPORT_LABEL: Export an atlas segmentation for a given surface
% 
% USAGE:  export_label(SurfaceFile, Atlas, OutputFile=[ask], FileFormat=[detect])
%         export_label(SurfaceFile, Atlas, OutputFile=[ask], FileFormat=[detect])

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
% Authors: Raymundo Cassani, 2026

% Get filename where to store the filename
% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(FileFormat)
    FileFormat = [];
end
if (nargin < 3) || isempty(OutputFile)
    OutputFile = [];
end
% CALL: export_label(SurfaceFile, ... )
if ischar(SurfaceFile)
    sSurf = in_tess_bst(SurfaceFile);
% CALL: export_label(sSurf, ... )
else
    sSurf = SurfaceFile;
end
% CALL: export_label(SurfaceFile, AtlasName)
if ischar(Atlas)
    Atlas = find(strcmp(Atlas, {sSurf.Atlas.Name}));
end
% CALL: export_label(SurfaceFile, AtlasIndex)
if isnumeric(Atlas)
    sAtlas = sSurf.Atlas(Atlas);
% CALL: export_label(SurfaceFile, sAtlas)
else
    sAtlas = Atlas;
end
if isempty(sAtlas)
    return
end
sScouts = sAtlas.Scouts;

% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile)
    % === Build a default filename ===
    LastUsedDirs = bst_get('LastUsedDirs');
    if strcmpi(sAtlas.Name, 'User scouts')
        if (length(sScouts) <= 3)
            OutputFile = bst_fullfile(LastUsedDirs.ExportAnat, ['scout', sprintf('_%s', sScouts.Label), '.mat']);
        else
            OutputFile = bst_fullfile(LastUsedDirs.ExportAnat, sprintf('scout_%d.mat', length(sScouts)));
        end
    else
        OutputFile = bst_fullfile(LastUsedDirs.ExportAnat, ['scout_', file_standardize(sAtlas.Name), sprintf('_%d.mat', length(sScouts))]);
    end
    % === Ask user filename ===
    [OutputFile, FileFormat] = java_getfile('save', 'Save selected scouts', OutputFile, ...
                             'single', 'files', ...
                             {{'_scout'}, 'Brainstorm cortical scouts (*scout*.mat)', 'BST'; ...
                              {'.label'}, 'FreeSurfer ROI, single scout (*.label)', 'FS-LABEL-SINGLE'; ...
                              {'.annot'}, 'FreeSurfer annotation, multiple scouts (*.annot)', 'FS-ANNOT'}, 1);
    if isempty(OutputFile)
        return;
    end
    % Save last used folder
    LastUsedDirs.ExportAnat = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs',  LastUsedDirs);

% Guess file format based on its extension
elseif isempty(FileFormat)
    [~, ~, BstExt] = bst_fileparts(OutputFile);
    switch lower(BstExt)
        case '.mat',   FileFormat = 'BST';
        case '.label', FileFormat = 'FS-LABEL-SINGLE';
        case '.annot', FileFormat = 'FS-ANNOT';
        otherwise,     error('Unsupported file extension.');
    end
end

% Switch file format
switch (FileFormat)
    case 'BST'
        % Make sure that filename contains the 'scout' tag
        if isempty(strfind(OutputFile, '_scout')) && isempty(strfind(OutputFile, 'scout_'))
            [filePath, fileBase, fileExt] = bst_fileparts(OutputFile);
            OutputFile = bst_fullfile(filePath, ['scout_' fileBase fileExt]);
        end
        % Save file
        bst_save(OutputFile, sAtlas, 'v7');

    case 'FS-LABEL-SINGLE'
        if length(sScouts) == 1
            out_label_fs(OutputFile, sScouts.Label, sScouts.Vertices - 1, sSurf.Vertices(sScouts.Vertices,:), ones(1, length(sScouts.Vertices)));
        else
            bst_error('FreeSurfer label file can only store a single scout. Please export each scout separatly');
            return;
        end

    case 'FS-ANNOT'
        vertices = [];
        label = [];
        ct = struct();
        ct.numEntries   = length(sScouts);
        ct.orig_tab     = sAtlas.Name;
        ct.struct_names = {sScouts.Label};
        ct.table = zeros(length(sScouts),5);

        % Make Scout colors unique, they need to be RGB with 0-255 range
        scoutColors = panel_scout('MakeColorsUnique', (round(cat(1, sScouts.Color) * 255)));
        for iScout = 1 : length(sScouts)
            sScouts(iScout).Color = scoutColors(iScout, :);
        end
        % Generate table with Scouts info
        for iScout = 1:length(sScouts)
            ct.table(iScout,1:3) = sScouts(iScout).Color;
            ct.table(iScout,5)   = ct.table(iScout,1) + ct.table(iScout,2) *2^8 + ct.table(iScout,3) *2^16;
            vertices = [vertices, sScouts(iScout).Vertices];
            label    = [label,  repmat(ct.table(iScout,5), 1, length(sScouts(iScout).Vertices))];
        end
        % A label for each vertex is needed, orphan vertices set as 'background'
        orphanVertices = setdiff(1:size(sSurf.Vertices,1), vertices);
        if ~isempty(orphanVertices)
            ct.numEntries          = ct.numEntries + 1;
            ct.struct_names{end+1} = 'background';
            ct.table(end+1, :)     = zeros(1,5);
            ct.table(end,1:3)      = [0 0 0];
            ct.table(end,5)        = ct.table(end,1) + ct.table(end,2) *2^8 + ct.table(end,3) *2^16;
            vertices = [vertices, orphanVertices];
            label    = [label,  repmat(ct.table(end,5), 1, length(orphanVertices))];
        end
        vertices = vertices-1; % 0-indexed
        write_annotation(OutputFile, vertices, label, ct)
end
