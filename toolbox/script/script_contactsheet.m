% SCRIPT_CONTACTSHEET: Display a sources file, set its orientation, create contact sheet and save it as an image
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
% Authors: Francois Tadel, 2010

% Define inputs
ResultsFile = 'Subject01\Right\results_wMNE_MEG_KERNEL_101117_0941.mat';
OutputImageFile = 'C:\test.jpg'; % You can use also other image formats (see help in Matlab imwrite function for supported formats)
nbSamples = 20;                  % Number of images to extract
TimeRange = [0.020, 0.100];      % In seconds - Leave empty to use all the recordings 

% Display sources
hFig = script_view_sources(ResultsFile, 'cortex');
% Set camera orientation (possible values: left, right, back, front, bottom, top)
figure_3d('SetStandardView', hFig, 'right');
% Hide the source colorbar
bst_colormaps('SetDisplayColorbar', 'Source', 0);
% Redimension figure (the contact sheet image size depends on this figure's size)
% Position = [x,y,width,height]
set(hFig, 'Position', [200,200,320,200]);    

% Create contact sheet figure
hContactFig = view_contactsheet( hFig, 'time', 'fig', OutputImageFile, nbSamples, TimeRange );
% Get the image definition (RGB) from the figure
img = get(findobj(hContactFig, 'Type', 'image'), 'CData');
% Save image in file
out_image(OutputImageFile, img);

% Close both figures
close(hContactFig);
close(hFig);






