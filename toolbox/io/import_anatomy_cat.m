function errorMsg = import_anatomy_cat(varargin)
% IMPORT_ANATOMY_CAT: Import a full CAT12 folder as the subject's anatomy (switch between versions).

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
% Authors: Francois Tadel, 2020

CatDir = varargin{2};
% Switch between versions for the CAT12 reader, depending on the existence of a label file
AnnotFile = file_find(CatDir, 'lh.aparc_DK40.*.annot', 2);
if file_exist(AnnotFile)
    errorMsg = import_anatomy_cat_2020(varargin{:});
else
    errorMsg = import_anatomy_cat_2019(varargin{:});
end

