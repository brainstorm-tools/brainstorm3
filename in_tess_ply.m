function TessMat = in_tess_ply(TessFile)
% IN_TESS_PLY: Import a PLY mesh file.
%
% USAGE:  TessMat = in_tess_ply(TessFile)
%
% INPUT:
%     - TessFile : Full path to a PLY mesh file
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
% Authors: ChatGPT Thinking 5.4, 2026
%          Chinmay Chinara, 2026

    %% ===== CHECK INPUT =====
    % Validate function call
    if (nargin < 1) || isempty(TessFile)
        bst_error('Invalid call. Please specify the mesh file to be loaded.', ...
                  'Importing tessellation', 1);
    end
    if ~exist(TessFile, 'file')
        bst_error(['File not found: ' TessFile], 'Importing tessellation', 1);
    end

    %% ===== READ PLY HEADER =====
    % Open once in text mode to parse the header and determine the file format
    fid = fopen(TessFile, 'r');
    if (fid == -1)
        bst_error(['Cannot open file: ' TessFile], 'Importing tessellation', 1);
    end

    % Check PLY magic string
    firstLine = strtrim(fgetl(fid));
    if ~strcmpi(firstLine, 'ply')
        fclose(fid);
        bst_error('Invalid PLY file: missing ''ply'' magic header.', ...
                  'Importing tessellation', 1);
    end

    % Initialize header description
    header = struct();
    header.format   = '';
    header.version  = '';
    header.elements = struct('name', {}, 'count', {}, 'properties', {});
    currentElem = [];

    % Parse header line by line until "end_header"
    while true
        line = fgetl(fid);
        if ~ischar(line)
            fclose(fid);
            bst_error('Invalid PLY file: missing ''end_header''.', ...
                      'Importing tessellation', 1);
        end

        line = strtrim(line);
        if isempty(line)
            continue;
        end
        if strcmpi(line, 'end_header')
            break;
        end

        tok = strsplit(line);
        key = lower(tok{1});

        switch key
            case 'comment'
                % Ignore free-text comments
            case 'obj_info'
                % Ignore optional object info
            case 'format'
                header.format = lower(tok{2});
                if numel(tok) >= 3
                    header.version = tok{3};
                end
            case 'element'
                % Start a new element block (eg, vertex, face)
                currentElem = numel(header.elements) + 1;
                header.elements(currentElem).name = lower(tok{2});
                header.elements(currentElem).count = str2double(tok{3});
                header.elements(currentElem).properties = struct( ...
                    'kind', {}, 'name', {}, 'type', {}, 'countType', {}, 'itemType', {});
            case 'property'
                % Add a property to the current element
                if isempty(currentElem)
                    fclose(fid);
                    bst_error('Invalid PLY header: property before element.', ...
                              'Importing tessellation', 1);
                end

                p = numel(header.elements(currentElem).properties) + 1;
                if strcmpi(tok{2}, 'list')
                    header.elements(currentElem).properties(p).kind      = 'list';
                    header.elements(currentElem).properties(p).countType = lower(tok{3});
                    header.elements(currentElem).properties(p).itemType  = lower(tok{4});
                    header.elements(currentElem).properties(p).name      = lower(tok{5});
                    header.elements(currentElem).properties(p).type      = '';
                else
                    header.elements(currentElem).properties(p).kind      = 'scalar';
                    header.elements(currentElem).properties(p).type      = lower(tok{2});
                    header.elements(currentElem).properties(p).name      = lower(tok{3});
                    header.elements(currentElem).properties(p).countType = '';
                    header.elements(currentElem).properties(p).itemType  = '';
                end
        end
    end

    % Save the position immediately after the header
    dataStartPos = ftell(fid);
    fclose(fid);

    if isempty(header.format)
        bst_error('Invalid PLY file: missing format declaration.', ...
                  'Importing tessellation', 1);
    end

    %% ===== FIND REQUIRED ELEMENTS =====
    % Locate vertex and face elements
    iVertex = find(strcmp({header.elements.name}, 'vertex'), 1);
    iFace   = find(strcmp({header.elements.name}, 'face'), 1);

    if isempty(iVertex) || isempty(iFace)
        bst_error('PLY file must contain both ''vertex'' and ''face'' elements.', ...
                  'Importing tessellation', 1);
    end

    vertexProps = header.elements(iVertex).properties;
    faceProps   = header.elements(iFace).properties;

    % Required vertex coordinates
    vx = find(strcmp({vertexProps.name}, 'x'), 1);
    vy = find(strcmp({vertexProps.name}, 'y'), 1);
    vz = find(strcmp({vertexProps.name}, 'z'), 1);
    if isempty(vx) || isempty(vy) || isempty(vz)
        bst_error('PLY vertex element must contain x, y, z properties.', ...
                  'Importing tessellation', 1);
    end

    % Optional vertex color channels
    vr = find(ismember({vertexProps.name}, {'red', 'r'}), 1);
    vg = find(ismember({vertexProps.name}, {'green', 'g'}), 1);
    vb = find(ismember({vertexProps.name}, {'blue', 'b'}), 1);

    % Required face list property
    iFaceList = find(strcmp({faceProps.kind}, 'list') & ...
                     ismember({faceProps.name}, {'vertex_indices', 'vertex_index'}), 1);
    if isempty(iFaceList)
        bst_error('PLY face element must contain a list property named vertex_indices or vertex_index.', ...
                  'Importing tessellation', 1);
    end

    %% ===== READ PLY DATA =====
    % Reopen the file with the proper endianness for binary files
    switch lower(header.format)
        case 'ascii'
            fid = fopen(TessFile, 'r');
        case 'binary_little_endian'
            fid = fopen(TessFile, 'r', 'ieee-le');
        case 'binary_big_endian'
            fid = fopen(TessFile, 'r', 'ieee-be');
        otherwise
            bst_error(['Unsupported PLY format: ' header.format], ...
                      'Importing tessellation', 1);
    end

    if (fid == -1)
        bst_error(['Cannot reopen file: ' TessFile], 'Importing tessellation', 1);
    end

    % Skip header and read data payload
    fseek(fid, dataStartPos, 'bof');

    switch lower(header.format)
        case 'ascii'
            [vertices, color, faces] = read_ascii_ply(fid, header, vx, vy, vz, vr, vg, vb, iFaceList);
        otherwise
            [vertices, color, faces] = read_binary_ply(fid, header, vx, vy, vz, vr, vg, vb, iFaceList);
    end

    fclose(fid);

    %% ===== CLEAN SURFACE =====
    if isempty(vertices) || isempty(faces)
        bst_error('No vertices or faces could be read from the PLY file.', ...
                  'Importing tessellation', 1);
    end

    % Remove invalid or degenerate triangles
    bad = any(isnan(faces), 2) | any(faces < 1, 2) | ...
          (faces(:,1) == faces(:,2)) | ...
          (faces(:,1) == faces(:,3)) | ...
          (faces(:,2) == faces(:,3));
    faces(bad,:) = [];

    % Remove vertices that are not referenced by any face
    ufacesIdx = unique(faces(:));
    remove = setdiff((1:size(vertices,1))', ufacesIdx);
    if ~isempty(remove)
        [vertices, faces] = tess_remove_vert(vertices, faces, remove);
        if ~isempty(color) && (size(color,1) >= max(ufacesIdx))
            color(remove,:) = [];
        end
    end

    % Normalize vertex colors to [0,1] if they are stored as [0,255]
    if ~isempty(color)
        if max(color(:)) > 1
            color = double(color) ./ 255;
        else
            color = double(color);
        end
    end

    % Center the mesh around the origin
    vertices = vertices - repmat(mean(vertices,1), [size(vertices,1), 1]);

    % Convert vertices' unit as locations in Brainstorm are saved in 'meters'
    vertices = channel_fixunits(vertices, 'mm', 1, 1);

    %% ===== RETURN SURFACE =====
    TessMat = struct( ...
        'Faces',    faces, ...
        'Vertices', vertices, ...
        'Color',    color, ...
        'Comment',  '');
end


%% ===== ASCII PLY READER =====
function [vertices, color, faces] = read_ascii_ply(fid, header, vx, vy, vz, vr, vg, vb, iFaceList)
% Read an ASCII PLY file based on the parsed header structure.

    vertices = [];
    color    = [];
    faces    = [];

    for iElem = 1:numel(header.elements)
        elem = header.elements(iElem);

        switch elem.name
            case 'vertex'
                nV = elem.count;
                vertices = zeros(nV, 3);

                hasColor = ~isempty(vr) && ~isempty(vg) && ~isempty(vb);
                if hasColor
                    color = zeros(nV, 3);
                end

                for i = 1:nV
                    line = fgetl(fid);
                    while ischar(line) && isempty(strtrim(line))
                        line = fgetl(fid);
                    end
                    vals = sscanf(line, '%f')';

                    vertices(i,:) = [vals(vx), vals(vy), vals(vz)];

                    if hasColor
                        color(i,:) = [vals(vr), vals(vg), vals(vb)];
                    end
                end

            case 'face'
                nF = elem.count;
                faceCell = cell(nF,1);

                for i = 1:nF
                    line = fgetl(fid);
                    while ischar(line) && isempty(strtrim(line))
                        line = fgetl(fid);
                    end
                    vals = sscanf(line, '%f')';

                    k = 1;
                    idxList = [];
                    for p = 1:numel(elem.properties)
                        prop = elem.properties(p);
                        if strcmp(prop.kind, 'scalar')
                            k = k + 1;
                        else
                            nList = vals(k);
                            if p == iFaceList
                                idxList = vals(k+1:k+nList);
                            end
                            k = k + 1 + nList;
                        end
                    end

                    % Convert zero-based PLY indices to MATLAB one-based indices
                    faceCell{i} = double(idxList(:)' + 1);
                end

                faces = triangulate_faces(faceCell);

            otherwise
                % Skip unsupported ASCII element blocks line by line
                for i = 1:elem.count
                    fgetl(fid);
                end
        end
    end
end


%% ===== BINARY PLY READER =====
function [vertices, color, faces] = read_binary_ply(fid, header, vx, vy, vz, vr, vg, vb, iFaceList)
% Read a binary PLY file based on the parsed header structure.

    vertices = [];
    color    = [];
    faces    = [];

    for iElem = 1:numel(header.elements)
        elem = header.elements(iElem);

        switch elem.name
            case 'vertex'
                nV = elem.count;
                vertices = zeros(nV, 3);

                hasColor = ~isempty(vr) && ~isempty(vg) && ~isempty(vb);
                if hasColor
                    color = zeros(nV, 3);
                end

                for i = 1:nV
                    vals = cell(1, numel(elem.properties));

                    for p = 1:numel(elem.properties)
                        prop = elem.properties(p);
                        if strcmp(prop.kind, 'scalar')
                            vals{p} = read_ply_scalar(fid, prop.type);
                        else
                            nList = read_ply_scalar(fid, prop.countType);
                            vals{p} = zeros(1, nList);
                            for j = 1:nList
                                vals{p}(j) = read_ply_scalar(fid, prop.itemType);
                            end
                        end
                    end

                    vertices(i,:) = [vals{vx}, vals{vy}, vals{vz}];

                    if hasColor
                        color(i,:) = [vals{vr}, vals{vg}, vals{vb}];
                    end
                end

            case 'face'
                nF = elem.count;
                faceCell = cell(nF,1);

                for i = 1:nF
                    vals = cell(1, numel(elem.properties));

                    for p = 1:numel(elem.properties)
                        prop = elem.properties(p);
                        if strcmp(prop.kind, 'scalar')
                            vals{p} = read_ply_scalar(fid, prop.type);
                        else
                            nList = read_ply_scalar(fid, prop.countType);
                            vals{p} = zeros(1, nList);
                            for j = 1:nList
                                vals{p}(j) = read_ply_scalar(fid, prop.itemType);
                            end
                        end
                    end

                    % Convert zero-based PLY indices to MATLAB one-based indices
                    faceCell{i} = double(vals{iFaceList}(:)' + 1);
                end

                faces = triangulate_faces(faceCell);

            otherwise
                % Skip unsupported binary element blocks property by property
                for i = 1:elem.count
                    for p = 1:numel(elem.properties)
                        prop = elem.properties(p);
                        if strcmp(prop.kind, 'scalar')
                            read_ply_scalar(fid, prop.type);
                        else
                            nList = read_ply_scalar(fid, prop.countType);
                            for j = 1:nList
                                read_ply_scalar(fid, prop.itemType);
                            end
                        end
                    end
                end
        end
    end
end


%% ===== TRIANGULATE POLYGONAL FACES =====
function faces = triangulate_faces(faceCell)
% Convert polygonal faces to triangles using a fan triangulation.

    nTri = 0;
    for i = 1:numel(faceCell)
        nv = numel(faceCell{i});
        if nv >= 3
            nTri = nTri + (nv - 2);
        end
    end

    faces = zeros(nTri, 3);
    k = 1;

    for i = 1:numel(faceCell)
        f = faceCell{i};
        nv = numel(f);

        if nv == 3
            faces(k,:) = f(1:3);
            k = k + 1;
        elseif nv > 3
            for j = 2:(nv - 1)
                faces(k,:) = [f(1), f(j), f(j + 1)];
                k = k + 1;
            end
        end
    end
end


%% ===== READ ONE PLY SCALAR VALUE =====
function val = read_ply_scalar(fid, plyType)
% Read one scalar value from a binary PLY file and convert it to double.

    switch lower(plyType)
        case {'char', 'int8'}
            val = fread(fid, 1, 'int8=>double');
        case {'uchar', 'uint8'}
            val = fread(fid, 1, 'uint8=>double');
        case {'short', 'int16'}
            val = fread(fid, 1, 'int16=>double');
        case {'ushort', 'uint16'}
            val = fread(fid, 1, 'uint16=>double');
        case {'int', 'int32'}
            val = fread(fid, 1, 'int32=>double');
        case {'uint', 'uint32'}
            val = fread(fid, 1, 'uint32=>double');
        case {'float', 'float32'}
            val = fread(fid, 1, 'single=>double');
        case {'double', 'float64'}
            val = fread(fid, 1, 'double=>double');
        otherwise
            error(['Unsupported PLY scalar type: ' plyType]);
    end

    if isempty(val)
        error('Unexpected end of file while reading PLY data.');
    end
end