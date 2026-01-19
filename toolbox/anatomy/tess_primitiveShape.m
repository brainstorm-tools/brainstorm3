function [vert, face] = tess_primitiveShape(iSubject, primitiveShape)
% TESS_CREATEPRIMITIVESHAPE: Create a premitive surface
%
% USAGE:  [vert, faces] = tess_generatePrimitive();
%         [vert, faces] = tess_generatePrimitive(iSubject);
%         [vert, faces] = tess_generatePrimitive(iSubject, primitiveShape);
% INPUTS:
%   - primitiveShape : string specifying the shape to generate:
%       {'sphere', 'boxe', 'cylinder', 'cone', 'ellipse'}
% Output:
%   - surface mesh with list of vert & face
%
% Description:
%   Generate a triangulated surface mesh of a simple geometric shape
%   (primitive) such as a sphere, box, cylinder, cone, or ellipsoid. This function
%   uses the Iso2Mesh library to build high-quality surface representations and
%   provides an interactive prompt for customizing shape parameters.
%
% Notes:
%   - The Iso2Mesh plugin must be installed and available in Brainstorm.
%   - The user is prompted to provide specific parameters (position, size, etc.)
%     for the selected shape via an interactive dialog.
%
% See also:
%   meshasphere, meshabox, meshacylinder, meshanellip, removeisolatedvert, meshreorient
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

%% ===== PARSE INPUTS =====
if(nargin < 1)
    iSubject = [];
    primitiveShape = 'sphere' ;
end

if(nargin == 1)
    if ~isnumeric(iSubject) || (iSubject < 0)
        error('Invalid subject indice.');
    end
    primitiveShape = 'sphere' ;
end

% Surface choice
if (nargin >=2) && isempty(primitiveShape)
    % Ask user the new number of vertices
    primitiveShapeList = {'sphere', 'boxe', 'cylinder', 'cone', 'ellipse'};
    [primitiveShape , isCancel] = java_dialog('combo', ['Select the surface shape:'], ...
        'Generate primitive surface', [], primitiveShapeList, 'sphere');
    if isempty(primitiveShape) || isCancel
        return
    end
end

% Progress bar
bst_progress('start','Generate Primitive Surface',['Generate a ' primitiveShape]);

% Check iso2mesh plugin
% Install/load iso2mesh plugin
[isInstalled, errInstall] = bst_plugin('Install', 'iso2mesh', 0);
if ~isInstalled
    errMsg = [errMsg, errInstall];
    return;
end

[vert, face] = generatePrimitiveSurface(lower(primitiveShape));

%% ===== SAVE RESULTS IN FILE =====
bst_progress('text', 'Saving new file...');
% Output structure
bst_progress('text', 'Saving new file...');
% Create output filenames
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject
sSubject = bst_get('Subject', iSubject);
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
ShapeFile  = file_unique(bst_fullfile(SurfaceDir, ['tess_' primitiveShape ' .mat']));
% Save head
sShape.Vertices = vert/1000;
sShape.Faces    = face;
sShape.Comment = primitiveShape;
sHead = bst_history('add', sShape, 'tess_createPrimitiveShape', primitiveShape);
bst_save(ShapeFile, sShape, 'v7');
iSurface = db_add_surface( iSubject, ShapeFile, sShape.Comment);
% Close, success
bst_progress('stop');

end

%% =========== GENERATE PRIMITIVE SURFACE ===========

