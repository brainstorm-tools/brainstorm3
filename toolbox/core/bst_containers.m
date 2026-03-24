function [varargout] = bst_containers(varargin)
% BST_CONTAINERS: Manages containers for container-based plugins in Brainstorm
%
% USAGE:  [isOk, eName, eStatus] = bst_containers('GetEngine')
%       [isOk, errMsg, imageSha] = bst_containers('ImportImage', imageSource)
%  [isOk, errMsg. containerName] = bst_containers('RunContainer', containerName, imageSha, [volumes], [isDaemon])
%                 [isOk, cmdout] = bst_containers('ExecInContainer', containerName, cmdStr)
%                 [isOk, cmdout] = bst_containers('StatusContainer', containerName)

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
% Authors: Raymundo Cassani, 2026
%          Takfarinas Medani, 2026


eval(macro_method);
end


%% ===== GET CONTAINER ENGINE =====
function [isFound, engineName, errMsg] = GetEngine(engineName)
% USAGE:  [isFound, engineName, errMsg] = bst_containers('GetEngine')             % Find, test and set a supported container engine
%         [isFound, engineName, errMsg] = bst_containers('GetEngine', engineName) % Test the requested container engine
    isFound = 0;
    errMsg  = '';

    % Get and test all the supported container engines
    if nargin < 1 || isempty(engineName) || strcmpi(engineName, 'auto-detect')
        [~, engineNames] = bst_get('ContainerEngine');
        % Remove 'auto-detect', first element in engineNames
        engineNames(1) = [];
        engineName     = '';
        isSetDefault   = 1;
    % Test only the requested container engine
    else
        engineNames  = {engineName};
        isSetDefault = 0;
    end

    % Tests container engines
    for iEngine = 1 : length(engineNames)
        if ispc
            [status, cmdout] = system(['where ' engineNames{iEngine}]);
            if status == 0
                cmdout = strsplit(strtrim(cmdout), '\n');
                if length(cmdout) >= 1
                    isFound = 1;
                    enginePath = strtrim(cmdout{1});
                end
            end
        else
            [status, cmdout] = system(['which ' engineNames{iEngine}]);
            if status == 0
                isFound = 1;
                enginePath = strtrim(cmdout);
            end
        end
        if isFound
            engineName = engineNames{iEngine};
            fprintf('Container engine "%s" found in "%s"\r', engineName, enginePath);
            break
        end
    end
    % Return if not found
    if ~isFound
        if isempty(engineName)
            errMsg = 'No valid container engine was found';
        else
            errMsg = ['Container engine ' engineName ' was not found'];
        end
        return
    end

    % Set as default the container engine found
    if isSetDefault
        bst_set('ContainerEngine', engineName);
    end

    % Check the container engine status
    switch(engineName)
        case 'docker'
            [status, cmdout] = system([engineName ' info']);
            cmdout = strtrim(cmdout);
            if status == 1 || ~isempty(strfind(lower(cmdout), 'failed')) || ~isempty(strfind(lower(cmdout), 'ERROR'))
                errMsg = cmdout;
                return
            end

        case 'podman'
            [status, cmdout] = system([engineName ' info', '-echo']);
            if status == 1
                errMsg = cmdout;
                return
            end

        otherwise

    end
end


%% ===== IMPORT IMAGE =====
function [isOk, errMsg, imageSha] = ImportImage(imageSource)
% Load container image into container engine
% USAGE:  [isOk, errMsg, imageSha] = bst_containers('ImportImage', imageSource)
    isOk = 0;
    errMsg = '';
    imageSha = '';

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        return
    end

    % [TODO] Check imageSource is: reference, local file or download URL
    imageType = 'reference';

    % [TODO] Get image from download link
    if strcmpi(imageType, 'url')
        % Download file in tmp
        % Update imageSource
        % Change type to file
    end

    % Import image
    switch engineName
        case 'docker'
            switch imageType
                case 'reference'
                    [status, cmdout] = system(['docker pull ' imageSource]);
                case 'file'
                    [status, cmdout] = system(['docker load --input ' imageSource]);
            end
            if status == 0
                tokens = regexp(cmdout, 'sha256:[a-f0-9]+', 'match');
                imageSha = strtrim(tokens{1});
            end
    end
    isOk = status == 0;
    if ~isOk
        return
    end
end


