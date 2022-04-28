function panel = BstPanel( varargin )
% Constructor for object BstPanel.
% A BstPanel object holds mainly a java Swing container to be displayed in the 
% Brainstorm main window.
%
% Constructor call :
%     BstPanel(name, jHandle, sControls)
%     BstPanel() : just to have a data template
%
% Data structure
%   - jHandle    : java handle to a javax.swing.JComponent object (panel handle)
%   - name       : string identifier to index and display this panel
%   - container  : string identifier of the panel container in which it should be displayed
%   - sControls  : list of the useful controls of the panel

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

% Parse inputs
if (nargin == 0)
    % Create an empty object (template to create structures)
    panel.jHandle    = [];
    panel.name       = '';
    panel.container  = struct('type',   '', ...
                              'handle', {});
    panel.sControls  = [];
    panel = class(panel, 'BstPanel'); 
    panel = repmat(panel, 0);
    return;
elseif (nargin == 3)
    name       = varargin{1};
    jHandle    = varargin{2};
    sControls  = varargin{3};
else
    error('Usage : BstPanel(name, jHandle, sControls)');
end

% Check inputs
if (~isa(jHandle, 'javax.swing.JComponent'))
    error('First argument ''jHandle'' must be a javax.swing.JComponent object');
elseif (~ischar(name))
    error('Second argument ''name'' must be a Matlab string');
elseif (~isstruct(sControls) && ~isempty(sControls))
    error('Third argument ''sControls'' must be a structure of Java Swing controls');
end
% Check intergrity of the structure sControls 
if (isempty(sControls))
    sControls = struct();
end

% Create data structure
panel.jHandle          = jHandle;
panel.name             = name;
panel.container.type   = '';
panel.container.handle = {};
panel.sControls        = sControls;
% Set object class
panel = class(panel, 'BstPanel');   
    
    