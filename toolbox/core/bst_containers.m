function varargout = bst_containers(varargin)
% BST_CONTAINERS: Manage containers for container-based plugins in Brainstorm
%
% USAGE: 
%  [errMsg, engineName]    = bst_containers('GetEngine')
%  [errMsg, imageList]     = bst_containers('GetImages')
%  [errMsg, imageSha]      = bst_containers('ImportImage', imageSource, [imageTag])
%   errMsg                 = bst_containers('RunContainer', containerName, imageSha, [volumes], [isDaemon])
%  [errMsg, cmdout]        = bst_containers('ExecInContainer', containerName, cmdStr)
%  [errMsg, containerInfo] = bst_containers('GetContainerInfo', containerName)
%   errMsg                 = bst_containers('StopContainer', containerName, [isForced=0])
%   errMsg                 = bst_containers('RemoveImage', imageSha/Name, [isForced=0])

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
function [errMsg, engineName] = GetEngine(engineName)
% USAGE: [errMsg, engineName] = bst_containers('GetEngine')             % Find, test and set a supported container engine
%        [errMsg, engineName] = bst_containers('GetEngine', engineName) % Test the requested container engine
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
    isFound = 0;
    for iEngine = 1 : length(engineNames)
        switch engineNames{iEngine}
            case {'docker'}
                if ispc
                    [status, cmdout] = system(['where ' engineNames{iEngine}]);
                    if status == 0
                        cmdout = strsplit(strtrim(cmdout), '\n');
                        if ~isempty(cmdout)
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
        end
        % Break loop if found
        if isFound
            engineName = engineNames{iEngine};
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
    % Set as default the container engine found
    elseif isSetDefault
        bst_set('ContainerEngine', engineName);
    end

    % Check the container engine status
    switch engineName
        case 'docker'
            [status, cmdout] = system([engineName ' info']);
            cmdout = strtrim(cmdout);
            if status == 1 || ~isempty(strfind(lower(cmdout), 'failed')) || ~isempty(strfind(lower(cmdout), 'error'))
                errMsg = cmdout;
                return
            end
    end
end


%% ===== GET AVAILABLE IMAGES =====
function [errMsg, imageList] = GetImages()
% USAGE:  [errMsg, imageList] = bst_containers('GetImages')
    imageList = cell(0,2); % [Name:Tag, SHA]

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end

    % List of available images
    switch engineName
        case 'docker'
            [status, cmdout] = system('docker images --all --no-trunc --format "{{.Repository}}:{{.Tag}} {{.ID}}"');
            if status == 0 && ~isempty(cmdout)
                imageList = strsplit(strtrim(strrep(cmdout, char(10), ' ')), ' ');
                if mod(length(imageList), 2) ~= 0
                    errMsg = 'Error parsing Docker image list';
                    return
                end
                imageList = reshape(imageList, 2, [])';
            elseif status ~= 0
                errMsg = cmdout;
            end
    end
end


