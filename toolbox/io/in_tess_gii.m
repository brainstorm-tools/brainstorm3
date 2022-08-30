function TessMat = in_tess_gii(TessFile)
% IN_TESS_GII: Import GIfTI/BrainVisa .gii tessellation files.
%
% USAGE:  TessMat = in_tess_gii(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
%
% SEE ALSO: in_tess

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
% Authors: Francois Tadel, 2012-2017

import sun.misc.BASE64Decoder;

% Read GII file
[sXml, Values] = in_gii(TessFile);
% Initialize matrices
Vertices = {};
Faces = {};
% For each data entry
for iArray = 1:length(sXml.GIFTI.DataArray)   
    % Identify type
    switch (sXml.GIFTI.DataArray(iArray).Intent)
        case 'NIFTI_INTENT_POINTSET'
            Vertices{end+1} = double(Values{iArray});
            % If there is a transformation available, apply it to the vertices
            if isfield(sXml.GIFTI.DataArray(iArray), 'CoordinateSystemTransformMatrix') && isfield(sXml.GIFTI.DataArray(iArray).CoordinateSystemTransformMatrix, 'MatrixData')
                Transf = str2num(sXml.GIFTI.DataArray(iArray).CoordinateSystemTransformMatrix.MatrixData.text);
                if (length(Transf) == 16)
                    Transf = reshape(Transf, 4, 4)';
                    Vertices{end} = bst_bsxfun(@plus, Transf(1:3,1:3) * Vertices{end}', Transf(1:3,4))';
                end
            end
            % Convert to meters
            Vertices{end} = Vertices{end} ./ 1000;
        case 'NIFTI_INTENT_TRIANGLE'
            Faces{end+1} = double(Values{iArray}) + 1;
    end
end

% Get number of meshes saved in this file
nTess = min(length(Vertices), length(Faces));
if (nTess == 0)
    error('This file does not contain a valid tesselation: NIFTI_INTENT_POINTSET or NIFTI_INTENT_TRIANGLE missing.');
end
% Return meshes
for iTess = 1:nTess
    TessMat(iTess).Vertices = Vertices{iTess};
    TessMat(iTess).Faces = Faces{iTess};
end





