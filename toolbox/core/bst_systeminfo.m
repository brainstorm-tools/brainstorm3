function  systemInfoText = bst_systeminfo(showInfo)
% BST_SYSTEMNINFO: Get general information about Brainstorm, Matlab and the Computer
%
% USAGE:  bst_systeminfo(showInfo)
% INPUTS:
%    - showInfo : 0 (default) only return system info text
%                 1 with GUI, open window with system info
%                   without GUI, print information in console
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
% Authors: Raymundo Cassani, 2024

% Parse inputs
if (nargin < 1) || isempty(showInfo)
    showInfo = 0;
end

summaryPairs = cell(0,2);
% == Brainstorm
summaryPairs = [summaryPairs; {'=== Brainstorm ===', ''}];
% Version
bst_version = bst_get('Version');
summaryPairs = [summaryPairs; {'Version ', bst_version.Version}];
summaryPairs = [summaryPairs; {'Release ', bst_version.Release}];
bst_variant  = 'source';
if bst_iscompiled()
    bst_variant = 'standalone';
end
summaryPairs = [summaryPairs; {'Variant ', bst_variant}];
% Plugins
pluginTextPairs = cell(0,2);
pluginTextPairs = [pluginTextPairs, {'Plugins ', 'No installed plugins.'}];
InstPlugs  = bst_plugin('GetInstalled');
nInstPlugs = length(InstPlugs);
iPluginRow = 0;
for ix = 1 : nInstPlugs
    plugName = InstPlugs(ix).Name;
    if InstPlugs(ix).isLoaded
        plugName = [plugName, '*'];
    end
    if mod(ix-1, 8) == 0
        iPluginRow = iPluginRow + 1;
        pluginTextPairs{iPluginRow, 2} = '';
    end
    pluginTextPairs{iPluginRow, 2} = strtrim([pluginTextPairs{iPluginRow, 2}, ' ', plugName]);
end
summaryPairs = [summaryPairs; pluginTextPairs];
summaryPairs = [summaryPairs; {'', ''}];

% == Directories
summaryPairs = [summaryPairs; {'=== Brainstorm directories ===', ''}];
summaryPairs = [summaryPairs; {'*** Directory paths may contain sensitive information, check before sharing ***', ''}];
summaryPairs = [summaryPairs; {'Brainstorm ', bst_get('BrainstormHomeDir')}];
summaryPairs = [summaryPairs; {'DataBase   ', bst_get('BrainstormDbDir')}];
summaryPairs = [summaryPairs; {'Bst_User   ', bst_get('BrainstormUserDir')}];
summaryPairs = [summaryPairs; {'Temporary  ', bst_get('BrainstormTmpDir')}];
summaryPairs = [summaryPairs; {'', ''}];

% === Matlab and Java
summaryPairs = [summaryPairs; {'=== Matlab ===', ''}];
summaryPairs = [summaryPairs; {'Matlab version ', [bst_get('MatlabReleaseName') ' (' num2str(bst_get('MatlabVersion')/100) ')']}];
summaryPairs = [summaryPairs; {'Java version   ', num2str(bst_get('JavaVersion'))}];
summaryPairs = [summaryPairs; {'', ''}];

% == System
summaryPairs = [summaryPairs; {'=== System ===', ''}];
summaryPairs = [summaryPairs; {'OS name   ', bst_get('OsName')}];
summaryPairs = [summaryPairs; {'OS type   ', bst_get('OsType')}];
[memTotal, memAvail] = bst_get('SystemMemory');
summaryPairs = [summaryPairs; {'Mem total ', [num2str(memTotal) ' MiB']}];
summaryPairs = [summaryPairs; {'Mem avail ', [num2str(memAvail) ' MiB']}];

% Format string
iFields = find(~cellfun(@isempty, summaryPairs(:,2)));
maxField = max([cellfun(@length, summaryPairs(iFields,1))]);
summaryPairs(iFields,1) = cellfun(@(x) ['  ', x, ':', repmat(' ', 1, maxField-length(x))], summaryPairs(iFields,1), 'UniformOutput', 0);
summaryRows = cellfun(@(x,y) strjoin({x,y}, ' '), summaryPairs(:,1), summaryPairs(:,2), 'UniformOutput', 0);
systemInfoText = strjoin(summaryRows, char(10));
if showInfo
    if bst_get('isGUI')
        view_text(systemInfoText, 'System info');
    else
        fprintf([systemInfoText, '\n']);
    end
end
