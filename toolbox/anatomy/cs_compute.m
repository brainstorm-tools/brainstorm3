function [Transf, sMri] = cs_compute(sMri, csname)
% CS_COMPUTE: Compute the transformation to move from the MRI coordiates coordinate system to SCS/MNI
%
% USAGE:  [Transf, sMri] = cs_compute(sMri, csname)
%
% INPUT:
%     - sMri   : Brainstorm MRI structure
%     - csname : Coordinate system for which we need to evaluate the transformation {'scs','mni','acpc','tal','captrak'}

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
% Authors: Francois Tadel, 2008-2022

Transf = [];

switch lower(csname)
    % ===== MRI => SCS =====
    case 'scs'
        % The necessary points are not defined
        if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3)
            disp('BST> Cannot compute MRI=>SCS transformation: Missing fiducial points.');
            return;
        end
        % Get coordinates
        NAS = double(sMri.SCS.NAS(:));
        LPA = double(sMri.SCS.LPA(:));
        RPA = double(sMri.SCS.RPA(:));
        % Origin: Mid point between LPA and RPA
        Origin = .5 * (LPA + RPA);
        % X axis: from origin to NAS
        vx = (NAS - Origin) / norm(NAS - Origin);
        % Z axis: Vector normal to the NAS-LPA-RPA plane, pointing upwards
        vz = cross(vx, LPA-RPA); 
        vz = vz/norm(vz);  
        % Y axis: From left to right
        vy = cross(vz,vx); 
        vy = vy/norm(vy);
        % If one of the vector could not be computed
        if any(isnan(vx)) || any(isnan(vy)) || any(isnan(vz))
            disp('BST> Cannot compute MRI=>SCS transformation: Invalid configuration of fiducial points.');
            return;
        end
        % Estimate transformation: rotation+translation
        Transf.Origin = Origin;
        Transf.R = inv([vx,vy,vz]); 
        Transf.T = - Transf.R * Origin; % Translation
        % If it was not possible to compute inverse matrix: Use pseudo-inverse instead
        if any(isinf(Transf.R(:))) || any(isnan(Transf.R(:)))
            Transf.R = pinv([vx,vy,vz]);
        end
        % Copy to MRI structure
        if (nargout >= 2)
            sMri.SCS.Origin = Transf.Origin;
            sMri.SCS.R      = Transf.R;
            sMri.SCS.T      = Transf.T;
        end
        
    % ===== MRI => MNI =====
    case 'mni'
        error('To estimate the MNI coordinates: right-click on the MRI > MNI normalization.');

    % ===== MRI => ACPC =====
    case 'acpc'
        % The necessary points are not defined
        if isempty(sMri) || ~isfield(sMri, 'NCS') || ~isfield(sMri.NCS, 'AC') || ~isfield(sMri.NCS, 'PC') || ~isfield(sMri.NCS, 'IH') || (length(sMri.NCS.AC)~=3) || (length(sMri.NCS.PC)~=3) || (length(sMri.NCS.IH)~=3)
            disp('BST> Cannot compute MRI=>ACPC transformation: Missing fiducial points.');
            return;
        end
        % Get coordinates in meters
        AC = sMri.NCS.AC / 1000;
        PC = sMri.NCS.PC / 1000;
        IH = sMri.NCS.IH / 1000;
        % Compute axes: Code from FieldTrip (ft_headcoordinates.m)
        origin = AC;
        diry   = AC - PC;
        dirz   = IH - AC;
        dirx   = cross(diry,dirz);
        dirz   = cross(dirx,diry);
        dirx   = dirx/norm(dirx);
        diry   = diry/norm(diry);
        dirz   = dirz/norm(dirz);
        % Compute the rotation matrix
        rot = eye(4);
        rot(1:3,1:3) = inv(eye(3) / [dirx; diry; dirz]);
        % compute the translation matrix
        tra = eye(4);
        tra(1:4,4) = [-origin(:); 1];
        % Combine these to compute the full homogeneous transformation matrix
        transform = rot * tra;
        % Return in split format
        Transf.R = transform(1:3,1:3);
        Transf.T = transform(1:3,4);

    % ===== MRI => CapTrak =====
    case 'captrak'
        % The necessary points are not defined
        if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3)
            disp('BST> Cannot compute MRI=>SCS transformation: Missing fiducial points.');
            return;
        end
        % Get coordinates in meters
        NAS = double(sMri.SCS.NAS(:))' ./ 1000;
        LPA = double(sMri.SCS.LPA(:))' ./ 1000;
        RPA = double(sMri.SCS.RPA(:))' ./ 1000;
        % X axis: From LPA through RPA exactly
        dirx   = RPA - LPA;
        dirx   = dirx/norm(dirx);
        % Y axis: Orthogonal to the X-axis through the nasion (NAS)
        origin = LPA + dirx * sum((NAS - LPA) .* dirx);
        diry = NAS - origin;
        diry   = diry/norm(diry);
        % Z axis: Orthogonal to the XY-plane through the vertex of the head
        dirz = cross(dirx,diry);
        % Compute the rotation matrix
        rot = eye(4);
        rot(1:3,1:3) = inv(eye(3) / [dirx; diry; dirz]);
        % compute the translation matrix
        tra = eye(4);
        tra(1:4,4) = [-origin(:); 1];
        % Combine these to compute the full homogeneous transformation matrix
        transform = rot * tra;
        % Return in split format
        Transf.R = transform(1:3,1:3);
        Transf.T = transform(1:3,4);

    % ===== SCS => TAL =====
    % Not a real TALAIRACH system, used only from tess_envelope.m
    case 'tal'
        % The necessary points are not defined
        if isempty(sMri) || ~isfield(sMri, 'NCS') || ~isfield(sMri.NCS, 'AC') || ~isfield(sMri.NCS, 'PC') || ~isfield(sMri.NCS, 'IH') || (length(sMri.NCS.AC)~=3) || (length(sMri.NCS.PC)~=3) || (length(sMri.NCS.IH)~=3)
            disp('BST> Cannot compute MRI=>TAL transformation: Missing fiducial points.');
            return;
        end
        % Convert to SCS the fiducials (AC, PC, IH)
        AC = cs_convert(sMri, 'mri', 'scs', sMri.NCS.AC / 1000);
        PC = cs_convert(sMri, 'mri', 'scs', sMri.NCS.PC / 1000);
        IH = cs_convert(sMri, 'mri', 'scs', sMri.NCS.IH / 1000);
        % Definition: Origin is AC and x is antero-posterior axis
        % => Translation: AC vector
        Transf.T = AC';
        % AC-PC vector
        ACPC = (PC-AC) ./ norm(PC-AC);
        % Rotation matrix
        mat1 = [    1     1     1 ;
                 AC(2) PC(2) IH(2);
                 AC(3) PC(3) IH(3)];
        mat2 = [ AC(1) PC(1) IH(1);
                    1     1     1;
                 AC(3) PC(3) IH(3)]; 
        mat3 = [ AC(1) PC(1) IH(1);
                 AC(2) PC(2) IH(2);
                    1     1     1];
        V1 = [det(mat1); det(mat2); det(mat3)];
        V1 = V1 ./ norm(V1);
        V2 = cross(V1,ACPC');
        V2 = V2/norm(V2);
        Transf.R  = [-ACPC' V1 V2]';
       
    otherwise
        error(['No tranformation can be computed to "' csname '" coordinates system.']);
end



    
    