%% ===== IMPORT IMAGE =====
function [errMsg, imageSha] = ImportImage(imageSource, imageTag)
% Import container image into container engine, and create a tag
% USAGE:  [errMsg, imageSha] = bst_containers('ImportImage', imageSource, [imageTag])
    imageSha = '';

    if (nargin < 2) || isempty(imageTag)
        imageTag = '';
    end

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end

    % Default: imageSource is an image reference
    imageType = 'reference';
    % If imageSource is a URL, download image file
    if ~isempty(regexp(imageSource, '^http[s]*://', 'once'))
        % Get tmp dir to bind container
        tmpDir = bst_get('BrainstormTmpDir', 0, 'pull_image');
        imageFile = bst_fullfile(tmpDir, 'image.tgz');
        disp(['BST> Downloading URL : ' imageSource]);
        disp(['BST> Saving to file  : ' imageFile]);
        errMsg = gui_brainstorm('DownloadFile', imageSource, imageFile, 'Download container image: ');
        if ~isempty(errMsg)
            errMsg = ['Impossible to download container image automatically:' 10 errMsg];
            return
        end
        imageSource = imageFile;
        imageType = 'file';
    end

    % Get current available images
    if ~isempty(imageTag)
        [errMsg, imageListOld] = GetImages();
        if ~isempty(errMsg)
            return
        end
    end

    % Import image
    switch engineName
        case 'docker'
            switch imageType
                case 'reference'
                    [status, cmdout] = system([' docker manifest inspect ' imageSource]);
                    if status == 0
                        image_info = jsondecode(cmdout);
                        image_size_go = sum([image_info.layers.size]) / 1e9;
                        % Ask for confirmation
                        if ~java_dialog('confirm', sprintf('Brainstorm will download %s of size %.2f Go. Do you want to continue ?', imageSource, round(image_size_go, 2)),  'Download docker image')
                            return;
                        end
                    else
                        errMsg = 'Unable to get image information.';
                        return;
                    end

                    [status, cmdout] = system(['docker pull ' imageSource]);
                    if status == 0
                        % If new or existent image, SHA256 is returned in output
                        % imageSha = regexp(cmdout, 'sha256:[a-f0-9]+', 'match', 'once');
                            [~, imageListNew] = GetImages();
                            image_name = strsplit(imageSource, '/');
                            imageSha = imageListNew{contains(imageListNew(:,1), image_name{end}), 2};
                    end

                case 'file'
                    [status, cmdout] = system(['docker load --input ' imageSource]);
                    if status == 0
                        % If new or existent image, Image name (or SHA256 for nameless image) is returned in output
                        token = regexp(cmdout, '[a-z0-9._-]+:[a-zA-Z0-9._-]+', 'match', 'once');
                        parts = strsplit(token, ':');
                        if strcmp(parts{1}, 'sha256') && ~isempty(regexp(parts{2}, '^[a-f0-9]+$', 'once'))
                            imageSha = token;
                        else
                            [~, imageListNew] = GetImages();
                            imageSha = imageListNew{strcmpi(imageListNew(:,1), token), 2};
                        end
                    end
            end
            % Tag image
            if status == 0 && ~isempty(imageTag)
                % Compare images before and after import
                [~, imageListNew] = GetImages();
                iOld = find(strcmpi(imageListOld(:,2), imageSha));
                iNew = find(strcmpi(imageListNew(:,2), imageSha));
                % Tag image
                [status, cmdout] = system(['docker tag ', imageSha, ' ', imageTag]);
                % Keep only the tag image IF the image was added in this call to ImportImage()
                if status == 0 && (length(iNew) - length(iOld)) == 1
                    if ~isempty(imageListOld)
                        [imageDel, iNew] = setdiff(imageListNew(iNew, 1), imageListOld(iOld, 1));
                    else
                        imageDel = imageListNew{iNew, 1};
                    end
                    if ~strcmpi(imageDel, '<none>:<none>')
                        [status, cmdout] = system(['docker rmi ', imageListNew{iNew, 1}]);
                    end
                end
            end
            if status ~= 0
                errMsg = cmdout;
                return
            end
    end
end


%% ===== RUN CONTAINER AS DAEMON =====
function errMsg = RunContainer(containerName, imageSha, volumes, isDaemon)
% USAGE: errMsg = bst_containers('RunContainer', containerName, imageSha, volumes, isDaemon)
    % Validate inputs
    if nargin < 4 || isempty(isDaemon)
        isDaemon = 0;
    end
    if nargin < 3 || ~iscell(volumes) || size(volumes,2) ~=2
        volumes = [];
    end

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end

    % Create volumes pairs
    volumesStr = '';
    if ~isempty(volumes)
        nPairs = size(volumes, 1);
        pairs = cell(nPairs, 1);
        for iPair = 1 : nPairs
            pairs{iPair} = ['-v ' volumes{iPair, 1} ':' volumes{iPair, 2}];
        end
        volumesStr = strjoin(pairs, ' ');
    end

    % Run container
    switch engineName
        case 'docker'
            if ~isDaemon
                % Run ENTRYPOINT
                cmdStr = sprintf('docker run --rm --name %s %s %s', containerName, volumesStr, imageSha);
            else
                % Replace ENTRYPOINT (if any) with `sleep infinity`
                cmdStr = sprintf('docker run -d --name %s %s --entrypoint sleep %s infinity', containerName, volumesStr, imageSha);
            end
            [status, cmdout] = system(cmdStr);
    end
    if status ~= 0
        errMsg = cmdout;
    end
