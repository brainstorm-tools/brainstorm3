function G = bst_seeg_uni(GridLoc, sChannel, sInnerSkull, Options)
% BST_EEG_SPH: Calculate the electric potential, spherical head, arbitrary orientation
%
% USAGE:  G = bst_eeg_sph(Rq, Channel, center, R, sigma);
%
% INPUT:
%    - GridLoc     : dipole location(in meters)    [nDipoles x 3]
%    - Channel     : a Brainstorm channel structure  [nSensors]  
%    - sInnerSkull : Inner skull surface
%    - Options structure
%       - Options.sigma : conductivity
%       - Options.minDistance : in meter

    % Add default options
    Options = struct_copy_fields(struct('sigma', 0.25, 'minDistance', 3/1000), Options, 1);
    min_distance        = Options.minDistance;
    sigma0              = Options.sigma;

    NbElectrodes = length(sChannel);
    NbVertices   = size(GridLoc, 1);

    % Find electrodes that are inside the inner skull
    SEEG_Loc = [sChannel.Loc]'; 
    isSEEGInsideSkull   = inpolyhd(SEEG_Loc, sInnerSkull.Vertices, sInnerSkull.Faces);
    
    % Compute the leadfield
    bst_progress('start', 'Computing head model', sprintf('Computing head model for %d contacts...', NbElectrodes), 0, NbElectrodes);
    G = zeros(NbElectrodes , 3*NbVertices);
    for iContact =  1:NbElectrodes
        
        if ~isSEEGInsideSkull(iContact)
            continue
        end

        VectorSEEGtoCortex =  SEEG_Loc(iContact, :) - GridLoc;
        DistanceToCortex = vecnorm(VectorSEEGtoCortex, 2, 2);

        % Filter short distance
        iShort =  find(DistanceToCortex < min_distance);
        if ~isempty(iShort)
            fprintf(' %d vertex had distance to the cortex smaller than %.2f mm to electrodes %s \n', length(iShort), min_distance*1000, sChannel(iContact).Name);
            
            VectorSEEGtoCortex(iShort, 1) = ( VectorSEEGtoCortex(iShort, 1) ./ DistanceToCortex(iShort)) * min_distance; 
            VectorSEEGtoCortex(iShort, 2) = ( VectorSEEGtoCortex(iShort, 2) ./ DistanceToCortex(iShort)) * min_distance; 
            VectorSEEGtoCortex(iShort, 3) = ( VectorSEEGtoCortex(iShort, 3) ./ DistanceToCortex(iShort)) * min_distance; 

            DistanceToCortex(iShort) =  min_distance;
        end

        % Normalize the vector
        VectorSEEGtoCortex = VectorSEEGtoCortex(:, 1) ./ repmat(DistanceToCortex, 1, 3); 
        
        % Compute the leadfield
        scaledVector = VectorSEEGtoCortex ./ repmat(DistanceToCortex.^2, 1, 3); 

        % Organize the matrix as x,y,z
        G(iContact, :) = reshape(scaledVector', 1, []);

        bst_progress('inc', 1);
    end

    % Add normalization constant 
    G = G / (4 * pi * sigma0);

    bst_progress('stop');
end