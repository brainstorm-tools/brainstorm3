function tutorial_visual(bids_dir, reports_dir)
% TUTORIAL_VISUAL: Runs the Brainstorm/SPM group analysis pipeline (BIDS version).
%
% ONLINE TUTORIALS: 
%    - https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle
%    - https://neuroimage.usc.edu/brainstorm/Tutorials/VisualGroup
%
% INPUTS:
%    - bids_dir    : Path to folder ds000117  (https://openneuro.org/datasets/ds000117)
%    - reports_dir : If defined, exports all the reports as HTML to this folder

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
% Author: Francois Tadel, Elizabeth Bock, 2017-2018

% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin < 1) || isempty(bids_dir) || ~file_exist(bids_dir)
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

% Protocol names
ProtocolNameSingle = 'TutorialVisual';
ProtocolNameGroup  = 'TutorialGroup';
% Part 1: Single subject analysis
tutorial_visual_single(bids_dir, reports_dir);
% Part 2: Copy to a new protocol for the group analysis
tutorial_visual_copy(ProtocolNameSingle, ProtocolNameGroup, reports_dir);
% Part 3: Group analysis
tutorial_visual_group(ProtocolNameGroup, reports_dir);