end


%% ===== EXECUTE COMMAND IN CONTAINER =====
function [errMsg, cmdout] = ExecInContainer(containerName, cmdStr)
    cmdout = '';

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end
    % Check if container is running
    [errMsg, containerInfo] = GetContainerInfo(containerName);
    if ~isempty(errMsg) || ~containerInfo.isRunning
        return
    end

    % Run command
    switch engineName
        case 'docker'
            if ispc
                commandWrapper = '"';  % Double quote
            else
                commandWrapper = ''''; % Single quote
            end
            [status, cmdout] = system(['docker exec ' containerName ' sh -c ' commandWrapper cmdStr commandWrapper]);
            if status ~= 0
                errMsg = strtrim(cmdout);
            end
    end
end


%% ===== CHECK CONTAINER STATUS =====
function [errMsg, containerInfo] = GetContainerInfo(containerName)
% [containerNameOut, isRunning, volumePairs, imageSha]
    containerInfo = struct();
    containerInfo.name      = '';
    containerInfo.isRunning =  0;
    containerInfo.volumes   = [];
    containerInfo.imageSha  = '';

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end

    % Search for existent container with the same name and image reference
    switch engineName
        case 'docker'
            % Find containers with same name
            [status, cmdout] = system(['docker inspect ' containerName ' --format "{{.Name}}"']);
            if status ~= 0
                errMsg = strtrim(cmdout);
                return
            end
            containerInfo.name = strrep(strtrim(cmdout), '/', '');
            [status, cmdout] = system(['docker inspect ' containerName ' --format "'...
                '{{.State.Status}} # {{.HostConfig.Binds}} # {{.Image}}"']);
            if status ~= 0
                errMsg = strtrim(cmdout);
                return
            end
            cmdout = strsplit(strtrim(cmdout), '#');
            containerInfo.isRunning = strcmpi('running', strtrim(cmdout{1}));
            volumes = regexprep(strtrim(cmdout{2}), '^\[|\]$', '');
            volumes = regexprep(volumes, ':\', ';\');
            volumePairs = strsplit(volumes, ':');
            volumePairs = cellfun(@(x) regexprep(x, ';\', ':\'), volumePairs, 'UniformOutput', 0);
            containerInfo.volumes = reshape(volumePairs, 2, [])';
            tokens = regexp(cmdout{3}, 'sha256:[a-f0-9]+', 'match');
            containerInfo.imageSha = strtrim(tokens{1});
    end
end


%% ===== STOP CONTAINER =====
function errMsg = StopContainer(containerName, isForce)
    % Validate inputs
    if nargin < 2 || isempty(isForce)
        isForce = 0;
    end

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
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
            if status ~=0
                errMsg = strtrim(cmdout);
            end
    end
end


%% ===== REMOVE IMAGE =====
function errMsg = RemoveImage(imageSha, isForce)
    % Validate inputs
    if nargin < 2 || isempty(isForce)
        isForce = 0;
    end

    % Check status of default container engine
    [errMsg, engineName] = GetEngine(bst_get('ContainerEngine'));
    if ~isempty(errMsg)
        return
    end

    % Remove image
    switch engineName
        case 'docker'
            if ~isForce
                % Remove image
                [status, cmdout] = system(['docker rmi ' imageSha]);
            else
                % Force remove image
                [status, cmdout] = system(['docker rmi -f ' imageSha]);
            end
            if status ~=0
                errMsg = strtrim(cmdout);
            end
    end
end

