function [vert, faces] = tess_generate_primitive(iSubject, primitive)
% TESS_GENERATE_PRIMITIVE: Generate a triangular mesh of a primitive geometric shape
%                          This function uses the Iso2Mesh plugin
%
% USAGE:  [vert, faces] = tess_generate_primitive(iSubject, primitive = [ask])
%
% INPUTS:
%   - iSubject  : Import surface to Subject if provided
%                 Valid options: [] = Do not import mesh, Subject name, index, or filename
%   - primitive : Name of the primitive geometric shape to generate:
%                 Valid options: [] = Ask user, 'sphere', 'cube', 'cylinder', 'cone'
%
% OUTPUT:
%   - vert      : Primitive vertices
%   - faces     : Primitive faces
%
% See also:
%   meshasphere, meshabox, meshacylinder, meshanellip, removeisolatedvert

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
% Authors: Takfarinas Medani, 2025
%          Raymundo Cassani, 2026

%% ===== PARSE INPUTS =====
vert  = [];
faces = [];

% Call: tess_generate_primitive(iSubject)
if(nargin == 1) && ~isempty(iSubject)
    sSubject = bst_get('Subject', iSubject);
    if isempty(sSubject)
        iSubject = [];
    end
    primitive = 'sphere';
end

% Call: tess_generate_primitive(iSubject, [])
if (nargin >=2) && isempty(primitive)
    % Ask user the new number of vertices
    primitiveList = {'Sphere', 'Ellipsoid', 'Cube', 'Cylinder', 'Cone'};
    [primitive , isCancel] = java_dialog('combo', 'Select the surface shape:', ...
        'Generate primitive surface', [], primitiveList, 'Sphere');
    if isempty(primitive) || isCancel
        return
    end
end

%% ===== COMPUTE PRIMITIVE MESH =====
% Progress bar
bst_progress('start','Generate primitive surface',['Generate a ' primitive]);

% Install/load iso2mesh plugin
[isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', 0);
if ~isInstalled
    bst_error(errMsg);
    return
end

% Generate primitive surface
[vert, faces, errMsg] = generatePrimitiveSurface(primitive);

if ~isempty(errMsg)
    bst_error(errMsg);
    return
end

% Do not import new primitive mesh
if isempty(iSubject)
    return
end

%% ===== SAVE PRIMITIVE MESH AND IMPORT =====
% Output structure
bst_progress('text', 'Saving new primitive surface...');
% Initialize struct for new primitive surface
PrimitiveTess = db_template('surfacemat');
PrimitiveTess.Vertices = vert;
PrimitiveTess.Faces    = faces;
PrimitiveTess.Comment  = ['Primitive: ' primitive];
PrimitiveTess = bst_history('add', PrimitiveTess, 'tess_generate_primitive', primitive);
% Create output filename
ProtocolInfo = bst_get('ProtocolInfo');
sSubject = bst_get('Subject', iSubject);
subjectSubDir = bst_fileparts(sSubject.FileName);
PrimitiveTessFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['tess_' lower(primitive) ' .mat']);
% Make this filename unique
PrimitiveTessFile = file_unique(PrimitiveTessFile);
% Save new surface in Brainstorm format
bst_save(PrimitiveTessFile, PrimitiveTess, 'v7');
% Add to database
db_add_surface(iSubject, PrimitiveTessFile, PrimitiveTess.Comment);
% Close, success
bst_progress('stop');

end

