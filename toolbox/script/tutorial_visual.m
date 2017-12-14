function tutorial_visual(tutorial_dir, reports_dir)
% TUTORIAL_VISUAL_COPY: Runs the Brainstorm/SPM group analysis pipeline (BIDS version).
%
% ONLINE TUTORIALS: 
%    - http://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle
%    - http://neuroimage.usc.edu/brainstorm/Tutorials/VisualGroup
%
% INPUTS:
%    - tutorial_dir : Directory containing the folder ds000117_R1.0.0  (https://openfmri.org/dataset/ds000117/, version 1.0.0)
%    - reports_dir  : If defined, exports all the reports as HTML to this folder

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Author: Francois Tadel, Elizabeth Bock, 2017

% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin < 1) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial folder.');
end

% Configure default surface display
DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
DefaultSurfaceDisplay.SurfShowSulci   = 1;
DefaultSurfaceDisplay.SurfSmoothValue = 0.5;
DefaultSurfaceDisplay.DataThreshold   = 0.3;
DefaultSurfaceDisplay.SizeThreshold   = 1;
DefaultSurfaceDisplay.DataAlpha       = 0;
bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay);
% Configure default time series display
bst_set('FlipYAxis', 0);
bst_set('AutoScaleY', 1);
bst_set('UniformizeTimeSeriesScales', 1);
bst_set('ShowXGrid', 0);
bst_set('ShowYGrid', 0);
bst_set('DisplayGFP', 1);

% Part 1: Single subject analysis
tutorial_visual_single(tutorial_dir, reports_dir);
% Part 2: Copy to a new protocol for the group analysis
tutorial_visual_copy('TutorialVisual', 'TutorialGroup', reports_dir);
% Part 3: Group analysis
tutorial_visual_group('TutorialGroup', reports_dir);


