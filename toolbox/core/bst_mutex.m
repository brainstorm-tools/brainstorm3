function res = bst_mutex( action, MutexName, releaseCallback )
% BST_MUTEX: Create, wait for, and release a Brainstorm mutex.
%
% USAGE:  hMutex = bst_mutex('create',  MutexName)
%         hMutex = bst_mutex('get',     MutexName)
%                  bst_mutex('waitfor', MutexName)
%                  bst_mutex('release', MutexName)
%              s = bst_mutex('elapsed', MutexName)
%                  bst_mutex('setReleaseCallback', MutexName, releaseCallback)
%                  bst_mutex('list')

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
% Authors: Francois Tadel, 2008-2016

if (nargin == 0)
    action = 'list';
end
if (nargin < 2)
    if ~strcmpi(action, 'list')
        error('You must provide a mutex name. To see all current mutex, use bst_mutex(''list'')');
    end
else
    MutexId = ['hBstMutex' MutexName];
end

% Enable the visibility of the mutex handles
if ismember(lower(action), {'list', 'get'})
    ShowHiddenHandles = get(0, 'ShowHiddenHandles');
    set(0, 'ShowHiddenHandles', 'on');
end

% Action
switch lower(action)
    case 'list'
        disp([10 'Current brainstorm mutexes:' ]);
        % Get all figures
        allFig = findobj(0,'-depth', 1, 'type','figure');       
        % Process all figures
        for i = 1:length(allFig)
            figName = get(allFig(i), 'Tag');
            if (length(figName) > 10) && strcmp(figName(1:9), 'hBstMutex')
                disp(['  - ' figName(10:end)]);
            end
        end
        disp(' ');
    case 'create'
        % Get if mutex already exists
        hMutex = bst_mutex('get', MutexName);
        % If mutex already exist: delete it
        if ~isempty(hMutex)
            disp(['BST> WARNING: Mutex "' MutexName '" already exists.']); 
            delete(hMutex);
        end
        
        % Is new mutex visible
        if exist('isdeployed', 'builtin') && isdeployed
            isVisible = 'on';
        else
            isVisible = 'off';
        end
        % Create mutex
        hMutex = figure('Visible',          isVisible, ...
                        'NumberTitle',      'off', ...
                        'IntegerHandle',    'off', ...
                        'HandleVisibility', 'off', ...
                        'Renderer',         'painters', ...
                        'MenuBar',          'none', ...
                        'Toolbar',          'none', ...
                        'DockControls',     'off', ...
                        'Units',            'pixels', ...
                        'Position',         [0 0 1 1], ...
                        'UserData',         clock(), ...
                        'Name',             MutexName, ...
                        'Tag',              MutexId);
        res = hMutex;
        
    case 'get'
        % Check if this mutex already exist
        hMutex = findobj(0, '-depth', 1, 'Type', 'figure', 'Tag', MutexId);
        res = hMutex;
        
    case 'release'
        % Get mutex handle
        hMutex = bst_mutex('get', MutexName);
        % Delete mutex
        if ~isempty(hMutex)
            delete(hMutex);
        else
%             warning('Bst:InvalidMutex', ['Mutex "' MutexName '" does not exist.']); 
        end
        res = [];
        
    case 'waitfor'
        % Get mutex handle
        hMutex = bst_mutex('get', MutexName);
        % Wait for the release of the mutex
        if ~isempty(hMutex)
            waitfor(hMutex);
        else
            warning('Bst:InvalidMutex', ['Mutex "' MutexName '" does not exist.']); 
        end
        res = [];
        
    case 'elapsed'
        % Get mutex handle
        hMutex = bst_mutex('get', MutexName);
        % Get number of seconds elapsed since mutex creation
        if ~isempty(hMutex)
            oldTime = get(hMutex, 'UserData');
            curTime = clock();
            res = etime(curTime, oldTime);
        else
            warning('Bst:InvalidMutex', ['Mutex "' MutexName '" does not exist.']); 
            res = 0;
        end
        
    case 'setreleasecallback'
        % Get mutex handle
        hMutex = bst_mutex('get', MutexName);
        % Get number of seconds elapsed since mutex creation
        if ~isempty(hMutex)
            set(hMutex, 'CloseRequestFcn', releaseCallback);
        else
            warning('Bst:InvalidMutex', ['Mutex "' MutexName '" does not exist.']); 
            res = 0;
        end

    otherwise
        error('Invalid mutex action.');
end

% Restore the visibility of the mutex handles
if ismember(lower(action), {'list', 'get'})
    set(0, 'ShowHiddenHandles', ShowHiddenHandles);
end

        
        
        
        