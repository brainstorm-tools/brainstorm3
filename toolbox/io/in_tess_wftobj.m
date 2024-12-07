function TessMat = in_tess_wftobj(TessFile)
% IN_TESS_WFTOBJ: Load a WAVEFRONT OBJ mesh file.
%
% USAGE:  TessMat = in_tess_wftobj(TessFile, FileType);
%
% INPUT: 
%     - TessFile   : full path to a tesselation file (*.obj)
%
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure with fields:
%         |- Vertices : {[nVertices x 3] double}, in millimeters
%         |- Faces    : {[nFaces x 3] double}
%         |- Color    : {[nColors x 3] double}, normalized between 0-1
%         |- Comment  : {information string}
%
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
% Authors: Yash Shashank Vakilna, 2024
%          Chinmay Chinara,       2024
%          Raymundo Cassani,      2024

%% ===== PARSE INPUTS =====
% Check inputs
if (nargin < 1) 
    bst_error('Invalid call. Please specify the mesh file to be loaded.', 'Importing tesselation', 1);
end

%% ===== PARSE THE OBJ FILE: SET UP IMPORT OPTIONS AND IMPORT THE DATA =====
if bst_get('MatlabVersion') < 901
    % MATLAB < R2016b
    % Read entire .wobj file
    fid = fopen(TessFile, 'r');
        txtStr = fread(fid, '*char')';
    fclose(fid);
    % Keep relevant lines from file content
    allData = regexp(txtStr, '(\w)+ ([^\n])*\n', 'tokens'); % (\w) ignores comments (#)
    allData = cat(1,allData{:});
    % Read data for each element type
    elementTags = {'v', 'vt', 'f'}; % Vertices, Texture, Faces
    elementData = cell(1, length(elementTags));
    % Parse element data
    for iElement = 1: length(elementTags)
        iLines = strcmp(elementTags{iElement}, allData(:,1));
        elementTmp = regexp(allData(iLines, 2), '([e|\-|\.|\d])*', 'match')';
        elementTmp = cat(1, elementTmp{:});
        elementSize = size(elementTmp);
        elementTmp = sscanf(sprintf(' %s', elementTmp{:}), '%f'); % Faster than str2double
        elementData{iElement} = reshape(elementTmp, elementSize);
    end
    vertices   = elementData{1, 1}(:, 1:3); % Use only the first 3
    texture    = elementData{2};
    faces      = elementData{1, 3}(:, [3,6,9]);
    textureIdx = elementData{1, 3}(:, [2,5,8]);
else
    % MATLAB R2016b to R2018a had 'DelimitedTextImportOptions'
    if(bst_get('MatlabVersion') >= 901) && (bst_get('MatlabVersion') <= 904)
        opts = matlab.io.text.DelimitedTextImportOptions();
    else
        opts = delimitedTextImportOptions('NumVariables', 10);
    end

    opts.Delimiter     = {' ', '/'};
    opts.VariableNames = {'type', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9'};
    opts.VariableTypes = {'categorical', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}; 
    
    % Specify file level properties
    opts.ExtraColumnsRule = 'ignore';
    opts.EmptyLineRule    = 'read';
    
    % Import the data
    objtbl = readtable(TessFile, opts);
    
    obj = struct;
    obj.Vertices      = objtbl{objtbl.type=='v',  2:4};
    obj.VertexNormals = objtbl{objtbl.type=='vn', 2:4};
    obj.Faces         = objtbl{objtbl.type=='f', [2,5,8]};
    obj.TextCoords    = objtbl{objtbl.type=='vt', 2:3};
    obj.TextIndices   = objtbl{objtbl.type=='f', [3,6,9]};
    % For some OBJ's exported from 3D softwares like Maya and Blender, when parsed using 
    % 'readtable', the vertex coordinates start from the 3rd column
    if isnan(obj.Vertices(:,1))
        obj.Vertices  = objtbl{objtbl.type=='v',  3:5};
    end        
    vertices   = obj.Vertices;
    faces      = obj.Faces;
    texture    = obj.TextCoords;
    textureIdx = obj.TextIndices;
end

%% ===== REFINE FACES, MESH AND GENERATE COLOR MATRIX =====
% Check if there exists a .jpg file of 'TessFile'
[pathstr, name] = fileparts(TessFile);
if exist(fullfile(pathstr, [name, '.jpg']), 'file')
    image = fullfile(pathstr, [name, '.jpg']);
    hasimage = true;
elseif exist(fullfile(pathstr,[name,'.png']), 'file')
    image    = fullfile(pathstr,[name,'.png']);
    hasimage = true;
else
    hasimage = false;
end

% Check if the texture is defined per vertex, in which case the texture can be refined below
if size(texture, 1)==size(vertices, 1)
    texture_per_vert = true;
else
    texture_per_vert = false;
end

% Remove the faces with 0's first
allzeros = sum(faces==0,2)==3;
faces(allzeros, :)      = [];
textureIdx(allzeros, :) = [];

% Check whether all vertices belong to a face. If not, prune the vertices and keep the faces consistent.
ufacesIdx = unique(faces(:));
remove  = setdiff((1:size(vertices, 1))', ufacesIdx);
if ~isempty(remove)
    [vertices, faces] = tess_remove_vert(vertices, faces, remove);
    if texture_per_vert
        % Also remove the removed vertices from the texture
        texture(remove, :) = [];
    end
end

color = [];
if hasimage
    % If true then there is an image/texture with color information
    if texture_per_vert
        picture = imread(image);
        color   = zeros(size(vertices, 1), 3);
        for i = 1:size(vertices, 1)
            color(i,1:3) = picture(floor((1-texture(i,2))*length(picture)),1+floor(texture(i,1)*length(picture)),1:3);
        end
    else
        % Do the texture to color mapping in a different way, without additional refinement
        picture      = flip(imread(image),1);
        [sy, sx, sz] = size(picture);
        picture      = reshape(picture, sy*sx, sz);
        
        % Make image 3D if grayscale
        if sz == 1
            picture = repmat(picture, 1, 3);
        end
        [~, ix] = unique(faces);
        textureIdx = textureIdx(ix);
        
        % Get the indices into the image
        x = abs(round(texture(:,1)*(sx-1)))+1;
        y = abs(round(texture(:,2)*(sy-1)))+1;

        % Eliminates points out of bounds
        if any(x > sx)
            texture(x > sx,:)   = 1;
            x(x > sx)           = sx;
        end

        if any(find(y > sy))
            texture(y > sy,:)   = 1;
            y(y > sy)           = sy;
        end

        xy    = sub2ind([sy sx], y, x);
        sel   = xy(textureIdx);
        color = double(picture(sel,:))/255;
    end
      
    % If color is specified as 0-255 rather than 0-1 correct by dividing by 255
    if range(color(:)) > 1
        color = color./255;
    end
end

% Centering vertices
vertices = vertices - repmat(mean(vertices,1), [size(vertices, 1),1]);

% Convert vertices' unit as locations in Brainstorm are saved in 'meters'
vertices = channel_fixunits(vertices, 'mm', 1, 1);

%% ===== BRAINSTORM SURFACE STRUCTURE =====
TessMat = struct('Faces',    faces, ...
                 'Vertices', vertices, ...
                 'Color',    color, ...
                 'Comment', '');
