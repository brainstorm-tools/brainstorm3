function jPanel = gui_river( varargin )
% GUI_RIVER: Create a RiverPanel Java object.
%
% USAGE:  jPanel = gui_river( gaps, extraInsets, title )
%         jPanel = gui_river( gaps, extraInsets )
%         jPanel = gui_river( gaps )
%         jPanel = gui_river( title )
%         jPanel = gui_river( )
%
% INPUT:
%    - gaps        : [horizontalGap, verticalGap]
%    - extraInsets : [top, left, bottom, right]
%    - title       : string (created a titled panel)

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
% Authors: Francois Tadel, 2008-2017

% Parse inputs
if (nargin == 0)
    gaps        = [];
    extraInsets = [];
    title       = [];
elseif (nargin == 1) && ischar(varargin{1})
    gaps        = [];
    extraInsets = [];
    title       = varargin{1};
elseif (nargin == 1)
    gaps        = varargin{1};
    extraInsets = [];
    title       = [];
elseif (nargin == 2)
    gaps        = varargin{1};
    extraInsets = varargin{2};
    title       = [];
elseif (nargin == 3)
    gaps        = varargin{1};
    extraInsets = varargin{2};
    title       = varargin{3};
end

% Get interface scaling
InterfaceScaling = bst_get('InterfaceScaling') / 100;
% Configure RiverLayout
jRiverLayout = java_create('se.datadosen.component.RiverLayout');
if ~isempty(gaps)
    jRiverLayout.setHgap(round(gaps(1) * InterfaceScaling));
    jRiverLayout.setVgap(round(gaps(2) * InterfaceScaling));
end
if ~isempty(extraInsets)
    %extraInsets = round(extraInsets * InterfaceScaling);
    jRiverLayout.setExtraInsets(java_scaled('insets', extraInsets(1), extraInsets(2), extraInsets(3), extraInsets(4))); 
end
jPanel = java_create('javax.swing.JPanel');
jPanel.setLayout(jRiverLayout)

% If there is a panel title
if ~isempty(title)
    jBorder = java_scaled('titledborder', title);
    jPanel.setBorder(jBorder);
else
    jPanel.setBorder([]);
end


