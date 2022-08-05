function export_label(filename,Surface, Scout)
% export_label: Export scout as FreeSurfer label
% USAGE: export_label(filename,Surface, Scout) : Export scout as label to filename
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
% Note: Can only export one scout per file
% Authors: Edouard Delaire, 2022
    

    LabelMat = struct();
    LabelMat.comment = Scout.Label;
    LabelMat.vertices = Scout.Vertices - 1;
    LabelMat.pos = Surface.Vertices(Scout.Vertices,:); % Might need to divide by 1000
    LabelMat.values = ones(1, length(Scout.Vertices));

    mne_write_label_file(filename,LabelMat);

end