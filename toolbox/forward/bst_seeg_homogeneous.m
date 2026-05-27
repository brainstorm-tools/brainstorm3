function G = bst_seeg_homogeneous(GridLoc, sChannel, sInnerSkull, Options)
% bst_seeg_homogeneous: Calculate the electric potential for infinite homogeneous medium
%
% USAGE:  G = bst_seeg_homogeneous(GridLoc, sChannel, sInnerSkull, Options)
%
% INPUT:
%    - GridLoc     : Dipole locations (in meters)  [nDipoles x 3]
%    - sChannel    : Channel structure             [nSensors]
%    - sInnerSkull : Inner skull surface structure
%    - Options structure
%       - Options.Conductivity      : Conductivity (S/m)
%       - Options.MinSeegDipoleDist : Minimum distance between SEEG and dipoles
% OUTPUTS:
%    - G : SEEG forward model gain matrix    [nSensors x (3*nDipoles)]
%
% DESCRIPTION:  sEEG single layer forward model
%     This function computes the voltage potential forward gain matrix for an array of 
%     sEEG electrodes inside the brain. The conductivity is assumed to be uniform and isotropoic
%     inside the medium (that is assumed to be infinite).
%       
%     For electrodes outside of the brain, the grain is set to 0. 
% 
%     Ref: 
%          + Grova, C., Aiguabella, M., Zelmann, R., Lina, J.-M., Hall, J.A. and Kobayashi, E. (2016), 
%            Intracranial EEG potentials estimated from MEG sources: A new approach to correlate MEG and iEEG data in epilepsy. 
%            Hum. Brain Mapp., 37: 1661-1683. https://doi.org/10.1002/hbm.23127
%   
%          + Næss, S., Halnes, G., Hagen, E., Hagler Jr, D. J., Dale, A. M., Einevoll, G. T., & Ness, T. V. (2021). 
%            Biophysically detailed forward modeling of the neural origin of EEG and MEG signals. NeuroImage, 225, 117467.  
%           
%                 dot(n_i, u_ij)
%     V(E_j) = --------------------------
%              4 * pi * sigma0 * (r_ij)^2
%
%     V(E_j) = Electric potential at sensor j
%     n_i    = Vector, current dipole for source i
%     u_ij   = Unit vector, oriented from source i to sensor j
%     sigma0 = Conductivity of infinite homogeneous medium
%     r_ij   = Euclidean distance between source i and sensor j
%
%     Written as matrix multiplication:  V = G * N
%     V = Electric potential at contacts [nSensors, nTime]
%     G = Gain matrix                    [nSensors, nDipoles]
%     N = Dipole activation currents     [nDipoles, nTime]
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
% Authors: Edouard Delaire, 2026

    % Add default options
    Options = struct_copy_fields(struct('Conductivity', 0.25, 'MinSeegDipoleDist', 3/1000), Options, 1);
    min_distance = Options.MinSeegDipoleDist;
    sigma0       = Options.Conductivity;

    NbElectrodes = length(sChannel);
    NbVertices   = size(GridLoc, 1);

    % Find electrodes that are inside the inner skull
    SEEG_Loc = [sChannel.Loc]'; 
    isSEEGInsideSkull   = inpolyhd(SEEG_Loc, sInnerSkull.Vertices, sInnerSkull.Faces);
    
    % Compute the leadfield
    bst_progress('start', 'Computing head model', sprintf('Computing head model for %d contacts...', NbElectrodes), 0, NbElectrodes);
    G = zeros(NbElectrodes , 3*NbVertices);
    for iContact = 1:NbElectrodes
        % Ignore contacts outside of the inner skull
        if ~isSEEGInsideSkull(iContact)
            continue
        end

        % Compute unit vectors from SEEG contact to source points (u_j)
        VectorDipolesToSEEG = SEEG_Loc(iContact, :) - GridLoc;
        DistanceToDipoles = sqrt(sum(VectorDipolesToSEEG.^2,2));
        VectorDipolesToSEEG = VectorDipolesToSEEG ./ repmat(DistanceToDipoles, 1, 3);

        % Filter short distance
        iShort = find(DistanceToDipoles < min_distance);
        if ~isempty(iShort)
            fprintf(' %d vertex had distance to the cortex smaller than %.2f mm to electrodes %s \n', length(iShort), min_distance*1000, sChannel(iContact).Name);           
            DistanceToDipoles(iShort) = min_distance;
        end

        % Compute the leadfield (u_j / (r_j)^2)
        scaledVector = VectorDipolesToSEEG ./ repmat(DistanceToDipoles.^2, 1, 3); 

        % Organize the matrix as x,y,z
        G(iContact, :) = reshape(scaledVector', 1, []);

        bst_progress('inc', 1);
    end

    % Add normalization constant 
    G = G / (4 * pi * sigma0);

    bst_progress('stop');
end