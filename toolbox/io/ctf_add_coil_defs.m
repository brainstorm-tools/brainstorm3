function Channel = ctf_add_coil_defs(Channel, systemName)
% CTF_ADD_COIL_DEFS: Add transformed coil definitions to the channel info.
%
% USAGE:  [Channel] = ctf_add_coil_defs(chs, coil_def_templates)
%
% INPUT:
%     - chs        : original channel definitions
%     - systemName : MEG Acquisition system that was used {'Vectorview306', ...}
%
% OUTPUT:
%     - Channel : Brainstorm Channel structure

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
% Authors: Francois Tadel, 2009-2018
% Adapted from: Matti Hamalainen, MNE toolbox, 2006

me='BST:ctf_add_coil_defs';

%% ===== PARSE INPUT =====
% System name
if (nargin < 2) || isempty(systemName)
    systemName = 'Vectorview306';
end
% Default Accuracy
Accuracy = 1;

% Localize coils definition file
coil_def_file = which('coil_def.dat');
if isempty(coil_def_file)
    error('Coils definition file was not found in path: coil_def.dat');
end
% We need the templates
templates = mne_load_coil_def(coil_def_file);


%% ===== GET COILS TYPES =====
% Intializations
nchan  = length(Channel);
nbMeg  = 0;
CoilDef = cell(1,nchan);
% Define MEG sensors types, respect to acquisition system name
sensCodes = zeros(1,nchan);
switch (lower(systemName))
    case 'vectorview306'
        iMegMag  = find(strcmpi({Channel.Type}, 'MEG MAG'));
        iMegGrad = find(strcmpi({Channel.Type}, 'MEG GRAD'));
        iMegAll = [iMegGrad iMegMag];
        sensCodes(iMegMag)  = 3022;
        sensCodes(iMegGrad) = 3012;        
    case 'ctf'
        % Get MEG sensors
        iMeg = find(strcmpi({Channel.Type}, 'MEG'));
        iRef = find(strcmpi({Channel.Type}, 'MEG REF'));
        iMegAll = [iRef iMeg];
        % Only one possible type of sensors for CTF MEG
        sensCodes(iMeg) = 5001;
        % References are more complicated
        for i = 1:length(iRef)
            % Reference magnetometer
            if (size(Channel(iRef(i)).Loc,2) == 1)
                sensCodes(iRef(i)) = 5002;
            % Reference gradiometers
            elseif (size(Channel(iRef(i)).Loc,2) == 2)
                % Vector between the two coils of the gradiometer
                c1c2 = Channel(iRef(i)).Loc(:,2) - Channel(iRef(i)).Loc(:,1);
                % Reference gradiometers (offdiag):  c1c2 perpendicular to coil orientation (ez)
                if (abs(sum(c1c2 .* Channel(iRef(i)).Orient(:,1))) < 1e-3)
                    sensCodes(iRef(i)) = 5004;
                % Reference gradiometers (diag):  c1c2 parallel to coil orientation (ez)
                else
                    sensCodes(iRef(i)) = 5003;
                end
            else
                warning('ERROR: Unknown MEG reference type.');
            end
        end
    case '4d'
        % Get MEG sensors
        iMeg = find(strcmpi({Channel.Type}, 'MEG'));
        iRef = find(strcmpi({Channel.Type}, 'MEG REF'));
        iMegAll = [iRef iMeg];
    case {'kit', 'ricoh'}
        iMeg     = find(strcmpi({Channel.Type}, 'MEG'));
        iMegMag  = find(strcmpi({Channel.Type}, 'MEG MAG'));
        iMegGrad = find(strcmpi({Channel.Type}, 'MEG GRAD'));
        iRef     = find(strcmpi({Channel.Type}, 'MEG REF'));
        iMegAll = [iRef iMeg iMegMag iMegGrad];
    case 'kriss'
        iMegAll = find(strcmpi({Channel.Type}, 'MEG'));
    otherwise
        error(['Unknown system: "' systemName '".']);
end

% Get the sensor type for the MEG references
for i = 1:nchan
    % If sensor code is already set or not a MEG sensor: skip
    if (sensCodes(i) > 0) || ~ismember(i,iMegAll)
        continue;
    end
    % Try to read code directly in the comment
    scode = str2num(Channel(i).Comment);
    % If found: use it
    if ~isempty(scode)
        sensCodes(i) = scode;
    % If not found: try to find the comment in the coil def file
    else
        iTemplate = find(strcmpi(Channel(i).Comment, {templates.description}));
        % If found: use the sensor number from this template
        if ~isempty(iTemplate)
            sensCodes(i) = templates(iTemplate(1)).id;
        end
    end
end


