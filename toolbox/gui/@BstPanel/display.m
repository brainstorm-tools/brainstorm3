function display(panel)
% Display function for BstPanel object.

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

% If displaying a template : do not display anything
if ((size(panel,1)==0) || (size(panel,2)==0))
    disp('Template Brainstorm panel...');
    return
end

for iPanel = 1:length(panel)
    % Display title and simple properties
    disp('Brainstorm window panel:');
    disp(sprintf('           name: %s', panel(iPanel).name));
    disp(sprintf('        jHandle: %s', char(panel(iPanel).jHandle.getClass())));
    switch (panel(iPanel).container.type)
        case ''
            disp(sprintf('      container: N/A'));
        case 'JavaWindow'
            disp(sprintf('      container: JavaWindow (%s)', char(panel(iPanel).container.handle{1})));
        case 'MatlabFigure'
            disp(sprintf('      container: MatlabFigure (%d)', panel(iPanel).container.handle{1}));
        case 'BrainstormTab'
            disp(sprintf('      container: BrainstormTab (''%s'')', panel(iPanel).container.handle{1}));
        case 'BrainstormPanel'
            disp(sprintf('      container: BrainstormPanel (''%s'')', panel(iPanel).container.handle{1}));
    end
    % Display sControls structure
    sControlsStr = '      sControls: ';
    sControlsFields = fieldnames(panel(iPanel).sControls);
    if isempty(sControlsFields)
        % No fields 
        sControlsStr = [sControlsStr 'No controls registered'];
    else
        % Display all the fields
        for i=1:length(sControlsFields)
            if isjava(panel(iPanel).sControls.(sControlsFields{i}))
                controlDesc = class(panel(iPanel).sControls.(sControlsFields{i}));
            else
                controlDesc = 'User value';
            end
            if (i == 1)
                sControlsStr = sprintf('%s%s (%s)', sControlsStr, sControlsFields{i}, controlDesc);
            else
                sControlsStr = sprintf('%s\n                 %s (%s)', sControlsStr, sControlsFields{i}, controlDesc);
            end
        end
    end
    disp(sControlsStr);
    disp(' ');
end