%% =========== GENERATE PRIMITIVE SURFACE ===========
function [vert, face, errMsg] = generatePrimitiveSurface(primitiveShape)
vert = [];
face = [];
errMsg = '';
switch lower(primitiveShape)
    % Sphere and ellipsoid
    case {'sphere', 'ellipsoid'}
        % Default inputs:
        c0 = [0, 0, 0]; % sphere center [mm] SCS XYZ
        if strcmpi(primitiveShape, 'sphere')
            r = 10;     % sphere radius [mm]
        elseif strcmpi(primitiveShape, 'ellipsoid')
            r = [5, 10, 20];  % Radii for X,Y,Z axes
        end
        % Ask user
        [res, isCancel] = java_dialog('input', ...
                              {'<HTML>Sphere center (in mm)<BR><FONT color="#404040">[x y z] SCS coordinates', ...
                               '<HTML>Radius (in mm)<BR><FONT color="#404040">One value for sphere, or three values for ellipsoid'}, ...
                              [primitiveShape ' parameters'], [], {num2str(c0), num2str(r)});
        if isempty(res) || (length(res) < 2) || isCancel
            return
        end
        c0 = str2num(res{1});
        r = str2num(res{2});
        % Sphere
        if length(r) == 1
            tsize = r/10; %maximum size of the surface triangles
            [vert,face] = meshasphere(c0,r,tsize);
        % Ellipsoid
        elseif length(r) == 3
            tsize = mean(r)/10;
            maxvol = tsize*tsize*tsize;
            [vert,face] = meshanellip(c0,r,tsize,maxvol);
        % Not supported
        else
            return
        end

    % Cube and rectangular cuboid
    case 'cube'
        % Default inputs
        c0 = [0 0 0];  % cube center [mm] SCS XYZ
        r  = 10;       % cube size [mm]
        % Ask user
        [res, isCancel] = java_dialog('input', ...
                              {'<HTML>Cube center (in mm)<BR><FONT color="#404040">[x y z] SCS coordinates', ...
                               '<HTML>Length (in mm)<BR><FONT color="#404040">One value for cube, or three values for rect cuboid'}, ...
                              [primitiveShape ' parameters'], [], {num2str(c0), num2str(r)});
        if isempty(res) || (length(res) < 2) || isCancel
            return
        end
        c0 = str2num(res{1});
        r = str2num(res{2});
        % Cube
        if length(r) == 1
            r = [r, r, r];
        % Rectangular cuboid
        elseif length(r) == 3
            % Do nothing
        % Not supported
        else
            return
        end
        % Processing
        p0 = [r(1), 0, 0];        % coordinates (x,y,z) for one end of the box diagonal
        p1 = [0, r(2), r(3)];     % coordinates (x,y,z) for the other end of the box diagonal
        tsize = mean([p0, p1])/10; % maximum volume of the tetrahedral elements
        [vert,face] = meshabox(p0,p1,tsize);
        % Move to the new center
        vert = (vert - mean(vert))+ c0;

    % Cylinder and cone
    case {'cylinder', 'cone'}
        % Default inputs:
        % Cylinder axis end points
        c0 = [0 0 0];  % Cylinder base 1 center coordinates
        c1 = [0 0 20]; % Cylinder base 2 center coordinates
        if strcmpi(primitiveShape, 'cylinder')
            r = 5;    % Radius for both bases
        elseif strcmpi(primitiveShape, 'cone')
            r = [5, 0.1];    % Radii for base and top
        end
        % Ask user
        [res, isCancel] = java_dialog('input', ...
                              {'<HTML>Base 1 center (in mm)<BR><FONT color="#404040">[x y z] SCS coordinates', ...
                               '<HTML>Base 2 center (in mm)<BR><FONT color="#404040">[x y z] SCS coordinates', ...
                               '<HTML>Radius (in mm)<BR><FONT color="#404040">One value for cylinder, or two values for cone trunk'}, ...
                              [primitiveShape ' parameters'], [], {num2str(c0), num2str(c1), num2str(r)});
        if isempty(res) || (length(res) < 3) || isCancel
            return
        end
        c0 = str2num(res{1});
        c1 = str2num(res{2});
        r  = str2num(res{3});
        % Cylinder
        if length(r) == 1
            r = [r, r];
        % Cone trunc
        elseif length(r) == 2
            % Do nothing
        % Not supported
        else
            return
        end
        % Processing
        tsize = mean(r)/5; % maximum surface triangle size on the sphere
        maxvol = tsize*tsize*tsize; % mmaximu volume of the tetrahedral elements
        ndiv = 20;
        % Generate the mesh
        [vert,face]= meshacylinder(c0,c1,r,tsize,maxvol,ndiv);

    otherwise
        errMsg = sprintf('Unknown "%s" primitive geometric shape.', primitiveShape);
        return
end
% Clean mesh
[vert, face] = removeisolatednode(vert,face);
vert = vert(:, 1:3) / 1000; % From [mm] to [m]
face = face(:, 1:3);
end
