function obj = set( obj, propName, propValue )
% Set a property of a BstPanel object.

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
% Authors: Francois Tadel, 2008


%% Modify object properties
switch (propName)
    % Try to redefine the container panel that holds the object
    % Argument propValue must be a cell array :
    %    - First cell is the container.type string {'JavaWindow', 'MatlabFigure', 'BrainstormTab'}
    %    - Other cells are the container.handle
    case 'container'
        % Verify that propValue is a cell array with at least 2 elements
        if (~iscell(propValue) || length(propValue)<2)
            error('The ''container'' property must be a cell array {containerType, containerHandle...}.');
        else
            obj.container.type = propValue{1};
            % Switch between container types
            switch(propValue{1})
                % JAVA WINDOW
                case 'JavaWindow'
                    if (~isa(propValue{2}, 'java.awt.Window'))
                        error('For a ''JavaWindow'' container type, propValue{2} must be a valid java.awt.Window object.');
                    end
                    obj.container.handle = propValue(2);
                    
                % MATLAB FIGURE
                case 'MatlabFigure'
                    if (~ishandle(propValue{2}))
                        error('For a ''MatlabFigure'' container type, propValue{2} must be a valid Figure handle.');
                    end
                    obj.container.handle = propValue(2);
                    
                % BRAINSTORM TAB/PANEL
                case {'BrainstormTab', 'BrainstormPanel'}
                    if (~ischar(propValue{2}) || isempty(bst_get('PanelContainer', propValue{2})))
                        error('For a ''BrainstormTab'' container type, propValue{2} must be a Brainstorm panel container.');
                    end
                    obj.container.handle = propValue(2);
                    
                % UNKNOWN CONTAINER TYPE
                otherwise
                    error('Unknown container type %''s''', propValue{1});
            end
        end
    case 'sControls'
        obj.sControls = propValue;
    otherwise
        % If property exists
        if (ismember(propName, fields(obj)))
            error('Property ''%s'' of class ''%s'' is read-only.', propName, class(obj));
        else
            error('Property ''%s'' not defined for class ''%s''.', propName, class(obj));
        end
end



