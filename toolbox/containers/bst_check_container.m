function [runtime, image, imageLocal] = bst_check_container(image)
% BST_CHECK_CONTAINER : Check availability of container runtime and image
%
% USAGE:
%   [runtime, image, imageLocal] = bst_check_container()
%   [runtime, image, imageLocal] = bst_check_container(image)
%
% DESCRIPTION:
%   - Detects an available container runtime
%   - Verifies that the runtime is usable (daemon running if required)
%   - Displays Brainstorm GUI dialogs when user action is required
%   - Checks availability of a container image and optionally downloads it
%
% INPUT:
%   image : Container image reference (eg. ghcr.io/user/image:tag)
%           If empty (''): only check the container runtime
%
% OUTPUT:
%   runtime    : Detected runtime ('docker' | 'podman' | 'apptainer' | 'singularity')
%   image      : Unchanged input image reference
%   imageLocal : Local image file for Apptainer/Singularity (.sif), empty otherwise
%
% NOTES:
%   - This function may display GUI dialogs and download container images
%   - No container is executed by this function
%   current duneuro image: 'ghcr.io/maltehoel/duneuro_in_docker_testing:wip';   [for testing]   
%
% TUTORIAL:
%   https://neuroimage.usc.edu/brainstorm/Tutorials/bstContainers
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
% Authors: Takfarinas Medani, 2026
    
    runtime    = '';
    imageLocal = '';

    % ------------------------------------------------------------------
    % Detect runtime
    % ------------------------------------------------------------------
    runtime = detectRuntime();
    if isempty(runtime)
        showRuntimeInstallDialog();
        return;
    end
    
    % ------------------------------------------------------------------
    % Check runtime usability
    % ------------------------------------------------------------------
    if ~runtimeUsable(runtime)
        showRuntimeNotRunningDialog(runtime);
        runtime = '';
        return;
    end
    
    % ------------------------------------------------------------------
    % Ensure image availability
    % ------------------------------------------------------------------
    if ~isempty(image)
        switch runtime
            case {'docker','podman'}
                if ~dockerImageExists(runtime, image)
                    if askPullImageDialog(image)
                        system(sprintf('%s pull %s', runtime, image));
                    else
                        bst_error('Container image is required but was not installed.', ...
                            'Container image missing', 0);
                        runtime = '';
                        return;
                    end
                end
    
            case {'apptainer','singularity'}
                imageLocal = makeSifName(image);
                if ~isfile(imageLocal)
                    if askPullImageDialog(image)
                        system(sprintf('%s pull %s docker://%s', ...
                            runtime, imageLocal, image));
                    else
                        bst_error('Container image is required but was not installed.', ...
                            'Container image missing', 0);
                        runtime = '';
                        imageLocal = '';
                        return;
                    end
                end
        end
    end
end

% =====================================================================
% Runtime detection
% =====================================================================
function runtime = detectRuntime()
    if commandExists('docker')
        runtime = 'docker';
    elseif commandExists('podman')
        runtime = 'podman';
    elseif commandExists('apptainer')
        runtime = 'apptainer';
    elseif commandExists('singularity')
        runtime = 'singularity';
    else
        runtime = '';
    end
end

function tf = commandExists(cmd)
    if ispc
        tf = system(sprintf('where %s >nul 2>&1', cmd)) == 0;
    else
        tf = system(sprintf('command -v %s >/dev/null 2>&1', cmd)) == 0;
    end
end

% =====================================================================
% Runtime usability
% =====================================================================
function ok = runtimeUsable(runtime)
    
    if ispc
        null = ' >nul 2>&1';
    else
        null = ' >/dev/null 2>&1';
    end
    
    switch runtime
        case 'docker'
            [status, out] = system('docker info');
            out = lower(out);
    
            if status ~= 0
                ok = false;
                return;
            end
    
            % Catch common "daemon not running" cases
            if contains(out, 'cannot connect') || ...
                    contains(out, 'is the docker daemon running') || ...
                    contains(out, 'error during connect')
                ok = false;
            else
                ok = true;
            end
    
        case 'podman'
            ok = system(['podman info' null]) == 0;
    
        case {'apptainer','singularity'}
            ok = system([runtime ' version' null]) == 0;
    
        otherwise
            ok = false;
    end
end


% =====================================================================
% Image checks
% =====================================================================
function exists = dockerImageExists(runtime, image)
    exists = system(sprintf('%s image inspect %s >/dev/null 2>&1', ...
        runtime, image)) == 0;
end

function sifFile = makeSifName(image)
    sifFile = regexprep(image, '[^a-zA-Z0-9_.-]', '_');
    sifFile = [sifFile '.sif'];
end

% =====================================================================
% Brainstorm GUI helpers
% =====================================================================
function showRuntimeInstallDialog()

    if ispc
        msg = [ ...
            'No container runtime was detected.' newline newline ...
            'Please install Docker Desktop (WSL2 required):' newline ...
            'https://docs.docker.com/desktop/' ];
    elseif ismac
        msg = [ ...
            'No container runtime was detected.' newline newline ...
            'Please install Docker Desktop:' newline ...
            'https://docs.docker.com/desktop/' ];
    else
        msg = [ ...
            'No container runtime was detected.' newline newline ...
            'Please install ONE of the following:' newline newline ...
            '• Docker: https://docs.docker.com/get-docker/' newline ...
            '• Podman: https://podman.io/get-started' newline ...
            '• Apptainer: https://apptainer.org/' ];
    end
    
    bst_error(msg, 'No container runtime found', 0);
end

function showRuntimeNotRunningDialog(runtime)

    switch runtime
        case 'docker'
            if ispc || ismac
                msg = [ ...
                    'Docker is installed but not running.' newline newline ...
                    'Please start Docker Desktop,' newline ...
                    'wait until it is ready,' newline ...
                    'then retry this operation.' ];
            else
                msg = [ ...
                    'Docker is installed but the daemon is not running.' newline newline ...
                    'You may need to run:' newline ...
                    '  sudo systemctl start docker' ];
            end
        otherwise
            msg = [ ...
                runtime ' is installed but not usable.' newline newline ...
                'Please verify that it is correctly installed ' ...
                'and available in your PATH.' ];
    end
    
    bst_error(msg, 'Container runtime not running', 0);
end

function yes = askPullImageDialog(image)

    choice = java_dialog( ...
        'confirm', ...
        ['The following container image is not installed:' newline newline ...
        image newline newline ...
        'Do you want to download it now?'], ...
        'Container image missing');
    
    yes = (choice == 1);
end