%% ===== RUN CONTAINER AS DAEMON =====
function [isOk, errMsg, containerName] = RunContainer(containerName, imageSha, volumes, isDaemon)
% USAGE:  [isOk, errMsg, imageSha] = bst_containers('RunDaemonContainer', imageSha, volumes)
    isOk = 0;

    % Validate inputs
    if nargin < 4 || isempty(isDaemon)
        isDaemon = 0;
    end
    if nargin < 3 || ~iscell(volumes) || size(volumes,2) ~=2
        volumes = [];
    end

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        return
    end

    % Create volumes pairs
    volumesStr = '';
    if ~isempty(volumes)
        nPairs = size(volumes, 1);
        pairs = cell(nPairs, 1);
        for iPair = 1 : nPairs
            pairs{iPair} = ['-v' volumes{1} ':' volumes{2}];
        end
        volumesStr = strjoin(pairs, ' ');
    end

    % Run container
    switch engineName
        case 'docker'
            cmdStr = ['docker run -d --name ' containerName];
            if ~isDaemon
                cmdStr = sprintf('docker run --rm --name %s %s %s', containerName, volumesStr, imageSha);
            else
                % Replace ENTRYPOINT (if any) with `sleep infinity`
                cmdStr = sprintf('docker run -d --name %s %s --entrypoint sleep %s infinity', containerName, volumesStr, imageSha);
            end
            [status, cmdout] = system(cmdStr);
    end
    isOk = status == 0;
    if ~isOk
        return
    end
end


%% ===== EXECUTE COMMAND IN CONTAINER =====
function [isOk, cmdout] = ExecInContainer(containerName, cmdStr)
    isOk = 0;
    cmdout = '';

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        disp(errMsg)
        return
    end

    % Check container status
    [containerName, isRunning] = GetContainerInfo(containerName);
    if isempty(containerName) || ~isRunning
        return
    end

    % Run command
    switch engineName
        case 'docker'
            [status, cmdout] = system(['docker exec ' containerName ' sh -c ' '''' cmdStr '''']);
            isOk = status == 0;
            cmdout = strtrim(cmdout);
    end
end


%% ===== CHECK CONTAINER STATUS =====
function [containerNameOut, isRunning, volumePairs, imageSha] = GetContainerInfo(containerName)
    containerNameOut = [];
    isRunning = 0;

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        disp(errMsg)
        return
    end

    % Search for existent container with the same name and image reference
    switch engineName
        case 'docker'
            % Find containers with same name
            [status, cmdout] = system(['docker inspect ' containerName ' --format "{{.Name}}"']);
            if status == 0
                isExist = 1;
                containerNameOut = strrep(strtrim(cmdout), '/', '');
                [status, cmdout] = system(['docker inspect ' containerName ' --format "'...
                    '{{.State.Status}} # ' ...
                    '{{.HostConfig.Binds}} # ' ...
                    '{{.Image}}"']);
                cmdout = strsplit(strtrim(cmdout), '#');
                isRunning = strcmpi('running', strtrim(cmdout{1}));
                volumes = regexprep(strtrim(cmdout{2}), '^\[|\]$', '');
                volumePairs = strsplit(volumes, ':');
                volumePairs = reshape(volumePairs, 2, [])';
                tokens = regexp(cmdout{3}, 'sha256:[a-f0-9]+', 'match');
                imageSha = strtrim(tokens{1});
            end
    end
end


%% ===== STOP CONTAINER =====
function isOk = StopContainer(containerName, isForce)
    isOk = 0;

    % Validate inputs
    if nargin < 2 || isempty(isForce)
        isForce = 0;
    end

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        disp(errMsg)
        return
    end

    % Stop container
    switch engineName
        case 'docker'
            if ~isForce
                % Stop and remove
                [status, cmdout] = system(['docker stop ' containerName ' && docker rm ' containerName]);
            else
                % Kill
                [status, cmdout] = system(['docker rm -f ' containerName]);
            end
            isOk = status == 0;
    end

end


%% ===== REMOVE IMAGE =====
function isOk = RemoveImage(imageSha, isForce)
    isOk = 0;

    % Validate inputs
    if nargin < 2 || isempty(isForce)
        isForce = 0;
    end

    isOk = 0;
    errMsg = '';
    imageSha = '';

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        return
    end

    % Default container engine
    engineName = bst_get('ContainerEngine');
    % Check status of container engine
    [isFound, engineName, errMsg] = GetEngine(engineName);
    if ~isFound || ~isempty(errMsg)
        disp(errMsg)
        return
    end

    % Stop container
    switch engineName
        case 'docker'
            if ~isForce
                % Remove image
                [status, cmdout] = system(['docker rmi ' imageSha]);
            else
                % Force remove image
                [status, cmdout] = system(['docker rmi -f ' imageSha]);
            end
            isOk = status == 0;
    end
end