%% ===== APPLY COILS DEFINITION =====
% Process all channels
for k = 1:nchan
    if (sensCodes(k) > 0)
        % Find a coil definition for this sensor code/Accuracy
        iTemplate = find(([templates.accuracy] == Accuracy) & ([templates.id] == sensCodes(k)), 1);
        if isempty(iTemplate)
            error(me,'Could not find an MEG coil template (coil type = %d Accuracy = %d) for channel %s', ...
                     sensCodes(k), Accuracy, Channel(k).Name);
        end
        temp = templates(iTemplate);
        nbPoints = size(temp.coildefs, 1);
        % Get values from this template
        Channel(k).Weight  = temp.coildefs(:,1)';
        Channel(k).Comment = temp.description;
        Channel(k).Orient  = repmat(Channel(k).Orient(:,1), [1,nbPoints]);
        CoilDef{k} = temp.coildefs(:,2:4);
        nbMeg = nbMeg + 1;
        
        % === CTF LOCATIONS ===
        if strcmpi(systemName, 'CTF') || strcmpi(systemName, '4D') || strcmpi(systemName, 'KIT') || strcmpi(systemName, 'KRISS') || strcmpi(systemName, 'RICOH')
            % Create a vector base for this sensor
            vx = [];
            vz = Channel(k).Orient(:,1) ./ norm(Channel(k).Orient(:,1));
            % CTF reference gradiometers (offdiag)
            if (sensCodes(k) == 5004)
                % Coil location = middle point between the two coils
                chLoc = mean(Channel(k).Loc,2);
                % vx points from the second coil to the first
                vx = Channel(k).Loc(:,1) - Channel(k).Loc(:,2);
                vx = vx ./ norm(vx);
            % 4D reference gradiometers (offdiag)
            elseif (sensCodes(k) == 4005)
                % Coil location = middle point between the two coils
                chLoc = mean(Channel(k).Loc,2);
                % vx points from the first coil to the second
                vx = Channel(k).Loc(:,2) - Channel(k).Loc(:,1);
                vx = vx ./ norm(vx);
            % 4D reference gradiometers (diag)
            elseif (sensCodes(k) == 4004)
                % Swap the coils if the orient vector is not pointing at the second coil
                chLoc = Channel(k).Loc(:,2);
            % Other sensors: Build an arbitrary base
            else
                chLoc = Channel(k).Loc(:,1);
            end
            % Build vx and vy (based on Matti Hamalainen's function)
            if isempty(vx)
                [ U, S, V ]  = svd(eye(3,3) - vz*vz');
                %  Make sure that ez is in the direction of the orientation matrix
                if vz'*U(:,3) < 0
                    U(:,3) = -U(:,3);
                end
                % Get the first (X) and last (Z) components
                vx = U(:,1);
                %vy = U(:,2);
                vz = U(:,3);
            end
            % Compute the Y vector
            vy = cross(vx,vz);
            % Reconstruct locations for all the integration points of the coil
            transf = [vx vy vz chLoc];
            nbPoints = size(CoilDef{k}, 1);
            Channel(k).Loc = (transf * [ CoilDef{k}'; ones(1,nbPoints) ]);
        end
    end
end

% === NEUROMAG LOCATIONS ===
% If Vectorview: Need all groups (1 magneto + 2 gradio) to get the positions
if strcmpi(systemName, 'Vectorview306') && (nbMeg == 306)
    firstMeg = min(iMegAll);
    for i = firstMeg:3:firstMeg+306-1
        % Get a base of vectors to represent the sensor
        vx = Channel(i).Loc(:,1) - Channel(i).Loc(:,2);     % Gradio 1
        vy = Channel(i+1).Loc(:,1) - Channel(i+1).Loc(:,2); % Gradio 2
        vz = Channel(i).Orient(:,1);
        % Normalize base
        vx = vx / norm(vx);
        vy = vy / norm(vy);
        vz = vz / norm(vz);
        % Reconstruct the transformation that was initially present in the FIF file
        pos = Channel(i+2).Loc(:,1);
        transf1 = [vx  vy vz pos];
        transf2 = [vy -vx vz pos];
        transf3 = [vx  vy vz pos];
        % Apply these transformations to the sensors definitions
        nbPoints = size(CoilDef{i}, 1);
        Channel(i).Loc   = (transf1 * [ CoilDef{i}'   ; ones(1,nbPoints) ]);
        Channel(i+1).Loc = (transf2 * [ CoilDef{i+1}' ; ones(1,nbPoints) ]);
        Channel(i+2).Loc = (transf3 * [ CoilDef{i+2}' ; ones(1,nbPoints) ]);
    end
end

% fprintf(1,'CTF> %d MEG coil definitions set up.\n',nbMeg);






