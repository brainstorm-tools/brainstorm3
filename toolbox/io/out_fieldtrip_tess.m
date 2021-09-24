function ftSurf = out_fieldtrip_tess(SurfaceFiles)
% OUT_FIELDTRIP_TESS Converts multiple surfaces to an array of FieldTrip structures
% 
% USAGE:  ftSurf = out_fieldtrip_tess(SurfaceFiles)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016

% Parse inputs
if ischar(SurfaceFiles)
    SurfaceFiles = {SurfaceFiles};
end

% Initialize variable
ftSurf = repmat(struct('pos', [], 'tri', [], 'unit', []), 1, length(SurfaceFiles));
% Loop on surfaces
for i = 1:length(SurfaceFiles)
    % Read file from database
    sSurf = in_tess_bst(SurfaceFiles{i});
    % Format it in FieldTrip format
    ftSurf(i).pos  = sSurf.Vertices;
    ftSurf(i).tri  = sSurf.Faces;
    ftSurf(i).unit = 'm';
end




