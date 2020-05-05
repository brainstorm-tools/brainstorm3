function out_projector_fif(FifFile, ChannelNames, Projectors)
% OUT_PROJECTOR_FIF: Saves a list of SSP projectors in Brainstorm format in a FIF file.

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
% Authors: Francois Tadel, 2012

% Get fiff constants
global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end

% Convert projectors to FIF format
projs = repmat(struct('kind',[], 'active',[], 'desc',[], 'data', []), 0);
% Loop on all the projector categories
for iCat = 1:length(Projectors)
    % Skip projectors that are not selected
    if (Projectors(iCat).Status == 0)
        continue;
    end
    % Get the selected components for this projector category
    iSelComp = find(Projectors(iCat).CompMask);
    % Save each component as a projector in the FIF file
    for i = 1:length(iSelComp)
        iComp = iSelComp(i);
        iProj = length(projs) + 1;
        projData = Projectors(iCat).Components(:,iComp)';
        iRows    = find(projData);
        projs(iProj).kind   = FIFF.FIFFV_PROJ_ITEM_FIELD;
        projs(iProj).active = (Projectors(iCat).Status == 2);
        projs(iProj).desc   = Projectors(iCat).Comment;
        projs(iProj).data.nrow      = 1;
        projs(iProj).data.ncol      = length(iRows);
        projs(iProj).data.row_names = [];
        projs(iProj).data.col_names = ChannelNames(iRows);
        projs(iProj).data.data      = projData(iRows);
    end
end

% Write FIF file
fid = fiff_start_file(FifFile);
fiff_write_proj(fid, projs);
fiff_end_file(fid);
            
            
            