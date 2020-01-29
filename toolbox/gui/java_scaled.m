function jObject = java_scaled(objType, varargin)
%JAVA_SCALED Create a scaled java AWT or SWING object
%
% USAGE:  jDimension = java_scaled('dimension', x, y)
%            jInsets = java_scaled('insets', top, left, bottom, right)
%          jTextArea = java_scaled('textarea', x, y)
%        scaledValue = java_scaled('value', value)
%            jBorder = java_scaled('titledborder', title)

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
% Authors: Francois Tadel, 2017

% Get scaling factor
InterfaceScaling = bst_get('InterfaceScaling') / 100;

% Create object
switch lower(objType)
    case 'dimension'
        jObject = java_create('java.awt.Dimension', 'II', ...
            round(varargin{1} * InterfaceScaling), ...
            round(varargin{2} * InterfaceScaling));
    case 'insets'
        jObject = java_create('java.awt.Insets', 'II', ...
            round(varargin{1} * InterfaceScaling), ...
            round(varargin{2} * InterfaceScaling), ...
            round(varargin{3} * InterfaceScaling), ...
            round(varargin{4} * InterfaceScaling));
    case 'textarea'
        jObject = java_create('javax.swing.JTextArea', 'II', ...
            round(varargin{1} * InterfaceScaling), ...
            round(varargin{2} * InterfaceScaling));
    case 'value'
        jObject = round(varargin{1} * InterfaceScaling);
    case 'titledborder'
        jObject = java_call('javax.swing.BorderFactory', 'createTitledBorder', 'Ljava.lang.String;', varargin{1});
        jObject.setTitleFont(bst_get('Font'));
end

