function imgRGB = java_geticon( imgName, bgColor )
% JAVA_GETICON: Load an icon with the IconLoader java class.
% 
% USAGE:  imgRGB = java_geticon( imgName )
%         imgRGB = java_geticon( imgName, bgColor )
% INPUT:
%    - imgName : Full path to the icon file to load
%    - bgColor : Background color that will be used to display pixels that as alpha values < 1.
% OUTPUT:
%    - imgRGB  : [x,y,3] uint8

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
% Authors: Francois Tadel, 2008-2010

import org.brainstorm.icon.*;

global java_getIcon_bgColor;

if (nargin < 2)
    % bgColor = [212, 208, 200];
    if isempty(java_getIcon_bgColor)
%         h = uicontrol('Style', 'pushbutton', 'Visible', 'off');
%         java_getIcon_bgColor = get(h, 'BackgroundColor') * 255;
%         delete(h);
        jColor = javax.swing.UIManager.getColor('Button.background');
        java_getIcon_bgColor = [jColor.getRed(), jColor.getGreen(), jColor.getBlue()];
    end
    bgColor = java_getIcon_bgColor;
end

% Get bytes array
imgArray = double(IconLoader.getIcon_RGB(imgName));
if isempty(imgArray)
    imgRGB = [];
    return;
end
% Get descriptor at the end of the array
nbValues = length(imgArray) - 3;
W = imgArray(nbValues + 1);
H = imgArray(nbValues + 2);

% Build icon background from button's background color
bgIcon = cat(3, ones(H, W) .* bgColor(1), ...
                ones(H, W) .* bgColor(2), ...
                ones(H, W) .* bgColor(3));

% Extract alpha values from array
alphaValues = double(reshape(imgArray(4:4:nbValues) > 0, W, H)');
imgRGB = uint8(cat(3, reshape(imgArray(1:4:nbValues), W, H)' .* alphaValues + bgIcon(:,:,1) .* (1-alphaValues), ...
                      reshape(imgArray(2:4:nbValues), W, H)' .* alphaValues + bgIcon(:,:,2) .* (1-alphaValues), ...
                      reshape(imgArray(3:4:nbValues), W, H)' .* alphaValues + bgIcon(:,:,3) .* (1-alphaValues)));

% Replace pixels where alpha=0 with button's background color


                  
% Convert pixel array in uint32
% => LES VALEURS SONT EN COMPLEMENTS A 2 => inversion de tous les bits necessaire
%imgArray = bitxor(uint32(-imgArray(1:end-3)), 4294967295);
% Separate values in three layers 32640, 
% imgRGB = uint8(cat(3, reshape(bitand(bitshift(imgArray, -16), 255), W, H)', ...
%                       reshape(bitand(bitshift(imgArray, -8), 255), W, H)', ...
%                       reshape(bitand(imgArray, 255), W, H)'));