function [vert, face] = generatePrimitiveSurface(primitiveShape)
switch lower(primitiveShape)
    case 'sphere'
        % === MESH A SPHERE ===
        disp(' MESH A SPHERE...')
        % default inputs:
        c0 = [0, 0, 0]; % center of the sphere
        r = 10; % radii of the sphere mm
        % Ask user
        res = java_dialog('input', {'Sphere Center [x, y, z]:', 'Radii(mm):'}, [primitiveShape ' parameters'], [], {num2str(c0), num2str(r)});
        if isempty(res) || (length(res) < 2)
            return
        end
        c0 = str2num(res{1});
        r = str2num(res{2});
        % Processing:
        tsize = r/10; %maximum size of the surface triangles
        [vert,face] = meshasphere(c0,r,tsize);

    case 'boxe'
        % === MESH A BOXE ===
        disp(' MESH A BOXE...')
        % default inputs
        c0 = [0 0 0];% boxe center
        depth = 10; % x direction
        width = 20; % y direction
        height = 30; % z direction
        % Ask user
        res = java_dialog('input', {'Boxe Center [x, y, z]:',...
            'depth in X direction(mm):',...
            'width in Y direction(mm):',...
            'height in Z direction(mm):',...
            }, [primitiveShape ' parameters'], [],...
            {num2str(c0), num2str(depth), num2str(width), num2str(height)});
        if isempty(res) || (length(res) < 4)
            return
        end
        c0 = str2num(res{1});
        depth = str2num(res{2});
        width = str2num(res{3});
        height = str2num(res{4});
        % processing
        p0 = [depth, 0, 0];  %coordinates (x,y,z) for one end of the box diagnoal
        p1 = [0, width, height];  %coordinates (x,y,z) for the other end of the box diagnoal
        tsize = min([p0, p1])/10; %maximum volume of the tetrahedral elements
        [vert,face] = meshabox(p0,p1,tsize);
        % move to the new center
        vert = vert + c0;

    case 'cylinder'
        % === MESH A CYLINDER ===
        % default inputs:
        %   c0, c1:  cylinder axis end points
        c0 = [0 0 0];
        c1 = [0 0 10];
        %   r:   radius of the cylinder; if r contains two elements, it outputs
        %        a cone trunk, with each r value specifying the radius on each end
        disp(' MESH A CYLINDER...')
        r0 = 1;
        r1 = 1;
        % Ask user
        res = java_dialog('input', ...
            {...
            'Cylinder axis point 1 coordinates [x, y, z]:',...
            'Cylinder axis point 2 coordinates [x, y, z]:',...
            'Radius of the cylinder(mm):',...
            }, [primitiveShape ' parameters'], [],...
            {num2str(c0), num2str(c1), num2str(r0)});
        if isempty(res) || (length(res) < 3)
            return
        end
        % Processing
        c0 = str2num(res{1});
        c1 = str2num(res{2});
        r0 = str2num(res{3});
        r1 = r0  ;
        r = ([r0 r1]);
        %   tsize: maximum surface triangle size on the sphere
        tsize = mean(r)/5;
        %   maxvol: maximu volume of the tetrahedral elements
        maxvol = tsize*tsize*tsize;
        %   ndiv: approximate the cylinder surface into ndiv flat pieces,
        % ndiv = norm(c0-c1);
        ndiv = 20;
        % Generate the mesh
        [vert,face]= meshacylinder(c0,c1,r,tsize,maxvol,ndiv);

    case 'cone'
        % === MESH A CONE ===
        % default inputs:
        %   c0, c1:  cylinder axis end points
        c0 = [0 0 0];
        c1 = [0 0 10];
        %   r:   radius of the cylinder; if r contains two elements, it outputs
        %        a cone trunk, with each r value specifying the radius on each end
        disp(' MESH A CYLINDER...')
        r0 = 1;
        r1 = 0.1;
        % Ask user
        res = java_dialog('input', ...
            {...
            'Cone axis Point 1 coordinates (the base) [x, y, z]:',...
            'Cone axis Point 2 coordinates(the corner) [x, y, z]:',...
            'Radius of the base(mm):',...
            'Radius of the corner(mm):',...
            }, [primitiveShape ' parameters'], [],...
            {num2str(c0), num2str(c1), num2str(r0), num2str(r1)});
        if isempty(res) || (length(res) < 4)
            return
        end
        % Processing
        c0 = str2num(res{1});
        c1 = str2num(res{2});
        r0 = str2num(res{3});
        r1 = str2num(res{4});
        r = ([r0 r1]);
        %   tsize: maximum surface triangle size on the sphere
        tsize = mean(r)/5;
        %   maxvol: maximu volume of the tetrahedral elements
        maxvol = tsize*tsize*tsize;
        %   ndiv: approximate the cylinder surface into ndiv flat pieces,
        % ndiv = norm(c0-c1);
        ndiv = 20;
        % Generate the mesh
        [vert,face]= meshacylinder(c0,c1,r,tsize,maxvol,ndiv);
    case 'ellipse'
        % === MESH A ELLIPSE ===
        disp(' MESH AN ELLIPSE...')
        % Inputs:
        c0 = [0, 0, 0];
        rr = [10 5 5];
        % Ask user
        res = java_dialog('input', ...
            {...
            'Ellipse center coordinates [x, y, z]:',...
            'Radius of major axis(mm):',...
            'Radius of minor axis 1(mm):',...
            'Radius of minor axis 2(mm):',...
            }, [primitiveShape ' parameters'], [],...
            {num2str(c0), num2str(rr(1)), num2str(rr(2)), num2str(rr(3))});
        if isempty(res) || (length(res) < 4)
            return
        end

        % Processing
        c0 = str2num(res{1});
        r1 = str2num(res{2});
        r2 = str2num(res{3});
        r3 = str2num(res{4});
        rr = [r1 r2 r3];
        % Processing:
        tsize = mean(rr)/10;
        maxvol = tsize*tsize*tsize;
        [vert,face] = meshanellip(c0,rr,tsize,maxvol);
        % move to the new center
        vert = vert + c0;
    otherwise
        disp('Unknown method.')
end
% clean mesh
[vert, face] = removeisolatednode(vert,face);
vert = vert(:, 1:3);
face = face(:, 1:3);
%mesh reorient
% [face, tmp] = meshreorient(vert, el);

% figure; plotmesh(vert,face, 'y>0'); axis equal;
% xlabel('X'); ylabel('Y'); zlabel('Z');
%
% figure; plotmesh(no,el, 'facecolor', 'r'); axis equal;
% xlabel('X'); ylabel('Y'); zlabel('Z');
end
